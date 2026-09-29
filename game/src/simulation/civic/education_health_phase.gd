class_name EducationHealthPhase
extends RefCounted

@warning_ignore_start("integer_division")

const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_CITY_POLLUTION := Sc2MiscLayout.CITY_POLLUTION
const MISC_POPULATION_TABLE := Sc2MiscLayout.POPULATION_TABLE
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_BUDGETS := Sc2MiscLayout.BUDGETS
const MISC_ORDINANCES := Sc2MiscLayout.ORDINANCES
const MISC_NORMAL_POPULATION := Sc2MiscLayout.NORMAL_POPULATION


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func _budget_funding(city: CityState, budget_id: int) -> int:
	return city.document.misc_i32(
		MISC_BUDGETS + budget_id * Sc2BudgetLayout.RECORD_SIZE + 4
	)


static func run(city: CityState, random: SimRandom) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if random == null:
		return _failed("a compatible random generator is required")

	return NativeSimulationBridge.run("education_health", city, random, null, null).result


class Result extends PhaseResult:
	var population := 0
	var deaths := 0
	var births := 0
	var immigrants := 0
	var emigrants := 0
	var health_capacity := 0
	var school_capacity := 0
	var college_capacity := 0
	var newborn_life_expectancy := 0
	var pollution_penalty := 0
	var workforce_population := 0
	var workforce_percent := 0
	var workforce_le := 0
	var workforce_eq := 0
	var empty_city := false
