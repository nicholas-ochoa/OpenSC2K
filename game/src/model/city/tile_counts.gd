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
# the native library reads every tile; a 4096 map has 16.7 million
static func count(city: CityState) -> PackedInt32Array:
	return NativeCityTools.building_counts(city.buildings, city.zones)


static func recount(city: CityState) -> int:
	return NativeSimulationBridge.run("tile_recount", city, null, null, null).result
