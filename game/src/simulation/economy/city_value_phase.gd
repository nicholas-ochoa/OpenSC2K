class_name CityValuePhase
extends RefCounted

@warning_ignore_start("integer_division")

const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_CITY_VALUE := Sc2MiscLayout.CITY_VALUE
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_SUBWAY_COUNT := Sc2MiscLayout.SUBWAY_COUNT


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func calculate(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("city_value.calculate", city, null, null, null).result


static func run(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("city_value.run", city, null, null, null).result


class Result extends PhaseResult:
	var city_value := 0
