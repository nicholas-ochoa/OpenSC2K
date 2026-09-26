class_name ScurkPlacePrintControl
extends Window

signal tile_selected(tile_id: int)
signal edit_tool_selected(group_index: int, subtool_index: int, zone_type: int)
signal export_bmp_requested
signal print_city_requested
signal undo_requested
signal redo_requested

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const Place = preload("res://src/tools/scurk/scurk_place_command.gd")
const PickCopy = preload("res://src/tools/scurk/scurk_pick_copy.gd")

const MODE_OBJECTS := 0
const MODE_EDIT_TOOLS := 1
static var EDIT_TOOLS: Array[ScurkEditTool] = [
	ScurkEditTool.new("Bulldozer", CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.DEMOLISH, -1, "either"),
	ScurkEditTool.new("Level Terrain", CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.LEVEL, -1, "city"),
	ScurkEditTool.new("Raise Terrain", CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.RAISE, -1, "city"),
	ScurkEditTool.new("Lower Terrain", CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.LOWER, -1, "city"),
	ScurkEditTool.new("De-zone", CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.DEZONE, 0, "city"),
	ScurkEditTool.new("Pond, Lake, or River", CityToolIds.Group.LANDSCAPE, CityToolIds.Landscape.WATER, -1, "city"),
	ScurkEditTool.new("Water Pipes", CityToolIds.Group.WATER, CityToolIds.Water.PIPES, -1, "underground"),
	ScurkEditTool.new("Light Residential", CityToolIds.Group.RESIDENTIAL, CityToolIds.Residential.LIGHT, 1, "city"),
	ScurkEditTool.new("Dense Residential", CityToolIds.Group.RESIDENTIAL, CityToolIds.Residential.DENSE, 2, "city"),
	ScurkEditTool.new("Light Commercial", CityToolIds.Group.COMMERCIAL, CityToolIds.Commercial.LIGHT, 3, "city"),
	ScurkEditTool.new("Dense Commercial", CityToolIds.Group.COMMERCIAL, CityToolIds.Commercial.DENSE, 4, "city"),
	ScurkEditTool.new("Light Industrial", CityToolIds.Group.INDUSTRIAL, CityToolIds.Industrial.LIGHT, 5, "city"),
	ScurkEditTool.new("Dense Industrial", CityToolIds.Group.INDUSTRIAL, CityToolIds.Industrial.DENSE, 6, "city"),
	ScurkEditTool.new("Seaport Zone", CityToolIds.Group.PORTS, CityToolIds.Ports.SEAPORT, 9, "city"),
	ScurkEditTool.new("Airport Zone", CityToolIds.Group.PORTS, CityToolIds.Ports.AIRPORT, 8, "city"),
	# Military uses the seaport command with a saved zone override.
	ScurkEditTool.new("Military Zone", CityToolIds.Group.PORTS, CityToolIds.Ports.SEAPORT, 7, "city"),
	ScurkEditTool.new("Road", CityToolIds.Group.ROADS, CityToolIds.Roads.ROAD, -1, "city"),
	ScurkEditTool.new("Highway", CityToolIds.Group.ROADS, CityToolIds.Roads.HIGHWAY, -1, "city"),
	ScurkEditTool.new("Tunnel", CityToolIds.Group.ROADS, CityToolIds.Roads.TUNNEL, -1, "city"),
	ScurkEditTool.new("On-ramp", CityToolIds.Group.ROADS, CityToolIds.Roads.ONRAMP, -1, "city"),
	ScurkEditTool.new("Power Line", CityToolIds.Group.POWER, CityToolIds.Power.WIRES, -1, "city"),
	ScurkEditTool.new("Rail", CityToolIds.Group.RAIL, CityToolIds.Rail.RAIL, -1, "city"),
	ScurkEditTool.new("Subway", CityToolIds.Group.RAIL, CityToolIds.Rail.SUBWAY, -1, "underground"),
	ScurkEditTool.new("Subway-to-Rail Connector", CityToolIds.Group.RAIL, CityToolIds.Rail.SUBWAY_TO_RAIL, -1, "underground"),
	ScurkEditTool.new("Center", CityToolIds.Group.CENTERING, CityToolIds.Centering.CENTER, -1, "either"),
]

const THUMBNAIL_SIZE := 64
const PANEL_SIZE := Vector2i(440, 680)
const ZONE_CHOICES := [
	["Automatic", 0],
	["Light Residential", 1],
	["Dense Residential", 2],
	["Light Commercial", 3],
	["Dense Commercial", 4],
	["Light Industrial", 5],
	["Dense Industrial", 6],
	["Military", 7],
	["Airport or Seaport", 8],
	["Special", 9],
]

