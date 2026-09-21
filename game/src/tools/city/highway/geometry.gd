class_name HighwayGeometry
extends HighwayConstants


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_ROADS and subtool_index == SUBTOOL_HIGHWAY


static func snap_anchor(point: Vector2i) -> Vector2i:
	return Vector2i(point.x & ~1, point.y & ~1)


static func _primary_direction(current: Vector2i, finish: Vector2i) -> int:
	var difference := finish - current

	if absi(difference.y) < absi(difference.x):
		return 1 if difference.x >= 0 else 3

	return 2 if difference.y >= 0 else 0


static func terrain_section_shape(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	anchor: Vector2i,
	map_edge: int = 128,
) -> int:
	if not _anchor_is_in_bounds(anchor, map_edge):
		return INVALID_TERRAIN_SHAPE

	if (
		buildings.size() != (map_edge * map_edge)
		or terrain.size() != (map_edge * map_edge)
		or altitude.size() != (map_edge * map_edge) * 2
	):
		return INVALID_TERRAIN_SHAPE

	var offsets := [
		Vector2i.ZERO,
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(0, 1),
	]
	var class_masks := PackedInt32Array([0, 0, 0, 0, 0])
	var heights := PackedInt32Array()

	for offset_index in offsets.size():
		var point: Vector2i = anchor + offsets[offset_index]
		var index := point.x * map_edge + point.y

		if not _building_is_allowed(int(buildings[index])):
			return INVALID_TERRAIN_SHAPE

		var terrain_id := int(terrain[index])
		var slope_class := _terrain_class(terrain_id)
		class_masks[slope_class] |= 1 << offset_index
		heights.append(_land_altitude(altitude, index))

	var odd_slope_mask := class_masks[1] | class_masks[3]
	var terrain_mask := (
		class_masks[1] | class_masks[2] | class_masks[3] | class_masks[4]
	)

	if terrain_mask == 0:
		return FLAT_TERRAIN_SHAPE

	if (
		(heights[2] < heights[0] and (terrain_mask & 1) != 0)
		or (heights[0] < heights[2] and (terrain_mask & 4) != 0)
		or (heights[3] < heights[1] and (terrain_mask & 2) != 0)
		or (heights[1] < heights[3] and (terrain_mask & 8) != 0)
	):
		return INVALID_TERRAIN_SHAPE

	var minimum_height := heights[0]

	for height in heights:
		minimum_height = mini(minimum_height, height)

	var raised_mask := 0

	for height_index in heights.size():
		if minimum_height < heights[height_index]:
			raised_mask |= 1 << height_index

	if 0x0f - raised_mask == class_masks[4]:
		return FILLED_FLAT_TERRAIN_SHAPE

	if raised_mask == 0 and int(terrain[anchor.x * map_edge + anchor.y]) == TerrainTileIds.RAISED:
		return FILLED_FLAT_TERRAIN_SHAPE

	var result := 0

	if raised_mask == 0:
		if odd_slope_mask == 8 or odd_slope_mask == 1 or odd_slope_mask == 9:
			result |= 1

		if odd_slope_mask == 1 or odd_slope_mask == 2 or odd_slope_mask == 3:
			result |= 2

		if odd_slope_mask == 2 or odd_slope_mask == 4 or odd_slope_mask == 6:
			result |= 4

		if odd_slope_mask == 4 or odd_slope_mask == 8 or odd_slope_mask == 12:
			result |= 8

	if (
		(raised_mask == 8 or raised_mask == 1 or raised_mask == 9)
		and (odd_slope_mask & 6) == 6
	):
		result |= 1

	if (
		(raised_mask == 1 or raised_mask == 2 or raised_mask == 3)
		and (odd_slope_mask & 12) == 12
	):
		result |= 2

	if (
		(raised_mask == 2 or raised_mask == 4 or raised_mask == 6)
		and (odd_slope_mask & 9) == 9
	):
		result |= 4

	if (
		(raised_mask == 4 or raised_mask == 8 or raised_mask == 12)
		and (odd_slope_mask & 3) == 3
	):
		result |= 8

	if terrain_mask == 7:
		if (class_masks[3] & 1) != 0:
			result |= 4

		if (class_masks[3] & 4) != 0:
			result |= 2

	if terrain_mask == 11:
		if (class_masks[3] & 8) != 0:
			result |= 2

		if (class_masks[3] & 2) != 0:
			result |= 1

	if terrain_mask == 13:
		if (class_masks[3] & 4) != 0:
			result |= 1

		if (class_masks[3] & 1) != 0:
			result |= 8

	if terrain_mask == 14:
		if (class_masks[3] & 8) != 0:
			result |= 4

		if (class_masks[3] & 2) != 0:
			result |= 8

	return result


static func _terrain_class(terrain_id: int) -> int:
	if (terrain_id >= TerrainTileIds.SLOPE_TOP_LEFT and terrain_id <= TerrainTileIds.SLOPE_BOTTOM_LEFT) or (terrain_id >= TerrainTileIds.DEEP_WATER_SLOPE_BOTTOM_RIGHT and terrain_id <= TerrainTileIds.SHORE_RAISED_EXCEPT_LEFT):
		return 1

	if terrain_id >= TerrainTileIds.RAISED_EXCEPT_BOTTOM and terrain_id <= TerrainTileIds.RAISED_EXCEPT_RIGHT:
		return 2

	if terrain_id >= TerrainTileIds.CORNER_TOP and terrain_id <= TerrainTileIds.CORNER_LEFT:
		return 3

	return 4 if terrain_id == TerrainTileIds.RAISED else 0


