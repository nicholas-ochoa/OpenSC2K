class_name NetworkCommand
extends NetworkConstants



static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return NetworkRules.supports_tool(group_index, subtool_index)


static func route(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	return NetworkRoutes.route(start, finish)


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
	return NetworkDragCommand.apply(city, group_index, subtool_index, start, finish, bridge_type, connection_choice, free_mode, false)


static func apply_segment(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	finish: Vector2i,
	bridge_type := BRIDGE_UNSELECTED,
	connection_choice := CONNECTION_UNSELECTED,
	free_mode := false
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

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

	var planned_directions: Array[int] = []
	var planned := _plan_route(
		buildings, terrain, zones, underground, flags, altitude,
		start, finish, mode, map_edge, planned_directions
	)
	var bridge_plan := {}
	var surface_mode := mode == MODE_ROAD or mode == MODE_RAIL or mode == MODE_POWER

	if surface_mode:
		if planned.is_empty() and _is_bridge_wrapper_tile(terrain, flags, start, map_edge):
			bridge_plan = _plan_bridge_from_start(
				buildings, terrain, start, city.compass_rotation(), map_edge
			)
		elif not planned.is_empty():
			var exit_direction := _route_exit_direction(planned, start, finish)
			var bridge_start: Vector2i = planned[-1] + DIRECTIONS[exit_direction]

			if _is_bridge_wrapper_tile(terrain, flags, bridge_start, map_edge):
				bridge_plan = _scan_bridge(
					buildings, terrain, bridge_start, exit_direction, false, map_edge
				)

	if planned.is_empty() and not bridge_plan.get("ok", false):
		return {
			"ok": false,
			"error": bridge_plan.get("error", "network cannot start on this tile"),
		}

	var tool := ToolCatalog.tool(group_index, subtool_index)
	var graded_tiles := 0
	var new_tiles := planned.size()

	for point in planned:
		var index := point.x * map_edge + point.y
		var reused := _reuses_surface(buildings[index], mode) if surface_mode else _reuses_underground(underground[index], mode)

		if reused:
			new_tiles -= 1
			continue

		var terrain_id := int(terrain[index])

		if terrain_id < 0x30 and TERRAIN_REQUIRES_GRADING[terrain_id & 0x0f]:
			graded_tiles += 1

	var listed_dry_cost := new_tiles * int(tool.cost) + graded_tiles * 25
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
		and _is_connection_exit(planned, start, finish, map_edge)
		and OverlayData.read(text_overlays,
			connection_anchor.x * map_edge + connection_anchor.y
		) != CONNECTION_LABEL
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
		var direction := planned_directions[point_index]

		match mode:
			MODE_ROAD:
				_place_surface(
					buildings, terrain, zones, flags, misc, point, MODE_ROAD,
					direction, text_overlays, map_edge
				)
			MODE_RAIL:
				_place_surface(
					buildings, terrain, zones, flags, misc, point, MODE_RAIL,
					direction, text_overlays, map_edge
				)
			MODE_POWER:
				_place_surface(
					buildings, terrain, zones, flags, misc, point, MODE_POWER,
					direction, text_overlays, map_edge
				)
			MODE_SUBWAY:
				_place_underground(
					underground, terrain, zones, flags, misc, point, false, direction, map_edge
				)
			MODE_PIPE:
				_place_underground(
					underground, terrain, zones, flags, misc, point, true, direction, map_edge
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
			selected_bridge, map_edge
		)

	if connection_built:
		OverlayData.write(text_overlays,
			connection_anchor.x * map_edge + connection_anchor.y
		, CONNECTION_LABEL)
		_retile_surface_neighborhood(
			buildings,
			terrain,
			zones,
			flags,
			misc,
			connection_anchor,
			mode,
			text_overlays, map_edge
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
		"bridge_exit": bridge_plan.start + DIRECTIONS[int(bridge_plan.direction)] * int(bridge_plan.span_length) if bridge_built else Vector2i(-1, -1),
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
	terrain: PackedByteArray, flags: PackedByteArray, point: Vector2i,
	map_edge: int = 128,
) -> bool:
	if point.x < 0 or point.x >= map_edge or point.y < 0 or point.y >= map_edge:
		return false

	var index := point.x * map_edge + point.y

	return (flags[index] & FLAG_WATER) != 0 and terrain[index] < 0x40


static func _plan_bridge_from_start(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	start: Vector2i,
	view_rotation: int,
	map_edge: int = 128,
) -> Dictionary:
	for direction in [
		view_rotation & 3,
		(view_rotation + 2) & 3,
		(view_rotation + 1) & 3,
		(view_rotation - 1) & 3,
	]:
		var plan := _scan_bridge(buildings, terrain, start, direction, true, map_edge)

		if plan.get("direction_allowed", false):
			return plan

	return {"ok": false, "error": "bridge does not face open water"}


static func _scan_bridge(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	start: Vector2i,
	direction: int,
	require_direction: bool,
	map_edge: int = 128,
) -> Dictionary:
	if start.x < 0 or start.x >= map_edge or start.y < 0 or start.y >= map_edge:
		return {"ok": false, "error": "bridge start is outside the city"}

	var start_index := start.x * map_edge + start.y
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
			var checked_index := checked.x * map_edge + checked.y

			if buildings[checked_index] != 0:
				return {
					"ok": false,
					"direction_allowed": true,
					"error": "bridge path contains a structure",
				}

		checked += DIRECTIONS[direction]

		if checked.x < 0 or checked.x >= map_edge or checked.y < 0 or checked.y >= map_edge:
			return {
				"ok": false,
				"direction_allowed": true,
				"error": "bridge does not reach another bank",
			}

		span_length += 1
		var checked_terrain := int(
			terrain[checked.x * map_edge + checked.y]
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
	return NetworkRoutes._route_exit_direction(planned, start, finish)


static func _connection_cost(mode: int) -> int:
	return NetworkRules._connection_cost(mode)


static func _is_connection_exit(
	planned: Array[Vector2i], start: Vector2i, finish: Vector2i,
	map_edge: int = 128,
) -> bool:
	return NetworkRoutes._is_connection_exit(planned, start, finish, map_edge)


static func _point_is_edge(point: Vector2i, map_edge: int = 128) -> bool:
	return NetworkRules._point_is_edge(point, map_edge)


static func _point_is_in_bounds(point: Vector2i, map_edge: int = 128) -> bool:
	return NetworkRules._point_is_in_bounds(point, map_edge)


static func _direction_index(offset: Vector2i) -> int:
	return NetworkRules._direction_index(offset)


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
	bridge_type: int,
	map_edge: int = 128,
) -> Array[Vector2i]:
	var start: Vector2i = plan.start
	var direction := int(plan.direction)
	var span_length := int(plan.span_length)
	var offset: Vector2i = DIRECTIONS[direction]
	var result: Array[Vector2i] = []
	_place_bridge_bank(
		altitude, buildings, terrain, zones, flags, misc,
		start, direction, bridge_type, true, map_edge
	)
	result.append(start)

	for span_index in range(1, span_length - 1):
		var point := start + offset * span_index
		var index := point.x * map_edge + point.y

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
		finish, direction, bridge_type, false, map_edge
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
	first: bool,
	map_edge: int = 128,
) -> void:
	var index := point.x * map_edge + point.y

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

	_place_surface(buildings, terrain, zones, flags, misc, point, mode, direction, PackedByteArray(), map_edge)


static func _bridge_tile(
	bridge_type: int, span_length: int, span_index: int, direction: int
) -> int:
	match bridge_type:
		BRIDGE_WIRE:
			return 0x5c
		BRIDGE_RAIL:
			var middle := int(IntegerMath.div_trunc(span_length, 2))

			if (
				span_index != middle
				and span_index >= middle - 2
				and span_index <= middle + 2
			):
				return 0x5b

			return 0x5a
		BRIDGE_ROAD_RAISING:
			var quarter := int(IntegerMath.div_trunc((span_length + 1), 4))

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
			var first_pattern := int(IntegerMath.div_trunc(pattern_span, 2))
			var pattern_end := span_length - int(IntegerMath.div_trunc((pattern_span + 1), 2))

			if span_index < first_pattern or span_index >= pattern_end:
				return 0x57

			var pattern_index := (span_index - first_pattern) % 5

			return 0x51 + pattern_index if direction == 0 or direction == 3 else 0x55 - pattern_index
		_:
			return 0x57


static func _land_altitude(altitude: PackedByteArray, index: int) -> int:
	return NetworkRules._land_altitude(altitude, index)


static func _set_land_altitude(
	altitude: PackedByteArray, index: int, value: int
) -> void:
	NetworkRules._set_land_altitude(altitude, index, value)


static func _plan_route(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	start: Vector2i,
	finish: Vector2i,
	mode: int,
	map_edge: int = 128,
	planned_directions: Array[int] = [],
) -> Array[Vector2i]:
	return NetworkRoutes._plan_route(
		buildings, terrain, zones, underground, flags, altitude, start, finish, mode, map_edge, planned_directions
	)


static func _step_is_eligible(
	buildings: PackedByteArray, terrain: PackedByteArray, zones: PackedByteArray,
	underground: PackedByteArray, flags: PackedByteArray, altitude: PackedByteArray,
	current: Vector2i, next: Vector2i, mode: int, direction: int,
	keep_straight: bool, map_edge: int,
) -> bool:
	return NetworkRoutes._step_is_eligible(
		buildings, terrain, zones, underground, flags, altitude, current, next, mode, direction, keep_straight,
		map_edge
	)


# some tiles force the incoming direction before we can turn toward the pointer
static func _route_keeps_direction(buildings: PackedByteArray, terrain: PackedByteArray, underground: PackedByteArray, point: Vector2i, mode: int, direction: int, edge: int) -> bool:
	return NetworkRoutes._route_keeps_direction(buildings, terrain, underground, point, mode, direction, edge)


static func _primary_direction(current: Vector2i, finish: Vector2i) -> int:
	return NetworkRoutes._primary_direction(current, finish)


static func _alternate_direction(current: Vector2i, finish: Vector2i, primary: int) -> int:
	return NetworkRoutes._alternate_direction(current, finish, primary)


static func _route_direction(points: Array[Vector2i], index: int) -> int:
	return NetworkRoutes._route_direction(points, index)


static func _tile_is_eligible(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	point: Vector2i,
	mode: int,
	direction: int,
	map_edge: int = 128,
) -> bool:
	return NetworkRules._tile_is_eligible(
		buildings, terrain, zones, underground, flags, altitude, point, mode, direction, map_edge
	)


static func _surface_fixed_axis(tile_id: int, mode: int) -> int:
	return NetworkRules._surface_fixed_axis(tile_id, mode)


static func _reuses_surface(tile_id: int, mode: int) -> bool:
	return NetworkRules._reuses_surface(tile_id, mode)


static func _place_surface(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	mode: int,
	direction: int,
	text_overlays := PackedByteArray(),
	map_edge: int = 128,
) -> void:
	var index := point.x * map_edge + point.y

	if _reuses_surface(buildings[index], mode):
		return

	_grade_surface_terrain(terrain, flags, point, direction, map_edge)
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
		buildings, terrain, zones, flags, misc, point, mode, text_overlays, map_edge
	)


