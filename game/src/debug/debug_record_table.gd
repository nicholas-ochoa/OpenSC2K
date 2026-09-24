class_name DebugRecordTable
extends VBoxContainer


signal locate_requested(site: Rect2i)

# yellow row background for a record with a warning. it stays readable in light and dark themes
const WARNING_COLOR := Color(1.0, 0.85, 0.2, 0.3)

@export var kind := "XMIC"
var rows: Dictionary = {}
var _last_refresh := -1000
var _host: Control
var _city_id := 0
# column holding the locate icon; -1 when this table has none
var locate_column := -1
var _locate_icon: Texture2D
var _titles: Array = []
# columns sized to their widest cell after each refresh
var _fitted_columns: Array[int] = []
# sorted column and direction; -1 keeps record order
var sort_column := -1
var sort_descending := false
@onready var table: Tree = $Table
@onready var search: LineEdit = $Controls/Search
@onready var show_empty: CheckBox = $Controls/ShowEmpty
@onready var live: CheckBox = $Controls/Live


func _ready() -> void:
	var titles := ["Record / field", "Value", "Hex", "Details"]
	var widths := [240, 160, 140, 270]
	var tooltips := {}

	if kind == "State":
		titles = ["Field", "Value", "Hex", "Description"]
	elif kind == "XMIC":
		titles.insert(3, "Position")
		widths.insert(3, 150)
		locate_column = 4
	elif kind == "Tiles":
		titles = ["Tile", "Constant", "Name", "On map", "Saved count"]
		widths = [0, 0, 0, 0, 0]
		locate_column = 1
		tooltips = {
			"Tile": "Building ID in the XBLD tile plane.",
			"Constant": "BuildingTileIds constant for the ID.",
			"Name": "Name that the query tool shows for the tile.",
			"On map": "Number of map tiles with this building ID outside military zones. Military bases have separate counts.",
			"Saved count": "Tile count that the city stores in MISC. The edit tools keep it up to date.",
		}
	elif kind == "Objects":
		titles = ["Object"]
		widths = [0]
		locate_column = 1
		tooltips["Object"] = "Record number of the moving thing in the saved city."

		for key: String in DebugObjectFields.COLUMNS:
			var title := key.capitalize() if key.length() > 2 else key.to_upper()
			titles.append(title)
			widths.append(0)
			tooltips[title] = DebugObjectFields.COLUMN_TOOLTIPS[key]

	if locate_column >= 0:
		# a plain icon column: tree omits row guide lines under item buttons
		titles.insert(locate_column, "")
		widths.insert(locate_column, 28)
		tooltips[""] = "Click the crosshair in a row to center the map on it."
		_locate_icon = locate_icon(12)
		table.gui_input.connect(_on_table_input)

	table.columns = titles.size()
	_titles = titles

	table.column_title_clicked.connect(_on_column_title_clicked)

	for column in titles.size():
		table.set_column_title(column, titles[column])
		table.set_column_title_tooltip_text(column, tooltips.get(titles[column], ""))
		table.set_column_custom_minimum_width(column, widths[column])
		table.set_column_expand(column, column == titles.size() - 1)

		if widths[column] == 0:
			_fitted_columns.append(column)

	if not _fitted_columns.is_empty():
		table.item_collapsed.connect(func(_item: TreeItem) -> void: _fit_columns())

	if kind == "State":
		sort_by(0)

	show_empty.visible = kind != "State"
	search.text_changed.connect(func(_text: String) -> void: _filter())
	show_empty.toggled.connect(func(_enabled: bool) -> void: refresh_from_host(_host, true))
	$Controls/Refresh.pressed.connect(func() -> void: refresh_from_host(_host, true))


func refresh_from_host(host: Control, force := false) -> void:
	_host = host

	if not is_instance_valid(host):
		return

	var document := host.get("document_state") as ActiveDocumentState
	var city: CityState = document.city if document != null else null
	var city_id := city.get_instance_id() if city != null else 0
	var changed_city := city_id != _city_id

	if not force and not changed_city and (not live.button_pressed or Time.get_ticks_msec() - _last_refresh < 1000):
		return

	if changed_city:
		table.clear()
		rows.clear()
		_city_id = city_id

	_last_refresh = Time.get_ticks_msec()
	var simulation := host.get("simulation_state") as SimulationSessionState
	var engine: SimulationEngine = simulation.simulation_engine if simulation != null else null
	update_records(DebugCityTables.collect(kind, city, engine, show_empty.button_pressed))