static func _section_altitude(
	terrain: PackedByteArray, altitude: PackedByteArray, anchor: Vector2i,
	map_edge: int = 128,
) -> int:
	var result := 0

	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * map_edge + point.y
		var height := _land_altitude(altitude, index)

		if terrain[index] != TerrainTileIds.FLAT:
			height += 1

		result = maxi(result, height)

	return result


static func _land_altitude(altitude: PackedByteArray, index: int) -> int:
	return ((altitude[index * 2] << 8) | altitude[index * 2 + 1]) & 0x1f


static func _building_is_allowed(tile_id: int) -> bool:
	if (tile_id >= SHAPED_FIRST and tile_id <= SHAPED_LAST) or (tile_id >= STRAIGHT_FIRST and tile_id <= STRAIGHT_LAST):
		return true

	if tile_id == SMALL_PARK or tile_id == RADIOACTIVITY:
		return false

	if tile_id >= Tiles.ROAD_SLOPE_1 and tile_id <= Tiles.ROAD_CROSSROADS:
		return false

	if tile_id >= Tiles.RAIL_SLOPE_1 and tile_id <= Tiles.RAIL_POWER_CROSSING_2:
		return false

	return tile_id <= STRAIGHT_LAST


static func _network_can_cross(tile_id: int, direction: int) -> bool:
	var directional_id := tile_id + (direction & 1)

	return directional_id == Tiles.POWER_LINE_STRAIGHT_2 or directional_id == Tiles.ROAD_STRAIGHT_2 or directional_id == Tiles.RAIL_STRAIGHT_2 or directional_id == Tiles.TUNNEL_ENTRANCE_2


static func _section_kind(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	anchor: Vector2i,
	map_edge: int = 128,
) -> int:
	if not _anchor_is_in_bounds(anchor, map_edge):
		return -1

	var anchor_index := anchor.x * map_edge + anchor.y
	var anchor_tile := int(buildings[anchor_index])

	if not _is_highway_tile(anchor_tile):
		return -1

	if (zones[anchor_index] & 0xf0) != 0xf0:
		var shaped_kind := anchor_tile - Tiles.HIGHWAY_ONRAMP_1

		if shaped_kind > 12:
			var south_index := anchor.x * map_edge + anchor.y + 1

			return 16 if (flags[south_index] & 0x02) != 0 else 15

		return shaped_kind

	var last_tile := anchor_tile

	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * map_edge + point.y
		last_tile = int(buildings[index])

		if last_tile >= Tiles.HIGHWAY_ROAD_CROSSING_1 and last_tile <= Tiles.HIGHWAY_POWER_CROSSING_2:
			return last_tile & 1

		if (flags[index] & FLAG_WATER) != 0:
			return 13 if last_tile == Tiles.HIGHWAY_STRAIGHT_1 else 14

	if last_tile >= STRAIGHT_FIRST and last_tile <= Tiles.HIGHWAY_STRAIGHT_2:
		return (last_tile & 1) + 2

	return -1


static func _is_highway_tile(tile_id: int) -> bool:
	return (
		(tile_id >= STRAIGHT_FIRST and tile_id <= STRAIGHT_LAST)
		or (tile_id >= SHAPED_FIRST and tile_id <= SHAPED_LAST)
	)


static func _grade_kind_for_shape(terrain_shape: int) -> int:
	if (terrain_shape & 2) != 0:
		return 5

	if (terrain_shape & 8) != 0:
		return 7

	if (terrain_shape & 1) != 0:
		return 4

	if (terrain_shape & 4) != 0:
		return 6

	return -1


static func _section_direction(
	sections: Array[Vector2i], section_index: int, finish: Vector2i
) -> int:
	if section_index + 1 < sections.size():
		return _direction_between(sections[section_index], sections[section_index + 1])

	if section_index > 0:
		return _direction_between(sections[section_index - 1], sections[section_index])

	return _primary_direction(sections[section_index], finish)


static func _direction_between(start: Vector2i, finish: Vector2i) -> int:
	var difference := finish - start

	if difference.x > 0:
		return 1

	if difference.x < 0:
		return 3

	return 2 if difference.y >= 0 else 0


static func _anchor_is_in_bounds(anchor: Vector2i, map_edge: int = 128) -> bool:
	return anchor.x >= 0 and anchor.x <= map_edge - 2 and anchor.y >= 0 and anchor.y <= map_edge - 2


static func _is_connection_exit(
	sections: Array[Vector2i], finish: Vector2i, map_edge: int = 128
) -> bool:
	if sections.is_empty():
		return false

	var last_index := sections.size() - 1
	var direction := _section_direction(sections, last_index, finish)
	var after_exit: Vector2i = sections[last_index] + DIRECTIONS[direction] * 2

	if not _anchor_is_in_bounds(after_exit, map_edge):
		return true

	return sections.size() == 1 and _anchor_is_on_border(sections[0], map_edge)


static func _anchor_is_on_border(anchor: Vector2i, map_edge: int = 128) -> bool:
	return anchor.x == 0 or anchor.x == map_edge - 2 or anchor.y == 0 or anchor.y == map_edge - 2


static func _section_has_water(flags: PackedByteArray, anchor: Vector2i, map_edge: int = 128) -> bool:
	if not _anchor_is_in_bounds(anchor, map_edge):
		return false

	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset

		if (flags[point.x * map_edge + point.y] & FLAG_WATER) != 0:
			return true

	return false


static func _section_is_existing_highway(buildings: PackedByteArray, anchor: Vector2i, map_edge: int = 128) -> bool:
	if not _anchor_is_in_bounds(anchor, map_edge):
		return false

	for x in range(anchor.x, anchor.x + 2):
		for y in range(anchor.y, anchor.y + 2):
			if not _is_highway_tile(buildings[x * map_edge + y]):
				return false

	return true
