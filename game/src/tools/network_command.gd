class_name NetworkCommand
extends RefCounted

const MISC_FUNDS := 0x0014
const MISC_TILE_COUNTS := 0x01f0
const MISC_MILITARY_TILE_COUNTS := 0x0fa8
const MILITARY_ZONE := 7
const FLAG_WATER := 0x04
const FLAG_FLIPPED := 0x02
const FLAG_PIPED := 0x20
const FLAG_POWERABLE := 0x80

const MODE_ROAD := 0
const MODE_RAIL := 1
const MODE_POWER := 2
const MODE_SUBWAY := 3
const MODE_PIPE := 4

const BRIDGE_CANCELLED := -2
const BRIDGE_UNSELECTED := -1
const BRIDGE_WIRE := 0
const BRIDGE_RAIL := 1
const BRIDGE_ROAD_CAUSEWAY := 2
const BRIDGE_ROAD_RAISING := 3
const BRIDGE_ROAD_SUSPENSION := 4

const CONNECTION_LABEL := 0xfa
const CONNECTION_UNSELECTED := -1
const CONNECTION_CANCELLED := 0
const CONNECTION_CONFIRMED := 1
const ROAD_CONNECTION_COST := 1000
const RAIL_CONNECTION_COST := 1500

const BRIDGE_NAMES := [
	"Raised Wires",
	"Rail Bridge",
	"Causeway",
	"Raising Bridge",
	"Suspension Bridge",
]
const BRIDGE_COSTS := [10, 75, 25, 50, 75]
const BRIDGE_MODE_MASKS := [0x1c, 0x02, 0x01]
const BRIDGE_SHORE_DIRECTIONS := [
	0, 2, 4, 8, 1, 6, 12, 9,
	3, 0, 0, 0, 0, 0, 0, 0,
]

const NETWORK_TOOLS := {
	36: MODE_POWER,
	48: MODE_PIPE,
	72: MODE_ROAD,
	84: MODE_RAIL,
	85: MODE_SUBWAY,
}

const NETWORK_SHAPES := [0, 0, 1, 6, 0, 0, 7, 11, 1, 9, 1, 10, 8, 13, 12, 14]
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const TERRAIN_REQUIRES_GRADING := [
	false, false, false, false, false, true, true, true,
	true, true, true, true, true, false, false, false,
]
const TERRAIN_IS_NETWORK_SLOPE := [
	false, true, true, true, true, false, false, false,
	false, true, true, true, true, false, false, false,
]
const TERRAIN_BLOCKS_DIRECTION := [
	false, false, false, false,
	true, false, true, false,
	false, true, false, true,
	true, false, true, false,
	false, true, false, true,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	true, false, true, false,
	true, false, true, false,
]
const GRADED_TERRAIN := [
	0, 0, 1, 0,
	0, 0, 0, 0,
	0, 0, 1, 1,
	0, 0, 1, 1,
	0, 0, 0, 0,
	0, 0, 0, 0,
	0, 0, 0, 0,
	0, 0, 0, 0,
	0, 0, 0, 0,
	2, 1, 2, 1,
	2, 3, 2, 3,
	4, 3, 4, 3,
	4, 1, 4, 1,
	0, 0, 1, 6,
	0, 0, 7, 11,
	1, 9, 1, 10,
]
const NETWORK_SLOPE_SHAPES := [0, 2, 3, 4, 5]
const MILITARY_TILE_COUNT_INDEX := {
	0xdd: 1,
	0xde: 2,
	0xef: 3,
	0xf2: 4,
	0xea: 5,
	0xe3: 6,
	0xe4: 7,
	0xe5: 8,
	0xf1: 9,
	0xe0: 10,
	0xe2: 11,
	0xe7: 12,
	0xe8: 13,
	0xf6: 14,
	0xf9: 15,
}


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return NETWORK_TOOLS.has(group_index * ToolCatalog.MAX_SLOTS_PER_GROUP + subtool_index)


