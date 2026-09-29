class_name SimNationPhase
extends RefCounted

const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_NATIONAL_POPULATION := Sc2MiscLayout.NATIONAL_POPULATION
const MISC_NATIONAL_FEDERAL_RATE := Sc2MiscLayout.NATIONAL_FEDERAL_RATE
const MISC_NATIONAL_ECONOMY_TREND := Sc2MiscLayout.NATIONAL_ECONOMY_TREND


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func economy_level(score: int) -> int:
	if score < 45:
		return 0

	if score < 60:
		return 1

	if score < 75:
		return 2

	return 3


static func run(city: CityState, random: SimRandom) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if random == null:
		return _failed("a compatible process random generator is required")

	return NativeSimulationBridge.run("simnation", city, random, null, null).result


class Result extends PhaseResult:
	var national_population := 0
	var national_value := 0
	var federal_rate := 0
	var economy_trend := 0
	var neighbor_populations := PackedInt64Array()
	var neighbor_values := PackedInt64Array()
	var shocked_neighbor := -1
