class_name GrowthScan
extends RefCounted
## One growth partition. The native library scans it in the original order.


static func run(
	city: CityState,
	random: SimRandom,
	step: int,
	substep: int,
	lfsr_random: SimLfsrRandom = null,
	game_random: GameLcgRandom = null
) -> GrowthResult:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if random == null:
		return _failed("a compatible random generator is required")

	if lfsr_random == null:
		lfsr_random = SimLfsrRandom.new(1)

	if game_random == null:
		game_random = GameLcgRandom.new(1)

	if city.simulation_slice != null:
		city.simulation_slice.checkpoint()

	var response := NativeSimulationBridge.run("growth", city, random, lfsr_random, game_random,
		{"step": step, "substep": substep, "detailed": SimulationTimingSpan.detailed})

	return response.result


static func _failed(message: String) -> GrowthResult:
	var result := GrowthResult.new()
	result.error = message

	return result