static func route(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [start]
	var current := start
	while current != finish:
		var direction := _primary_direction(current, finish)
		current += DIRECTIONS[direction]
		result.append(current)
	return result


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	finish: Vector2i,
	bridge_type := BRIDGE_UNSELECTED,
	connection_choice := CONNECTION_UNSELECTED,
	free_mode := false
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool is not a linear network tool"}
	if city.index_of(start.x, start.y) < 0 or city.index_of(finish.x, finish.y) < 0:
		return {"ok": false, "error": "network path is outside the city"}

	var old_payloads := _city_payloads(city)
	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}
	var changed_payloads := _duplicate_payloads(old_payloads)
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var underground: PackedByteArray = changed_payloads.XUND
	var flags: PackedByteArray = changed_payloads.XBIT
	var text_overlays: PackedByteArray = changed_payloads.XTXT
	var misc: PackedByteArray = changed_payloads.MISC
	var altitude: PackedByteArray = changed_payloads.ALTM
	var mode := int(NETWORK_TOOLS[group_index * ToolCatalog.MAX_SLOTS_PER_GROUP + subtool_index])

	var planned := _plan_route(
		buildings, terrain, zones, underground, flags, altitude,
		start, finish, mode
	)
	var bridge_plan := {}
	var surface_mode := mode == MODE_ROAD or mode == MODE_RAIL or mode == MODE_POWER
	if surface_mode:
		if planned.is_empty() and _is_bridge_wrapper_tile(terrain, flags, start):
			bridge_plan = _plan_bridge_from_start(
				buildings, terrain, start, city.compass_rotation()
			)
		elif not planned.is_empty():
			var exit_direction := _route_exit_direction(planned, start, finish)
			var bridge_start: Vector2i = planned[-1] + DIRECTIONS[exit_direction]
			if _is_bridge_wrapper_tile(terrain, flags, bridge_start):
				bridge_plan = _scan_bridge(
					buildings, terrain, bridge_start, exit_direction, false
				)
	if planned.is_empty() and not bridge_plan.get("ok", false):
		return {
			"ok": false,
			"error": bridge_plan.get("error", "network cannot start on this tile"),
		}
	var tool := ToolCatalog.tool(group_index, subtool_index)
	var graded_tiles := 0
	if surface_mode:
		for point in planned:
			var terrain_id := int(terrain[point.x * CityState.MAP_SIZE + point.y])
			if terrain_id < 0x30 and TERRAIN_REQUIRES_GRADING[terrain_id & 0x0f]:
				graded_tiles += 1
	var listed_dry_cost := planned.size() * int(tool.cost) + graded_tiles * 25
	var dry_cost := 0 if free_mode else listed_dry_cost
	if city.funds() < dry_cost:
		return {"ok": false, "error": "insufficient funds", "cost": dry_cost}

	var selected_bridge := bridge_type
	var bridge_choices: Array[Dictionary] = []
	if bridge_plan.get("ok", false):
		bridge_choices = _bridge_choices(int(bridge_plan.span_length), mode)
		if mode == MODE_ROAD and selected_bridge == BRIDGE_UNSELECTED:
			return {
				"ok": false,
				"bridge_selection_required": true,
				"bridge_choices": bridge_choices,
				"bridge_span_length": bridge_plan.span_length,
				"dry_cost": dry_cost,
				"listed_dry_cost": listed_dry_cost,
				"free_mode": free_mode,
				"dry_points": planned,
				"error": "bridge type selection is required",
			}
		if mode == MODE_RAIL:
			selected_bridge = BRIDGE_RAIL
		elif mode == MODE_POWER:
			selected_bridge = BRIDGE_WIRE
		if selected_bridge >= 0 and not _bridge_choice_exists(
			bridge_choices, selected_bridge
		):
			return {"ok": false, "error": "selected bridge type is not available"}

	if (
		bridge_plan.get("ok", false)
		and selected_bridge == BRIDGE_CANCELLED
		and planned.is_empty()
	):
		return {"ok": false, "cancelled": true, "error": "bridge selection canceled"}

	var listed_bridge_cost := 0
	var bridge_cost := 0
	var bridge_built := false
	var bridge_error := ""
	if bridge_plan.get("ok", false) and selected_bridge >= 0:
		listed_bridge_cost = (
			int(bridge_plan.span_length) * int(BRIDGE_COSTS[selected_bridge])
		)
		bridge_cost = 0 if free_mode else listed_bridge_cost
		if not free_mode and city.funds() - dry_cost < bridge_cost:
			bridge_error = "insufficient funds for the bridge"
			if planned.is_empty():
				return {
					"ok": false,
					"error": "insufficient funds",
					"cost": bridge_cost,
				}
		else:
			bridge_built = true
	var cost := dry_cost + (bridge_cost if bridge_built else 0)
	var connection_anchor: Vector2i = planned[-1] if not planned.is_empty() else start
	var listed_connection_cost := _connection_cost(mode)
	var connection_cost := 0 if free_mode else listed_connection_cost
	var connection_available: bool = (
		not bridge_plan.get("ok", false)
		and not planned.is_empty()
		and listed_connection_cost > 0
		and _is_connection_exit(planned, start, finish)
		and text_overlays[
			connection_anchor.x * CityState.MAP_SIZE + connection_anchor.y
		] != CONNECTION_LABEL
	)
	var connection_affordable: bool = (
		free_mode or city.funds() - dry_cost >= connection_cost
	)
	if (
		connection_available
		and connection_affordable
		and connection_choice == CONNECTION_UNSELECTED
	):
		return {
			"ok": false,
			"connection_selection_required": true,
			"connection_anchor": connection_anchor,
			"connection_cost": connection_cost,
			"listed_connection_cost": listed_connection_cost,
			"dry_cost": dry_cost,
			"listed_dry_cost": listed_dry_cost,
			"free_mode": free_mode,
			"dry_points": planned,
			"error": "neighbor connection confirmation is required",
		}
	if connection_choice == CONNECTION_CONFIRMED:
		if not connection_available:
			return {"ok": false, "error": "neighbor connection is not available"}
		if not connection_affordable:
			return {
				"ok": false,
				"error": "insufficient funds",
				"cost": dry_cost + connection_cost,
			}
	var connection_built := connection_choice == CONNECTION_CONFIRMED
	var connection_error := ""
	if connection_available and not connection_affordable:
		connection_error = "insufficient funds for the neighbor connection"
	cost += connection_cost if connection_built else 0

	for point_index in planned.size():
		var point := planned[point_index]
		var direction := _route_direction(planned, point_index)
		match mode:
			MODE_ROAD:
				_place_surface(
					buildings, terrain, zones, flags, misc, point, MODE_ROAD,
					direction, text_overlays
				)
			MODE_RAIL:
				_place_surface(
					buildings, terrain, zones, flags, misc, point, MODE_RAIL,
					direction, text_overlays
				)
			MODE_POWER:
				_place_surface(
					buildings, terrain, zones, flags, misc, point, MODE_POWER,
					direction, text_overlays
				)
			MODE_SUBWAY:
				_place_underground(
					underground, terrain, zones, flags, misc, point, false
				)
			MODE_PIPE:
				_place_underground(
					underground, terrain, zones, flags, misc, point, true
				)
	var bridge_points: Array[Vector2i] = []
	if bridge_built:
		bridge_points = _place_bridge(
			altitude,
			buildings,
			terrain,
			zones,
			flags,
			misc,
			bridge_plan,
			selected_bridge
		)
	if connection_built:
		text_overlays[
			connection_anchor.x * CityState.MAP_SIZE + connection_anchor.y
		] = CONNECTION_LABEL
		_retile_surface_neighborhood(
			buildings,
			terrain,
			zones,
			flags,
			misc,
			connection_anchor,
			mode,
			text_overlays
		)
	_write_u32_be(misc, MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()
	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)
	if not _apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		return {"ok": false, "error": "cannot store network changes"}
	var all_points: Array[Vector2i] = planned.duplicate()
	all_points.append_array(bridge_points)
	return {
		"ok": true,
		"command_type": "network",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"mode": mode,
		"points": all_points,
		"dry_points": planned,
		"bridge_points": bridge_points,
		"bridge_built": bridge_built,
		"bridge_type": selected_bridge if bridge_built else BRIDGE_UNSELECTED,
		"bridge_name": bridge_type_name(selected_bridge) if bridge_built else "",
		"bridge_cancelled": (
			bridge_plan.get("ok", false) and selected_bridge == BRIDGE_CANCELLED
		),
		"bridge_span_length": bridge_plan.get("span_length", 0),
		"bridge_cost": bridge_cost if bridge_built else 0,
		"listed_bridge_cost": listed_bridge_cost if bridge_built else 0,
		"bridge_error": bridge_error,
		"connection_anchor": connection_anchor,
		"connection_built": connection_built,
		"connection_cancelled": (
			connection_available and connection_choice == CONNECTION_CANCELLED
		),
		"connection_cost": connection_cost if connection_built else 0,
		"listed_connection_cost": (
			listed_connection_cost if connection_built else 0
		),
		"connection_error": connection_error,
		"cost": cost,
		"dry_cost": dry_cost,
		"listed_cost": (
			listed_dry_cost
			+ (listed_bridge_cost if bridge_built else 0)
			+ (listed_connection_cost if connection_built else 0)
		),
		"listed_dry_cost": listed_dry_cost,
		"free_mode": free_mode,
		"graded_tiles": graded_tiles,
		"stopped_early": not bridge_built and planned[-1] != finish,
		"changed_ids": changed_ids,
		"old_payloads": old_payloads,
		"new_payloads": changed_payloads,
		"error": "",
	}


