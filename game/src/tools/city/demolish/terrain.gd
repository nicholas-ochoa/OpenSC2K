class_name DemolishTerrain
extends DemolishConstants



static func _remove_surface_water(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	var index := point.x * map_edge + point.y

	if terrain[index] == TerrainTileIds.WATERFALL:
		TerrainRetile.retile_region(
			altitude,
			buildings,
			terrain,
			zones,
			flags,
			misc,
			PackedInt32Array([index]),
			BinaryData.read_u32_be(misc, 0x0e40) & 0x1f, map_edge
		)
	else:
		terrain[index] = TerrainTileIds.FLAT

	flags[index] &= ~FLAG_WATER & 0xff
	_retile_surface_water(terrain, flags, point, false, map_edge)


static func _retile_surface_water(
	terrain: PackedByteArray, flags: PackedByteArray, point: Vector2i, include_center: bool,
	map_edge: int = 128,
) -> void:
	for x in range(maxi(0, point.x - 1), mini(map_edge, point.x + 2)):
		for y in range(maxi(0, point.y - 1), mini(map_edge, point.y + 2)):
			if not include_center and x == point.x and y == point.y:
				continue

			var index := x * map_edge + y

			if (flags[index] & FLAG_WATER) == 0:
				continue

			var shape := LandscapeCommand._water_shape(flags, x, y, map_edge)
			var transition := LandscapeCommand._water_transition(terrain[index], shape)

			if not transition.early_return:
				terrain[index] = transition.value


static func _retile_adjacent_roads(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	for offset in DIRECTIONS:
		var neighbor: Vector2i = point + offset

		if _point_is_in_bounds(neighbor, map_edge):
			NetworkTiles.retile_surface(
				buildings, terrain, zones, flags, misc, neighbor, NetworkCommand.MODE_ROAD, PackedByteArray(), map_edge
			)


static func _clear_tunnel_level(altitude: PackedByteArray, index: int) -> void:
	var offset := index * 2
	var word := (altitude[offset] << 8) | altitude[offset + 1]
	word &= ~TUNNEL_MASK & 0xffff
	altitude[offset] = (word >> 8) & 0xff
	altitude[offset + 1] = word & 0xff


static func _land_altitude(altitude: PackedByteArray, index: int) -> int:
	return altitude[index * 2 + 1] & 0x1f


static func _water_altitude(altitude: PackedByteArray, index: int) -> int:
	return (((altitude[index * 2] << 8) | altitude[index * 2 + 1]) >> 5) & 0x1f


static func _set_land_altitude(altitude: PackedByteArray, index: int, value: int) -> void:
	var offset := index * 2
	altitude[offset + 1] = (altitude[offset + 1] & 0xe0) | (value & 0x1f)


static func _point_is_in_bounds(point: Vector2i, map_edge: int = 128) -> bool:
	return point.x >= 0 and point.x < map_edge and point.y >= 0 and point.y < map_edge


static func _retile_after_demolition(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	points: Array[Vector2i],
	text_overlays := PackedByteArray(),
	map_edge: int = 128,
) -> void:
	for point in points:
		for offset in DIRECTIONS:
			var neighbor: Vector2i = point + offset

			if neighbor.x < 0 or neighbor.x >= map_edge or neighbor.y < 0 or neighbor.y >= map_edge:
				continue

			NetworkTiles.retile_surface(
				buildings,
				terrain,
				zones,
				flags,
				misc,
				neighbor,
				NetworkCommand.MODE_ROAD,
				text_overlays, map_edge
			)
			NetworkTiles.retile_surface(
				buildings,
				terrain,
				zones,
				flags,
				misc,
				neighbor,
				NetworkCommand.MODE_RAIL,
				text_overlays, map_edge
			)
			NetworkTiles.retile_surface(
				buildings,
				terrain,
				zones,
				flags,
				misc,
				neighbor,
				NetworkCommand.MODE_POWER,
				text_overlays, map_edge
			)

		BuildingUnderground._retile_neighborhood(underground, terrain, point, false, map_edge)
		BuildingUnderground._retile_neighborhood(underground, terrain, point, true, map_edge)
