class_name TerrainRetile
extends TerrainEditConstants
# Keep retiling separate so demolition can call it without a TerrainEditSurface dependency cycle.

@warning_ignore_start("integer_division")


const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

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
	# Neighbor steps and masks in NEIGHBOR_OFFSETS order. Land altitude is the masked low byte.
	var steps_x := PackedInt32Array()
	var steps_y := PackedInt32Array()
	var masks := PackedInt32Array(NEIGHBOR_MASKS)
	var level_mask := Sc2AltitudeLayout.LEVEL_MASK

	for offset: Vector2i in NEIGHBOR_OFFSETS:
		steps_x.append(offset.x)
		steps_y.append(offset.y)

	for index in indices:
		var x := index / map_edge
		var y := index % map_edge
		var land := altitude[index * 2 + 1] & level_mask
		var higher_mask := 0

		for neighbor_index in 8:
			var near_x := x + steps_x[neighbor_index]
			var near_y := y + steps_y[neighbor_index]

			if (near_x >= 0 and near_x < map_edge and near_y >= 0 and near_y < map_edge
					and (altitude[(near_x * map_edge + near_y) * 2 + 1] & level_mask) > land):
				higher_mask |= masks[neighbor_index]

		var shape := int(TERRAIN_SHAPES[higher_mask])

		if shape != TerrainTileIds.FLAT:
			zones[index] &= Sc2ZoneLayout.CORNERS_MASK

		var raised_basin := shape == RAISE_BASIN

		if raised_basin:
			land = mini(31, land + 1)
			TerrainEditHeights.set_land_altitude(altitude, index, land)
			shape = TerrainTileIds.FLAT

		if land >= sea_level:
			flags[index] &= ~FLAG_WATER & 0xff
			terrain[index] = shape
			continue

		flags[index] |= FLAG_WATER
		TerrainEditHeights._set_water_altitude(altitude, index, sea_level)

		if buildings[index] != Tiles.EMPTY and buildings[index] != Tiles.RADIOACTIVE_WASTE:
			NetworkState.replace_building(buildings, zones, misc, index, Tiles.EMPTY)

		terrain[index] = (
			TerrainTileIds.DEEP_WATER_FLAT
			if raised_basin
			else shape + (TerrainTileIds.SHORE_FIRST if sea_level - land == 1 else TerrainTileIds.DEEP_WATER_FIRST)
		)