static func bridge_type_name(bridge_type: int) -> String:
	if bridge_type < 0 or bridge_type >= BRIDGE_NAMES.size():
		return "Unknown Bridge"
	return BRIDGE_NAMES[bridge_type]


static func undo(city: CityState, command: Dictionary) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not command.get("ok", false) or command.get("command_type", "") != "network":
		return {"ok": false, "error": "network command is invalid"}
	var changed_ids: PackedStringArray = command.get("changed_ids", PackedStringArray())
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})
	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return {"ok": false, "error": "city changed after this network command"}
	if not _apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore network changes"}
	var points: Array = command.get("points", [])
	return {"ok": true, "restored_tiles": points.size(), "error": ""}


static func _is_bridge_wrapper_tile(
	terrain: PackedByteArray, flags: PackedByteArray, point: Vector2i
) -> bool:
	if point.x < 0 or point.x >= 128 or point.y < 0 or point.y >= 128:
		return false
	var index := point.x * CityState.MAP_SIZE + point.y
	return (flags[index] & FLAG_WATER) != 0 and terrain[index] < 0x40


static func _plan_bridge_from_start(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	start: Vector2i,
	view_rotation: int
) -> Dictionary:
	for direction in [
		view_rotation & 3,
		(view_rotation + 2) & 3,
		(view_rotation + 1) & 3,
		(view_rotation - 1) & 3,
	]:
		var plan := _scan_bridge(buildings, terrain, start, direction, true)
		if plan.get("direction_allowed", false):
			return plan
	return {"ok": false, "error": "bridge does not face open water"}


