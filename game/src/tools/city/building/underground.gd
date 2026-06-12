class_name BuildingUnderground
extends BuildingConstants



static func _place_pipe(
	underground: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	var index := point.x * map_edge + point.y
	var old_tile := int(underground[index])

	if (old_tile >= UNDER_PIPE_FIRST and old_tile <= UNDER_PIPE_LAST) or old_tile == UNDER_PIPE_SUBWAY_LR or old_tile == UNDER_PIPE_SUBWAY_TB:
		return

	var new_tile := -1

	if old_tile == 0:
		new_tile = UNDER_PIPE_FIRST
	elif old_tile == 1:
		new_tile = UNDER_PIPE_SUBWAY_LR
	elif old_tile == 2:
		new_tile = UNDER_PIPE_SUBWAY_TB
	else:
		return

	_replace_underground(underground, zones, misc, index, new_tile)
	flags[index] |= FLAG_PIPED
	_retile_neighborhood(underground, terrain, point, true, map_edge)


# connect and retile the subway before replacing the center with the station
static func _place_subway_station(
	underground: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	var index := point.x * map_edge + point.y
	var old_tile := int(underground[index])
	var inserted_tile := -1

	if old_tile == 0:
		inserted_tile = UNDER_SUBWAY_FIRST
	elif old_tile == UNDER_PIPE_FIRST:
		inserted_tile = UNDER_PIPE_SUBWAY_TB
	elif old_tile == UNDER_PIPE_FIRST + 1:
		inserted_tile = UNDER_PIPE_SUBWAY_LR

	if inserted_tile >= 0:
		_replace_underground(underground, zones, misc, index, inserted_tile)
		_retile_neighborhood(underground, terrain, point, false, map_edge)

	_replace_underground(underground, zones, misc, index, UNDER_SUBWAY_ENTRANCE)
	flags[index] &= ~FLAG_PIPED & 0xff


static func _replace_underground(
	underground: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	var old_tile := int(underground[index])

	if old_tile == new_tile:
		return

	if (zones[index] & 0x0f) != MILITARY_ZONE:
		var count := BuildingState._read_u32_be(misc, MISC_SUBWAY_COUNT)

		if _is_subway_tile(old_tile):
			count = (count - 1) & (0xffff if underground.size() == 16384 else 0xffffffff)

		if _is_subway_tile(new_tile):
			count = (count + 1) & (0xffff if underground.size() == 16384 else 0xffffffff)

		BuildingState._write_u32_be(misc, MISC_SUBWAY_COUNT, count)

	underground[index] = new_tile


static func _is_subway_tile(tile_id: int) -> bool:
	return (
		(tile_id > 0 and tile_id < UNDER_PIPE_FIRST)
		or tile_id == UNDER_PIPE_SUBWAY_LR
		or tile_id == UNDER_PIPE_SUBWAY_TB
		or tile_id == UNDER_UNKNOWN
		or tile_id == UNDER_SUBWAY_ENTRANCE
	)


static func _retile_neighborhood(
	underground: PackedByteArray, terrain: PackedByteArray, point: Vector2i, pipes: bool,
	map_edge: int = 128,
) -> void:
	_retile_underground(underground, terrain, point, pipes, map_edge)

	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var near: Vector2i = point + offset

		if near.x >= 0 and near.x < map_edge and near.y >= 0 and near.y < map_edge:
			_retile_underground(underground, terrain, near, pipes, map_edge)


static func _retile_underground(
	underground: PackedByteArray, terrain: PackedByteArray, point: Vector2i, pipes: bool,
	map_edge: int = 128,
) -> void:
	var index := point.x * map_edge + point.y
	var current := int(underground[index])

	if pipes:
		if current < UNDER_PIPE_FIRST or current > UNDER_PIPE_LAST:
			return
	else:
		if current < UNDER_SUBWAY_FIRST or current > UNDER_SUBWAY_LAST:
			return

	var terrain_shape := int(terrain[index]) & 0x0f if terrain[index] <= 0x30 else 0
	var base := UNDER_PIPE_FIRST if pipes else UNDER_SUBWAY_FIRST

	if FORCED_TERRAIN_MASKS.has(terrain_shape):
		underground[index] = base + FORCED_TERRAIN_SHAPES[terrain_shape]

		return

	var connections := 0

	if point.x > 0:
		var west_index := (point.x - 1) * map_edge + point.y

		if _underground_connects(underground[west_index], pipes) and _allows_horizontal(terrain[west_index]):
			connections |= 8

	if point.x < (map_edge - 1):
		var east_index := (point.x + 1) * map_edge + point.y

		if _underground_connects(underground[east_index], pipes) and _allows_horizontal(terrain[east_index]):
			connections |= 2

	if point.y > 0:
		var north_index := point.x * map_edge + point.y - 1

		if _underground_connects(underground[north_index], pipes) and _allows_vertical(terrain[north_index]):
			connections |= 1

	if point.y < (map_edge - 1):
		var south_index := point.x * map_edge + point.y + 1

		if _underground_connects(underground[south_index], pipes) and _allows_vertical(terrain[south_index]):
			connections |= 4

	if pipes and connections == 0:
		connections = 15

	underground[index] = base + NETWORK_SHAPES[connections]


static func _underground_connects(tile_id: int, pipes: bool) -> bool:
	if pipes:
		return (
			(tile_id >= UNDER_PIPE_FIRST and tile_id <= UNDER_PIPE_LAST)
			or tile_id == UNDER_PIPE_SUBWAY_LR
			or tile_id == UNDER_PIPE_SUBWAY_TB
		)

	return (
		(tile_id >= UNDER_SUBWAY_FIRST and tile_id <= UNDER_SUBWAY_LAST)
		or tile_id == UNDER_SUBWAY_ENTRANCE
		or tile_id == UNDER_PIPE_SUBWAY_LR
		or tile_id == UNDER_PIPE_SUBWAY_TB
		or tile_id == UNDER_UNKNOWN
	)


static func _allows_vertical(terrain_id: int) -> bool:
	return NetworkTerrainRules.allows_connection(terrain_id, 0)


static func _allows_horizontal(terrain_id: int) -> bool:
	return NetworkTerrainRules.allows_connection(terrain_id, 1)
