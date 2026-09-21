class_name ArmyBaseLayout
extends RefCounted



const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const ZONE_TYPE_MASK := 0x0f
const ALL_BUILDING_CORNERS := 0xf0

static func build(
	buildings: PackedByteArray, terrain: PackedByteArray, zones: PackedByteArray,
	underground: PackedByteArray, flags: PackedByteArray, misc: PackedByteArray,
	origin: Vector2i, edge: int,
) -> void:
	for offset in [2, 5]:
		_strip(buildings, terrain, zones, underground, flags, misc,
			origin + Vector2i(offset, 0), Vector2i.DOWN, edge)
	for offset in [2, 5]:
		_strip(buildings, terrain, zones, underground, flags, misc,
			origin + Vector2i(0, offset), Vector2i.RIGHT, edge)


static func _strip(
	buildings: PackedByteArray, terrain: PackedByteArray, zones: PackedByteArray,
	underground: PackedByteArray, flags: PackedByteArray, misc: PackedByteArray,
	start: Vector2i, step: Vector2i, edge: int,
) -> void:
	var placed := 0
	var direction := 2 if step.y != 0 else 1
	for distance in 8:
		var point: Vector2i = start + step * distance
		var index: int = point.x * edge + point.y
		if (zones[index] & ZONE_TYPE_MASK) != NetworkConstants.MILITARY_ZONE or underground[index] != UndergroundTileIds.EMPTY or flags[index] & NetworkConstants.FLAG_WATER:
			continue
		var tile := int(buildings[index])
		if tile >= Tiles.SMALL_PARK or tile == Tiles.RADIOACTIVE_WASTE or terrain[index] >= TerrainTileIds.DEEP_WATER_FIRST:
			continue
		if NetworkCommand.TERRAIN_BLOCKS_DIRECTION[(terrain[index] & TerrainTileIds.SHAPE_MASK) * 4 + direction]:
			continue
		NetworkTiles._grade_surface_terrain(terrain, flags, point, direction, edge)
		SpecialZoneState._replace_special_building(buildings, zones, misc, index, Tiles.ROAD_STRAIGHT_1)
		NetworkTiles._retile_surface_neighborhood(buildings, terrain, zones, flags,
			misc, point, NetworkCommand.MODE_ROAD, PackedByteArray(), edge)
		placed += 1
	if placed == 0:
		return
	for distance in [0, 7]:
		var point: Vector2i = start + step * distance
		var index: int = point.x * edge + point.y
		if distance == 7 and placed < 2:
			continue
		if terrain[index] == TerrainTileIds.FLAT and (zones[index] & ZONE_TYPE_MASK) == NetworkConstants.MILITARY_ZONE and buildings[index] in [Tiles.ROAD_STRAIGHT_1, Tiles.ROAD_STRAIGHT_2]:
			SpecialZoneState._replace_special_building(buildings, zones, misc, index, Tiles.RUNWAY_CROSSING)
			zones[index] |= ALL_BUILDING_CORNERS
			flags[index] &= 0x0f