static func _scan_bridge(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	start: Vector2i,
	direction: int,
	require_direction: bool
) -> Dictionary:
	if start.x < 0 or start.x >= 128 or start.y < 0 or start.y >= 128:
		return {"ok": false, "error": "bridge start is outside the city"}
	var start_index := start.x * CityState.MAP_SIZE + start.y
	var terrain_id := int(terrain[start_index])
	if terrain_id < 0x20 or terrain_id >= 0x40:
		return {"ok": false, "error": "bridge must start on shoreline terrain"}
	var direction_mask := int(BRIDGE_SHORE_DIRECTIONS[terrain_id & 0x0f])
	if direction_mask == 0:
		return {"ok": false, "error": "bridge shoreline shape is not eligible"}
	var direction_allowed := (direction_mask & (1 << direction)) != 0
	if require_direction and not direction_allowed:
		return {"ok": false, "direction_allowed": false, "error": ""}

	var span_length := 0
	var checked := start
	while true:
		if span_length != 0:
			var checked_index := checked.x * CityState.MAP_SIZE + checked.y
			if buildings[checked_index] != 0:
				return {
					"ok": false,
					"direction_allowed": true,
					"error": "bridge path contains a structure",
				}
		checked += DIRECTIONS[direction]
		if checked.x < 0 or checked.x >= 128 or checked.y < 0 or checked.y >= 128:
			return {
				"ok": false,
				"direction_allowed": true,
				"error": "bridge does not reach another bank",
			}
		span_length += 1
		var checked_terrain := int(
			terrain[checked.x * CityState.MAP_SIZE + checked.y]
		)
		if checked_terrain <= 0x0f or checked_terrain >= 0x40:
			break
	return {
		"ok": true,
		"direction_allowed": true,
		"start": start,
		"direction": direction,
		"span_length": span_length,
	}


static func _route_exit_direction(
	planned: Array[Vector2i], start: Vector2i, finish: Vector2i
) -> int:
	if planned.size() > 1:
		return _direction_index(planned[-1] - planned[-2])
	return _primary_direction(start, finish)


static func _connection_cost(mode: int) -> int:
	if mode == MODE_ROAD:
		return ROAD_CONNECTION_COST
	if mode == MODE_RAIL:
		return RAIL_CONNECTION_COST
	return 0


static func _is_connection_exit(
	planned: Array[Vector2i], start: Vector2i, finish: Vector2i
) -> bool:
	if planned.is_empty():
		return false
	var endpoint: Vector2i = planned[-1]
	if not _point_is_edge(endpoint):
		return false
	if start == endpoint:
		return true
	var direction := _route_exit_direction(planned, start, finish)
	return not _point_is_in_bounds(endpoint + DIRECTIONS[direction])


static func _point_is_edge(point: Vector2i) -> bool:
	return point.x == 0 or point.x == 127 or point.y == 0 or point.y == 127


static func _point_is_in_bounds(point: Vector2i) -> bool:
	return point.x >= 0 and point.x < 128 and point.y >= 0 and point.y < 128


