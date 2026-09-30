class_name ControlActions
extends RefCounted
## The player actions that keys and mouse buttons can start, with their
## default bindings. The action ids are stored in the settings file.

# map actions need the city view with no dialog or text field in use. global
# actions work while a text field has focus. fixed rows are read-only help
const SCOPE_MAP := "map"
const SCOPE_GLOBAL := "global"
const SCOPE_FIXED := "fixed"
# press actions start once. hold actions are active while the binding is down.
# click actions use the map tile under the pointer. drag actions follow the
# pointer while the button is down
const KIND_PRESS := "press"
const KIND_HOLD := "hold"
const KIND_CLICK := "click"
const KIND_DRAG := "drag"
const CATEGORIES: Array[String] = ["Camera", "Speed", "Tools", "View", "Windows", "Options", "File", "Mouse", "Fixed"]
const TOOL_IDS: Array[String] = [
	"tool_bulldozer", "tool_landscape", "tool_dispatch", "tool_power", "tool_water", "tool_rewards",
	"tool_roads", "tool_rail", "tool_ports", "tool_residential", "tool_commercial", "tool_industrial",
	"tool_education", "tool_services", "tool_recreation", "tool_signs", "tool_query", "tool_center",
]
const TOOL_LABELS: Array[String] = [
	"Bulldozer", "Landscape", "Emergency dispatch", "Power", "Water", "Rewards",
	"Roads", "Rail", "Ports", "Residential zones", "Commercial zones", "Industrial zones",
	"Education", "City services", "Recreation", "Signs", "Query", "Center",
]
const TOOL_DEFAULTS: Dictionary[String, Array] = {
	"tool_bulldozer": ["key:X"], "tool_query": ["key:Z"], "tool_center": ["key:C"],
}
const CAMERA_DIRECTIONS: Dictionary[String, Vector2] = {
	"camera_up": Vector2.UP, "camera_left": Vector2.LEFT, "camera_down": Vector2.DOWN, "camera_right": Vector2.RIGHT,
}
const SPEED_IDS: Array[String] = ["speed_pause", "speed_turtle", "speed_llama", "speed_cheetah", "speed_african_swallow"]
const SURFACE_LAYERS: Array[Array] = [
	["view_show_buildings", "Show buildings", "buildings"], ["view_show_networks", "Show networks", "networks"],
	["view_show_water", "Show water", "water"], ["view_show_trees", "Show trees", "trees"],
	["view_show_zones", "Show zones", "zones"], ["view_show_signs", "Show signs", "signs"],
	["view_show_pipes", "Show pipes", "pipes"], ["view_show_water_mains", "Show water mains", "water_mains"],
	["view_show_vehicles", "Show vehicles", "vehicles"],
]
const DATA_VIEW_IDS: Array[String] = [
	"view_density", "view_growth", "view_traffic", "view_pollution", "view_crime",
	"view_police_power", "view_fire_power", "view_land_value", "view_water_supply", "view_power_supply", "view_height",
]
# Windows menu ids, in CityMenuBar order
const WINDOW_ACTIONS: Array[Array] = [
	["window_budget", "Budget", 0, ["key:B"]], ["window_ordinances", "Ordinances", 1, []],
	["window_population", "Population", 2, []], ["window_industry", "Industry", 3, []],
	["window_graphs", "Graphs", 4, ["key:G"]], ["window_neighbors", "Neighbors", 5, []],
	["window_map", "Map", 6, ["key:M"]], ["window_scenario_goals", "Scenario goals", 8, []],
	["window_debug", "Debug window", 7, ["key:F12"]],
]

static var _catalog: Array[Action] = []
static var _by_id: Dictionary[String, Action] = {}


static func all() -> Array[Action]:
	if _catalog.is_empty():
		_build()

	return _catalog


static func find(id: String) -> Action:
	if _catalog.is_empty():
		_build()

	return _by_id.get(id)


static func has(id: String) -> bool:
	return find(id) != null


static func bindable_ids() -> Array[String]:
	var result: Array[String] = []

	for action in all():
		if action.scope != SCOPE_FIXED:
			result.append(action.id)

	return result


