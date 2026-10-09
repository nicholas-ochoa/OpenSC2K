class_name DebugRecordTable
extends VBoxContainer
## A debug record table: MicroSim records, moving things, tile counts or engine
## state. A virtual table draws only the rows in view. MicroSims and Moving
## Things build a row only when it is drawn, sorted or searched, and they skip a
## refresh while their chunks keep their revisions, so the 32,768 MicroSim
## records of a 4096 city stay responsive.

signal locate_requested(site: Rect2i)
# a field cell of an editable table changed: the record, the field name and the text
signal field_edited(kind: String, record: int, field: String, text: String)
signal undo_requested()

# yellow row background for a record with a warning. it stays readable in light and dark themes
const WARNING_COLOR := DebugVirtualTable.WARNING_COLOR
# a search of a larger table waits for a pause in typing
const IMMEDIATE_FILTER_ROWS := 2000
const FILTER_DELAY_MSEC := 300
# a packed sort key holds three values of 0 to 2^20 - 1
const PACKED_KEY_BITS := 20
const PACKED_KEY_LIMIT := 1 << PACKED_KEY_BITS
const LAZY_KINDS := ["XMIC", "Objects"]
# the width of each count column of the tile counts table
const COUNT_WIDTH := 96
# chunks whose change rebuilds the rows. facility sites follow the buildings
# (XBLD), not XTXT, which changes whenever a moving thing moves
const LAZY_CHUNKS := { "XMIC": ["XMIC", "XLAB", "XBLD"], "Objects": ["XTHG", "XTXT"] }

@export var kind := "XMIC"

var _last_refresh := -1000
var _host: Control
var _city_id := 0
# column holding the locate icon; -1 when this table has none
var locate_column := -1
var _titles: Array = []
# records the city can hold. -1 when the table has no limit
var record_limit := -1
# sorted column and direction; -1 keeps record order
var sort_column := -1
var sort_descending := false
var source := DebugTableSource.new()
var _order_signature: Array = []
var _filter_due := -1