var palette: Sc2Palette
var sprites: Sc2SpriteArchive
var custom_names: Dictionary = {}
var current_group := PickCopy.GROUP_RESIDENTIAL
var selected_tile_id := -1
var selected_edit_index := 0
var icon_cache: Dictionary = {}

var instructions: Label
var mode_selector: OptionButton
var group_row: HBoxContainer
var group_selector: OptionButton
var zone_row: HBoxContainer
var zone_selector: OptionButton
var object_list: ItemList
var tool_list: ItemList
var selection_label: Label
var export_bmp_button: Button
var undo_button: Button
var redo_button: Button


func _ready() -> void:
	hide()
	instructions = get_node("Panel/Margin/Content/Instructions")
	mode_selector = get_node("Panel/Margin/Content/WorkspaceRow/ModeSelector")
	group_row = get_node("Panel/Margin/Content/GroupRow")
	group_selector = get_node("Panel/Margin/Content/GroupRow/GroupSelector")
	zone_row = get_node("Panel/Margin/Content/ZoneRow")
	zone_selector = get_node("Panel/Margin/Content/ZoneRow/ZoneSelector")
	object_list = get_node("Panel/Margin/Content/PlaceObjectList")
	tool_list = get_node("Panel/Margin/Content/PlaceEditToolList")
	selection_label = get_node("Panel/Margin/Content/SelectionLabel")
	export_bmp_button = get_node("Panel/Margin/Content/OutputActions/ExportBmpButton")
	undo_button = get_node("Panel/Margin/Content/HistoryActions/UndoButton")
	redo_button = get_node("Panel/Margin/Content/HistoryActions/RedoButton")
	get_node("Panel/Margin/Content/WorkspaceRow/ModeSelector").item_selected.connect(_on_mode_selected)
	get_node("Panel/Margin/Content/GroupRow/GroupSelector").item_selected.connect(_on_group_selected)
	get_node("Panel/Margin/Content/PlaceObjectList").item_selected.connect(_on_object_selected)
	get_node("Panel/Margin/Content/PlaceObjectList").item_activated.connect(_on_object_selected)
	get_node("Panel/Margin/Content/PlaceEditToolList").item_selected.connect(_on_edit_tool_selected)
	get_node("Panel/Margin/Content/PlaceEditToolList").item_activated.connect(_on_edit_tool_selected)
	export_bmp_button.pressed.connect(export_bmp_requested.emit)
	$Panel/Margin/Content/OutputActions/PrintCity.pressed.connect(print_city_requested.emit)
	undo_button.pressed.connect(undo_requested.emit)
	redo_button.pressed.connect(redo_requested.emit)
	$Panel/Margin/Content/HistoryActions/Close.pressed.connect(close_requested.emit)
	tool_list.clear()

	for index in EDIT_TOOLS.size():
		var tool: ScurkEditTool = EDIT_TOOLS[index]
		var item := tool_list.add_item(String(tool.name))
		tool_list.set_item_metadata(item, index)
		tool_list.set_item_tooltip(item, "%s is free in Place & Print. Normal terrain and map-edge rules still apply." % tool.name)

	tool_list.select(selected_edit_index)
	_sync_mode_controls()


func configure(
	value_palette: Sc2Palette,
	value_sprites: Sc2SpriteArchive,
	value_names: Dictionary = {},
	value_graphics: ScurkGraphics = null,
) -> void:
	palette = value_palette
	sprites = value_sprites
	custom_names = value_names.duplicate()
	set_workspace_images(value_graphics.workspace_images if value_graphics != null else {})
	icon_cache.clear()
	_refresh_objects()


func set_workspace_images(images: Dictionary) -> void:
	if tool_list == null:
		return

	var textures := {}

	for id in images:
		if id >= 1200 and id <= 1215:
			textures[id] = PixelArtTexture.wrap(ImageTexture.create_from_image(images[id]))

	tool_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mode_selector.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	object_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	for i in EDIT_TOOLS.size():
		var tool: ScurkEditTool = EDIT_TOOLS[i]
		var id := 1200

		if int(tool.zone) >= 0:
			id = 1202
		else:
			id = {0: 1200, 1: 1201, 3: 1205, 4: 1201, 6: 1203, 7: 1204, 17: 1210}.get(int(tool.group), 1200)

		tool_list.set_item_icon(i, textures.get(id))

	mode_selector.set_item_icon(MODE_OBJECTS, textures.get(1212))
	mode_selector.set_item_icon(MODE_EDIT_TOOLS, textures.get(1200))


