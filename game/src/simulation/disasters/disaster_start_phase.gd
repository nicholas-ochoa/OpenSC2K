class_name DisasterStartPhase
extends DisasterStartConstants


# `scenario` is true while a scenario runs. a monster then gets no goal
static func start(
	city: CityState, disaster_type: int, point: Vector2i, random: SimRandom, lfsr_random: SimLfsrRandom = null,
	scenario := false
) -> DisasterStartResult:
	if city == null or not city.is_valid():
		return DisasterStartResult.failed("city is invalid")

	return NativeSimulationBridge.run("disaster_start", city, random, lfsr_random, null, {
		"disaster_type": disaster_type,
		"point": point,
		"has_random": random != null,
		"has_lfsr": lfsr_random != null,
		"scenario": scenario,
	}).result
