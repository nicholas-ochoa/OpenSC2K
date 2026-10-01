class_name DebugVirtualTable
extends Control
## A table that draws only the rows in view. It holds the row order, not the
## rows: a DebugTableSource builds each row when the table first draws it. A
## table of 32,768 records costs the same to draw and scroll as one of 150.
## A row can open to show its field rows under it.

signal title_clicked(column: int)
signal locate_clicked(id: String)
# an editable cell changed: the record ID, the field row from 0, the column and the text
signal cell_edited(id: String, field: int, column: int, text: String)

const CELL_PADDING := 8
const ROW_PADDING := 6
const FIELD_INDENT := 18
# a wheel step scrolls this part of a page, as a Tree does. a trackpad sends
# steps of a smaller factor
const WHEEL_PAGE_PART := 1.0 / 8.0
const WARNING_COLOR := Color(1.0, 0.85, 0.2, 0.3)
const ELLIPSIS := "…"
# the field part of a display row: 0 is the record row, n is field n - 1
const FIELD_BITS := 16
const FIELD_MASK := (1 << FIELD_BITS) - 1

var titles: Array = []
var title_tooltips: Array = []
var minimum_widths: Array = []
var locate_column := -1
var locate_icon: Texture2D
# the last column takes the free width
var expand_last := true
var source: DebugTableSource
# indices of source.ids in display order. a filter leaves rows out
var order := PackedInt32Array()
var expanded: Dictionary[String, bool] = {}
var selected := ""
# (record: DebugTableRecord, field: int, column: int) -> bool
var editable := Callable()
var _display := PackedInt64Array()
var _widths: Array[float] = []
var _v_scroll := VScrollBar.new()
var _h_scroll := HScrollBar.new()
var _editor := LineEdit.new()
var _edit_target: Array = []
# the display row under the mouse, or -1
var _hovered := -1
# the rows draw here, clipped below the header
var _body := Control.new()


func _init() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_CLICK
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.name = "Rows"
	_body.clip_contents = true
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.draw.connect(_draw_rows)
	add_child(_body)
	_v_scroll.value_changed.connect(func(_value: float) -> void: _hover_mouse())
	_h_scroll.value_changed.connect(func(_value: float) -> void: _redraw())
	add_child(_v_scroll)
	add_child(_h_scroll)
	_editor.hide()
	_editor.text_submitted.connect(_commit_edit)
	_editor.focus_exited.connect(_cancel_edit)
	add_child(_editor)
	resized.connect(_layout_scrollbars)
	mouse_exited.connect(_set_hovered.bind(-1))


func _draw() -> void:
	draw_style_box(get_theme_stylebox("panel", "Tree"), Rect2(Vector2.ZERO, size))
	var scroll := _scroll_pixels()
	var first := int(scroll / _row_height())
	var last := mini(_display.size(), int((scroll + _body_height()) / _row_height()) + 1)

	if _fit_visible(first, last):
		_layout_scrollbars()

	_draw_header(_font(), _font_size(), _column_offset(), _draw_widths())
	_body.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var pan := event as InputEventPanGesture

	# a trackpad pan, as a Tree scrolls it
	if pan != null:
		_v_scroll.value += _v_scroll.page * pan.delta.y * WHEEL_PAGE_PART
		_h_scroll.value += _h_scroll.page * pan.delta.x * WHEEL_PAGE_PART
		accept_event()

		return

	if event is InputEventMouseMotion:
		var target := hit((event as InputEventMouseMotion).position)
		_set_hovered(target[0] if target[0] >= 0 else -1)

		return

	var button := event as InputEventMouseButton

	if button == null or not button.pressed:
		return

	var factor := button.factor if button.factor > 0.0 else 1.0

	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			var step := (-1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0) * factor * WHEEL_PAGE_PART

			if button.shift_pressed:
				_h_scroll.value += step * _h_scroll.page
			else:
				_v_scroll.value += step * _v_scroll.page

			accept_event()
		MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
			var step := (-1.0 if button.button_index == MOUSE_BUTTON_WHEEL_LEFT else 1.0) * factor * WHEEL_PAGE_PART
			_h_scroll.value += step * _h_scroll.page
			accept_event()
		MOUSE_BUTTON_LEFT:
			_click(button)
			accept_event()


func _get_tooltip(at: Vector2) -> String:
	var target := hit(at)

	if target[1] < 0:
		return ""

	if target[0] == -2:
		return str(title_tooltips[target[1]]) if target[1] < title_tooltips.size() else ""

	if target[0] < 0:
		return ""

	var entry := display_row(target[0])

	return tooltip_of(entry[0], entry[1], target[1])