@onready var table: DebugVirtualTable = $Table
@onready var search: LineEdit = $Controls/Search
@onready var show_empty: CheckBox = $Controls/ShowEmpty
@onready var live: CheckBox = $Controls/Live
@onready var total: Label = $Total


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
		# the counts share one width, and the name takes the free width
		titles = ["Tile", "Constant", "Name", "Instances", "On map", "Saved count"]
		widths = [0, 0, 0, COUNT_WIDTH, COUNT_WIDTH, COUNT_WIDTH]
		locate_column = 1
		table.expand_column = 3
		tooltips = {
			"Tile": "Building ID in the XBLD tile plane, in decimal and hexadecimal.",
			"Constant": "BuildingTileIds constant for the ID.",
			"Name": "Name that the query tool shows for the tile.",
			"Instances": "Number of whole buildings on the map: the map tiles divided by the tiles in one 1×1, 2×2, 3×3 or 4×4 building.",
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
		titles.insert(locate_column, "")
		widths.insert(locate_column, 28)
		tooltips[""] = "Click the crosshair in a row to center the map on it."
		table.locate_icon = locate_icon(12)

	_titles = titles
	table.set_columns(titles, titles.map(func(title: String) -> String: return tooltips.get(title, "")), widths, locate_column)
	table.title_clicked.connect(_on_column_title_clicked)
	table.locate_clicked.connect(locate_on_map)
	table.cell_edited.connect(_on_cell_edited)
	table.editable = _is_cell_editable

	if kind == "State":
		sort_by(0)

	show_empty.visible = kind != "State"
	total.visible = kind != "State"

	if is_editable():
		var undo := Button.new()
		undo.name = "Undo"
		undo.text = "Undo edit"
		undo.tooltip_text = "Put back the record bytes from before the last debug edit."
		undo.pressed.connect(undo_requested.emit)
		$Controls.add_child(undo)
		$Controls.move_child(undo, $Controls/Refresh.get_index())

	search.text_changed.connect(func(_text: String) -> void: _search_changed())
	show_empty.toggled.connect(func(_enabled: bool) -> void: refresh_from_host(_host, true))
	$Controls/Refresh.pressed.connect(func() -> void: refresh_from_host(_host, true))
	set_process(false)


func _process(_delta: float) -> void:
	if _filter_due >= 0 and Time.get_ticks_msec() >= _filter_due:
		_filter_due = -1
		set_process(false)
		_apply()


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

	# a refresh would end an open cell edit
	if not force and table.is_editing():
		return

	if changed_city:
		table.expanded.clear()
		table.selected = ""
		table.reset_widths()
		_city_id = city_id

	_last_refresh = Time.get_ticks_msec()
	var simulation := host.get("simulation_state") as SimulationSessionState
	var engine: SimulationEngine = simulation.simulation_engine if simulation != null else null
	var controller: GameSpeedController = simulation.speed_controller if simulation != null else null
	record_limit = DebugCityTables.record_limit(kind, city)

	if kind in LAZY_KINDS and city != null and city.is_valid():
		_show_source(_lazy_source(city))
	else:
		update_records(DebugCityTables.collect(kind, city, engine, show_empty.button_pressed, controller))


# the lazy rows of a city. the same source returns while its chunks keep their revisions
func _lazy_source(city: CityState) -> DebugTableSource:
	var signature: Array = [kind, show_empty.button_pressed, city.mirror_signature(PackedStringArray(LAZY_CHUNKS[kind]))]

	if source.signature == signature:
		return source

	var ids := PackedStringArray()

	for id in DebugCityTables.record_ids(kind, city, show_empty.button_pressed):
		ids.append(str(id))

	# one site scan for the source, not one for each row
	var sites: Dictionary[int, CityRecords.Site] = {}

	if kind == "XMIC":
		sites = city.microsim_sites()

	var builder := func(id: String) -> DebugTableRecord:
		return (DebugCityTables.microsim_row(city, int(id), sites) if kind == "XMIC"
			else DebugCityTables.object_row(city, int(id)))

	var result := DebugTableSource.lazy(ids, builder, signature)

	if kind == "XMIC":
		var data := city.document.find_chunk("XMIC").decoded_payload
		result.key_builder = func(id: String, column: int) -> Variant:
			return DebugCityTables.microsim_sort_key(city, int(id), column, data, sites)
		result.search_builder = func(id: String) -> String:
			return DebugCityTables.microsim_search_text(city, int(id), data, sites)

	return result


func update_records(records: Array[DebugTableRecord]) -> void:
	_show_source(DebugTableSource.of(records))


func _show_source(value: DebugTableSource) -> void:
	value.with_position = kind == "XMIC"
	var changed := value != source
	source = value
	_apply(changed)


# sort and search the rows, then show them. an unchanged source keeps its order
func _apply(force := false) -> void:
	var needle := search.text.strip_edges().to_lower()
	var signature: Array = [source.signature, source.size(), sort_column, sort_descending, needle]

	if force or signature != _order_signature:
		_order_signature = signature
		var rows := _sorted_rows()

		if not needle.is_empty():
			var found := PackedInt32Array()

			for index in rows:
				if needle in source.search_text(source.ids[index]):
					found.append(index)

			rows = found

		table.show_rows(source, rows)
	else:
		table.queue_redraw()

	_update_total(table.order.size())


func _search_changed() -> void:
	if source.size() <= IMMEDIATE_FILTER_ROWS:
		_apply()

		return

	_filter_due = Time.get_ticks_msec() + FILTER_DELAY_MSEC
	set_process(true)


func _update_total(shown: int) -> void:
	var count := source.size()
	var noun := "record" if count == 1 else "records"
	total.text = "%d %s" % [count, noun] if shown == count else "%d of %d %s shown" % [shown, count, noun]

	if record_limit >= 0:
		total.text += ". Limit: %d" % record_limit
		total.tooltip_text = tr("The city can hold %d records. Record 0 is not used.") % record_limit


func _sorted_rows() -> PackedInt32Array:
	var count := source.size()
	var rows := PackedInt32Array()

	if sort_column < 0:
		rows.resize(count)

		for index in count:
			rows[index] = index

		return rows

	var keys := []
	keys.resize(count)

	for index in count:
		keys[index] = _sort_key(source.ids[index], sort_column)

	return ordered(keys, sort_descending)


# the sort value of a table column. the locate column sorts by position
func _sort_key(id: String, column: int) -> Variant:
	if column == locate_column:
		var site := source.row(id).site

		return null if site == null else [site.x, site.y]

	return source.sort_key(id, column - (1 if locate_column >= 0 and column > locate_column else 0))


# row indices in key order. equal keys keep their order, and rows without a
# key stay last in both directions. the native library sorts integer keys;
# other keys sort by rank
static func ordered(keys: Array, descending: bool) -> PackedInt32Array:
	var present := PackedInt32Array()
	var missing := PackedInt32Array()

	for index in keys.size():
		if keys[index] == null:
			missing.append(index)
		else:
			present.append(index)

	var packed := PackedInt64Array()
	packed.resize(present.size())
	var values := []

	for index in present:
		values.append(keys[index])

	var ranks := _integer_keys(values)

	for index in present.size():
		packed[index] = ranks[index]

	var result := PackedInt32Array()

	for index in NativeDebugTiles.stable_order(packed, descending):
		result.append(present[index])

	result.append_array(missing)

	return result


# integers stay; short lists of small integers pack into one integer; other
# values become their rank
static func _integer_keys(values: Array) -> Array:
	if values.all(func(value: Variant) -> bool: return value is int):
		return values

	if values.all(_packable):
		return values.map(func(value: Array) -> int:
			var packed := 0

			for part in 3:
				packed = (packed << PACKED_KEY_BITS) | (int(value[part]) if part < value.size() else 0)

			return packed)

	var unique := {}

	for value in values:
		unique[value] = true

	var sorted_values := unique.keys()
	sorted_values.sort_custom(func(a: Variant, b: Variant) -> bool: return compare_keys(a, b) < 0)
	var rank := {}

	for index in sorted_values.size():
		rank[sorted_values[index]] = index

	return values.map(func(value: Variant) -> int: return rank[value])


static func _packable(value: Variant) -> bool:
	if not value is Array or value.size() > 3:
		return false

	return value.all(func(part: Variant) -> bool: return part is int and part >= 0 and part < PACKED_KEY_LIMIT)


func sort_by(column: int, descending := false) -> void:
	sort_column = column
	sort_descending = descending

	for index in _titles.size():
		var marker := "" if index != column else (" ▼" if descending else " ▲")
		table.set_title(index, str(_titles[index]) + marker)

	_apply()


# title clicks cycle ascending, descending, then record order
func _on_column_title_clicked(column: int) -> void:
	if column != sort_column:
		sort_by(column)
	elif not sort_descending:
		sort_by(column, true)
	else:
		sort_by(-1)


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


# the MicroSims and Moving Things tables accept debug edits of their records
func is_editable() -> bool:
	return kind in ["XMIC", "Objects"]


# MicroSim field rows edit their value; the stored values row of a moving
# thing edits each field column
func _is_cell_editable(_record: DebugTableRecord, field: int, column: int) -> bool:
	if field < 0 or not is_editable():
		return false

	return column == 1 if kind == "XMIC" else not object_field(column).is_empty()


# the XTHG field of a Moving Things column, or an empty string
func object_field(column: int) -> String:
	var index := column - 1 - (1 if locate_column >= 0 and column > locate_column else 0)

	if kind != "Objects" or column == locate_column or index < 0 or index >= DebugObjectFields.COLUMNS.size():
		return ""

	return DebugObjectFields.COLUMNS[index]


func _on_cell_edited(id: String, field: int, column: int, text: String) -> void:
	var name_of_field := source.row(id).fields[field].name if kind == "XMIC" else object_field(column)

	if not name_of_field.is_empty():
		field_edited.emit(kind, int(id), name_of_field, text)


func locate_on_map(id: String) -> void:
	var site := source.row(id).site if source.has(id) else null

	if site != null:
		locate_requested.emit(Rect2i(site.x, site.y, site.width, site.height))


# the record rows in display order
func shown_ids() -> PackedStringArray:
	var result := PackedStringArray()

	for index in table.order:
		result.append(source.ids[index])

	return result


func has_row(id: String) -> bool:
	return source.has(id)


func row_count() -> int:
	return source.size()


func row_cells(id: String, field := -1) -> Array[String]:
	return table.cells_of(id, field)


func column_title(column: int) -> String:
	return str(table.titles[column])


# crosshair drawn at runtime: a ring, a centre dot and four ticks, antialiased
static func locate_icon(icon_size: int) -> ImageTexture:
	var image := Image.create_empty(icon_size, icon_size, false, Image.FORMAT_RGBA8)
	var samples := 4

	for py in icon_size:
		for px in icon_size:
			var covered := 0

			for sy in samples:
				for sx in samples:
					# unit coordinates in -1..1 with the icon centre at 0
					var u := ((px + (sx + 0.5) / samples) / icon_size) * 2.0 - 1.0
					var v := ((py + (sy + 0.5) / samples) / icon_size) * 2.0 - 1.0
					var radius := sqrt(u * u + v * v)
					var ring := radius >= 0.58 and radius <= 0.74
					var dot := radius <= 0.2
					var tick := (absf(u) <= 0.08 and absf(v) >= 0.64 and absf(v) <= 0.98) \
						or (absf(v) <= 0.08 and absf(u) >= 0.64 and absf(u) <= 0.98)

					if ring or dot or tick:
						covered += 1

			image.set_pixel(px, py, Color(1, 1, 1, float(covered) / (samples * samples)))

	return ImageTexture.create_from_image(image)
