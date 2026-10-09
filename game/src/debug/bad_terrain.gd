class_name BadTerrain
extends RefCounted
## The "bad terrain" of sc2kfix: a dry tile whose own water level is above the
## city water level and its land. Such a tile acts as water in some checks. The
## repair follows sc2kfix DoFixBadTerrain. It finds the water level of the map
## from its water tiles, sets that level on each bad tile, and marks a tile
## below it as water.

const LEVEL_MASK := Sc2AltitudeLayout.LEVEL_MASK
const WATER_SHIFT := Sc2AltitudeLayout.WATER_SHIFT
const FIRST_LAND_LEVEL := 30


static func city_water_level(city: CityState) -> int:
	return city.document.misc_u32(Sc2MiscLayout.WATER_LEVEL) & 0xffff


static func is_bad(word: int, flags: int, water_level: int) -> bool:
	var land := word & LEVEL_MASK
	var water := (word >> WATER_SHIFT) & LEVEL_MASK

	return flags & Sc2TileFlags.WATER == 0 and water > water_level and land < water


# The water level of the map: the highest water level of a water tile, among
# the water tiles that set a new lowest land level in scan order. The city
# water level when no water tile qualifies.
static func detected_water_level(city: CityState) -> int:
	var last_land := FIRST_LAND_LEVEL
	var last_water := 0
	var detected := false

	for index in city.altitude_words.size():
		if city.tile_flags[index] & Sc2TileFlags.WATER == 0:
			continue

		var word := city.altitude_words[index]
		var land := word & LEVEL_MASK
		var water := (word >> WATER_SHIFT) & LEVEL_MASK

		if land < last_land:
			if water > land and water > last_water:
				last_water = water
				detected = true

			last_land = land

	return last_water if detected else city_water_level(city)


# The repaired ALTM and XBIT payloads and the number of repaired tiles.
static func repair(city: CityState) -> Repair:
	var result := Repair.new()
	var level := city_water_level(city)
	var detected := detected_water_level(city)
	var altitude_chunk := city.document.find_chunk("ALTM")
	var flag_chunk := city.document.find_chunk("XBIT")
	result.detected_level = detected

	if altitude_chunk == null or flag_chunk == null:
		return result

	result.altitude = altitude_chunk.decoded_payload.duplicate()
	result.flags = flag_chunk.decoded_payload.duplicate()

	for index in city.altitude_words.size():
		var word := city.altitude_words[index]

		if not is_bad(word, city.tile_flags[index], level):
			continue

		var land := word & LEVEL_MASK
		var water := (word >> WATER_SHIFT) & LEVEL_MASK

		if water == detected and detected > land:
			result.flags[index] |= Sc2TileFlags.WATER

		var stored := BinaryData.read_u16_be(result.altitude, index * 2)
		BinaryData.write_u16_be(result.altitude, index * 2, (stored & ~Sc2AltitudeLayout.WATER_MASK) | (detected << WATER_SHIFT))
		result.tiles += 1

	return result


class Repair extends RefCounted:
	var tiles := 0
	var detected_level := 0
	var altitude := PackedByteArray()
	var flags := PackedByteArray()
