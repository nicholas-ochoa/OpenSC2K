class_name DebugRecordTable
extends VBoxContainer


signal locate_requested(site: Rect2i)

@export var kind := "XMIC"
var rows: Dictionary = {}
var _last_refresh := -1000
var _host: Control
var _city_id := 0
var _locate_icon: Texture2D
@onready var table: Tree = $Table
@onready var search: LineEdit = $Controls/Search
@onready var show_empty: CheckBox = $Controls/ShowEmpty
@onready var live: CheckBox = $Controls/Live
@onready var status: Label = $Status


func _ready() -> void:
	var titles := ["Record / field", "Value", "Hex", "Details"]
	var widths := [240, 160, 140, 270]

	if kind == "XMIC":
		titles.insert(3, "Position")
		widths.insert(3, 150)
		_locate_icon = locate_icon(16)
		table.button_clicked.connect(_on_button_clicked)
	elif kind == "Objects":
		titles = ["Object"]
		widths = [110]
		var column_widths := {"type": 140, "state": 200, "direction": 120, "goal": 200, "label": 160}

		for key: String in DebugObjectFields.COLUMNS:
			titles.append(key.capitalize() if key.length() > 2 else key.to_upper())
			widths.append(column_widths.get(key, 70))

	table.columns = titles.size()

	for column in titles.size():
		table.set_column_title(column, titles[column])
		table.set_column_custom_minimum_width(column, widths[column])
		table.set_column_expand(column, column == titles.size() - 1)
		# objects cells stay one line high; long translations are trimmed and shown in tooltips
		table.set_column_clip_content(column, kind == "Objects")

	show_empty.visible = kind != "State"
	search.text_changed.connect(func(_text: String) -> void: _filter())
	show_empty.toggled.connect(func(_enabled: bool) -> void: refresh_from_host(_host, true))
	$Controls/Refresh.pressed.connect(func() -> void: refresh_from_host(_host, true))


func refresh_from_host(host: Control, force := false) -> void:
	_host = host

	if not is_instance_valid(host):
		return

	var city := host.get("city") as CityState
	var city_id := city.get_instance_id() if city != null else 0
	var changed_city := city_id != _city_id

	if not force and not changed_city and (not live.button_pressed or Time.get_ticks_msec() - _last_refresh < 1000):
		return

	if changed_city:
		table.clear()
		rows.clear()
		_city_id = city_id

	_last_refresh = Time.get_ticks_msec()
	var engine := host.get("simulation_engine") as SimulationEngine
	update_records(DebugCityTables.collect(kind, city, engine, show_empty.button_pressed))
	status.text = "No city loaded." if city == null else "%d records • published state • refresh at most once per second" % rows.size()


func update_records(records: Array[Dictionary]) -> void:
	if table.get_root() == null:
		table.create_item()

	var retained := {}

	for record in records:
		var id: String = record.id
		retained[id] = true
		var row: TreeItem = rows.get(id)

		if row == null:
			row = table.create_item(table.get_root())
			row.collapsed = true
			rows[id] = row

		_set_cells(row, record)
		var fields: Array = record.get("fields", [])

		while row.get_child_count() > fields.size():
			row.get_child(row.get_child_count() - 1).free()

		for index in fields.size():
			var child := row.get_child(index) if index < row.get_child_count() else table.create_item(row)
			_set_cells(child, fields[index])

	for id in rows.keys():
		if not retained.has(id):
			rows[id].free()
			rows.erase(id)

	_filter()


func _set_cells(row: TreeItem, record: Dictionary) -> void:
	var cells: Array = record.get("cells", [])

	var tooltips: Array = record.get("tooltips", [])

	if cells.is_empty():
		for key in ["name", "value", "raw", "position", "detail"] if kind == "XMIC" else ["name", "value", "raw", "detail"]:
			cells.append(str(record.get(key, "")))

	for column in table.columns:
		var text := str(cells[column])
		row.set_text(column, text)
		row.set_tooltip_text(column, str(tooltips[column]) if column < tooltips.size() else text)

	if kind == "XMIC":
		_set_locate_button(row, record.get("site", {}))


func _set_locate_button(row: TreeItem, site: Dictionary) -> void:
	var column := 3

	if site.is_empty():
		if row.get_button_count(column) > 0:
			row.erase_button(column, 0)

		row.set_metadata(column, null)

		return

	row.set_metadata(column, Rect2i(site.x, site.y, site.width, site.height))

	if row.get_button_count(column) == 0:
		row.add_button(column, _locate_icon, 0, false, "Center the map here")
		row.set_button_color(column, 0, table.get_theme_color("font_color"))


func _on_button_clicked(item: TreeItem, column: int, _id: int, mouse_button: int) -> void:
	if mouse_button == MOUSE_BUTTON_LEFT and item.get_metadata(column) is Rect2i:
		locate_requested.emit(item.get_metadata(column))


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
					var ring := radius >= 0.52 and radius <= 0.78
					var dot := radius <= 0.22
					var tick := (absf(u) <= 0.12 and absf(v) >= 0.6 and absf(v) <= 0.98) \
						or (absf(v) <= 0.12 and absf(u) >= 0.6 and absf(u) <= 0.98)

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