func update_records(records: Array[DebugTableRecord]) -> void:
	if table.get_root() == null:
		table.create_item()

	var retained := {}

	for order in records.size():
		var record := records[order]
		var id: String = record.id
		retained[id] = true
		var row: TreeItem = rows.get(id)

		if row == null:
			row = table.create_item(table.get_root())
			row.collapsed = true
			rows[id] = row

		_set_cells(row, record)
		row.set_meta("order", order)
		var fields := record.fields

		while row.get_child_count() > fields.size():
			row.get_child(row.get_child_count() - 1).free()

		for index in fields.size():
			var child := row.get_child(index) if index < row.get_child_count() else table.create_item(row)
			_set_cells(child, fields[index])

	for id in rows.keys():
		if not retained.has(id):
			rows[id].free()
			rows.erase(id)

	_apply_sort()
	_filter()
	_fit_columns()


func sort_by(column: int, descending := false) -> void:
	sort_column = column
	sort_descending = descending

	for index in _titles.size():
		var marker := "" if index != column else (" ▼" if descending else " ▲")
		table.set_column_title(index, str(_titles[index]) + marker)

	_apply_sort()


# title clicks cycle ascending, descending, then record order
func _on_column_title_clicked(column: int, mouse_button: int) -> void:
	if mouse_button != MOUSE_BUTTON_LEFT:
		return

	if column != sort_column:
		sort_by(column)
	elif not sort_descending:
		sort_by(column, true)
	else:
		sort_by(-1)


func _apply_sort() -> void:
	var root := table.get_root()

	if root == null:
		return

	var ordered: Array[TreeItem] = []
	var item := root.get_first_child()

	while item != null:
		ordered.append(item)
		item = item.get_next()

	var sorted := ordered.duplicate()
	sorted.sort_custom(_row_before)

	if sorted == ordered:
		return

	# move rows in place so expansion, selection and scrolling survive
	sorted[0].move_before(root.get_first_child())

	for index in range(1, sorted.size()):
		sorted[index].move_after(sorted[index - 1])


func _row_before(a: TreeItem, b: TreeItem) -> bool:
	if sort_column >= 0:
		var a_keys: Array = a.get_meta("sort", [])
		var b_keys: Array = b.get_meta("sort", [])
		var a_key: Variant = a_keys[sort_column] if sort_column < a_keys.size() else a.get_text(sort_column)
		var b_key: Variant = b_keys[sort_column] if sort_column < b_keys.size() else b.get_text(sort_column)

		# missing values stay last in both directions
		if (a_key == null) != (b_key == null):
			return b_key == null

		var order := compare_keys(a_key, b_key)

		if order != 0:
			return order > 0 if sort_descending else order < 0

	return int(a.get_meta("order", 0)) < int(b.get_meta("order", 0))


static func compare_keys(a: Variant, b: Variant) -> int:
	if a == null or b == null:
		return 0

	if a is Array and b is Array:
		for index in mini(a.size(), b.size()):
			var order := compare_keys(a[index], b[index])

			if order != 0:
				return order

		return signi(a.size() - b.size())

	if (a is int or a is float) and (b is int or b is float):
		return -1 if a < b else (1 if a > b else 0)

	return str(a).naturalnocasecmp_to(str(b))


