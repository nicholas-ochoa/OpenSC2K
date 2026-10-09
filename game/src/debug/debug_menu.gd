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
const MENU_REPAIR_BAD_TERRAIN := 0x8417
const MENU_FIND_ORPHAN_LABELS := 0x8418
const MENU_REMOVE_ORPHAN_LABELS := 0x8419
const MENU_RUN_SCRIPT := 0x841a
const MENU_RESET_SCRIPTS := 0x841b
const MENU_SCRIPT_INSPECTOR := 0x841c
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
# hover text of each item
const TOOLTIPS := {
	MENU_TILE_INSPECTOR: "Select the Tile Inspector. Point at a tile to read its stored bytes, flags and data map values.",
	MENU_TRIP_QUERY: "Select the Trip Query. Click a zone or network tile to show its routes and trip costs.",
	MENU_TILE_LAYERS: "Color each tile by one stored value or data map.",
	MENU_TILE_VALUES: "Write the tile layer value on each visible tile at a close zoom.",
	MENU_TILE_GRID: "Draw tile edges and X, Y coordinates on the map.",
	MENU_BASELINES: "Select the moment that the Changed Tiles layer compares with.",
	MENU_TAKE_SNAPSHOT: "Record the city now. Changed Tiles then shows changes since this moment.",
	MENU_REGION_BOUNDS: "Outline each render region. The color shows if it is ready, stale, building or missing.",
	MENU_REGION_REPAINTS: "Flash each render region when it draws again.",
	MENU_OCCLUDERS: "Outline the rectangles that hide moving things behind buildings.",
	MENU_SPRITE_BOUNDS: "Outline the bounds of each static and moving sprite.",
	MENU_DRAW_ORDER: "Write the painter order number on each sprite in view.",
	MENU_THING_PATHS: "Show the position and path of each moving thing.",
	MENU_FREEZE_PALETTE: "Stop the palette animation of water, lights and fire.",
	MENU_MISSING_ARTWORK: "Look for tiles around the view that have no sprite in the tile set.",
	MENU_REPAIR_BAD_TERRAIN: ("Repair dry tiles under a water level above the city's, as sc2kfix does. " +
		"The Unusual Values layer shows them. Undo Edit restores them."),
	MENU_FIND_ORPHAN_LABELS: "List the sign labels that no tile shows, as sc2kfix does. A cancelled sign can leave one.",
	MENU_REMOVE_ORPHAN_LABELS: "Clear the text of each sign label that no tile shows. Undo Edit restores them.",
	MENU_STEP_PHASE: "Run the next simulation step of the day. The city must be paused.",
	MENU_STEP_DAY: "Run the rest of the current day, or one full day. The city must be paused.",
	MENU_DISASTER_PREVIEWS: "Show where a disaster would spread from the center of the view. The city does not change.",
	MENU_VERIFY_SAVE: "Save a copy to a temporary file, load it again and compare each chunk. The city file does not change.",
	MENU_UNDO_EDIT: "Undo the last record edit from the Debug window.",
	MENU_PERFORMANCE_HUD: "Show frame time, render counters and a frame-time graph.",
	MENU_CAPTURE: "Save a screenshot and a JSON file of the debug state in the debug_captures folder.",
	MENU_DEBUG_WINDOW: "Open the Debug window with city records, metrics and edit tools.",
	MENU_RUN_SCRIPT: "Run a JavaScript file. Its event listeners, timers and console commands stay active until a reset.",
	MENU_RESET_SCRIPTS: "Stop all scripts: their event listeners, timers and console commands.",
	MENU_SCRIPT_INSPECTOR: "Let Chrome DevTools connect to scripts on port 9229: open chrome://inspect in Chrome.",
}
const BASELINE_TOOLTIPS := [
	"Compare with the city as it was loaded.",
	"Compare with the last change snapshot.",
	"Show the changes of the last simulated day.",
]


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
	popup.add_item("Repair Bad Terrain", MENU_REPAIR_BAD_TERRAIN)
	popup.add_item("Find Orphaned Labels", MENU_FIND_ORPHAN_LABELS)
	popup.add_item("Remove Orphaned Labels", MENU_REMOVE_ORPHAN_LABELS)
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
	popup.add_separator()
	popup.add_item("Run Script File", MENU_RUN_SCRIPT)
	popup.add_item("Reset Script Runtime", MENU_RESET_SCRIPTS)
	popup.add_check_item("Script Inspector", MENU_SCRIPT_INSPECTOR)

	for id: int in TOOLTIPS:
		popup.set_item_tooltip(popup.get_item_index(id), TOOLTIPS[id])


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
		menu.set_item_tooltip(baseline, BASELINE_TOOLTIPS[baseline])

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
