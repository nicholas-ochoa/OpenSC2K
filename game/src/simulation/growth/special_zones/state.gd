class_name SpecialZoneState
extends SpecialZoneConstants



const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")

static func replace_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	_replace_special_building(buildings, zones, misc, index, new_tile)


static func _replace_special_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	var old_tile := int(buildings[index])

	if old_tile == new_tile:
		return

	var military := (zones[index] & Sc2ZoneLayout.TYPE_MASK) == Sc2ZoneLayout.MILITARY
	var old_offset := _special_count_offset(old_tile, military)
	var new_offset := _special_count_offset(new_tile, military)
	BinaryData.write_u32_be(misc, old_offset, (BinaryData.read_u32_be(misc, old_offset) - 1) & (0xffff if buildings.size() == 16384 else 0xffffffff))
	BinaryData.write_u32_be(misc, new_offset, (BinaryData.read_u32_be(misc, new_offset) + 1) & (0xffff if buildings.size() == 16384 else 0xffffffff))
	buildings[index] = new_tile


static func tile_count(misc: PackedByteArray, tile: int, military: bool, map_edge: int = 128) -> int:
	return _special_tile_count(misc, tile, military, map_edge)


static func _special_tile_count(misc: PackedByteArray, tile: int, military: bool, map_edge: int = 128) -> int:
	return BinaryData.read_u32_be(misc, _special_count_offset(tile, military)) & (0xffff if map_edge == 128 else 0xffffffff)


static func _special_count_offset(tile: int, military: bool) -> int:
	if not military:
		return MISC_TILE_COUNTS + tile * 4

	return MISC_MILITARY_TILE_COUNTS + int(MILITARY_TILE_COUNT_INDEX.get(tile, 0)) * 4


static func _special_axis_is_flipped(x_delta: int, rotation: int) -> bool:
	return bool(rotation & 1) if x_delta == 0 else not bool(rotation & 1)


static func replace_underground(
	underground: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	var old_tile := int(underground[index])

	if old_tile == new_tile:
		return

	if (zones[index] & Sc2ZoneLayout.TYPE_MASK) != Sc2ZoneLayout.MILITARY:
		var count := BinaryData.read_u32_be(misc, MISC_SUBWAY_COUNT)

		if NetworkTileMembership.subway(old_tile):
			count = (count - 1) & (0xffff if underground.size() == 16384 else 0xffffffff)

		if NetworkTileMembership.subway(new_tile):
			count = (count + 1) & (0xffff if underground.size() == 16384 else 0xffffffff)

		BinaryData.write_u32_be(misc, MISC_SUBWAY_COUNT, count)

	underground[index] = new_tile


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.x >= map_edge or point.y < 0 or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y
