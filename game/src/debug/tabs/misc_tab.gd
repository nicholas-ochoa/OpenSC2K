class_name CityDebugMiscTab
extends DebugWindowTab
## The city values and every MISC word. Named fields come from Sc2MiscLayout;
## a field that spans several words lists each word, and the words between
## named fields are listed as unnamed. Double-click a value to change a word.
## Each change is a debug edit that Undo can reverse.

@warning_ignore_start("integer_division")

const COLUMNS := ["Field", "Offset", "Value", "Hex", "Notes"]
const VALUE_COLUMN := 2
const REFRESH_MSEC := 1000
const SKIPPED := ["SIZE", "WORD_SIZE"]

var table: Tree
var search: LineEdit
var _rows: Dictionary[int, TreeItem] = {}
var _city_rows: Dictionary[String, TreeItem] = {}
var _city_id := 0
var _refreshed_at := -REFRESH_MSEC


func _init() -> void:
	name = "MISC"
	var controls := HBoxContainer.new()
	add_child(controls)
	search = LineEdit.new()
	search.placeholder_text = "Filter fields…"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_text: String) -> void: _filter())
	controls.add_child(search)
	make_button(controls, "Undo edit", "Put back the MISC bytes from before the last debug edit.", _undo)
	table = make_table(COLUMNS, 4)
	table.set_column_custom_minimum_width(0, 260)
	table.item_edited.connect(_on_item_edited)
	add_child(table)


func refresh(force := false) -> void:
	var app := application()
	var city: CityState = app.document_state.city if app != null else null

	if city == null:
		table.clear()
		_rows.clear()
		_city_id = 0

		return

	if city.get_instance_id() != _city_id:
		_build(city)
	elif not force and (Time.get_ticks_msec() - _refreshed_at < REFRESH_MSEC or table.get_edited() != null):
		return

	_refreshed_at = Time.get_ticks_msec()
	_update(city)


# the named MISC fields by offset, and the number of words of each
static func fields(size: int) -> Array:
	var named: Dictionary[int, String] = {}
	var constants: Dictionary = (Sc2MiscLayout as Script).get_script_constant_map()

	for key: String in constants:
		if key not in SKIPPED and constants[key] is int and int(constants[key]) < size:
			named[int(constants[key])] = key

	var offsets := named.keys()
	offsets.sort()
	var result := []
	var position := 0

	for index in offsets.size():
		var offset: int = offsets[index]

		if offset > position:
			result.append(["Unnamed", position, (offset - position) / Sc2MiscLayout.WORD_SIZE])

		var end: int = offsets[index + 1] if index + 1 < offsets.size() else size
		result.append([named[offset], offset, maxi(1, (end - offset) / Sc2MiscLayout.WORD_SIZE)])
		position = offset + maxi(1, (end - offset) / Sc2MiscLayout.WORD_SIZE) * Sc2MiscLayout.WORD_SIZE

	if position < size:
		result.append(["Unnamed", position, (size - position) / Sc2MiscLayout.WORD_SIZE])

	return result


func _build(city: CityState) -> void:
	table.clear()
	_rows.clear()
	_city_rows.clear()
	_city_id = city.get_instance_id()
	var root := table.create_item()
	var city_group := _group(root, "City values (read only)")

	for key in ["Name", "Mayor", "File format", "Map size", "Date", "Funds", "Population", "RCI demand", "City mode",
			"Difficulty", "Compass rotation", "Weather", "Age in days"]:
		var row := table.create_item(city_group)
		row.set_text(0, key)
		_city_rows[key] = row

	var misc_group := _group(root, "MISC words")
	var chunk := city.document.find_chunk("MISC")
	var size := chunk.decoded_payload.size() if chunk != null else 0

	for field: Array in fields(size):
		var title: String = field[0]
		var offset: int = field[1]
		var words: int = field[2]

		if words == 1:
			_word_row(misc_group, title, offset)

			continue

		var parent := table.create_item(misc_group)
		parent.set_text(0, "%s (%d words)" % [title, words] if title != "Unnamed" else "Unnamed (%d words)" % words)
		parent.set_text(1, "0x%04X" % offset)
		parent.collapsed = true

		for word in words:
			_word_row(parent, "%s[%d]" % [title if title != "Unnamed" else "word", word], offset + word * Sc2MiscLayout.WORD_SIZE)


func _group(root: TreeItem, title: String) -> TreeItem:
	var group := table.create_item(root)
	group.set_text(0, title)
	group.set_selectable(0, false)

	return group


func _word_row(parent: TreeItem, title: String, offset: int) -> void:
	var row := table.create_item(parent)
	row.set_text(0, title)
	row.set_text(1, "0x%04X" % offset)
	row.set_editable(VALUE_COLUMN, true)
	row.set_tooltip_text(VALUE_COLUMN, "Double-click to change this word. The change is a debug edit.")
	row.set_meta("offset", offset)
	row.set_meta("name", title)
	_rows[offset] = row


func _update(city: CityState) -> void:
	var document := city.document
	var values := {
		"Name": city.city_name(), "Mayor": city.mayor_name(), "File format": DebugFileInfo.format_name(document),
		"Map size": "%d x %d" % [city.map_size, city.map_size],
		"Date": "%02d/%02d/%04d" % [city.current_month(), city.current_day(), city.current_year()],
		"Funds": str(city.funds()), "Population": str(city.population()), "RCI demand": str(city.rci_demand()),
		"City mode": str(city.city_mode()), "Difficulty": str(city.difficulty()),
		"Compass rotation": str(city.compass_rotation()), "Weather": str(city.weather_type()),
		"Age in days": str(city.age_in_days()),
	}

	for key in values:
		_city_rows[key].set_text(VALUE_COLUMN, str(values[key]))

	for offset in _rows:
		var row := _rows[offset]

		if row == table.get_edited():
			continue

		row.set_text(VALUE_COLUMN, str(document.misc_i32(offset)))
		row.set_text(3, "0x%08X" % document.misc_u32(offset))

	_filter()


func _filter() -> void:
	var needle := search.text.strip_edges().to_lower()

	for offset in _rows:
		var row := _rows[offset]
		var parent := row.get_parent()
		var shown := needle.is_empty() or needle in row.get_text(0).to_lower() or needle in row.get_text(1).to_lower()
		row.visible = shown or (parent != null and needle in parent.get_text(0).to_lower())

	for parent in _parents():
		var any := false

		for child in parent.get_children():
			any = any or child.visible

		parent.visible = any or needle.is_empty()

		if not needle.is_empty() and any:
			parent.collapsed = false


func _parents() -> Array[TreeItem]:
	var result: Array[TreeItem] = []
	var root := table.get_root()

	if root == null:
		return result

	for group in root.get_children():
		for item in group.get_children():
			if item.get_child_count() > 0:
				result.append(item)

	return result


func _on_item_edited() -> void:
	var row := table.get_edited()

	if row == null or not row.has_meta("offset") or application() == null:
		return

	var edits := application().debug_tools.edits
	report(edits.set_misc_word(int(row.get_meta("offset")), row.get_text(VALUE_COLUMN), str(row.get_meta("name"))))
	refresh(true)


func _undo() -> void:
	if application() != null:
		report(application().debug_tools.edits.undo())
		refresh(true)
