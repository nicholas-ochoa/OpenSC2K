class_name CityDebugMenu
extends RefCounted
## Items of the Debug menu. The menu appears in debug mode. Its tile layer and
## change baseline submenus send their own IDs to the same handler.

const MENU_TILE_INSPECTOR := 0x8400
const MENU_TRIP_QUERY := 0x8401
const MENU_TILE_VALUES := 0x8402
const MENU_REGION_BOUNDS := 0x8403
const MENU_REGION_REPAINTS := 0x8404
const MENU_OCCLUDERS := 0x8405
const MENU_SPRITE_BOUNDS := 0x8406
const MENU_THING_PATHS := 0x8407
const MENU_PERFORMANCE_HUD := 0x8408
const MENU_TAKE_SNAPSHOT := 0x8409
const MENU_CAPTURE := 0x840a
const MENU_DEBUG_WINDOW := 0x840b
const MENU_TILE_LAYERS := 0x840c
const MENU_BASELINES := 0x840d
const MENU_VERIFY_SAVE := 0x840e
const MENU_STEP_PHASE := 0x840f
const MENU_STEP_DAY := 0x8410
const MENU_DRAW_ORDER := 0x8411
const MENU_MISSING_ARTWORK := 0x8412
const MENU_FREEZE_PALETTE := 0x8413
const MENU_TILE_GRID := 0x8414
const MENU_DISASTER_PREVIEWS := 0x8415
const MENU_UNDO_EDIT := 0x8416
# a disaster preview item has this ID plus the disaster ID
const PREVIEW_BASE := 0x8700
# disaster ticks of a menu preview. The Scenario tab of the Debug window sets other counts
const PREVIEW_TICKS := 20
# a tile layer item has this ID plus its layer
const LAYER_BASE := 0x8500
# a change baseline item has this ID plus its baseline
const BASELINE_BASE := 0x8600
const BASELINE_TITLES := ["Since Load", "Since Snapshot", "Since Previous Day"]
# check items and the state field of each
const CHECKS := {
	MENU_TILE_VALUES: "tile_values", MENU_REGION_BOUNDS: "region_bounds", MENU_REGION_REPAINTS: "region_repaints",
	MENU_OCCLUDERS: "occluders", MENU_SPRITE_BOUNDS: "sprite_bounds", MENU_THING_PATHS: "thing_paths",
	MENU_PERFORMANCE_HUD: "performance_hud", MENU_DRAW_ORDER: "draw_order", MENU_FREEZE_PALETTE: "palette_frozen",
	MENU_TILE_GRID: "tile_grid",
}
# check items that the debug tools switch themselves
const HANDLED_CHECKS := [MENU_TILE_GRID]


static func populate(popup: PopupMenu, handler: Callable) -> void:
	popup.clear()
	popup.add_item("Tile Inspector", MENU_TILE_INSPECTOR)
	popup.add_item("Trip Query", MENU_TRIP_QUERY)
	popup.add_separator()
	popup.add_submenu_node_item("Tile Layer", _layer_menu(handler), MENU_TILE_LAYERS)
	popup.add_check_item("Show Tile Values", MENU_TILE_VALUES)
	popup.add_check_item("Tile Grid and Coordinates", MENU_TILE_GRID)
	popup.add_submenu_node_item("Change Baseline", _baseline_menu(handler), MENU_BASELINES)
	popup.add_item("Take Change Snapshot", MENU_TAKE_SNAPSHOT)
	popup.add_separator()
	popup.add_check_item("Region Bounds", MENU_REGION_BOUNDS)
	popup.add_check_item("Region Repaints", MENU_REGION_REPAINTS)
	popup.add_check_item("Occlusion Rectangles", MENU_OCCLUDERS)
	popup.add_check_item("Sprite Bounds", MENU_SPRITE_BOUNDS)
	popup.add_check_item("Draw Order", MENU_DRAW_ORDER)
	popup.add_check_item("Moving Thing Paths", MENU_THING_PATHS)
	popup.add_check_item("Freeze Palette Cycling", MENU_FREEZE_PALETTE)
	popup.add_item("Check Missing Artwork", MENU_MISSING_ARTWORK)
	popup.add_separator()
	popup.add_item("Advance One Phase", MENU_STEP_PHASE)
	popup.add_item("Advance One Day", MENU_STEP_DAY)
	popup.add_submenu_node_item("Preview Disaster at View Center", _preview_menu(handler), MENU_DISASTER_PREVIEWS)
	popup.add_separator()
	popup.add_item("Verify Save", MENU_VERIFY_SAVE)
	popup.add_item("Undo Debug Edit", MENU_UNDO_EDIT)
	popup.add_separator()
	popup.add_check_item("Performance HUD", MENU_PERFORMANCE_HUD)
	popup.add_item("Capture Screenshot and State", MENU_CAPTURE)
	popup.add_item("Debug Window", MENU_DEBUG_WINDOW)


static func _preview_menu(handler: Callable) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.name = "DisasterPreviews"

	for item in CityMenuBar.DISASTER_ITEMS:
		menu.add_item(item[0], PREVIEW_BASE + int(item[1]))

	menu.id_pressed.connect(handler)

	return menu


static func _layer_menu(handler: Callable) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.name = "TileLayers"
	menu.add_radio_check_item(DebugTileLayers.title(DebugTileLayers.Layer.NONE), LAYER_BASE + DebugTileLayers.Layer.NONE)

	for group in DebugTileLayers.GROUPS:
		menu.add_separator(group[0])

		for layer in group[1]:
			menu.add_radio_check_item(DebugTileLayers.title(layer), LAYER_BASE + layer)

	menu.id_pressed.connect(handler)

	return menu


static func _baseline_menu(handler: Callable) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.name = "ChangeBaselines"

	for baseline in BASELINE_TITLES.size():
		menu.add_radio_check_item(BASELINE_TITLES[baseline], BASELINE_BASE + baseline)

	menu.id_pressed.connect(handler)

	return menu


# check marks and radio marks from the state
static func sync(popup: PopupMenu, state: DebugViewState, inspector_selected: bool, trip_selected: bool) -> void:
	for id in CHECKS:
		var index := popup.get_item_index(id)

		if index >= 0:
			popup.set_item_checked(index, bool(state.get(CHECKS[id])))

	for pair in [[MENU_TILE_INSPECTOR, inspector_selected], [MENU_TRIP_QUERY, trip_selected]]:
		var index := popup.get_item_index(pair[0])

		if index >= 0:
			popup.set_item_as_checkable(index, true)
			popup.set_item_checked(index, pair[1])

	var layers := _submenu(popup, MENU_TILE_LAYERS)

	if layers != null:
		for index in layers.item_count:
			var id := layers.get_item_id(index)

			if id >= LAYER_BASE and not layers.is_item_separator(index):
				layers.set_item_checked(index, id - LAYER_BASE == state.tile_layer)

	var baselines := _submenu(popup, MENU_BASELINES)

	if baselines != null:
		for index in baselines.item_count:
			baselines.set_item_checked(index, baselines.get_item_id(index) - BASELINE_BASE == state.change_baseline)


static func _submenu(popup: PopupMenu, id: int) -> PopupMenu:
	var index := popup.get_item_index(id)

	return popup.get_item_submenu_node(index) if index >= 0 else null
