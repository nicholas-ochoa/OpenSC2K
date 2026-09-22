class_name NetworkRules
extends NetworkConstants



const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")

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


static func land_altitude(altitude: PackedByteArray, index: int) -> int:
	return altitude[index * 2 + 1] & Sc2AltitudeLayout.LEVEL_MASK


static func set_land_altitude(
	altitude: PackedByteArray, index: int, value: int
) -> void:
	var offset := index * 2
	altitude[offset + 1] = (altitude[offset + 1] & (~Sc2AltitudeLayout.LAND_MASK & 0xff)) | (value & Sc2AltitudeLayout.LEVEL_MASK)


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

	if (zones[index] & Sc2ZoneLayout.TYPE_MASK) == MILITARY_ZONE:
		return false

	var terrain_id := int(terrain[index])

	if not NetworkTerrainRules.allows_entry(terrain_id, direction):
		return false

	if mode == MODE_SUBWAY or mode == MODE_PIPE:
		var altitude_offset := index * 2
		var altitude_word := (altitude[altitude_offset] << 8) | altitude[altitude_offset + 1]
		var tunnel_level := (altitude_word & Sc2AltitudeLayout.TUNNEL_MASK) >> Sc2AltitudeLayout.TUNNEL_SHIFT

		if tunnel_level == 1 or tunnel_level == 2:
			return false

		var under_tile := int(underground[index])

		if _reuses_underground(under_tile, mode):
			if under_tile in [UnderTiles.PIPE_TB_SUBWAY_LR, UnderTiles.PIPE_LR_SUBWAY_TB]:
				var axis := under_tile - UnderTiles.PIPE_TB_SUBWAY_LR
				if mode == MODE_PIPE:
					axis = 1 - axis
				return (direction & 1) == axis

			return true

		if under_tile == UnderTiles.EMPTY:
			return true

		if mode == MODE_PIPE:
			return under_tile + (direction & 1) == UnderTiles.PIPE_TB

		return under_tile >= UnderTiles.PIPE_FIRST and under_tile <= UnderTiles.PIPE_LAST

	if flags[index] & FLAG_WATER and terrain_id < TerrainTileIds.CHANNEL_FIRST:
		return false

	if terrain_id >= TerrainTileIds.DEEP_WATER_FIRST and terrain_id < TerrainTileIds.SHORE_FIRST:
		return false

	var building := int(buildings[index])

	if _reuses_surface(building, mode):
		var axis := _surface_fixed_axis(building, mode)
		return axis < 0 or (direction & 1) == axis

	if building == Tiles.RADIOACTIVE_WASTE or building == Tiles.SMALL_PARK or building > Tiles.HIGHWAY_POWER_CROSSING_2:
		return false

	if building <= Tiles.TREE_LAST:
		return true

	var directional_id := building + (direction & 1)

	return directional_id == Tiles.POWER_LINE_STRAIGHT_2 or directional_id == Tiles.ROAD_STRAIGHT_2 or directional_id == Tiles.RAIL_STRAIGHT_2 or directional_id == Tiles.HIGHWAY_STRAIGHT_2


static func _surface_fixed_axis(tile_id: int, mode: int) -> int:
	# existing mixed crossings cannot turn. this is a geometry constraint,
	# separate from whether reuse is free or a future saved edge is blocked
	if mode == MODE_ROAD:
		return {Tiles.ROAD_POWER_CROSSING_1: 0, Tiles.ROAD_POWER_CROSSING_2: 1, Tiles.ROAD_RAIL_CROSSING_1: 0, Tiles.ROAD_RAIL_CROSSING_2: 1, Tiles.HIGHWAY_ROAD_CROSSING_1: 1, Tiles.HIGHWAY_ROAD_CROSSING_2: 0}.get(tile_id, -1)
	if mode == MODE_RAIL:
		return {Tiles.ROAD_RAIL_CROSSING_1: 1, Tiles.ROAD_RAIL_CROSSING_2: 0, Tiles.RAIL_POWER_CROSSING_1: 0, Tiles.RAIL_POWER_CROSSING_2: 1, Tiles.HIGHWAY_RAIL_CROSSING_1: 1, Tiles.HIGHWAY_RAIL_CROSSING_2: 0}.get(tile_id, -1)
	return {Tiles.ROAD_POWER_CROSSING_1: 1, Tiles.ROAD_POWER_CROSSING_2: 0, Tiles.RAIL_POWER_CROSSING_1: 1, Tiles.RAIL_POWER_CROSSING_2: 0, Tiles.HIGHWAY_POWER_CROSSING_1: 1, Tiles.HIGHWAY_POWER_CROSSING_2: 0}.get(tile_id, -1)


static func _reuses_surface(tile_id: int, mode: int) -> bool:
	return (mode == MODE_ROAD and _road_connects(tile_id)) or (
		mode == MODE_RAIL and _rail_connects(tile_id)
	) or (mode == MODE_POWER and (
		(tile_id >= Tiles.POWER_LINE_FIRST and tile_id <= Tiles.POWER_LINE_LAST)
		or (tile_id >= Tiles.ROAD_POWER_CROSSING_1 and tile_id <= Tiles.ROAD_POWER_CROSSING_2)
		or (tile_id >= Tiles.RAIL_POWER_CROSSING_1 and tile_id <= Tiles.RAIL_POWER_CROSSING_2)
		or (tile_id >= Tiles.HIGHWAY_POWER_CROSSING_1 and tile_id <= Tiles.HIGHWAY_POWER_CROSSING_2)
	))


static func _road_connects(tile_id: int) -> bool:
	return (
		(tile_id >= Tiles.FIRST_ROAD and tile_id <= Tiles.LAST_ROAD)
		or (tile_id >= Tiles.TUNNEL_FIRST and tile_id <= Tiles.ROAD_RAIL_CROSSING_2)
		or tile_id == Tiles.HIGHWAY_ROAD_CROSSING_1
		or tile_id == Tiles.HIGHWAY_ROAD_CROSSING_2
		or (tile_id >= Tiles.ONRAMP_FIRST and tile_id <= Tiles.ONRAMP_LAST)
	)


static func _rail_connects(tile_id: int) -> bool:
	return (
		(tile_id >= Tiles.RAIL_FIRST and tile_id <= Tiles.RAIL_LAST)
		or (tile_id >= Tiles.ROAD_RAIL_CROSSING_1 and tile_id <= Tiles.RAIL_POWER_CROSSING_2)
		or tile_id == Tiles.HIGHWAY_RAIL_CROSSING_1
		or tile_id == Tiles.HIGHWAY_RAIL_CROSSING_2
		or (tile_id >= Tiles.RAIL_SUBWAY_FIRST and tile_id <= Tiles.RAIL_SUBWAY_LAST)
	)


static func _reuses_underground(tile_id: int, mode: int) -> bool:
	return (mode == MODE_PIPE or mode == MODE_SUBWAY) and BuildingUnderground._underground_connects(
		tile_id, mode == MODE_PIPE
	)
