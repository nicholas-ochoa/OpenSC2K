class_name NetworkBridges
extends NetworkConstants


@warning_ignore_start("integer_division")


class Plan extends RefCounted:
	var ok := false
	var error := ""
	var start := Vector2i.ZERO
	var direction := 0
	var span_length := 0
	var direction_allowed := false

	static func failure(message: String, allowed := false) -> Plan:
		var result := Plan.new()
		result.error = message
		result.direction_allowed = allowed

		return result


static func bridge_type_name(bridge_type: int) -> String:
	if bridge_type < 0 or bridge_type >= BRIDGE_NAMES.size():
		return "Unknown Bridge"

	return BRIDGE_NAMES[bridge_type]


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
) -> Plan:
	for direction in [
		view_rotation & 3,
		(view_rotation + 2) & 3,
		(view_rotation + 1) & 3,
		(view_rotation - 1) & 3,
	]:
		var plan := _scan_bridge(buildings, terrain, start, direction, true, map_edge)

		if plan.direction_allowed:
			return plan

	return Plan.failure("bridge does not face open water")


static func _scan_bridge(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	start: Vector2i,
	direction: int,
	require_direction: bool,
	map_edge: int = 128,
) -> Plan:
	if start.x < 0 or start.x >= map_edge or start.y < 0 or start.y >= map_edge:
		return Plan.failure("bridge start is outside the city")

	var start_index := start.x * map_edge + start.y
	var terrain_id := int(terrain[start_index])

	if terrain_id < 0x20 or terrain_id >= 0x40:
		return Plan.failure("bridge must start on shoreline terrain")

	var direction_mask := int(BRIDGE_SHORE_DIRECTIONS[terrain_id & 0x0f])

	if direction_mask == 0:
		return Plan.failure("bridge shoreline shape is not eligible")

	var direction_allowed := (direction_mask & (1 << direction)) != 0

	if require_direction and not direction_allowed:
		return Plan.failure("", false)

	var span_length := 0
	var checked := start

	while true:
		if span_length != 0:
			var checked_index := checked.x * map_edge + checked.y

			if buildings[checked_index] != 0:
				return Plan.failure("bridge path contains a structure", true)

		checked += DIRECTIONS[direction]

		if checked.x < 0 or checked.x >= map_edge or checked.y < 0 or checked.y >= map_edge:
			return Plan.failure("bridge does not reach another bank", true)

		span_length += 1
		var checked_terrain := int(
			terrain[checked.x * map_edge + checked.y]
		)

		if checked_terrain <= 0x0f or checked_terrain >= 0x40:
			break

	var result := Plan.new()
	result.ok = true
	result.direction_allowed = true
	result.start = start
	result.direction = direction
	result.span_length = span_length

	return result


static func bridge_choices(span_length: int, mode: int) -> Array[BridgeChoice]:
	var available_mask := 0x07

	if span_length > 4 and span_length < 12:
		available_mask |= 0x08

	if span_length > 6:
		available_mask |= 0x10

	available_mask &= int(BRIDGE_MODE_MASKS[mode])
	var result: Array[BridgeChoice] = []

	for bridge_type in BRIDGE_NAMES.size():
		if (available_mask & (1 << bridge_type)) == 0:
			continue

		result.append(BridgeChoice.new(
			bridge_type, bridge_type_name(bridge_type),
			BRIDGE_COSTS[bridge_type], span_length * int(BRIDGE_COSTS[bridge_type])
		))

	return result


static func _bridge_choice_exists(choices: Array[BridgeChoice], bridge_type: int) -> bool:
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
	plan: Plan,
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

		NetworkState.replace_building(
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
		NetworkRules.set_land_altitude(
			altitude, index, NetworkRules.land_altitude(altitude, index) + 1
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

	NetworkTiles._place_surface(buildings, terrain, zones, flags, misc, point, mode, direction, PackedByteArray(), map_edge)


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
