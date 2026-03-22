class_name DebugRecordTable
extends VBoxContainer

@export var kind := "XMIC"
var rows: Dictionary = {}
var _last_refresh := -1000
var _host: Control
var _city_id := 0
@onready var table: Tree = $Table
@onready var search: LineEdit = $Controls/Search
@onready var show_empty: CheckBox = $Controls/ShowEmpty
@onready var live: CheckBox = $Controls/Live
@onready var status: Label = $Status


func _ready() -> void:
	var titles := ["Record / field", "Value", "Hex / position", "Details"]

	for column in 4:
		table.set_column_title(column, titles[column])
		table.set_column_custom_minimum_width(column, [240, 160, 140, 270][column])
		table.set_column_expand(column, column == 3)

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
	for column in 4:
		var text := str(record.get(["name", "value", "raw", "detail"][column], ""))
		row.set_text(column, text)
		row.set_tooltip_text(column, text)


func _filter() -> void:
	var needle := search.text.strip_edges().to_lower()

	for row: TreeItem in rows.values():
		var content := ""

		for item: TreeItem in [row] + row.get_children():
			for column in 4:
				content += " " + item.get_text(column).to_lower()

		row.visible = needle.is_empty() or needle in content
