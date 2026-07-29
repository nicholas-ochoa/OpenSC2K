class_name NetworkTiles
extends NetworkConstants



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

	if NetworkRules._reuses_surface(buildings[index], mode):
		return

	_grade_surface_terrain(terrain, flags, point, direction, map_edge)
	var old_tile := int(buildings[index])
	var new_tile := _surface_replacement(old_tile, mode)

	if new_tile < 0:
		return

	NetworkState.replace_building(buildings, zones, misc, index, new_tile)

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
	retile_surface(
		buildings, terrain, zones, flags, misc, point, mode, text_overlays, map_edge
	)

	for offset in DIRECTIONS:
		var near: Vector2i = point + offset

		if near.x >= 0 and near.x < map_edge and near.y >= 0 and near.y < map_edge:
			retile_surface(
				buildings, terrain, zones, flags, misc, near, mode, text_overlays, map_edge
			)


static func retile_surface(
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
			NetworkState.replace_building(
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
				NetworkState.replace_building(buildings, zones, misc, index, 0x3a + shape)

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
			connects = NetworkRules._road_connects(buildings[near_index])
		else:
			connects = NetworkRules._rail_connects(buildings[near_index])

		if connects and NetworkTerrainRules.allows_connection(terrain[near_index], direction):
			connections |= 1 << direction

	NetworkState.replace_building(buildings, zones, misc, index, base + NETWORK_SHAPES[connections])


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

	if NetworkRules._reuses_underground(old_tile, MODE_PIPE if pipes else MODE_SUBWAY):
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
	BuildingUnderground._replace_underground(underground, zones, misc, index, new_tile)
	_retile_underground_neighborhood(underground, terrain, point, pipes, map_edge)


static func _retile_underground_neighborhood(
	underground: PackedByteArray, terrain: PackedByteArray, point: Vector2i, pipes: bool,
	map_edge: int = 128,
) -> void:
	BuildingUnderground._retile_neighborhood(underground, terrain, point, pipes, map_edge)
