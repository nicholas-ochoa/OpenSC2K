class_name CityMapWindowControl
extends VBoxContainer

signal mode_changed(mode: String)
signal center_requested(point: Vector2i)

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

var city: CityState
var palette: Sc2Palette
var strings: Dictionary = {}
var icon_sheet: Image
var tab_bar: TabBar
var preview: CityMapPreviewControl
var mode_list: ItemList
var selected_tab := 0
var selected_item := 0
var refreshing := false
var image_signature: Array = []


func _ready() -> void:
	name = "CityMapWindowControl"
	add_theme_constant_override("separation", 8)
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
	add_child(preview)

	mode_list = ItemList.new()
	mode_list.name = "CityMapModes"
	mode_list.custom_minimum_size = Vector2(0, 96)
	mode_list.select_mode = ItemList.SELECT_SINGLE
	mode_list.item_selected.connect(_on_mode_selected)
	add_child(mode_list)

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
	if mode_list == null:
		return

	refreshing = true
	mode_list.clear()
	var modes: Array = TAB_MODES[selected_tab]

	for mode in modes:
		var resource_id := int(MODE_STRING_IDS.get(mode, 0))
		mode_list.add_item(str(strings.get(resource_id, MODE_NAMES.get(mode, mode))))

	selected_item = clampi(selected_item, 0, modes.size() - 1)
	mode_list.select(selected_item)
	refreshing = false


func _on_tab_changed(tab: int) -> void:
	if refreshing:
		return

	selected_tab = clampi(tab, 0, TAB_MODES.size() - 1)
	selected_item = 0
	_rebuild_modes()
	refresh()
	mode_changed.emit(current_mode())


func _on_mode_selected(item: int) -> void:
	if refreshing:
		return

	selected_item = clampi(item, 0, TAB_MODES[selected_tab].size() - 1)
	refresh()
	mode_changed.emit(current_mode())


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
