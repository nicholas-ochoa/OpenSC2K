class_name NetworkRoutes
extends NetworkConstants



static func route(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [start]
	var current := start

	while current != finish:
		var direction := _primary_direction(current, finish)
		current += DIRECTIONS[direction]
		result.append(current)

	return result


static func _route_exit_direction(
	planned: Array[Vector2i], start: Vector2i, finish: Vector2i
) -> int:
	if planned.size() > 1:
		return NetworkRules._direction_index(planned[-1] - planned[-2])

	return _primary_direction(start, finish)


static func _is_connection_exit(
	planned: Array[Vector2i], start: Vector2i, finish: Vector2i,
	map_edge: int = 128,
) -> bool:
	if planned.is_empty():
		return false

	var endpoint: Vector2i = planned[-1]

	if not NetworkRules._point_is_edge(endpoint, map_edge):
		return false

	if start == endpoint:
		return true

	var direction := _route_exit_direction(planned, start, finish)

	return not NetworkRules._point_is_in_bounds(endpoint + DIRECTIONS[direction], map_edge)


static func plan_route(
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
	var result: Array[Vector2i] = []
	var current := start
	var direction := _primary_direction(current, finish)

	if not NetworkRules._tile_is_eligible(buildings, terrain, zones, underground, flags, altitude, current, mode, direction, map_edge):
		if start == finish:
			for candidate_direction in DIRECTIONS.size():
				if NetworkRules._tile_is_eligible(
					buildings, terrain, zones, underground, flags, altitude,
					current, mode, candidate_direction, map_edge
				):
					result.append(current)
					planned_directions.append(candidate_direction)

					return result

		var start_alternate := _alternate_direction(current, finish, direction)

		if start_alternate < 0 or not NetworkRules._tile_is_eligible(
			buildings, terrain, zones, underground, flags, altitude,
			current, mode, start_alternate, map_edge
		):
			return result

		direction = start_alternate

	result.append(current)
	planned_directions.append(direction)

	while current != finish:
		var incoming_direction := direction
		var keep_straight := _route_keeps_direction(buildings, terrain, underground, current, mode, direction, map_edge)

		if not keep_straight:
			direction = _primary_direction(current, finish)

		var next: Vector2i = current + DIRECTIONS[direction]

		if keep_straight and (next.x < mini(start.x, finish.x) or next.x > maxi(start.x, finish.x) or next.y < mini(start.y, finish.y) or next.y > maxi(start.y, finish.y)):
			break

		if not _step_is_eligible(buildings, terrain, zones, underground, flags, altitude, current, next, mode, direction, keep_straight, map_edge):
			var alternate := _alternate_direction(current, finish, direction)

			if keep_straight or alternate < 0:
				break

			next = current + DIRECTIONS[alternate]

			if not _step_is_eligible(buildings, terrain, zones, underground, flags, altitude, current, next, mode, alternate, keep_straight, map_edge):
				break

			direction = alternate

		# Check the rail grade after choosing the axis, as the original does.
		# A failed check ends the route; it does not try the other turn.
		if mode == MODE_RAIL and direction != incoming_direction and terrain[next.x * map_edge + next.y] != 0:
			break

		current = next
		result.append(current)
		planned_directions.append(direction)

	return result


static func _step_is_eligible(
	buildings: PackedByteArray, terrain: PackedByteArray, zones: PackedByteArray,
	underground: PackedByteArray, flags: PackedByteArray, altitude: PackedByteArray,
	current: Vector2i, next: Vector2i, mode: int, direction: int,
	keep_straight: bool, map_edge: int,
) -> bool:
	if not NetworkRules._tile_is_eligible(buildings, terrain, zones, underground, flags, altitude, next, mode, direction, map_edge):
		return false

	var current_index := current.x * map_edge + current.y
	var next_index := next.x * map_edge + next.y

	return NetworkTerrainRules.allows_height_step(
		terrain[current_index], NetworkRules.land_altitude(altitude, current_index),
		terrain[next_index], NetworkRules.land_altitude(altitude, next_index),
		keep_straight, mode == MODE_RAIL
	)


# some tiles force the incoming direction before we can turn toward the pointer
static func _route_keeps_direction(buildings: PackedByteArray, terrain: PackedByteArray, underground: PackedByteArray, point: Vector2i, mode: int, direction: int, edge: int) -> bool:
	# supplied executable 0x00448f50 preserves the incoming direction on
	# slopes and straight crossing cells before it chooses either target axis
	var index := point.x * edge + point.y

	if TERRAIN_IS_NETWORK_SLOPE[terrain[index] & 0x0f]:
		return true

	if mode < MODE_SUBWAY:
		var tile := int(buildings[index])

		return NetworkRules._surface_fixed_axis(tile, mode) >= 0 or (tile > 0x0d and tile + (direction & 1) in [0x0f, 0x1e, 0x2d, 0x4a])

	var tile := int(underground[index])

	return tile in [0x1f, 0x20] or (tile != 0 and tile + (direction & 1) in [2, 0x11])


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
