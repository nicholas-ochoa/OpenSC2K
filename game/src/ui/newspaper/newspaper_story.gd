class_name NewspaperStory
extends Control
## One newspaper panel: an optional title and headline, story copy in one or two
## justified columns, and a continuation notice when the copy does not fit.
## The panel opens the full story when the player clicks it or presses Enter.

@warning_ignore_start("integer_division")

signal read_requested(title: String, text: String)

const INK := Color("#171713")
const RULE := Color("#666666")
const REPORT_RULE := Color("#777777")
const FOCUS := Color("#555555")
const COLUMN_GAP := 16.0
const COLUMN_STEP := 131.0
const MAX_COLUMNS := 2
const COPY_SIZE := 13
const COPY_LINE := 15.6
const TITLE_SIZE := 17
const TITLE_LINE := 17.85
const HEADING_SIZE := 19
const HEADING_LINE := 20.52
const HEADING_GAP := 5.0
const NOTICE_SIZE := 10
const NOTICE_LINE := 11.2
const NOTICE_GAP := 3.0
const REPORT_PADDING := 7.0
# the smallest free space below a story that can hold another story
const MIN_FREE_HEIGHT := 48.0

var title_text := ""
var heading_text := ""
var copy_text := ""
var notice_text := ""
var read_title := ""
var read_text := ""
var report := false
var columns := 1
var truncated := false
var copy_top := 0.0
var copy_height := 0.0
var rows := 0

var _title: TextParagraph
var _heading: TextParagraph
var _copy: TextParagraph
var _notice: TextParagraph
var _hovered := false

static var _spaces := RegEx.create_from_string("\\s+")


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


# the column count that a panel width allows
static func columns_for_width(width: float) -> int:
	return clampi(floori((width + COLUMN_GAP) / COLUMN_STEP), 1, MAX_COLUMNS)


# joins the words of a story with single spaces
static func collapse_spaces(text: String) -> String:
	return _spaces.sub(text.strip_edges(), " ", true)


static func paragraph(text: String, font: Font, font_size: int, width: float,
		alignment: HorizontalAlignment) -> TextParagraph:
	var result := TextParagraph.new()
	result.width = maxf(1.0, width)
	result.alignment = alignment
	result.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	result.justification_flags |= TextServer.JUSTIFICATION_TRIM_EDGE_SPACES
	result.add_string(text, font, font_size)

	return result


# draws each line on a fixed line pitch, like a CSS line-height. draw_line
# justifies a filled line but does not move a centered or right-aligned line
static func draw_paragraph(canvas: RID, text: TextParagraph, origin: Vector2, line_height: float, color: Color) -> void:
	for line in text.get_line_count():
		var line_size := text.get_line_size(line)
		var offset := Vector2(line_indent(text, line), line * line_height + (line_height - line_size.y) / 2.0)
		text.draw_line(canvas, origin + offset, line, color)


static func line_indent(text: TextParagraph, line: int) -> float:
	var spare := text.width - text.get_line_size(line).x

	match text.alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			return spare / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			return spare

	return 0.0


static func paragraph_height(text: TextParagraph, line_height: float) -> float:
	return 0.0 if text == null else text.get_line_count() * line_height


# places the panel and fits its copy. a complete story uses the smallest
# balanced column height. a long story fills the panel and ends with the notice
func fit(rect: Rect2) -> void:
	position = rect.position
	size = Vector2(maxf(1.0, rect.size.x), maxf(1.0, rect.size.y))
	var padding := _padding()
	var top := padding
	_title = null
	_heading = null

	if not title_text.is_empty():
		_title = paragraph(title_text, NewspaperFonts.body_bold(), TITLE_SIZE, size.x, HORIZONTAL_ALIGNMENT_CENTER)
		top += paragraph_height(_title, TITLE_LINE) + HEADING_GAP

	if not heading_text.is_empty():
		_heading = paragraph(heading_text, NewspaperFonts.headline(), HEADING_SIZE, size.x, HORIZONTAL_ALIGNMENT_CENTER)
		top += paragraph_height(_heading, HEADING_LINE) + HEADING_GAP

	copy_top = top
	var available := maxf(0.0, size.y - top - padding)
	var text := collapse_spaces(copy_text)
	_copy = paragraph(text, NewspaperFonts.body(), COPY_SIZE, column_width(), HORIZONTAL_ALIGNMENT_FILL)
	var lines := 0 if text.is_empty() else _copy.get_line_count()
	truncated = lines > floori(available / COPY_LINE) * columns

	if not truncated:
		rows = ceili(float(lines) / columns)
		copy_height = minf(available, rows * COPY_LINE + 1.0)
		_notice = null
		queue_redraw()

		return

	_notice = paragraph(notice_text, NewspaperFonts.body_italic(), NOTICE_SIZE, size.x, HORIZONTAL_ALIGNMENT_RIGHT)
	copy_height = maxf(0.0, available - NOTICE_GAP - NOTICE_LINE)
	rows = floori(copy_height / COPY_LINE)
	var shown := rows * columns

	if shown > 0:
		# greedy wrapping keeps the line breaks of a prefix, and the last shown
		# line is no longer justified
		var end := _copy.get_line_range(shown - 1).y
		_copy = paragraph(text.substr(0, end).strip_edges(), NewspaperFonts.body(), COPY_SIZE, column_width(),
			HORIZONTAL_ALIGNMENT_FILL)
	else:
		_copy = null

	queue_redraw()


