class_name DisasterMapMarkers
extends DisasterMapConstants


static func run_toxic(city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom) -> DisasterMapResult:
	return DisasterMapScanDispatch._native("disaster_map.toxic", city, random, lfsr_random)


static func run_riot(city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom) -> DisasterMapResult:
	return DisasterMapScanDispatch._native("disaster_map.riot", city, random, lfsr_random)
