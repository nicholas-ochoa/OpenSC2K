class_name CityMapWindowControl
extends VBoxContainer

signal mode_changed(mode: String)
signal center_requested(point: Vector2i)

signal isometric_view_requested(mode: CityViewMode.Mode)

const Minimap = preload("res://src/view/city_minimap.gd")
const Preview = preload("res://src/view/city_map_preview_control.gd")

const TAB_NAMES := [
	"City", "Transit", "Power", "Water", "Population", "Police",
	"Pollution", "Land Value", "Services",
]
const TAB_MODES := [
	["structures", "zones"],
	["roads", "rail", "traffic"],
	["power"],
	["water"],
	["density", "growth"],
	["crime", "police_power", "police_stations"],
	["pollution"],
	["land_value"],
	["fire_power", "fire_stations", "schools", "colleges"],
]
const MODE_NAMES := {
	"structures": "Structures",
	"zones": "Zones",
	"roads": "Roads",
	"rail": "Rail",
	"traffic": "Traffic",
	"power": "Power",
	"water": "Water Supply",
	"density": "Density",
	"growth": "Rate of Growth",
	"crime": "Crime Rate",
	"police_power": "Police Power",
	"police_stations": "Police Depts",
	"pollution": "Pollution",
	"land_value": "Land Value",
	"fire_power": "Fire Power",
	"fire_stations": "Fire Depts",
	"schools": "Schools",
	"colleges": "Colleges",
}
# isometric data view behind each map mode. modes without one stay on the city view
const MODE_VIEWS := {
	"traffic": CityViewMode.Mode.TRAFFIC,
	"power": CityViewMode.Mode.POWER,
	"water": CityViewMode.Mode.WATER,
	"density": CityViewMode.Mode.DENSITY,
	"growth": CityViewMode.Mode.GROWTH,
	"crime": CityViewMode.Mode.CRIME,
	"police_power": CityViewMode.Mode.POLICE_POWER,
	"pollution": CityViewMode.Mode.POLLUTION,
	"land_value": CityViewMode.Mode.LAND_VALUE,
	"fire_power": CityViewMode.Mode.FIRE_POWER,
}
const MODE_STRING_IDS := {
	"structures": 327,
	"zones": 328,
	"roads": 329,
	"rail": 330,
	"traffic": 331,
	"power": 332,
	"water": 333,
	"density": 334,
	"growth": 335,
	"crime": 336,
	"police_power": 337,
	"police_stations": 338,
	"pollution": 339,
	"land_value": 340,
	"fire_power": 341,
	"fire_stations": 342,
	"schools": 343,
	"colleges": 344,
}

const MAP_MODE_STRINGS: Dictionary[int, String] = {
	327: "Structures",
	328: "Zones",
	329: "Roads",
	330: "Rail",
	331: "Traffic",
	332: "Power",
	333: "Water Supply",
	334: "Density",
	335: "Rate of Growth",
	336: "Crime Rate",
	337: "Police Power",
	338: "Police Depts",
	339: "Pollution",
	340: "Land Value",
	341: "Fire Power",
	342: "Fire Depts",
	343: "Schools",
	344: "Colleges",
}

var city: CityState
var palette: Sc2Palette
var strings: Dictionary = {}
var icon_sheet: Image
var tab_bar: TabBar
var preview: CityMapPreviewControl
var preview_frame: AspectRatioContainer
var mode_grid: GridContainer
var mode_buttons: Array[CheckBox] = []
var mode_button_group: ButtonGroup
var isometric_check: CheckBox
var selected_tab := 0
var selected_item := 0
var refreshing := false
var image_signature: Array = []


func _ready() -> void:
	name = "CityMapWindowControl"
	add_theme_constant_override("separation", 6)
	tab_bar = TabBar.new()
	tab_bar.name = "CityMapTabs"
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.tab_changed.connect(_on_tab_changed)
	add_child(tab_bar)

	preview = Preview.new()
	preview.name = "CityMapPreview"
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.center_requested.connect(center_requested.emit)

	# the map is square. fitting it here keeps the window from padding it out
	preview_frame = AspectRatioContainer.new()
	preview_frame.name = "CityMapPreviewFrame"
	preview_frame.ratio = 1.0
	preview_frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	preview_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_frame.add_child(preview)
	add_child(preview_frame)

	mode_button_group = ButtonGroup.new()
	mode_grid = GridContainer.new()
	mode_grid.name = "CityMapModes"
	mode_grid.columns = 2
	mode_grid.add_theme_constant_override("h_separation", 12)
	mode_grid.add_theme_constant_override("v_separation", 0)
	add_child(mode_grid)

	isometric_check = CheckBox.new()
	isometric_check.name = "CityMapIsometricView"
	isometric_check.text = "Isometric View"
	isometric_check.tooltip_text = "Show the selected map in the isometric city view."
	isometric_check.toggled.connect(_on_isometric_toggled)
	add_child(isometric_check)

	_rebuild_tabs()
	_rebuild_modes()


