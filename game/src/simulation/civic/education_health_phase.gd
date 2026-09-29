class_name EducationHealthPhase
extends RefCounted

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_CITY_POLLUTION := Sc2MiscLayout.CITY_POLLUTION
const MISC_POPULATION_TABLE := Sc2MiscLayout.POPULATION_TABLE
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_BUDGETS := Sc2MiscLayout.BUDGETS
const MISC_ORDINANCES := Sc2MiscLayout.ORDINANCES
const MISC_NORMAL_POPULATION := Sc2MiscLayout.NORMAL_POPULATION
const POPULATION_STRIDE := 12
const POPULATION_COHORTS := 20
const RAW_POPULATION_FIELD := 0
const EDUCATION_FIELD := 4
const LIFE_EXPECTANCY_FIELD := 8
const HOSPITAL_TILE := Tiles.HOSPITAL
const SCHOOL_TILE := Tiles.SCHOOL
const COLLEGE_TILE := Tiles.COLLEGE
const ORDINANCE_PUBLIC_SMOKING_BAN := OrdinanceIds.PUBLIC_SMOKING_BAN_MASK
const ORDINANCE_FREE_CLINICS := OrdinanceIds.FREE_CLINICS_MASK
const ORDINANCE_PRO_READING := OrdinanceIds.PRO_READING_MASK
const ORDINANCE_ANTI_DRUG := OrdinanceIds.ANTI_DRUG_MASK
const ORDINANCE_CPR_TRAINING := OrdinanceIds.CPR_TRAINING_MASK


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func _apply_aging(
	population: PackedInt64Array,
	education: PackedInt64Array,
	life_expectancy: PackedInt64Array,
	school_capacity: int,
	college_capacity: int,
	pollution_penalty: int,
	ordinance_flags: int,
	random: SimRandom
) -> void:
	for target_cohort in range(POPULATION_COHORTS - 1, 0, -1):
		var source_cohort := target_cohort - 1
		var source_population := population[source_cohort]

		if source_population == 0:
			continue

		var moved_population := int(source_population / 60)

		if random.next_u15() % 60 < source_population % 60:
			moved_population += 1

		moved_population = mini(moved_population, source_population)

		if moved_population == 0:
			continue

		var moved_education := int(
			((education[source_cohort] * moved_population) / source_population)
		)
		education[source_cohort] -= moved_education

		if target_cohort < 3:
			moved_education += mini(moved_population, school_capacity) * 35
		elif target_cohort == 3:
			var educated_population := mini(moved_population, college_capacity)
			moved_education += int(
				(int((educated_population * moved_education) / moved_population) / 2)
			)

		if ordinance_flags & ORDINANCE_PRO_READING == 0:
			# decay cannot turn the transferred education into unsigned debt
			moved_education = maxi(moved_education - moved_population, 0)

		education[target_cohort] = _u32(education[target_cohort] + moved_education)

		var moved_life_expectancy := int(
			((life_expectancy[source_cohort] * moved_population) / source_population)
		)
		life_expectancy[source_cohort] -= moved_life_expectancy
		life_expectancy[target_cohort] = _u32(
			life_expectancy[target_cohort] + moved_life_expectancy - pollution_penalty
		)
		population[source_cohort] -= moved_population
		population[target_cohort] += moved_population


static func _tile_count(city: CityState, tile_id: int) -> int:
	return city.document.misc_i32(MISC_TILE_COUNTS + tile_id * 4)


static func _budget_funding(city: CityState, budget_id: int) -> int:
	return city.document.misc_i32(
		MISC_BUDGETS + budget_id * Sc2BudgetLayout.RECORD_SIZE + 4
	)


static func _sum(values: PackedInt64Array) -> int:
	var total := 0

	for value in values:
		total += value

	return total


static func _u32(value: int) -> int:
	return value & 0xffffffff


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