func column_width() -> float:
	return (size.x - COLUMN_GAP * (columns - 1)) / columns


func shows_copy() -> bool:
	return _copy != null and rows > 0 and _copy.get_line_count() > 0 and copy_height >= COPY_LINE


func copy_fits() -> bool:
	return _copy == null or _copy.get_line_count() <= rows * columns


# the headings, copy and notice stay inside the panel
func fits() -> bool:
	var bottom := copy_top + copy_height + _padding()

	if _notice != null:
		bottom += NOTICE_GAP + NOTICE_LINE

	return copy_fits() and bottom <= size.y + 0.5


# shrinks a complete story to its text and returns the free space below it
func take_free_space(gap: float) -> Rect2:
	if truncated:
		return Rect2()

	var used := ceilf(copy_top + copy_height + _padding() + 2.0)
	var remaining := size.y - used - gap

	if remaining < MIN_FREE_HEIGHT:
		return Rect2()

	size.y = used

	return Rect2(position.x, position.y + used + gap, size.x, remaining)


func _padding() -> float:
	return REPORT_PADDING if report else 0.0


func _draw() -> void:
	var canvas := get_canvas_item()

	if report:
		draw_line(Vector2(0.0, 0.5), Vector2(size.x, 0.5), REPORT_RULE)
		draw_line(Vector2(0.0, size.y - 0.5), Vector2(size.x, size.y - 0.5), REPORT_RULE)

	var top := _padding()

	if _title != null:
		draw_paragraph(canvas, _title, Vector2(0.0, top), TITLE_LINE, INK)
		top += paragraph_height(_title, TITLE_LINE) + HEADING_GAP

	if _heading != null:
		draw_paragraph(canvas, _heading, Vector2(0.0, top), HEADING_LINE, INK)

		if _hovered:
			_underline(_heading, top)

	if _copy != null and rows > 0:
		var step := column_width() + COLUMN_GAP

		for line in _copy.get_line_count():
			var column := line / rows
			var line_size := _copy.get_line_size(line)
			var origin := Vector2(column * step, copy_top + (line % rows) * COPY_LINE + (COPY_LINE - line_size.y) / 2.0)
			_copy.draw_line(canvas, origin, line, INK)

		for column in range(1, columns):
			if column * rows < _copy.get_line_count():
				var x := floorf(column * step - COLUMN_GAP / 2.0) + 0.5
				draw_line(Vector2(x, copy_top), Vector2(x, copy_top + copy_height), RULE)

	if _notice != null:
		draw_paragraph(canvas, _notice, Vector2(0.0, copy_top + copy_height + NOTICE_GAP), NOTICE_LINE, INK)

	if has_focus(true):
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2.0, 2.0)), FOCUS, false, 2.0)


func _underline(text: TextParagraph, top: float) -> void:
	for line in text.get_line_count():
		var width := text.get_line_size(line).x
		var x := line_indent(text, line)
		var y := top + line * HEADING_LINE + HEADING_LINE - 2.0
		draw_line(Vector2(x, y), Vector2(x + width, y), INK)


func _gui_input(event: InputEvent) -> void:
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT

	if clicked or event.is_action_pressed("ui_accept"):
		accept_event()
		read_requested.emit(read_title, read_text)


func _set_hovered(value: bool) -> void:
	_hovered = value
	queue_redraw()