func show_workspace() -> bool:
	if (
		palette == null
		or not palette.is_valid()
		or sprites == null
		or not sprites.is_valid()
	):
		return false

	popup_centered(PANEL_SIZE)

	if is_object_mode() and object_list != null:
		object_list.grab_focus()
	elif tool_list != null:
		tool_list.grab_focus()

	return true


func is_object_mode() -> bool:
	return mode_selector == null or mode_selector.selected == MODE_OBJECTS


func selected_edit_tool() -> ScurkEditTool:
	if is_object_mode() or selected_edit_index < 0 or selected_edit_index >= EDIT_TOOLS.size():
		return null

	return EDIT_TOOLS[selected_edit_index].copy()


func select_edit_tool(index: int, notify := true) -> bool:
	if index < 0 or index >= EDIT_TOOLS.size():
		return false

	selected_edit_index = index

	if mode_selector != null:
		mode_selector.select(MODE_EDIT_TOOLS)

	_sync_mode_controls()

	if tool_list != null:
		tool_list.select(index)
		tool_list.ensure_current_is_visible()

	_update_selection_label()

	if notify:
		_emit_edit_tool()

	return true


func selected_zone_id() -> int:
	if zone_selector == null or zone_selector.selected < 0:
		return 0

	return zone_selector.get_item_id(zone_selector.selected)


func select_tile(tile_id: int, notify := true) -> bool:
	if not Place.is_placeable_tile(tile_id):
		return false

	var group := _first_group_for_tile(tile_id)

	if group < 0:
		return false

	current_group = group
	selected_tile_id = tile_id

	if mode_selector != null:
		mode_selector.select(MODE_OBJECTS)

	_sync_mode_controls()
	_select_group_button(group)
	_refresh_objects()

	if notify:
		tile_selected.emit(selected_tile_id)

	return true


func set_history_enabled(can_undo: bool, can_redo: bool) -> void:
	if undo_button != null:
		undo_button.disabled = not can_undo

	if redo_button != null:
		redo_button.disabled = not can_redo


func set_export_enabled(enabled: bool) -> void:
	if export_bmp_button == null:
		return

	export_bmp_button.disabled = not enabled
	export_bmp_button.tooltip_text = (
		"Export the current work area as a small-view indexed BMP."
		if enabled
		else "Zoom out to 25% before you export the Place & Print city."
	)


func set_status(message: String) -> void:
	if selection_label != null:
		selection_label.text = message
		selection_label.tooltip_text = message


func _on_mode_selected(index: int) -> void:
	if index < MODE_OBJECTS or index > MODE_EDIT_TOOLS:
		return

	_sync_mode_controls()
	_update_selection_label()

	if is_object_mode():
		if selected_tile_id >= 0:
			tile_selected.emit(selected_tile_id)
	else:
		_emit_edit_tool()


func _on_group_selected(index: int) -> void:
	if index < 0 or index >= group_selector.item_count:
		return

	current_group = group_selector.get_item_id(index)
	selected_tile_id = -1
	_refresh_objects()


func _on_object_selected(index: int) -> void:
	if index < 0 or index >= object_list.item_count:
		return

	selected_tile_id = int(object_list.get_item_metadata(index))
	_update_selection_label()
	tile_selected.emit(selected_tile_id)


func _on_edit_tool_selected(index: int) -> void:
	if index < 0 or index >= tool_list.item_count:
		return

	selected_edit_index = int(tool_list.get_item_metadata(index))
	_update_selection_label()
	_emit_edit_tool()


func _refresh_objects() -> void:
	if object_list == null:
		return

	object_list.clear()

	if sprites == null or not sprites.is_valid():
		return

	var selected_index := -1

	for large_id in Place.placeable_large_ids(current_group):
		if sprites.find_sprite(large_id) == null:
			continue

		var tile_id := ScurkEditorRules.object_tile_id(large_id)
		var label := "%03d\n%s" % [tile_id, _object_name(tile_id)]
		var item_index := object_list.add_item(label, _object_icon(tile_id))
		object_list.set_item_metadata(item_index, tile_id)
		object_list.set_item_tooltip(
			item_index,
			"%s\nTile %d; large sprite %d" % [
				_object_name(tile_id), tile_id, large_id,
			]
		)

		if tile_id == selected_tile_id:
			selected_index = item_index

	if selected_index < 0 and object_list.item_count > 0:
		selected_index = 0
		selected_tile_id = int(object_list.get_item_metadata(0))

	if selected_index >= 0:
		object_list.select(selected_index)
		object_list.ensure_current_is_visible()

	_update_selection_label()

	if selected_tile_id >= 0 and is_object_mode():
		tile_selected.emit(selected_tile_id)


