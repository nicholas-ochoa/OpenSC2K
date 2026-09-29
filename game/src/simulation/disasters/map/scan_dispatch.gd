class_name DisasterMapScanDispatch
extends DisasterMapConstants


static func run_all(
	city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom, map_counter: int, hurricane_counter := 0
) -> DisasterMapResult:
	return _native("disaster_map.run_all", city, random, lfsr_random, {
		"map_counter": map_counter, "hurricane_counter": hurricane_counter,
	})


static func run_dispatch(city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom) -> DisasterMapResult:
	return _native("disaster_map.dispatch", city, random, lfsr_random)


static func _native(
	operation: String, city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom, args := {}
) -> DisasterMapResult:
	if city == null or not city.is_valid():
		return DisasterMapResult.failure("city is invalid")

	args["has_random"] = random != null
	args["has_lfsr"] = lfsr_random != null

	return NativeSimulationBridge.run(operation, city, random, lfsr_random, null, args).result