func _set_cells(row: TreeItem, record: DebugTableRecord) -> void:
	var cells := record.cells.duplicate()
	var tooltips := record.tooltips.duplicate()

	if not cells.is_empty() and locate_column >= 0:
		cells.insert(locate_column, "")

		if tooltips.size() >= locate_column:
			tooltips.insert(locate_column, "")

	if cells.is_empty():
		for key in ["name", "value", "raw", "position", "detail"] if kind == "XMIC" else ["name", "value", "raw", "detail"]:
			cells.append(str(record.get(key)))

		if kind == "XMIC":
			cells.insert(locate_column, "")

	for column in table.columns:
		var text := str(cells[column])
		row.set_text(column, text)
		row.set_tooltip_text(column, str(tooltips[column]) if column < tooltips.size() else text)

		if record.warning.is_empty():
			row.clear_custom_bg_color(column)
		else:
			row.set_custom_bg_color(column, WARNING_COLOR)
			row.set_tooltip_text(column, record.warning)

	var sort: Array = record.sort.duplicate()

	if not sort.is_empty() and locate_column >= 0:
		var site: CityRecords.Site = record.site
		sort.insert(locate_column, null if site == null else [site.x, site.y])

	row.set_meta("sort", sort)

	if locate_column >= 0:
		_set_locate_icon(row, record.site)


# the tree fits a column to its title only. measure filtered rows too, so that
# the widths stay the same while the filter changes
func _fit_columns() -> void:
	if _fitted_columns.is_empty():
		return

	var font := table.get_theme_font("font")
	var font_size := table.get_theme_font_size("font_size")
	# keep a gap of about one character between adjacent cells
	var padding := (table.get_theme_constant("inner_item_margin_left") + table.get_theme_constant("inner_item_margin_right")
		+ table.get_theme_constant("h_separation") + font_size)
	var widths := {}

	for row: TreeItem in rows.values():
		for item: TreeItem in [row] + ([] if row.collapsed else row.get_children()):
			for column in _fitted_columns:
				var width := font.get_string_size(item.get_text(column), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				widths[column] = maxf(widths.get(column, 0.0), width)

	# the first column also holds the fold arrow and the child indent
	if widths.has(0):
		widths[0] += table.get_theme_icon("arrow").get_width() + table.get_theme_constant("item_margin")

	for column in _fitted_columns:
		table.set_column_custom_minimum_width(column, ceili(widths.get(column, 0.0)) + padding)


func _set_locate_icon(row: TreeItem, site: CityRecords.Site) -> void:
	var column := locate_column

	if site == null:
		row.set_icon(column, null)
		row.set_metadata(column, null)
		row.set_tooltip_text(column, "")

		return

	row.set_metadata(column, Rect2i(site.x, site.y, site.width, site.height))
	row.set_icon(column, _locate_icon)
	row.set_icon_modulate(column, table.get_theme_color("font_color"))
	row.set_text_alignment(column, HORIZONTAL_ALIGNMENT_CENTER)
	row.set_tooltip_text(column, "Center the map here")


func _on_table_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton

	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT \
			and table.get_column_at_position(click.position) == locate_column:
		locate_on_map(table.get_item_at_position(click.position))


func locate_on_map(item: TreeItem) -> void:
	if item != null and locate_column >= 0 and item.get_metadata(locate_column) is Rect2i:
		locate_requested.emit(item.get_metadata(locate_column))


# crosshair drawn at runtime: a ring, a centre dot and four ticks, antialiased
static func locate_icon(size: int) -> ImageTexture:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var samples := 4

	for py in size:
		for px in size:
			var covered := 0

			for sy in samples:
				for sx in samples:
					# unit coordinates in -1..1 with the icon centre at 0
					var u := ((px + (sx + 0.5) / samples) / size) * 2.0 - 1.0
					var v := ((py + (sy + 0.5) / samples) / size) * 2.0 - 1.0
					var radius := sqrt(u * u + v * v)
					var ring := radius >= 0.58 and radius <= 0.74
					var dot := radius <= 0.2
					var tick := (absf(u) <= 0.08 and absf(v) >= 0.64 and absf(v) <= 0.98) \
						or (absf(v) <= 0.08 and absf(u) >= 0.64 and absf(u) <= 0.98)

					if ring or dot or tick:
						covered += 1

			image.set_pixel(px, py, Color(1, 1, 1, float(covered) / (samples * samples)))

	return ImageTexture.create_from_image(image)


func _filter() -> void:
	var needle := search.text.strip_edges().to_lower()

	for row: TreeItem in rows.values():
		var content := ""

		for item: TreeItem in [row] + row.get_children():
			for column in table.columns:
				content += " " + item.get_text(column).to_lower()

		row.visible = needle.is_empty() or needle in content
