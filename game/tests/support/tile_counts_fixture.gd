class_name TileCountsFixture
extends RefCounted
## Stamp fixture tiles and keep the saved MISC counts, as the tools do. The
## tools themselves run in the native simulation library.

const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")


# store `tile` and move one tile count outside military zones
static func replace_building(buildings: PackedByteArray, zones: PackedByteArray, misc: PackedByteArray, index: int, tile: int) -> void:
	var old := int(buildings[index])

	if old == tile:
		return

	var mask := 0xffff if buildings.size() == 16384 else 0xffffffff
	var old_offset := Sc2MiscLayout.TILE_COUNTS + old * 4
	var new_offset := Sc2MiscLayout.TILE_COUNTS + tile * 4

	if (zones[index] & Sc2ZoneLayout.TYPE_MASK) == Sc2ZoneLayout.MILITARY:
		old_offset = Sc2MiscLayout.MILITARY_TILE_COUNTS + int(Sc2MilitaryLayout.TILE_COUNT_INDEX.get(old, 0)) * 4
		new_offset = Sc2MiscLayout.MILITARY_TILE_COUNTS + int(Sc2MilitaryLayout.TILE_COUNT_INDEX.get(tile, 0)) * 4

	BinaryData.write_u32_be(misc, old_offset, (BinaryData.read_u32_be(misc, old_offset) - 1) & mask)
	BinaryData.write_u32_be(misc, new_offset, (BinaryData.read_u32_be(misc, new_offset) + 1) & mask)
	buildings[index] = tile


# store an underground `tile` and keep the subway count outside military zones
static func replace_underground(underground: PackedByteArray, zones: PackedByteArray, misc: PackedByteArray, index: int, tile: int) -> void:
	var old := int(underground[index])

	if old == tile:
		return

	if (zones[index] & Sc2ZoneLayout.TYPE_MASK) != Sc2ZoneLayout.MILITARY:
		var mask := 0xffff if underground.size() == 16384 else 0xffffffff
		var count := BinaryData.read_u32_be(misc, Sc2MiscLayout.SUBWAY_COUNT)
		count = (count - int(_is_subway(old)) + int(_is_subway(tile))) & mask
		BinaryData.write_u32_be(misc, Sc2MiscLayout.SUBWAY_COUNT, count)

	underground[index] = tile


static func _is_subway(tile: int) -> bool:
	return ((tile > UnderTiles.EMPTY and tile < UnderTiles.PIPE_FIRST) or tile in [UnderTiles.PIPE_TB_SUBWAY_LR,
		UnderTiles.PIPE_LR_SUBWAY_TB, UnderTiles.MISSILE_SILO, UnderTiles.SUBWAY_ENTRANCE])
