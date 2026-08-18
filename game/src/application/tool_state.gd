class_name ToolState
extends RefCounted


const Random = preload("res://src/simulation/random/sim_random.gd")

# selected tool
var selected_group := 9
var selected_subtool := 0
var selected_tool_available := false
# edit state
var last_edit_command: EditCommandResult
var tool_random := Random.new(1)
var dispatch_cycles := PackedInt32Array([0, 0, 0])
var dispatch_initialized := false
# landscape editing
var landscape_brush_command: EditCommandResult
var level_brush_altitude := -1
var landscape_editor := false
var terrain_stretch := TerrainStretchSession.new()
# pending tool prompts
var pending_sign_tile := Vector2i(-1, -1)
var pending_bridge_request: Dictionary = {}
var pending_tool_choices: Dictionary = {}
var pending_stadium_command: BuildingEditResult
var pending_network_connection: Dictionary = {}
var pending_highway_connection: Dictionary = {}
var pending_tunnel_request: Dictionary = {}
var active_query_result: Dictionary = {}
var pending_building_objection_group := -1
var pending_building_objection_subtool := -1
