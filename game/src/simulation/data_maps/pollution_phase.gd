class_name PollutionPhase
extends RefCounted
## The pollution, land value, crime, and service maps. The native simulation
## library runs them; see native/core/sim/src/sim/data_maps.


@warning_ignore_start("integer_division")


static func run(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return failed("city is invalid")

	return NativeSimulationBridge.run("pollution", city, null, null, null).result


# the legacy and native scans report the same totals
static func totals(
	pollution_total: int,
	land_value_total: int,
	crime_total: int,
	developed_tiles: int,
	city_center: Vector2i,
	timing: SimulationTiming = null
) -> Result:
	var result := Result.new()
	result.ok = true
	result.pollution_total = pollution_total
	result.land_value_total = land_value_total
	result.crime_total = crime_total
	result.developed_tiles = developed_tiles
	result.city_center = city_center
	result.timing = timing if timing != null else SimulationTiming.new()

	return result


static func failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


class Result extends PhaseResult:
	var pollution_total := 0
	var land_value_total := 0
	var crime_total := 0
	var developed_tiles := 0
	var city_center := Vector2i.ZERO
