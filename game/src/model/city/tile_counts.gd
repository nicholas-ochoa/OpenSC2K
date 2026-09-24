class_name CityTileCounts
extends RefCounted
# The MISC tile counts hold the number of tiles of each building ID outside
# military zones. Military bases have separate counts.
# SC2 cities keep the original running counts. Some original changes skip the
# counts, so these counts drift. Game rules read the saved values, so drift is
# kept for compatibility. Extended cities count the map again on load and at
# the start of each month, so their counts stay exact.


# true when the city keeps exact counts
static func exact(city: CityState) -> bool:
	return city != null and city.document != null and city.document.is_extended()


# tiles of each building ID outside military zones
static func count(city: CityState) -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(BuildingTileIds.COUNT)
	var buildings := city.buildings
	var zones := city.zones

	for index in buildings.size():
		if (zones[index] & Sc2ZoneLayout.TYPE_MASK) != Sc2ZoneLayout.MILITARY:
			counts[buildings[index]] += 1

	return counts


# write the map counts to MISC. only changed values are written.
# returns the number of changed counts, or -1 when MISC is missing
static func recount(city: CityState) -> int:
	var chunk := city.document.find_chunk("MISC")

	if chunk == null or chunk.decoded_payload.size() < Sc2MiscLayout.TILE_COUNTS + BuildingTileIds.COUNT * 4:
		return -1

	var counts := count(city)
	var changed := 0

	for tile_id in BuildingTileIds.COUNT:
		var offset := Sc2MiscLayout.TILE_COUNTS + tile_id * 4

		if BinaryData.read_u32_be(chunk.decoded_payload, offset) != counts[tile_id]:
			city.document.set_misc_u32(offset, counts[tile_id])
			changed += 1

	return changed