static func _grade_surface_terrain(
	terrain: PackedByteArray, flags: PackedByteArray, point: Vector2i, direction: int,
	map_edge: int = 128,
) -> void:
	var index := point.x * map_edge + point.y
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
	text_overlays := PackedByteArray(),
	map_edge: int = 128,
) -> void:
	_retile_surface(
		buildings, terrain, zones, flags, misc, point, mode, text_overlays, map_edge
	)

	for offset in DIRECTIONS:
		var near: Vector2i = point + offset

		if near.x >= 0 and near.x < map_edge and near.y >= 0 and near.y < map_edge:
			_retile_surface(
				buildings, terrain, zones, flags, misc, near, mode, text_overlays, map_edge
			)


static func _retile_surface(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	mode: int,
	text_overlays := PackedByteArray(),
	map_edge: int = 128,
) -> void:
	var index := point.x * map_edge + point.y
	var current := int(buildings[index])
	var base := 0

	if mode == MODE_ROAD:
		if current < 0x1d or current > 0x2b:
			return

		base = 0x1d
	elif mode == MODE_RAIL:
		if current < 0x2c or current > 0x3e:
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

	# flat rail at the low end of a slope uses the native transition tile
	if mode == MODE_RAIL and terrain_id == 0:
		const LOW_SIDE := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

		for shape in range(1, 5):
			var slope: Vector2i = point - LOW_SIDE[shape - 1]

			if slope.x < 0 or slope.y < 0 or slope.x >= map_edge or slope.y >= map_edge:
				continue

			var slope_index := slope.x * map_edge + slope.y

			if terrain[slope_index] == shape and buildings[slope_index] == 0x2d + shape:
				_replace_building(buildings, zones, misc, index, 0x3a + shape)

				return

	var connections := 0
	var has_connection_label := (
		OverlayData.count(text_overlays) == (map_edge * map_edge)
		and OverlayData.read(text_overlays, index) == CONNECTION_LABEL
	)

	for direction in 4:
		var near: Vector2i = point + DIRECTIONS[direction]

		if near.x < 0 or near.x >= map_edge or near.y < 0 or near.y >= map_edge:
			if has_connection_label:
				connections |= 1 << direction

			continue

		var near_index := near.x * map_edge + near.y
		var connects := false

		if mode == MODE_POWER:
			connects = (flags[near_index] & FLAG_POWERABLE) != 0
		elif mode == MODE_ROAD:
			connects = _road_connects(buildings[near_index])
		else:
			connects = _rail_connects(buildings[near_index])

		if connects and NetworkTerrainRules.allows_connection(terrain[near_index], direction):
			connections |= 1 << direction

	_replace_building(buildings, zones, misc, index, base + NETWORK_SHAPES[connections])


