class_name NetworkRules
extends NetworkConstants



static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return NETWORK_TOOLS.has(group_index * ToolCatalog.MAX_SLOTS_PER_GROUP + subtool_index)


static func _connection_cost(mode: int) -> int:
	if mode == MODE_ROAD:
		return ROAD_CONNECTION_COST

	if mode == MODE_RAIL:
		return RAIL_CONNECTION_COST

	return 0


static func _point_is_edge(point: Vector2i, map_edge: int = 128) -> bool:
	return point.x == 0 or point.x == (map_edge - 1) or point.y == 0 or point.y == (map_edge - 1)


static func _point_is_in_bounds(point: Vector2i, map_edge: int = 128) -> bool:
	return point.x >= 0 and point.x < map_edge and point.y >= 0 and point.y < map_edge


static func _direction_index(offset: Vector2i) -> int:
	for direction in DIRECTIONS.size():
		if DIRECTIONS[direction] == offset:
			return direction

	return 0


static func _land_altitude(altitude: PackedByteArray, index: int) -> int:
	return altitude[index * 2 + 1] & 0x1f


static func _set_land_altitude(
	altitude: PackedByteArray, index: int, value: int
) -> void:
	var offset := index * 2
	altitude[offset + 1] = (altitude[offset + 1] & 0xe0) | (value & 0x1f)


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
	if point.x < 0 or point.x >= map_edge or point.y < 0 or point.y >= map_edge:
		return false

	var index := point.x * map_edge + point.y

	if (zones[index] & 0x0f) == MILITARY_ZONE:
		return false

	var terrain_id := int(terrain[index])

	if not NetworkTerrainRules.allows_entry(terrain_id, direction):
		return false

	if mode == MODE_SUBWAY or mode == MODE_PIPE:
		var altitude_offset := index * 2
		var altitude_word := (altitude[altitude_offset] << 8) | altitude[altitude_offset + 1]
		var tunnel_level := (altitude_word & 0x7c00) >> 10

		if tunnel_level == 1 or tunnel_level == 2:
			return false

		var under_tile := int(underground[index])

		if _reuses_underground(under_tile, mode):
			if under_tile in [0x1f, 0x20]:
				var axis := under_tile - 0x1f
				if mode == MODE_PIPE:
					axis = 1 - axis
				return (direction & 1) == axis

			return true

		if under_tile == 0:
			return true

		if mode == MODE_PIPE:
			return under_tile + (direction & 1) == 0x11

		return under_tile >= 0x10 and under_tile <= 0x1e

	if flags[index] & FLAG_WATER and terrain_id < 0x40:
		return false

	if terrain_id >= 0x10 and terrain_id < 0x20:
		return false

	var building := int(buildings[index])

	if _reuses_surface(building, mode):
		var axis := _surface_fixed_axis(building, mode)
		return axis < 0 or (direction & 1) == axis

	if building == 0x05 or building == 0x0d or building > 0x50:
		return false

	if building <= 0x0c:
		return true

	var directional_id := building + (direction & 1)

	return directional_id == 0x0f or directional_id == 0x1e or directional_id == 0x2d or directional_id == 0x4a


static func _surface_fixed_axis(tile_id: int, mode: int) -> int:
	# existing mixed crossings cannot turn. this is a geometry constraint,
	# separate from whether reuse is free or a future saved edge is blocked
	if mode == MODE_ROAD:
		return {0x43: 0, 0x44: 1, 0x45: 0, 0x46: 1, 0x4b: 1, 0x4c: 0}.get(tile_id, -1)
	if mode == MODE_RAIL:
		return {0x45: 1, 0x46: 0, 0x47: 0, 0x48: 1, 0x4d: 1, 0x4e: 0}.get(tile_id, -1)
	return {0x43: 1, 0x44: 0, 0x47: 1, 0x48: 0, 0x4f: 1, 0x50: 0}.get(tile_id, -1)


static func _reuses_surface(tile_id: int, mode: int) -> bool:
	return (mode == MODE_ROAD and _road_connects(tile_id)) or (
		mode == MODE_RAIL and _rail_connects(tile_id)
	) or (mode == MODE_POWER and (
		(tile_id >= 0x0e and tile_id <= 0x1c)
		or (tile_id >= 0x43 and tile_id <= 0x44)
		or (tile_id >= 0x47 and tile_id <= 0x48)
		or (tile_id >= 0x4f and tile_id <= 0x50)
	))


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


static func _reuses_underground(tile_id: int, mode: int) -> bool:
	return (mode == MODE_PIPE or mode == MODE_SUBWAY) and BuildingCommand._underground_connects(
		tile_id, mode == MODE_PIPE
	)
