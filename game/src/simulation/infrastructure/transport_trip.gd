class_name TransportTrip
extends TransportTripConstants


static func run(
	city: CityState,
	origin: Vector2i,
	zone: int,
	traffic_weight: int,
	random: SimRandom,
	maximum_cost := 100
) -> TransportTripResult:
	if city == null or not city.is_valid():
		return TransportTripResult.failure("city is invalid")

	if random == null:
		return TransportTripResult.failure("a compatible random generator is required")

	return NativeSimulationBridge.run("trip", city, random, null, null, {
		"origin": origin, "zone": zone, "traffic_weight": traffic_weight, "maximum_cost": maximum_cost,
	}).result
