class_name TerrainRetile
extends TerrainEditConstants
# Keep retiling separate so demolition can call it without a TerrainEditSurface dependency cycle.

@warning_ignore_start("integer_division")


static func retile_region(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	indices: PackedInt32Array,
	sea_level: int,
	map_edge: int = 128,
) -> void:
	for index in indices:
		var point := Vector2i(int(index / map_edge), index % map_edge)
		var land := TerrainEditHeights.land_altitude(altitude, index)
		var higher_mask := 0

		for neighbor_index in 8:
			var neighbor: Vector2i = point + NEIGHBOR_OFFSETS[neighbor_index]

			if TerrainEditHeights._point_is_in_bounds(neighbor, map_edge):
				var checked_index := neighbor.x * map_edge + neighbor.y

				if TerrainEditHeights.land_altitude(altitude, checked_index) > land:
					higher_mask |= NEIGHBOR_MASKS[neighbor_index]

		var shape := int(TERRAIN_SHAPES[higher_mask])

		if shape != 0:
			zones[index] &= 0xf0

		var raised_basin := shape == 50

		if raised_basin:
			land = mini(31, land + 1)
			TerrainEditHeights.set_land_altitude(altitude, index, land)
			shape = 0

		if land >= sea_level:
			flags[index] &= ~FLAG_WATER & 0xff
			terrain[index] = shape
			continue

		flags[index] |= FLAG_WATER
		TerrainEditHeights._set_water_altitude(altitude, index, sea_level)

		if buildings[index] != 0 and buildings[index] != 5:
			NetworkState.replace_building(buildings, zones, misc, index, 0)

		terrain[index] = (
			0x10
			if raised_basin
			else shape + (0x20 if sea_level - land == 1 else 0x10)
		)
