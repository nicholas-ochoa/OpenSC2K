class_name PowerPhase
extends RefCounted

@warning_ignore_start("integer_division")

const MAP_SIZE := CityState.MAP_SIZE
const FLAG_POWERED := Sc2TileFlags.POWERED
const FLAG_POWERABLE := Sc2TileFlags.POWERABLE


static func run(city: CityState, random: SimRandom) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if random == null:
		return _failed("random state is required")

	return NativeSimulationBridge.run("power", city, random, null, null).result


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


class Result extends PhaseResult:
	var generation := 0
	var consumers := 0
	var supplied_consumers := 0
	var usage_percent := 0
