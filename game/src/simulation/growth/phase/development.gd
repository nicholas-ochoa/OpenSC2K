class_name GrowthDevelopment
extends GrowthConstants


@warning_ignore_start("integer_division")


static func _abandon(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	density: int,
	pattern: int,
	random: SimRandom,
	rotation: int,
	land_value: PackedByteArray,
	map_edge: int = 128,
) -> void:
	match density:
		1:
			place_zone(
				buildings, zones, flags, misc, land_value, point,
				1, CLASS_ABANDONED, random, rotation, map_edge
			)
		2:
			if pattern == 0:
				place_zone(
					buildings, zones, flags, misc, land_value, point,
					2, CLASS_ABANDONED, random, rotation, map_edge
				)
			else:
				for abandoned_point in [
					point,
					point + Vector2i(1, 0),
					point + Vector2i(1, -1),
					point + Vector2i(0, -1),
				]:
					place_zone(
						buildings, zones, flags, misc, land_value, abandoned_point,
						1, CLASS_ABANDONED, random, rotation, map_edge
					)
		3:
			place_zone(
				buildings, zones, flags, misc, land_value, point,
				3 if pattern == 0 else 2, CLASS_ABANDONED, random, rotation, map_edge
			)
		4:
			if pattern == 0:
				place_zone(
					buildings, zones, flags, misc, land_value, point,
					4, CLASS_ABANDONED, random, rotation, map_edge
				)
			else:
				for abandoned_point in [
					point,
					point + Vector2i(1, 0),
					point + Vector2i(2, 0),
					point + Vector2i(2, -1),
					point + Vector2i(2, -2),
					point + Vector2i(1, -2),
					point + Vector2i(0, -2),
					point + Vector2i(0, -1),
				]:
					place_zone(
						buildings, zones, flags, misc, land_value, abandoned_point,
						1, CLASS_ABANDONED, random, rotation, map_edge
					)

				var selection: int = random.next_u15() & 3
				place_zone(
					buildings,
					zones,
					flags,
					misc,
					land_value,
					point + Vector2i(selection & 1, -int(selection / 2)),
					3,
					CLASS_ABANDONED,
					random,
					rotation, map_edge,
				)


static func place_zone(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	land_value: PackedByteArray,
	anchor: Vector2i,
	density: int,
	building_class: int,
	random: SimRandom,
	rotation: int,
	map_edge: int = 128,
) -> bool:
	var tile: int

	if density == 1 and building_class == CLASS_RESIDENTIAL:
		var value_index := CityDataGrid.index(land_value, map_edge, anchor.x, anchor.y)
		var value_group := mini(int(land_value[value_index]) >> 6, 2)
		tile = BUILDING_BASE[1] + value_group * 4 + (random.next_u15() & 3)
	else:
		var table_index := density + building_class * 4
		var tile_range: int = BUILDING_RANGE[table_index]
		tile = BUILDING_BASE[table_index] + random.next_u15() % tile_range

	if density == 1:
		var index := GrowthState._index(anchor, map_edge)

		if index < 0:
			return false

		GrowthState.replace_building(buildings, zones, misc, index, tile)
		zones[index] |= Sc2ZoneLayout.CORNERS_MASK
		flags[index] |= Sc2TileFlags.STRUCTURE_MASK

		return true

	var radius := int(density / 2)

	if (
		anchor.x <= 1
		or anchor.y <= 1
		or anchor.x > map_edge - 2 - radius
		or anchor.y > map_edge - 2 - radius
	):
		return false

	var site_position := Vector2i(anchor.x, anchor.y - radius)

	for x in range(site_position.x, site_position.x + radius + 1):
		for y in range(site_position.y, site_position.y + radius + 1):
			var index := x * map_edge + y
			GrowthState.replace_building(buildings, zones, misc, index, tile)
			zones[index] &= Sc2ZoneLayout.TYPE_MASK
			flags[index] |= Sc2TileFlags.STRUCTURE_MASK

	GrowthSiteRules.set_corners(zones, site_position, radius + 1, rotation, map_edge)

	return true


static func _place_church(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	rotation: int,
	map_edge: int = 128,
) -> bool:
	if anchor.x <= 0 or anchor.y <= 0 or anchor.x >= (map_edge - 1) or anchor.y >= (map_edge - 1):
		return false

	var position := Vector2i(anchor.x, anchor.y - 1)

	for x in range(position.x, position.x + 2):
		for y in range(position.y, position.y + 2):
			var index := x * map_edge + y
			GrowthState.replace_building(buildings, zones, misc, index, CHURCH_TILE)
			zones[index] = 0
			flags[index] |= Sc2TileFlags.STRUCTURE_MASK

	GrowthSiteRules.set_corners(zones, position, 2, rotation, map_edge)

	return true


static func density(tile: int) -> int:
	if tile <= Tiles.DEVELOPED_1X1_LAST:
		return 1

	if tile <= Tiles.NICE_APARTMENTS_2X2_1:
		return 2

	if tile <= Tiles.RESIDENTIAL_2X2_LAST:
		return 3

	if tile <= Tiles.OFFICE_BUILDING_2X2_2:
		return 2

	if tile <= Tiles.COMMERCIAL_2X2_LAST:
		return 3

	if tile <= Tiles.FACTORY_2X2_2:
		return 2

	if tile <= Tiles.INDUSTRIAL_2X2_LAST:
		return 3

	if tile <= Tiles.CONSTRUCTION_2X2_2:
		return 2

	if tile <= Tiles.CONSTRUCTION_2X2_LAST:
		return 3

	if tile <= Tiles.ABANDONED_2X2_2:
		return 2

	if tile <= Tiles.DEVELOPED_2X2_LAST:
		return 3

	return 4


static func _status(tile: int) -> int:
	if (
		(tile >= Tiles.CONSTRUCTION_1X1_FIRST and tile <= Tiles.CONSTRUCTION_1X1_LAST)
		or (tile >= Tiles.CONSTRUCTION_2X2_FIRST and tile <= Tiles.CONSTRUCTION_2X2_LAST)
		or (tile >= Tiles.CONSTRUCTION_3X3_FIRST and tile <= Tiles.CONSTRUCTION_3X3_LAST)
	):
		return STATUS_CONSTRUCTION

	if (
		(tile >= Tiles.ABANDONED_1X1_FIRST and tile <= Tiles.DEVELOPED_1X1_LAST)
		or (tile >= Tiles.ABANDONED_2X2_FIRST and tile <= Tiles.DEVELOPED_2X2_LAST)
		or (tile >= Tiles.ABANDONED_3X3_FIRST and tile <= Tiles.DEVELOPED_3X3_LAST)
	):
		return STATUS_ABANDONED

	return STATUS_NORMAL