func _update_selection_label() -> void:
	if not is_object_mode():
		var tool := selected_edit_tool()

		if tool == null:
			set_status("Select an edit tool.")

			return

		set_status(
			"Selected: %s. This tool does not change city funds." % tool.name
		)

		return

	if selected_tile_id < 0:
		set_status("No object is available in this group.")

		return

	if selected_tile_id > Tiles.MAX_ID:
		set_status("Artwork stamp: kept in this workspace session. Undo and Redo are available.")

		return

	var area := Place.footprint(selected_tile_id, Vector2i(8, 8)).size.x
	set_status(
		"Selected: %s (tile %d, %d by %d footprint)."
		% [_object_name(selected_tile_id), selected_tile_id, area, area]
	)


func _sync_mode_controls() -> void:
	var objects_visible := is_object_mode()

	if group_row != null:
		group_row.visible = objects_visible

	if zone_row != null:
		zone_row.visible = objects_visible

	if object_list != null:
		object_list.visible = objects_visible

	if tool_list != null:
		tool_list.visible = not objects_visible

	if instructions != null:
		instructions.text = (
			"Select an object. Then click its anchor tile in the city. "
			+ "SCURK placement does not use city funds or normal development gates."
			if objects_visible
			else (
				"Select an edit tool. Then click or drag in the city. "
				+ "Money, time, population, and development limits do not apply."
			)
		)


func _emit_edit_tool() -> void:
	var tool := selected_edit_tool()

	if tool == null:
		return

	edit_tool_selected.emit(
		int(tool.group), int(tool.subtool), int(tool.zone)
	)


func _object_name(tile_id: int) -> String:
	var custom_name := String(custom_names.get(tile_id, "")).strip_edges()

	if not custom_name.is_empty():
		return custom_name

	if tile_id >= Tiles.DEVELOPED_FIRST and tile_id <= Tiles.DEVELOPED_3X3_LAST:
		return "Residential, Commercial, or Industrial"

	if tile_id >= Tiles.HYDRO_POWER_1 and tile_id <= Tiles.COAL_POWER:
		return "Power Plant"

	if tile_id >= Tiles.CITY_HALL and tile_id <= Tiles.PIER:
		return "City Service"

	if tile_id >= Tiles.CRANE and tile_id <= Tiles.DESALINIZATION:
		return "City Infrastructure"

	if tile_id <= Tiles.SMALL_PARK:
		return "Landscape Object"

	return ScurkEditorRules.sprite_role(tile_id)


func _object_icon(tile_id: int) -> Texture2D:
	if icon_cache.has(tile_id):
		return icon_cache[tile_id]

	var entry = sprites.find_sprite(ScurkSpriteIds.LARGE_FIRST + tile_id)

	if entry == null:
		return null

	var rendered := entry.create_image(palette)

	if not rendered.ok:
		return null

	var image: Image = rendered.image.duplicate()
	var scale := minf(
		1.0,
		minf(
			float(THUMBNAIL_SIZE) / float(maxi(1, image.get_width())),
			float(THUMBNAIL_SIZE) / float(maxi(1, image.get_height()))
		)
	)

	if scale < 1.0:
		image.resize(
			maxi(1, floori(image.get_width() * scale)),
			maxi(1, floori(image.get_height() * scale)),
			Image.INTERPOLATE_NEAREST
		)

	var texture := PixelArtTexture.wrap(ImageTexture.create_from_image(image))
	icon_cache[tile_id] = texture

	return texture


func _select_group_button(group: int) -> void:
	if group_selector == null:
		return

	for index in group_selector.item_count:
		if group_selector.get_item_id(index) == group:
			group_selector.select(index)

			return


static func placeable_groups() -> PackedInt32Array:
	return PackedInt32Array([
		PickCopy.GROUP_RESIDENTIAL,
		PickCopy.GROUP_COMMERCIAL,
		PickCopy.GROUP_INDUSTRIAL,
		PickCopy.GROUP_SPECIAL,
		PickCopy.GROUP_POWER,
		PickCopy.GROUP_TRANSPORTATION,
		PickCopy.GROUP_MISC,
		PickCopy.GROUP_CONSTRUCTION,
		PickCopy.GROUP_ALL,
	])


static func _first_group_for_tile(tile_id: int) -> int:
	for group in placeable_groups():
		if group == PickCopy.GROUP_ALL:
			continue

		if PickCopy.GROUP_TILE_IDS[group].has(tile_id):
			return group

	return -1