static func _build() -> void:
	var mac := OS.has_feature("macos")
	_add("camera_up", "Move up", "Camera", SCOPE_MAP, KIND_HOLD, ["key:W", "key:Up"])
	_add("camera_left", "Move left", "Camera", SCOPE_MAP, KIND_HOLD, ["key:A", "key:Left"])
	_add("camera_down", "Move down", "Camera", SCOPE_MAP, KIND_HOLD, ["key:S", "key:Down"])
	_add("camera_right", "Move right", "Camera", SCOPE_MAP, KIND_HOLD, ["key:D", "key:Right"])
	_add("camera_fast", "Fast move (hold)", "Camera", SCOPE_MAP, KIND_HOLD, ["key:Shift"])
	_add("zoom_in", "Zoom in", "Camera", SCOPE_MAP, KIND_PRESS, ["key:E", "key:Equal", "key:Plus", "key:Kp Add", "mouse:WheelUp"])
	_add("zoom_out", "Zoom out", "Camera", SCOPE_MAP, KIND_PRESS,
		["key:Q", "key:Minus", "key:Kp Subtract", "mouse:WheelDown"])
	_add("zoom_reset", "Reset zoom to 100%", "Camera", SCOPE_MAP, KIND_PRESS, ["key:0"])
	_add("rotate_clockwise", "Rotate clockwise", "Camera", SCOPE_MAP, KIND_PRESS, ["key:Period", "mouse:Extra2"])
	_add("rotate_counter_clockwise", "Rotate counterclockwise", "Camera", SCOPE_MAP, KIND_PRESS, ["key:Comma", "mouse:Extra1"])

	_add("speed_toggle_pause", "Pause or resume", "Speed", SCOPE_MAP, KIND_PRESS, ["key:Space"])
	_add("speed_pause", "Pause", "Speed", SCOPE_MAP, KIND_PRESS, [])
	_add("speed_turtle", "Turtle", "Speed", SCOPE_MAP, KIND_PRESS, ["key:1"])
	_add("speed_llama", "Llama", "Speed", SCOPE_MAP, KIND_PRESS, ["key:2"])
	_add("speed_cheetah", "Cheetah", "Speed", SCOPE_MAP, KIND_PRESS, ["key:3"])
	_add("speed_african_swallow", "African Swallow", "Speed", SCOPE_MAP, KIND_PRESS, ["key:4"])
	_add("speed_faster", "Faster", "Speed", SCOPE_MAP, KIND_PRESS, [])
	_add("speed_slower", "Slower", "Speed", SCOPE_MAP, KIND_PRESS, [])

	for index in TOOL_IDS.size():
		_add(TOOL_IDS[index], TOOL_LABELS[index], "Tools", SCOPE_MAP, KIND_PRESS, TOOL_DEFAULTS.get(TOOL_IDS[index], []))

	_add("tool_next_subtool", "Next tool in group", "Tools", SCOPE_MAP, KIND_PRESS, ["key:Tab"])
	_add("tool_previous_subtool", "Previous tool in group", "Tools", SCOPE_MAP, KIND_PRESS, ["key:Shift+Tab"])
	_add("brush_larger", "Larger brush", "Tools", SCOPE_MAP, KIND_PRESS, ["key:BracketRight"])
	_add("brush_smaller", "Smaller brush", "Tools", SCOPE_MAP, KIND_PRESS, ["key:BracketLeft"])
	_add("tool_previous", "Previous tool", "Tools", SCOPE_MAP, KIND_PRESS, [])
	_add("cancel_selection", "Cancel selection", "Tools", SCOPE_MAP, KIND_PRESS, [])

	_add("view_city", "City view", "View", SCOPE_MAP, KIND_PRESS, ["key:V"])
	_add("view_toggle_underground", "Underground view", "View", SCOPE_MAP, KIND_PRESS, ["key:U"])

	for index in DATA_VIEW_IDS.size():
		_add(DATA_VIEW_IDS[index], "%s view" % CityDataView.TITLES[index], "View", SCOPE_MAP, KIND_PRESS, [])

	for layer in SURFACE_LAYERS:
		_add(layer[0], layer[1], "View", SCOPE_MAP, KIND_PRESS, [])

	_add("toggle_fullscreen", "Full screen", "View", SCOPE_GLOBAL, KIND_PRESS, ["key:Command+Ctrl+F"] if mac else ["key:F11"])

	for window in WINDOW_ACTIONS:
		_add(window[0], window[1], "Windows", SCOPE_MAP if window[0] != "window_debug" else SCOPE_GLOBAL, KIND_PRESS, window[3])

	_add("window_newspaper", "Latest newspaper", "Windows", SCOPE_MAP, KIND_PRESS, ["key:N"])

	_add("option_auto_budget", "Auto-Budget", "Options", SCOPE_MAP, KIND_PRESS, [])
	_add("option_auto_goto", "Auto-Goto", "Options", SCOPE_MAP, KIND_PRESS, [])
	_add("option_sound_effects", "Sound effects", "Options", SCOPE_MAP, KIND_PRESS, [])
	_add("option_music", "Music", "Options", SCOPE_MAP, KIND_PRESS, [])
	_add("settings", "Settings", "Options", SCOPE_GLOBAL, KIND_PRESS, ["key:Command+Comma"])

	_add("undo", "Undo", "File", SCOPE_GLOBAL, KIND_PRESS, ["key:Command+Z"])
	_add("file_new", "New city", "File", SCOPE_GLOBAL, KIND_PRESS, ["key:Command+N"])
	_add("file_open", "Open city", "File", SCOPE_GLOBAL, KIND_PRESS, ["key:Command+O"])
	_add("file_save", "Save city", "File", SCOPE_GLOBAL, KIND_PRESS, ["key:Command+S"])
	_add("file_save_as", "Save city as", "File", SCOPE_GLOBAL, KIND_PRESS, ["key:Command+Shift+S"])
	_add("file_rename", "Rename city", "File", SCOPE_GLOBAL, KIND_PRESS, [])
	_add("file_export_png", "Export city as PNG", "File", SCOPE_GLOBAL, KIND_PRESS, [])
	_add("file_main_menu", "Main menu", "File", SCOPE_GLOBAL, KIND_PRESS, [])
	_add("file_quit", "Quit", "File", SCOPE_GLOBAL, KIND_PRESS, ["key:Command+Q"] if mac else [])

	_add("map_use_tool", "Use tool", "Mouse", SCOPE_FIXED, KIND_CLICK, ["mouse:Left"])
	_add("map_context_menu", "Context menu", "Mouse", SCOPE_MAP, KIND_CLICK, ["mouse:Right"])
	_add("map_center_on_tile", "Center on tile", "Mouse", SCOPE_MAP, KIND_CLICK, ["mouse:Middle"])
	_add("map_pan", "Move map (drag)", "Mouse", SCOPE_MAP, KIND_DRAG, ["mouse:Right", "mouse:Middle"])

	_add_fixed("fixed_escape", "Cancel or close", "Esc")
	_add_fixed("fixed_shift_tool", "Line, rectangle, or query with the current tool", "Hold Shift")
	_add_fixed("fixed_media", "Music playback", "Media keys")
	_add_fixed("fixed_scurk", "SCURK editor", "Editor shortcuts")


static func _add(id: String, label: String, category: String, scope: String, kind: String, defaults: Array) -> void:
	var action := Action.new()
	action.id = id
	action.label = label
	action.category = category
	action.scope = scope
	action.kind = kind
	action.defaults.assign(defaults)
	_catalog.append(action)
	_by_id[id] = action


static func _add_fixed(id: String, label: String, text: String) -> void:
	_add(id, label, "Fixed", SCOPE_FIXED, KIND_PRESS, [])
	_by_id[id].fixed_text = text


class Action extends RefCounted:
	var id := ""
	var label := ""
	var category := ""
	var scope := SCOPE_MAP
	var kind := KIND_PRESS
	var defaults: Array[String] = []
	# text for fixed rows that have no binding
	var fixed_text := ""