func set_resources(value: Image, value_strings: Dictionary) -> void:
	icon_sheet = value
	strings = value_strings.duplicate()
	_rebuild_tabs()
	_rebuild_modes()


func set_city(value: CityState, value_palette: Sc2Palette) -> void:
	if city != value or palette != value_palette:
		image_signature.clear()

	city = value
	palette = value_palette
	refresh()


func refresh(points := PackedVector2Array()) -> void:
	if not is_node_ready() or city == null or palette == null:
		return

	var signature := _image_signature()

	if signature != image_signature:
		preview.set_map(Minimap.create_image(city, palette, current_mode()))
		image_signature = signature

	preview.set_viewport_outline(points)


func refresh_viewport(points: PackedVector2Array) -> void:
	if preview != null:
		preview.set_viewport_outline(points)


func current_mode() -> String:
	var modes: Array = TAB_MODES[selected_tab]

	return str(modes[clampi(selected_item, 0, modes.size() - 1)])


func _rebuild_tabs() -> void:
	if tab_bar == null:
		return

	refreshing = true
	tab_bar.clear_tabs()

	for index in TAB_NAMES.size():
		var icon: Texture2D

		if (
			icon_sheet != null
			and not icon_sheet.is_empty()
			and icon_sheet.get_width() >= (index + 1) * 26
		):
			var region := icon_sheet.get_region(Rect2i(index * 26, 0, 26, 20))
			icon = ImageTexture.create_from_image(region)

		tab_bar.add_tab("", icon)
		tab_bar.set_tab_tooltip(index, TAB_NAMES[index])

	tab_bar.current_tab = selected_tab
	refreshing = false


func _rebuild_modes() -> void:
	if mode_grid == null:
		return

	refreshing = true

	for button in mode_buttons:
		button.button_group = null
		mode_grid.remove_child(button)
		button.queue_free()

	mode_buttons.clear()
	var modes: Array = TAB_MODES[selected_tab]
	selected_item = clampi(selected_item, 0, modes.size() - 1)

	for index in modes.size():
		var mode: String = str(modes[index])
		var resource_id := int(MODE_STRING_IDS.get(mode, 0))
		var button := CheckBox.new()
		button.text = str(strings.get(resource_id, MODE_NAMES.get(mode, mode)))
		# one group keeps the checkboxes mutually exclusive, like radio buttons
		button.button_group = mode_button_group
		button.set_pressed_no_signal(index == selected_item)
		button.pressed.connect(_on_mode_selected.bind(index))
		mode_grid.add_child(button)
		mode_buttons.append(button)

	refreshing = false


func _on_tab_changed(tab: int) -> void:
	if refreshing:
		return

	selected_tab = clampi(tab, 0, TAB_MODES.size() - 1)
	selected_item = 0
	_rebuild_modes()
	refresh()
	mode_changed.emit(current_mode())
	_follow_isometric_view()


func _on_mode_selected(item: int) -> void:
	if refreshing:
		return

	selected_item = clampi(item, 0, TAB_MODES[selected_tab].size() - 1)
	refresh()
	mode_changed.emit(current_mode())
	_follow_isometric_view()


func _on_isometric_toggled(_enabled: bool) -> void:
	if refreshing:
		return

	_emit_isometric_view()


func _emit_isometric_view() -> void:
	if isometric_check == null:
		return

	isometric_view_requested.emit(current_view_mode() if isometric_check.button_pressed else CityViewMode.Mode.CITY)


# a new selection only moves the city view while the checkbox is on
func _follow_isometric_view() -> void:
	if isometric_check != null and isometric_check.button_pressed:
		_emit_isometric_view()


# isometric view for the selected map mode, or the plain city view when it has none
func current_view_mode() -> CityViewMode.Mode:
	var mode: CityViewMode.Mode = MODE_VIEWS.get(current_mode(), CityViewMode.Mode.CITY)

	return mode


# follows the active isometric view when it changes outside this window
func sync_view_mode(mode: CityViewMode.Mode) -> void:
	if isometric_check == null:
		return

	# only clear the box: another view taking over means this window no longer drives it
	if isometric_check.button_pressed and mode != current_view_mode():
		refreshing = true
		isometric_check.set_pressed_no_signal(false)
		refreshing = false


func _image_signature() -> Array:
	var mode := current_mode()
	var result := [
		mode,
		hash(city.altitude_words),
		hash(city.buildings),
		hash(city.tile_flags),
	]

	if mode == "zones":
		result.append(hash(city.zones))
	elif mode == "water":
		result.append(hash(city.underground))

	var chunk_id: String = {
		"traffic": "XTRF",
		"density": "XPOP",
		"growth": "XROG",
		"crime": "XCRM",
		"police_power": "XPLC",
		"pollution": "XPLT",
		"land_value": "XVAL",
		"fire_power": "XFIR",
	}.get(mode, "")

	if not chunk_id.is_empty():
		var chunk := city.document.find_chunk(chunk_id)
		result.append(hash(chunk.decoded_payload) if chunk != null else 0)

	return result
