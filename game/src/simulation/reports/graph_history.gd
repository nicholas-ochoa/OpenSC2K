class_name GraphHistory
extends RefCounted


@warning_ignore_start("integer_division")

const SERIES_COUNT := Sc2GraphLayout.SERIES_COUNT
const VALUES_PER_SERIES := Sc2GraphLayout.VALUES_PER_SERIES
const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_CITY_LAND_VALUE := Sc2MiscLayout.CITY_LAND_VALUE
const MISC_CITY_CRIME := Sc2MiscLayout.CITY_CRIME
const MISC_CITY_POLLUTION := Sc2MiscLayout.CITY_POLLUTION
const MISC_NATIONAL_POPULATION := Sc2MiscLayout.NATIONAL_POPULATION
const MISC_NATIONAL_FEDERAL_RATE := Sc2MiscLayout.NATIONAL_FEDERAL_RATE
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_BUDGETS := Sc2MiscLayout.BUDGETS
const MISC_ARCOLOGY_POPULATION := Sc2MiscLayout.ARCOLOGY_POPULATION
const BUDGET_ROAD := Sc2BudgetLayout.ROAD


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func run(
	city: CityState, developed_tiles: int, power_usage_percent: int, water_usage_percent: int
) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("graphs", city, null, null, null, {"developed_tiles": developed_tiles,
		"power_usage_percent": power_usage_percent, "water_usage_percent": water_usage_percent}).result


# shift the histories and store the sixteen current values
static func advance(city: CityState, current_values: PackedInt64Array) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("graphs.advance", city, null, null, null, {"values": current_values}).result


# the sixteen current graph values and the unemployment rate
static func calculate_current_values(
	city: CityState, developed_tiles: int, power_usage_percent: int, water_usage_percent: int
) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("graphs.current_values", city, null, null, null, {"developed_tiles": developed_tiles,
		"power_usage_percent": power_usage_percent, "water_usage_percent": water_usage_percent}).result


class Result extends PhaseResult:
	var month := 0
	var elapsed_years := 0
	var values := PackedInt64Array()
	var unemployment := 0
