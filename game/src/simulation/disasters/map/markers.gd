class_name DisasterMapMarkers
extends DisasterMapConstants

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")


static func run_toxic(city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom) -> DisasterMapResult:
	return DisasterMapScanDispatch._native("disaster_map.toxic", city, random, lfsr_random)


static func run_riot(city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom) -> DisasterMapResult:
	return DisasterMapScanDispatch._native("disaster_map.riot", city, random, lfsr_random)
