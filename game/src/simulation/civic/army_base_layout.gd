class_name ArmyBaseLayout
extends RefCounted



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
		if (zones[index] & 15) != 7 or underground[index] != 0 or flags[index] & 4:
			continue
		var tile := int(buildings[index])
		if tile >= 0x0d or tile == 0x05 or terrain[index] >= 0x10:
			continue
		if NetworkCommand.TERRAIN_BLOCKS_DIRECTION[(terrain[index] & 15) * 4 + direction]:
			continue
		NetworkTiles._grade_surface_terrain(terrain, flags, point, direction, edge)
		SpecialZoneState._replace_special_building(buildings, zones, misc, index, 0x1d)
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
		if terrain[index] == 0 and (zones[index] & 15) == 7 and buildings[index] in [0x1d, 0x1e]:
			SpecialZoneState._replace_special_building(buildings, zones, misc, index, 0xde)
			zones[index] |= 0xf0
			flags[index] &= 0x0f