# the rows, on a clipped area under the header. the scroll value is in pixels,
# so a row can show in part
func _draw_rows() -> void:
	var font := _font()
	var font_size := _font_size()
	var color := get_theme_color("font_color", "Tree")
	var scroll := _scroll_pixels()
	var row_height := _row_height()
	var first := int(scroll / row_height)
	var last := mini(_display.size(), int((scroll + _body_height()) / row_height) + 1)
	var offset := _column_offset()
	var baseline := (row_height + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var available := _body.size.x
	var widths := _draw_widths()
	var selected_box := get_theme_stylebox("selected", "Tree")
	var hovered_box := get_theme_stylebox("hovered", "Tree")
	var hovered_selected_box := get_theme_stylebox("hovered_selected", "Tree")
	var guides := get_theme_constant("draw_guides", "Tree") != 0
	var guide_color := get_theme_color("guide_color", "Tree")

	for index in range(first, last):
		var y := index * row_height - scroll
		var row := display_row(index)
		var id: String = row[0]
		var field: int = row[1]
		var record := source.row(id)
		var rect := Rect2(0, y, available, row_height)

		if field < 0 and not record.warning.is_empty():
			_body.draw_rect(rect, WARNING_COLOR)

		if id == selected and field < 0:
			_body.draw_style_box(hovered_selected_box if index == _hovered else selected_box, rect)
		elif index == _hovered:
			_body.draw_style_box(hovered_box, rect)

		if guides:
			_body.draw_line(Vector2(0, y + row_height - 0.5), Vector2(available, y + row_height - 0.5), guide_color)

		var cells := cells_of(id, field)
		var x := offset

		for column in widths.size():
			var width: float = widths[column]

			if column == locate_column:
				if field < 0 and record.site != null and locate_icon != null:
					var icon_at := Vector2(x + (width - locate_icon.get_width()) * 0.5, y + (row_height - locate_icon.get_height()) * 0.5)
					_body.draw_texture(locate_icon, icon_at, color)
			elif column < cells.size():
				var indent := 0.0

				if column == 0:
					indent = FIELD_INDENT if field >= 0 else 0.0

					if field < 0 and not record.fields.is_empty():
						var arrow := get_theme_icon("arrow" if expanded.has(id) else "arrow_collapsed", "Tree")
						_body.draw_texture(arrow, Vector2(x + 2, y + (row_height - arrow.get_height()) * 0.5), color)

					indent += FIELD_INDENT

				var room := width - CELL_PADDING * 2 - indent
				var text := _fit_text(cells[column], room, font, font_size)
				_body.draw_string(font, Vector2(x + CELL_PADDING + indent, y + baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
					font_size, color)

			x += width


# a scroll moves other rows under a still mouse
func _hover_mouse() -> void:
	var at := get_local_mouse_position()
	var inside := Rect2(Vector2.ZERO, size).has_point(at)
	var target := hit(at) if inside else [-1, -1]
	_hovered = target[0] if target[0] >= 0 else -1
	_redraw()


func _set_hovered(row: int) -> void:
	if row != _hovered:
		_hovered = row
		_redraw()


func set_columns(column_titles: Array, tooltips: Array, widths: Array, locate := -1) -> void:
	titles = column_titles.duplicate()
	title_tooltips = tooltips.duplicate()
	minimum_widths = widths.duplicate()
	locate_column = locate
	reset_widths()


func set_title(column: int, text: String) -> void:
	titles[column] = text
	_redraw()


func column_count() -> int:
	return titles.size()


# show `rows`, indices of the source IDs. expanded rows and the selection stay
func show_rows(rows_source: DebugTableSource, rows: PackedInt32Array) -> void:
	source = rows_source
	order = rows
	_rebuild_display()


func toggle(id: String) -> void:
	set_expanded(id, not expanded.has(id))


func set_expanded(id: String, open: bool) -> void:
	if open:
		expanded[id] = true
	else:
		expanded.erase(id)

	_rebuild_display()


func is_expanded(id: String) -> bool:
	return expanded.has(id)


func display_count() -> int:
	return _display.size()


# [record ID, field row or -1] of a display row
func display_row(index: int) -> Array:
	var entry := _display[index]

	return [source.ids[entry >> FIELD_BITS], int(entry & FIELD_MASK) - 1]


# the cells of a record row, or of one of its field rows, in column order
func cells_of(id: String, field := -1) -> Array[String]:
	var record := source.row(id)

	if field >= 0:
		record = record.fields[field]

	return with_locate(record_cells(record, source.with_position), locate_column)


func tooltip_of(id: String, field: int, column: int) -> String:
	var record := source.row(id)

	if field < 0 and not record.warning.is_empty():
		return record.warning

	var item := record.fields[field] if field >= 0 else record
	var tooltips: Array = with_locate(item.tooltips, locate_column) if not item.tooltips.is_empty() else []

	if column == locate_column:
		return "Center the map here" if field < 0 and record.site != null else ""

	if column < tooltips.size() and not str(tooltips[column]).is_empty():
		return str(tooltips[column])

	var cells := cells_of(id, field)

	return cells[column] if column < cells.size() else ""


func column_width(column: int) -> float:
	return _widths[column] if column < _widths.size() else 0.0


func reset_widths() -> void:
	_widths.clear()

	for column in titles.size():
		_widths.append(float(minimum_widths[column]) if column < minimum_widths.size() else 0.0)

	_redraw()


func scroll_to(id: String) -> void:
	for index in _display.size():
		if source.ids[_display[index] >> FIELD_BITS] == id:
			_v_scroll.value = (index + 0.5) * _row_height() - _body_height() * 0.5

			return


# the cells of a record for the standard columns: name, value, raw value,
# position for MicroSims, and details. a row with its own cells keeps them
static func record_cells(record: DebugTableRecord, with_position := false) -> Array[String]:
	if not record.cells.is_empty():
		return record.cells.duplicate()

	var cells: Array[String] = [record.name, record.value, record.raw]

	if with_position:
		cells.append(record.position)

	cells.append(record.detail)

	return cells


static func with_locate(cells: Array, column: int) -> Array[String]:
	var result: Array[String] = []
	result.assign(cells)

	if column >= 0 and not result.is_empty() and column <= result.size():
		result.insert(column, "")

	return result


func _rebuild_display() -> void:
	_display = PackedInt64Array()

	if source == null:
		_layout_scrollbars()

		return

	_display.resize(order.size())
	var at := 0

	for index in order:
		_display[at] = int(index) << FIELD_BITS
		at += 1
		var id := source.ids[index]

		if not expanded.has(id):
			continue

		var fields := source.row(id).fields.size()
		_display.resize(_display.size() + fields)

		for field in fields:
			_display[at] = (int(index) << FIELD_BITS) | (field + 1)
			at += 1

	_layout_scrollbars()
	_redraw()


func _font() -> Font:
	return get_theme_font("font", "Tree")


func _font_size() -> int:
	return get_theme_font_size("font_size", "Tree")


func _row_height() -> float:
	return _font().get_height(_font_size()) + ROW_PADDING


func _header_height() -> float:
	return _row_height() + 4.0


# the header and the rows draw again
func _redraw() -> void:
	queue_redraw()
	_body.queue_redraw()


func _scroll_pixels() -> float:
	return _v_scroll.value if _v_scroll.visible else 0.0


func _column_offset() -> float:
	return -_h_scroll.value if _h_scroll.visible else 0.0


# the column widths to draw. the last column takes the free width
func _draw_widths() -> Array:
	var widths := _widths.duplicate()
	var available := size.x - (_v_scroll.size.x if _v_scroll.visible else 0.0)

	if expand_last and not widths.is_empty() and _total_width() < available:
		widths[-1] += available - _total_width()

	return widths


# the height of the rows area, between the header and the horizontal scroll bar
func _body_height() -> float:
	return maxf(0.0, size.y - _header_height() - (_h_scroll.size.y if _h_scroll.visible else 0.0))


func _layout_scrollbars() -> void:
	var bar := _v_scroll.get_combined_minimum_size().x
	var bar_height := _h_scroll.get_combined_minimum_size().y
	_v_scroll.position = Vector2(size.x - bar, _header_height())
	_v_scroll.size = Vector2(bar, maxf(0.0, size.y - _header_height() - bar_height))
	_h_scroll.position = Vector2(0, size.y - bar_height)
	_h_scroll.size = Vector2(maxf(0.0, size.x - bar), bar_height)
	var total := _total_width()
	_h_scroll.max_value = total
	_h_scroll.page = size.x - bar
	_h_scroll.visible = total > size.x - bar
	_v_scroll.max_value = _display.size() * _row_height()
	_v_scroll.page = _body_height()
	_v_scroll.visible = _v_scroll.max_value > _v_scroll.page
	_body.position = Vector2(0, _header_height())
	_body.size = Vector2(size.x - (_v_scroll.size.x if _v_scroll.visible else 0.0), _body_height())


func _total_width() -> float:
	var total := 0.0

	for width in _widths:
		total += width

	return total


# fit the columns to the titles and the rows in view. widths only grow, so a
# scroll does not move the columns
func _fit_visible(first: int, last: int) -> bool:
	var font := _font()
	var font_size := _font_size()
	var changed := false

	for column in titles.size():
		var width := font.get_string_size(str(titles[column]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + CELL_PADDING * 2

		if width > _widths[column]:
			_widths[column] = width
			changed = true

	for index in range(first, last):
		var row := display_row(index)
		var cells := cells_of(row[0], row[1])

		for column in mini(cells.size(), titles.size()):
			var extra: float = CELL_PADDING * 2 + (FIELD_INDENT if column == 0 else 0)
			var width := font.get_string_size(cells[column], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + extra

			if width > _widths[column]:
				_widths[column] = width
				changed = true

	return changed


func _draw_header(font: Font, font_size: int, offset: float, widths: Array) -> void:
	var height := _header_height()
	var box := get_theme_stylebox("title_button_normal", "Tree")
	var color := get_theme_color("title_button_color", "Tree")
	var x := offset

	for column in widths.size():
		var width: float = widths[column]
		draw_style_box(box, Rect2(x, 0, width, height))
		var baseline := (height + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		var text := _fit_text(str(titles[column]), width - CELL_PADDING * 2, font, font_size)
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(x + (width - text_width) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += width


# the text, cut with an ellipsis to `room` pixels
static func _fit_text(text: String, room: float, font: Font, font_size: int) -> String:
	if text.is_empty() or font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= room:
		return text

	var length := text.length()

	while length > 0 and font.get_string_size(text.left(length) + ELLIPSIS, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		length = length * 3 / 4 if length > 8 else length - 1

	return text.left(length) + ELLIPSIS if length > 0 else ""


# [display row or -1, column or -1] at a point. row -2 is the header
func hit(at: Vector2) -> Array:
	var column := -1
	var x := _column_offset()
	var widths := _draw_widths()

	for index in widths.size():
		if at.x >= x and at.x < x + float(widths[index]):
			column = index
			break

		x += float(widths[index])

	if at.y < _header_height():
		return [-2, column]

	var scroll := _v_scroll.value if _v_scroll.visible else 0.0
	var row := int((at.y - _header_height() + scroll) / _row_height())

	return [row if row < _display.size() else -1, column]


func _click(button: InputEventMouseButton) -> void:
	var target := hit(button.position)
	var row: int = target[0]
	var column: int = target[1]

	if row == -2:
		if column >= 0:
			title_clicked.emit(column)

		return

	if row < 0:
		return

	var entry := display_row(row)
	var id: String = entry[0]
	var field: int = entry[1]
	var record := source.row(id)

	if field < 0:
		selected = id

	if field < 0 and column == locate_column:
		locate_clicked.emit(id)
	elif field < 0 and column == 0 and not record.fields.is_empty() and (button.double_click or _on_arrow(button.position)):
		toggle(id)
	elif button.double_click and editable.is_valid() and editable.call(record, field, column):
		_begin_edit(row, id, field, column)

	_redraw()


func _on_arrow(at: Vector2) -> bool:
	var x := -_h_scroll.value if _h_scroll.visible else 0.0

	return at.x >= x and at.x < x + FIELD_INDENT + 4


func _begin_edit(row: int, id: String, field: int, column: int) -> void:
	var x := -_h_scroll.value if _h_scroll.visible else 0.0

	for index in column:
		x += _widths[index]

	_edit_target = [id, field, column]
	var scroll := _v_scroll.value if _v_scroll.visible else 0.0
	_editor.position = Vector2(x, _header_height() + row * _row_height() - scroll)
	_editor.size = Vector2(_widths[column], _row_height())
	_editor.text = cells_of(id, field)[column]
	_editor.show()
	_editor.grab_focus()
	_editor.select_all()


func _commit_edit(text: String) -> void:
	if _edit_target.is_empty():
		return

	var target := _edit_target
	_edit_target = []
	_editor.hide()
	cell_edited.emit(target[0], target[1], target[2], text)


func _cancel_edit() -> void:
	_edit_target = []
	_editor.hide()


func is_editing() -> bool:
	return _editor.visible
