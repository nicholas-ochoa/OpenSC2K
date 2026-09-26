class_name NewTerrainSurface
extends NewTerrainConstants



static func _grow_trees(
	buildings: PackedByteArray,
	flags: PackedByteArray,
	cluster_count: int,
	random: SimRandom,
	map_edge: int = 128,
) -> void:
	for _cluster in cluster_count:
		var base_x := random.next_u15() % map_edge
		var base_y := random.next_u15() % map_edge
		var attempts := random.next_u15() & 0x3f

		for _attempt in attempts:
			var x := (
				base_x + random.next_u15() % 5 - random.next_u15() % 5
			)
			var first_y_random := random.next_u15()
			var y := base_y + first_y_random % 5 - random.next_u15() % 5

			if x < 0 or x >= map_edge or y < 0 or y >= map_edge:
				continue

			var index := NewTerrainValues._index(x, y, map_edge)

			if flags[index] & FLAG_WATER:
				continue

			var current := int(buildings[index])

			if current < FIRST_TREE:
				buildings[index] = FIRST_TREE + (random.next_u15() & 1)
			elif current < BuildingTileIds.TREES_6:
				buildings[index] = current + 1
			elif current <= LAST_TREE:
				buildings[index] = BuildingTileIds.TREES_6 + (random.next_u15() & 1)


static func _finish_ocean(flags: PackedByteArray, map_edge: int = 128) -> void:
	var both := FLAG_SALT_WATER | FLAG_WATER
	var fresh_mask := ~FLAG_SALT_WATER & 0xff

	# Index x * map_edge + y.
	for _pass_index in 4:
		for y in range(1, map_edge):
			for x in range(1, map_edge):
				var index := x * map_edge + y
				var water_bits := flags[index] & both

				if water_bits == FLAG_SALT_WATER:
					flags[index] &= fresh_mask
				elif water_bits == both:
					flags[index - 1] |= FLAG_SALT_WATER
					flags[index - map_edge] |= FLAG_SALT_WATER


static func _make_stream(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	misc: PackedByteArray,
	start: Vector2i,
	length: int,
	random: SimRandom,
	map_edge: int = 128,
) -> void:
	var point := start
	var direction := 1
	_make_water(
		altitude, buildings, terrain, zones, flags, text_overlays, misc, point, map_edge
	)

	for _step in length:
		var altitude_limit := NewTerrainValues._land_altitude(altitude, NewTerrainValues._index(point.x, point.y, map_edge))

		if terrain[NewTerrainValues._index(point.x, point.y, map_edge)] == WATERFALL:
			altitude_limit += 1

		var accepted_attempt := -1
		var next_point := point

		for attempt in 4:
			var candidate_direction: int = (
				int(STREAM_TURN_ORDER[attempt]) + direction
			) & 3
			var candidate := point + Vector2i(
				STREAM_X_OFFSETS[candidate_direction],
				STREAM_Y_OFFSETS[candidate_direction],
			)

			if not NewTerrainValues._in_bounds(candidate, map_edge):
				return

			var candidate_index := NewTerrainValues._index(candidate.x, candidate.y, map_edge)
			var candidate_altitude := NewTerrainValues._land_altitude(altitude, candidate_index)
			var candidate_terrain := int(terrain[candidate_index])

			if candidate_altitude > altitude_limit:
				continue

			if candidate_terrain >= TerrainTileIds.DEEP_WATER_FIRST and candidate_terrain < TerrainTileIds.SURFACE_WATER_FIRST:
				return

			if candidate_altitude < altitude_limit or candidate_terrain == TerrainTileIds.FLAT:
				accepted_attempt = attempt
				next_point = candidate
				break

		if accepted_attempt == -1:
			return

		point = next_point
		_make_water(
			altitude, buildings, terrain, zones, flags, text_overlays, misc, point, map_edge
		)
		direction += STREAM_TURN_ORDER[accepted_attempt]

		if random.next_u15() % 3 != 0:
			direction = (direction + random.next_u15() * 2 + 1) & 3


static func _make_water(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	var index := NewTerrainValues._index(point.x, point.y, map_edge)

	if terrain[index] == FORBIDDEN_COAST or terrain[index] == WATERFALL:
		return

	if flags[index] & FLAG_WATER:
		var shape := Landscapes._water_shape(flags, point.x, point.y, map_edge)
		var transition := Landscapes._water_transition(terrain[index], shape)

		if not transition.early_return:
			terrain[index] = transition.value

		return

	Landscapes._place_water(
		buildings, terrain, zones, flags, altitude, text_overlays, misc, point, map_edge
	)
