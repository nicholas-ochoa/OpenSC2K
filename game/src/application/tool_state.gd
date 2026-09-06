class_name ToolState
extends RefCounted


class BridgeRequest extends RefCounted:
	var start: Vector2i
	var finish: Vector2i
	var group_index: int
	var subtool_index: int
	var request_type: String
	var free_mode: bool
	var choices: Array[BridgeChoice] = []
	var dry_points: Array[Vector2i] = []

	func copy() -> BridgeRequest:
		var result := BridgeRequest.new()
		result.start = start
		result.finish = finish
		result.group_index = group_index
		result.subtool_index = subtool_index
		result.request_type = request_type
		result.free_mode = free_mode
		result.dry_points = dry_points.duplicate()

		for choice in choices:
			result.choices.append(choice.copy())

		return result


class ToolChoices extends RefCounted:
	var group_index: int
	var subtools: Array[int]

	func _init(value_group_index: int, value_subtools: Array[int]) -> void:
		group_index = value_group_index
		subtools = value_subtools


class TunnelRequest extends RefCounted:
	var start: Vector2i
	var group_index: int
	var subtool_index: int

	func _init(value_start: Vector2i, value_group_index: int, value_subtool_index: int) -> void:
		start = value_start
		group_index = value_group_index
		subtool_index = value_subtool_index


class ConnectionRequest extends RefCounted:
	var start: Vector2i
	var finish: Vector2i
	var group_index: int
	var subtool_index: int
	var bridge_type: int
	var free_mode: bool

	func _init(value_start: Vector2i, value_finish: Vector2i, value_group_index: int, value_subtool_index: int, value_bridge_type: int, value_free_mode: bool) -> void:
		start = value_start
		finish = value_finish
		group_index = value_group_index
		subtool_index = value_subtool_index
		bridge_type = value_bridge_type
		free_mode = value_free_mode


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
var pending_bridge_request: BridgeRequest
var pending_tool_choices: ToolChoices
var pending_stadium_command: BuildingEditResult
var pending_network_connection: ConnectionRequest
var pending_highway_connection: ConnectionRequest
var pending_tunnel_request: TunnelRequest
var active_query_result: Dictionary = {}
var pending_building_objection_group := -1
var pending_building_objection_subtool := -1
