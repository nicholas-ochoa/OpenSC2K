class_name DisasterMapFireFlood
extends DisasterMapConstants


static func run_fire(city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom) -> DisasterMapResult:
	return DisasterMapScanDispatch._native("disaster_map.fire", city, random, lfsr_random)


static func run_flood(
	city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom, map_counter: int
) -> DisasterMapResult:
	return DisasterMapScanDispatch._native("disaster_map.flood", city, random, lfsr_random, {"map_counter": map_counter})