static func _road_connects(tile_id: int) -> bool:
	return NetworkRules._road_connects(tile_id)


static func _rail_connects(tile_id: int) -> bool:
	return NetworkRules._rail_connects(tile_id)


static func _reuses_underground(tile_id: int, mode: int) -> bool:
	return NetworkRules._reuses_underground(tile_id, mode)


static func _place_underground(
	underground: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	pipes: bool,
	direction := 0,
	map_edge: int = 128,
) -> void:
	var index := point.x * map_edge + point.y
	var old_tile := int(underground[index])

	if _reuses_underground(old_tile, MODE_PIPE if pipes else MODE_SUBWAY):
		return

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
		elif old_tile >= 0x10 and old_tile <= 0x1e:
			new_tile = 0x1f if (direction & 1) == 0 else 0x20
		else:
			return

	_grade_surface_terrain(terrain, flags, point, direction, map_edge)
	BuildingCommand._replace_underground(underground, zones, misc, index, new_tile)
	_retile_underground_neighborhood(underground, terrain, point, pipes, map_edge)


static func _retile_underground_neighborhood(
	underground: PackedByteArray, terrain: PackedByteArray, point: Vector2i, pipes: bool,
	map_edge: int = 128,
) -> void:
	BuildingCommand._retile_neighborhood(underground, terrain, point, pipes, map_edge)


static func _replace_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	NetworkState._replace_building(buildings, zones, misc, index, new_tile)


static func _city_payloads(city: CityState) -> Dictionary:
	return NetworkState._city_payloads(city)


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary:
	return NetworkState._duplicate_payloads(payloads)


static func _apply_payloads(
	city: CityState, chunk_ids: PackedStringArray, payloads: Dictionary, rollback: Dictionary
) -> bool:
	return NetworkState._apply_payloads(city, chunk_ids, payloads, rollback)


static func _refresh_city_arrays(city: CityState, refresh_altitude := true) -> void:
	NetworkState._refresh_city_arrays(city, refresh_altitude)


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return NetworkState._read_u32_be(data, offset)


static func _write_u32_be(data: PackedByteArray, offset: int, value: int) -> void:
	NetworkState._write_u32_be(data, offset, value)
