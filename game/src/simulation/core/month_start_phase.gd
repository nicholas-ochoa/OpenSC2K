class_name MonthStartPhase
extends RefCounted


@warning_ignore_start("integer_division")

const MISC_SIZE := Sc2MiscLayout.SIZE
const ZONE_POPULATION_COUNT := 8
# the original opens the subscribed newspaper after the April and August budget
const SUBSCRIPTION_MONTHS := [3, 7]


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func run(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("month_start", city, null, null, null).result


class Result extends PhaseResult:
	var cleared_population_fields := 0
