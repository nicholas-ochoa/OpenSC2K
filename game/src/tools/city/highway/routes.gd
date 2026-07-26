class_name HighwayRoutes
extends HighwayConstants


static func _plan_flat_route(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	start: Vector2i,
	finish: Vector2i,
	map_edge: int = 128,
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current := start
	var direction := HighwayGeometry._primary_direction(current, finish)

	if not _section_is_flat_eligible(
		buildings, terrain, flags, altitude, current, direction, map_edge
	):
		return result

	result.append(current)
	var visited := {current: true}
	var drag_bounds := Rect2i(start.min(finish), (finish - start).abs() + Vector2i.ONE)

	while current != finish:
		var current_shape := HighwayGeometry.terrain_section_shape(
			buildings, terrain, altitude, current, map_edge
		)

		var keep_straight := current_shape != FLAT_TERRAIN_SHAPE or _section_has_straight_crossing(buildings, current, direction, map_edge)

		if not keep_straight:
			direction = HighwayGeometry._primary_direction(current, finish)

		var next: Vector2i = current + DIRECTIONS[direction] * 2

		# Reject overshoots and revisited tiles on a forced grade. Otherwise the
		# preview worker can loop back along the route indefinitely.
		if not drag_bounds.has_point(next) or visited.has(next):
			break

		if not _section_follows(
			buildings, terrain, flags, altitude, current, next, direction, map_edge
		):
			if keep_straight:
				break

			var alternate := _alternate_direction(current, finish, direction)

			if alternate < 0:
				break

			next = current + DIRECTIONS[alternate] * 2

			if not drag_bounds.has_point(next) or visited.has(next):
				break

			if not _section_follows(
				buildings, terrain, flags, altitude, current, next, alternate, map_edge
			):
				break

			direction = alternate

		current = next
		visited[current] = true
		result.append(current)

	return result


static func _section_has_straight_crossing(buildings: PackedByteArray, anchor: Vector2i, direction: int, map_edge: int) -> bool:
	# SIMCITY.EXE 0x00461bfa checks all four cells before changing axis.
	# Include both straight power crossings; its threshold misses 0x0e.
	# Existing highways can still extend.
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var tile_id := int(buildings[point.x * map_edge + point.y])

		if tile_id >= 0x0e and not HighwayGeometry._is_highway_tile(tile_id) and HighwayGeometry._network_can_cross(tile_id, direction):
			return true

	return false


static func _alternate_direction(current: Vector2i, finish: Vector2i, primary: int) -> int:
	var difference := finish - current

	if primary == 1 or primary == 3:
		if difference.y == 0:
			return -1

		return 2 if difference.y > 0 else 0

	if difference.x == 0:
		return -1

	return 1 if difference.x > 0 else 3


static func _section_is_flat_eligible(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	anchor: Vector2i,
	direction: int,
	map_edge: int = 128,
) -> bool:
	if not HighwayGeometry._anchor_is_in_bounds(anchor, map_edge):
		return false

	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * map_edge + point.y

		if (flags[index] & FLAG_WATER) != 0:
			return false

		var tile_id := int(buildings[index])

		if not HighwayGeometry._building_is_allowed(tile_id):
			return false

		if tile_id > 0x0e and not HighwayGeometry._is_highway_tile(tile_id) and not HighwayGeometry._network_can_cross(tile_id, direction):
			return false

	return (
		HighwayGeometry.terrain_section_shape(buildings, terrain, altitude, anchor, map_edge)
		!= INVALID_TERRAIN_SHAPE
	)


static func _section_follows(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	current: Vector2i,
	candidate: Vector2i,
	direction: int,
	map_edge: int = 128,
) -> bool:
	if not _section_is_flat_eligible(
		buildings, terrain, flags, altitude, candidate, direction, map_edge
	):
		return false

	return absi(
		HighwayGeometry._section_altitude(terrain, altitude, candidate, map_edge)
		- HighwayGeometry._section_altitude(terrain, altitude, current, map_edge)
	) <= 1


static func select_section_kind(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	_text_overlays: PackedByteArray,
	anchor: Vector2i,
	direction: int,
	map_edge: int = 128,
) -> int:
	if not HighwayGeometry._anchor_is_in_bounds(anchor, map_edge):
		return -1

	var current_kind := HighwayGeometry._section_kind(buildings, zones, flags, anchor, map_edge)

	if (
		current_kind == 0
		or current_kind == 1
		or (current_kind >= 4 and current_kind <= 7)
		or current_kind > 12
	):
		return -1

	var current_height := HighwayGeometry._section_altitude(terrain, altitude, anchor, map_edge)
	var connections := 0

	for direction_index in 4:
		connections |= _neighbor_connection_flags(
			buildings,
			terrain,
			zones,
			flags,
			altitude,
			anchor,
			current_height,
			direction_index, map_edge
		)

	# neighbor markers affect the economy, not the highway geometry

	var terrain_shape := HighwayGeometry.terrain_section_shape(
		buildings, terrain, altitude, anchor, map_edge
	)

	if terrain_shape == INVALID_TERRAIN_SHAPE:
		return -1

	if current_kind == 2 or current_kind == 3:
		if connections == 1 or connections == 4:
			return 2

		if connections == 2 or connections == 8:
			return 3

		if terrain_shape == FILLED_FLAT_TERRAIN_SHAPE:
			return -1

	if connections == 0:
		if current_kind == 2 or current_kind == 3:
			# no adjacent geometry changed. keep the installed straight pixels
			return -1

		if terrain_shape == FLAT_TERRAIN_SHAPE:
			return (direction & 1) + 2

		var grade_kind := HighwayGeometry._grade_kind_for_shape(terrain_shape)

		if grade_kind >= 0:
			return grade_kind

	if (connections & 0x10) != 0 and (terrain_shape & 2) != 0:
		return 5

	if (connections & 0x40) != 0 and (terrain_shape & 8) != 0:
		return 7

	if (connections & 0x80) != 0 and (terrain_shape & 1) != 0:
		return 4

	if (connections & 0x20) != 0 and (terrain_shape & 4) != 0:
		return 6

	var connection_mask := connections & 0x0f

	if terrain_shape != FLAT_TERRAIN_SHAPE:
		if (connections & 1) != 0 and (terrain_shape & 2) != 0:
			return 5

		if (connections & 4) != 0 and (terrain_shape & 8) != 0:
			return 7

		if (connections & 8) != 0 and (terrain_shape & 1) != 0:
			return 4

		if (connections & 2) != 0 and (terrain_shape & 4) != 0:
			return 6

		return GRADED_SHAPE_BY_CONNECTIONS[connection_mask]

	return SHAPE_BY_CONNECTIONS[connection_mask]


static func _neighbor_connection_flags(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	anchor: Vector2i,
	current_height: int,
	direction_index: int,
	map_edge: int = 128,
) -> int:
	var neighbor: Vector2i = anchor + DIRECTIONS[direction_index] * 2

	if not HighwayGeometry._anchor_is_in_bounds(neighbor, map_edge):
		return 0

	var neighbor_kind := HighwayGeometry._section_kind(buildings, zones, flags, neighbor, map_edge)

	if not _neighbor_kind_connects(
		buildings, terrain, altitude, neighbor, neighbor_kind, direction_index, map_edge
	):
		return 0

	var neighbor_height := HighwayGeometry._section_altitude(terrain, altitude, neighbor, map_edge)
	var result := 1 << direction_index

	match direction_index:
		0:
			if current_height < neighbor_height and neighbor_kind != 5:
				result |= 0x10

			if neighbor_height < current_height or (
				neighbor_height == current_height and neighbor_kind == 5
			):
				result |= 0x40
		1:
			if current_height < neighbor_height and neighbor_kind != 6:
				result |= 0x20

			if neighbor_height < current_height or (
				neighbor_height == current_height and neighbor_kind == 6
			):
				result |= 0x80
		2:
			if current_height < neighbor_height and neighbor_kind != 7:
				result |= 0x40

			if neighbor_height < current_height or (
				neighbor_height == current_height and neighbor_kind == 7
			):
				result |= 0x10
		3:
			if current_height < neighbor_height and neighbor_kind != 4:
				result |= 0x80

			if neighbor_height < current_height or (
				neighbor_height == current_height and neighbor_kind == 4
			):
				result |= 0x20

	return result


static func _neighbor_kind_connects(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	neighbor: Vector2i,
	neighbor_kind: int,
	direction_index: int,
	map_edge: int = 128,
) -> bool:
	var north_south := direction_index == 0 or direction_index == 2

	if north_south:
		if neighbor_kind == 1 or neighbor_kind == 3:
			return true

		if (
			neighbor_kind >= 0
			and neighbor_kind < NORTH_SOUTH_KIND_CONNECTIONS.size()
			and neighbor_kind > 3
			and NORTH_SOUTH_KIND_CONNECTIONS[neighbor_kind]
		):
			return true

		return (
			neighbor_kind == 2
			and HighwayGeometry.terrain_section_shape(buildings, terrain, altitude, neighbor, map_edge)
			!= FILLED_FLAT_TERRAIN_SHAPE
		)

	if neighbor_kind == 0 or neighbor_kind == 2:
		return true

	if (
		neighbor_kind >= 0
		and neighbor_kind < EAST_WEST_KIND_CONNECTIONS.size()
		and neighbor_kind > 3
		and EAST_WEST_KIND_CONNECTIONS[neighbor_kind]
	):
		return true

	return (
		neighbor_kind == 3
		and HighwayGeometry.terrain_section_shape(buildings, terrain, altitude, neighbor, map_edge)
		!= FILLED_FLAT_TERRAIN_SHAPE
	)