static func _direction_index(offset: Vector2i) -> int:
	for direction in DIRECTIONS.size():
		if DIRECTIONS[direction] == offset:
			return direction
	return 0


static func _bridge_choices(span_length: int, mode: int) -> Array[Dictionary]:
	var available_mask := 0x07
	if span_length > 4 and span_length < 12:
		available_mask |= 0x08
	if span_length > 6:
		available_mask |= 0x10
	available_mask &= int(BRIDGE_MODE_MASKS[mode])
	var result: Array[Dictionary] = []
	for bridge_type in BRIDGE_NAMES.size():
		if (available_mask & (1 << bridge_type)) == 0:
			continue
		result.append({
			"type": bridge_type,
			"name": bridge_type_name(bridge_type),
			"cost_per_tile": BRIDGE_COSTS[bridge_type],
			"cost": span_length * int(BRIDGE_COSTS[bridge_type]),
		})
	return result


static func _bridge_choice_exists(choices: Array[Dictionary], bridge_type: int) -> bool:
	for choice in choices:
		if int(choice.type) == bridge_type:
			return true
	return false


static func _place_bridge(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	plan: Dictionary,
	bridge_type: int
) -> Array[Vector2i]:
	var start: Vector2i = plan.start
	var direction := int(plan.direction)
	var span_length := int(plan.span_length)
	var offset: Vector2i = DIRECTIONS[direction]
	var result: Array[Vector2i] = []
	_place_bridge_bank(
		altitude, buildings, terrain, zones, flags, misc,
		start, direction, bridge_type, true
	)
	result.append(start)
	for span_index in range(1, span_length - 1):
		var point := start + offset * span_index
		var index := point.x * CityState.MAP_SIZE + point.y
		if (direction & 1) != 0:
			flags[index] |= FLAG_FLIPPED
		_replace_building(
			buildings,
			zones,
			misc,
			index,
			_bridge_tile(bridge_type, span_length, span_index, direction)
		)
		if bridge_type == BRIDGE_WIRE:
			flags[index] |= FLAG_POWERABLE
		result.append(point)
	var finish_offset := maxi(1, span_length - 1)
	var finish := start + offset * finish_offset
	_place_bridge_bank(
		altitude, buildings, terrain, zones, flags, misc,
		finish, direction, bridge_type, false
	)
	result.append(finish)
	return result


static func _place_bridge_bank(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	direction: int,
	bridge_type: int,
	first: bool
) -> void:
	var index := point.x * CityState.MAP_SIZE + point.y
	if terrain[index] < 0x30:
		_set_land_altitude(
			altitude, index, _land_altitude(altitude, index) + 1
		)
	terrain[index] = (
		((direction + (1 if first else -1)) & 3) + 1
	)
	flags[index] &= ~FLAG_WATER & 0xff
	var mode := MODE_POWER
	if bridge_type == BRIDGE_RAIL:
		mode = MODE_RAIL
	elif bridge_type >= BRIDGE_ROAD_CAUSEWAY:
		mode = MODE_ROAD
	_place_surface(buildings, terrain, zones, flags, misc, point, mode, direction)


static func _bridge_tile(
	bridge_type: int, span_length: int, span_index: int, direction: int
) -> int:
	match bridge_type:
		BRIDGE_WIRE:
			return 0x5c
		BRIDGE_RAIL:
			var middle := int(span_length / 2)
			if (
				span_index != middle
				and span_index >= middle - 2
				and span_index <= middle + 2
			):
				return 0x5b
			return 0x5a
		BRIDGE_ROAD_RAISING:
			var quarter := int((span_length + 1) / 4)
			if span_index < quarter:
				return 0x57
			if span_index == quarter:
				return 0x56
			if span_index < span_length - quarter - 1:
				return 0x58
			if span_length - quarter - span_index == 1:
				return 0x56
			return 0x57
		BRIDGE_ROAD_SUSPENSION:
			var pattern_span := (span_length - 2) % 5 + 2
			var first_pattern := int(pattern_span / 2)
			var pattern_end := span_length - int((pattern_span + 1) / 2)
			if span_index < first_pattern or span_index >= pattern_end:
				return 0x57
			var pattern_index := (span_index - first_pattern) % 5
			return 0x51 + pattern_index if direction == 0 or direction == 3 else 0x55 - pattern_index
		_:
			return 0x57


static func _land_altitude(altitude: PackedByteArray, index: int) -> int:
	return altitude[index * 2 + 1] & 0x1f


static func _set_land_altitude(
	altitude: PackedByteArray, index: int, value: int
) -> void:
	var offset := index * 2
	altitude[offset + 1] = (altitude[offset + 1] & 0xe0) | (value & 0x1f)


static func _plan_route(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	start: Vector2i,
	finish: Vector2i,
	mode: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current := start
	var direction := _primary_direction(current, finish)
	if not _tile_is_eligible(buildings, terrain, zones, underground, flags, altitude, current, mode, direction):
		if start == finish:
			for candidate_direction in DIRECTIONS.size():
				if _tile_is_eligible(
					buildings, terrain, zones, underground, flags, altitude,
					current, mode, candidate_direction
				):
					result.append(current)
					return result
		var start_alternate := _alternate_direction(current, finish, direction)
		if start_alternate < 0 or not _tile_is_eligible(
			buildings, terrain, zones, underground, flags, altitude,
			current, mode, start_alternate
		):
			return result
	result.append(current)
	while current != finish:
		direction = _primary_direction(current, finish)
		var next: Vector2i = current + DIRECTIONS[direction]
		if not _tile_is_eligible(buildings, terrain, zones, underground, flags, altitude, next, mode, direction):
			var alternate := _alternate_direction(current, finish, direction)
			if alternate < 0:
				break
			next = current + DIRECTIONS[alternate]
			if not _tile_is_eligible(buildings, terrain, zones, underground, flags, altitude, next, mode, alternate):
				break
		current = next
		result.append(current)
	return result


static func _primary_direction(current: Vector2i, finish: Vector2i) -> int:
	var difference := finish - current
	if absi(difference.y) < absi(difference.x):
		return 1 if difference.x >= 0 else 3
	return 2 if difference.y >= 0 else 0


static func _alternate_direction(current: Vector2i, finish: Vector2i, primary: int) -> int:
	var difference := finish - current
	if primary == 1 or primary == 3:
		if difference.y == 0:
			return -1
		return 2 if difference.y > 0 else 0
	if difference.x == 0:
		return -1
	return 1 if difference.x > 0 else 3


static func _route_direction(points: Array[Vector2i], index: int) -> int:
	if points.size() <= 1:
		return 0
	var difference: Vector2i
	if index + 1 < points.size():
		difference = points[index + 1] - points[index]
	else:
		difference = points[index] - points[index - 1]
	for direction in DIRECTIONS.size():
		if DIRECTIONS[direction] == difference:
			return direction
	return 0


static func _tile_is_eligible(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	point: Vector2i,
	mode: int,
	direction: int
) -> bool:
	if point.x < 0 or point.x >= 128 or point.y < 0 or point.y >= 128:
		return false
	var index := point.x * CityState.MAP_SIZE + point.y
	if (zones[index] & 0x0f) == MILITARY_ZONE:
		return false
	if mode == MODE_SUBWAY or mode == MODE_PIPE:
		var altitude_offset := index * 2
		var altitude_word := (altitude[altitude_offset] << 8) | altitude[altitude_offset + 1]
		var tunnel_level := (altitude_word & 0x7c00) >> 10
		if tunnel_level == 1 or tunnel_level == 2:
			return false
		var under_tile := int(underground[index])
		if under_tile == 0:
			return true
		if mode == MODE_PIPE:
			return under_tile + (direction & 1) == 0x11
		return under_tile + (direction & 1) == 0x02

	var terrain_id := int(terrain[index])
	if flags[index] & FLAG_WATER and terrain_id < 0x40:
		return false
	if terrain_id >= 0x10 and terrain_id < 0x20:
		return false
	if terrain_id < 0x40 and TERRAIN_BLOCKS_DIRECTION[(terrain_id & 0x0f) * 4 + direction]:
		return false
	var building := int(buildings[index])
	if building == 0x05 or building == 0x0d or building > 0x50:
		return false
	if building <= 0x0c:
		return true
	var directional_id := building + (direction & 1)
	return directional_id == 0x0f or directional_id == 0x1e or directional_id == 0x2d or directional_id == 0x4a


static func _place_surface(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	mode: int,
	direction: int,
	text_overlays := PackedByteArray()
) -> void:
	var index := point.x * CityState.MAP_SIZE + point.y
	_grade_surface_terrain(terrain, flags, point, direction)
	var old_tile := int(buildings[index])
	var new_tile := _surface_replacement(old_tile, mode)
	if new_tile < 0:
		return
	_replace_building(buildings, zones, misc, index, new_tile)
	if mode == MODE_POWER:
		flags[index] |= FLAG_POWERABLE
	else:
		zones[index] &= 0xf0
	_retile_surface_neighborhood(
		buildings, terrain, zones, flags, misc, point, mode, text_overlays
	)


static func _grade_surface_terrain(
	terrain: PackedByteArray, flags: PackedByteArray, point: Vector2i, direction: int
) -> void:
	var index := point.x * CityState.MAP_SIZE + point.y
	var terrain_id := int(terrain[index])
	if terrain_id >= 0x30:
		return
	var shape := terrain_id & 0x0f
	if not TERRAIN_REQUIRES_GRADING[shape]:
		return
	if TERRAIN_IS_NETWORK_SLOPE[shape]:
		terrain[index] = (terrain_id & 0xf0) | GRADED_TERRAIN[shape * 4 + direction]
		return
	terrain[index] = 0x0d if terrain_id < 0x10 else 0x1d
	flags[index] &= ~FLAG_WATER


static func _surface_replacement(old_tile: int, mode: int) -> int:
	if mode == MODE_ROAD:
		if old_tile < 0x0e:
			return 0x1d
		return {0x0e: 0x44, 0x0f: 0x43, 0x2c: 0x46, 0x2d: 0x45, 0x49: 0x4b, 0x4a: 0x4c}.get(old_tile, -1)
	if mode == MODE_RAIL:
		if old_tile < 0x0e:
			return 0x2c
		return {0x0e: 0x48, 0x0f: 0x47, 0x1d: 0x45, 0x1e: 0x46, 0x49: 0x4d, 0x4a: 0x4e}.get(old_tile, -1)
	if old_tile < 0x0e:
		return 0x0e
	return {0x1d: 0x43, 0x1e: 0x44, 0x2c: 0x47, 0x2d: 0x48, 0x49: 0x4f, 0x4a: 0x50}.get(old_tile, -1)


static func _retile_surface_neighborhood(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	mode: int,
	text_overlays := PackedByteArray()
) -> void:
	_retile_surface(
		buildings, terrain, zones, flags, misc, point, mode, text_overlays
	)
	for offset in DIRECTIONS:
		var near: Vector2i = point + offset
		if near.x >= 0 and near.x < 128 and near.y >= 0 and near.y < 128:
			_retile_surface(
				buildings, terrain, zones, flags, misc, near, mode, text_overlays
			)


static func _retile_surface(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	mode: int,
	text_overlays := PackedByteArray()
) -> void:
	var index := point.x * CityState.MAP_SIZE + point.y
	var current := int(buildings[index])
	var base := 0
	if mode == MODE_ROAD:
		if current < 0x1d or current > 0x2b:
			return
		base = 0x1d
	elif mode == MODE_RAIL:
		if current < 0x2c or current > 0x3a:
			return
		base = 0x2c
	else:
		if current < 0x0e or current > 0x1c:
			return
		base = 0x0e

	var terrain_id := int(terrain[index])
	if terrain_id < 0x30:
		var terrain_shape := terrain_id & 0x0f
		if TERRAIN_IS_NETWORK_SLOPE[terrain_shape] and terrain_shape < NETWORK_SLOPE_SHAPES.size():
			_replace_building(
				buildings, zones, misc, index,
				base + NETWORK_SLOPE_SHAPES[terrain_shape]
			)
			return

	var connections := 0
	var has_connection_label := (
		text_overlays.size() == CityState.TILE_COUNT
		and text_overlays[index] == CONNECTION_LABEL
	)
	for direction in 4:
		var near: Vector2i = point + DIRECTIONS[direction]
		if near.x < 0 or near.x >= 128 or near.y < 0 or near.y >= 128:
			if has_connection_label:
				connections |= 1 << direction
			continue
		var near_index := near.x * CityState.MAP_SIZE + near.y
		var connects := false
		if mode == MODE_POWER:
			connects = (flags[near_index] & FLAG_POWERABLE) != 0
		elif mode == MODE_ROAD:
			connects = _road_connects(buildings[near_index])
		else:
			connects = _rail_connects(buildings[near_index])
		if connects:
			connections |= 1 << direction
	_replace_building(buildings, zones, misc, index, base + NETWORK_SHAPES[connections])


static func _road_connects(tile_id: int) -> bool:
	return (
		(tile_id >= 0x1d and tile_id <= 0x2b)
		or (tile_id >= 0x3f and tile_id <= 0x46)
		or tile_id == 0x4b
		or tile_id == 0x4c
		or (tile_id >= 0x5d and tile_id <= 0x60)
	)


static func _rail_connects(tile_id: int) -> bool:
	return (
		(tile_id >= 0x2c and tile_id <= 0x3e)
		or (tile_id >= 0x45 and tile_id <= 0x48)
		or tile_id == 0x4d
		or tile_id == 0x4e
		or (tile_id >= 0x6c and tile_id <= 0x6f)
	)


static func _place_underground(
	underground: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	pipes: bool
) -> void:
	var index := point.x * CityState.MAP_SIZE + point.y
	var old_tile := int(underground[index])
	var new_tile := -1
	if pipes:
		if old_tile == 0:
			new_tile = 0x10
		elif old_tile == 0x01:
			new_tile = 0x1f
		elif old_tile == 0x02:
			new_tile = 0x20
		else:
			return
		flags[index] |= FLAG_PIPED
	else:
		if old_tile == 0:
			new_tile = 0x01
		elif old_tile == 0x10:
			new_tile = 0x20
		elif old_tile == 0x11:
			new_tile = 0x1f
		else:
			return
	BuildingCommand._replace_underground(underground, zones, misc, index, new_tile)
	_retile_underground_neighborhood(underground, terrain, point, pipes)


static func _retile_underground_neighborhood(
	underground: PackedByteArray, terrain: PackedByteArray, point: Vector2i, pipes: bool
) -> void:
	BuildingCommand._retile_neighborhood(underground, terrain, point, pipes)


static func _replace_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	var old_tile := int(buildings[index])
	if old_tile == new_tile:
		return
	var zone := zones[index] & 0x0f
	var old_offset := MISC_TILE_COUNTS + old_tile * 4
	var new_offset := MISC_TILE_COUNTS + new_tile * 4
	if zone == MILITARY_ZONE:
		old_offset = MISC_MILITARY_TILE_COUNTS + int(
			MILITARY_TILE_COUNT_INDEX.get(old_tile, 0)
		) * 4
		new_offset = MISC_MILITARY_TILE_COUNTS + int(
			MILITARY_TILE_COUNT_INDEX.get(new_tile, 0)
		) * 4
	_write_u32_be(misc, old_offset, (_read_u32_be(misc, old_offset) - 1) & 0xffff)
	_write_u32_be(misc, new_offset, (_read_u32_be(misc, new_offset) + 1) & 0xffff)
	buildings[index] = new_tile


static func _city_payloads(city: CityState) -> Dictionary:
	var result := {}
	for checked in [
		["ALTM", CityState.TILE_COUNT * 2],
		["XBLD", CityState.TILE_COUNT],
		["XTER", CityState.TILE_COUNT],
		["XZON", CityState.TILE_COUNT],
		["XUND", CityState.TILE_COUNT],
		["XBIT", CityState.TILE_COUNT],
		["XTXT", CityState.TILE_COUNT],
		["MISC", 4800],
	]:
		var chunk := city.document.find_chunk(checked[0])
		if chunk == null or chunk.decoded_payload.size() != checked[1]:
			return {}
		result[checked[0]] = chunk.decoded_payload.duplicate()
	return result


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary:
	var result := {}
	for chunk_id in payloads:
		result[chunk_id] = payloads[chunk_id].duplicate()
	return result


static func _apply_payloads(
	city: CityState, chunk_ids: PackedStringArray, payloads: Dictionary, rollback: Dictionary
) -> bool:
	var applied := PackedStringArray()
	for chunk_id in chunk_ids:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or not payloads.has(chunk_id) or not chunk.set_decoded_payload(payloads[chunk_id]):
			for rollback_id in applied:
				city.document.find_chunk(rollback_id).set_decoded_payload(rollback[rollback_id])
			_refresh_city_arrays(city)
			return false
		applied.append(chunk_id)
	_refresh_city_arrays(city)
	return true


static func _refresh_city_arrays(city: CityState) -> void:
	var altitude := city.document.find_chunk("ALTM").decoded_payload
	for index in CityState.TILE_COUNT:
		city.altitude_words[index] = (altitude[index * 2] << 8) | altitude[index * 2 + 1]
	city.buildings = city.document.find_chunk("XBLD").decoded_payload.duplicate()
	city.terrain = city.document.find_chunk("XTER").decoded_payload.duplicate()
	city.zones = city.document.find_chunk("XZON").decoded_payload.duplicate()
	city.underground = city.document.find_chunk("XUND").decoded_payload.duplicate()
	var text_chunk := city.document.find_chunk("XTXT")
	if text_chunk != null:
		city.text_overlays = text_chunk.decoded_payload.duplicate()
	city.tile_flags = city.document.find_chunk("XBIT").decoded_payload.duplicate()


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _write_u32_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff
