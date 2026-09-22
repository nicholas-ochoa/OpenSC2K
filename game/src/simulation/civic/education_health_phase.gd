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


static func run(city: CityState, random: SimRandom) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if random == null:
		return _failed("a compatible random generator is required")

	var misc := city.document.find_chunk("MISC")

	if misc == null or misc.decoded_payload.size() != MISC_SIZE:
		return _failed("MISC is missing or has the wrong size")

	var span := SimulationTimingSpan.new(city.simulation_slice)
	span.mark("prepare data")
	var population := PackedInt64Array()
	var education := PackedInt64Array()
	var life_expectancy := PackedInt64Array()

	for cohort in POPULATION_COHORTS:
		var offset := MISC_POPULATION_TABLE + cohort * POPULATION_STRIDE
		population.append(city.document.misc_u32(offset + RAW_POPULATION_FIELD))
		education.append(city.document.misc_u32(offset + EDUCATION_FIELD))
		life_expectancy.append(city.document.misc_u32(offset + LIFE_EXPECTANCY_FIELD))

	var city_population := city.document.misc_u32(MISC_NORMAL_POPULATION)

	if city_population == 0:
		population.fill(0)
		education.fill(0)
		life_expectancy.fill(0)
		var empty_data: PackedByteArray = misc.decoded_payload.duplicate()
		_write_tables(empty_data, population, education, life_expectancy)

		if not misc.set_decoded_payload(empty_data):
			return _failed("cannot store cleared demographic tables")

		var cleared := Result.new()
		cleared.ok = true
		cleared.empty_city = true
		cleared.timing = span.finish()

		return cleared

	span.mark("service capacities")
	var ordinance_flags := city.document.misc_u32(MISC_ORDINANCES)
	var health_capacity := int(
		((int(_tile_count(city, HOSPITAL_TILE) / 9)
		* _budget_funding(city, Sc2BudgetLayout.HEALTH)
		* 25) / 100)
	)
	var school_capacity := int(
		((int(_tile_count(city, SCHOOL_TILE) / 9)
		* _budget_funding(city, Sc2BudgetLayout.SCHOOL)
		* 15) / 100)
	)
	var college_capacity := int(
		((int(_tile_count(city, COLLEGE_TILE) / 16)
		* _budget_funding(city, Sc2BudgetLayout.COLLEGE)
		* 50) / 100)
	)
	var newborn_life_expectancy := 85

	if ordinance_flags & ORDINANCE_ANTI_DRUG:
		newborn_life_expectancy += 5

	if ordinance_flags & ORDINANCE_CPR_TRAINING:
		newborn_life_expectancy += 5

	if ordinance_flags & ORDINANCE_PUBLIC_SMOKING_BAN:
		newborn_life_expectancy += 5

	if ordinance_flags & ORDINANCE_FREE_CLINICS:
		health_capacity += int(
			(city.document.misc_i32(MISC_BUDGETS) / 400)
		)

	span.mark("mortality and aging")
	var deaths := _apply_mortality(population, education, life_expectancy, random)
	var abandoned_population := city.document.misc_u32(Sc2MiscLayout.ZONE_POPULATIONS + 7 * 4)
	var pollution_penalty := int(
		(city.document.misc_u32(MISC_CITY_POLLUTION) / (city_population + abandoned_population * 10 + 1))
	)
	pollution_penalty = mini(pollution_penalty, 3)
	_apply_aging(
		population,
		education,
		life_expectancy,
		school_capacity,
		college_capacity,
		pollution_penalty,
		ordinance_flags,
		random
	)

	span.mark("births")
	var fertile_population := 0

	for cohort in range(4, 9):
		fertile_population += population[cohort]

	var births := int(fertile_population / 300)
	# The original subtracts pollution here instead of using the modulo remainder.
	var birth_threshold := fertile_population - pollution_penalty * 300

	if random.next_u15() % 300 < birth_threshold:
		births += 1

	if births > 0:
		var protected_births := mini(births, health_capacity)
		life_expectancy[0] += (
			(newborn_life_expectancy - 35) * protected_births + births * 35
		)
		education[0] += int(
			((births * city.document.misc_u32(Sc2MiscLayout.WORKFORCE_EDUCATION)) / 5)
		)
		population[0] += births

	span.mark("migration")
	var table_population := _sum(population)
	var immigrants := 0
	var emigrants := 0

	if table_population < city_population:
		immigrants = city_population - table_population
		_add_population(population, education, life_expectancy, immigrants)
	elif table_population > city_population:
		emigrants = table_population - city_population
		var removal := _remove_population(
			population, education, life_expectancy, emigrants, city_population, random
		)

		if not removal.ok:
			return _failed(removal.error)

	span.mark("workforce")
	var workforce_population := 0
	var workforce_education := 0
	var workforce_life_expectancy := 0

	for cohort in range(4, 11):
		workforce_population += population[cohort]
		workforce_education += education[cohort]
		workforce_life_expectancy += life_expectancy[cohort]

	var workforce_percent := 0
	var workforce_eq := 0
	var workforce_le := 0

	if workforce_population > 0:
		workforce_percent = int((workforce_population * 100) / (city_population + 1))
		workforce_eq = int(workforce_education / workforce_population)
		workforce_le = int(workforce_life_expectancy / workforce_population)

	span.mark("store demographics")
	var changed: PackedByteArray = misc.decoded_payload.duplicate()
	_write_tables(changed, population, education, life_expectancy)
	BinaryData.write_u32_be(changed, Sc2MiscLayout.WORKFORCE_PERCENT, workforce_percent)
	BinaryData.write_u32_be(changed, Sc2MiscLayout.WORKFORCE_LIFE_EXPECTANCY, workforce_le)
	BinaryData.write_u32_be(changed, Sc2MiscLayout.WORKFORCE_EDUCATION, workforce_eq)

	if not misc.set_decoded_payload(changed):
		return _failed("cannot store updated demographic data")

	var result := Result.new()
	result.ok = true
	result.population = _sum(population)
	result.deaths = deaths
	result.births = births
	result.immigrants = immigrants
	result.emigrants = emigrants
	result.health_capacity = health_capacity
	result.school_capacity = school_capacity
	result.college_capacity = college_capacity
	result.newborn_life_expectancy = newborn_life_expectancy
	result.pollution_penalty = pollution_penalty
	result.workforce_population = workforce_population
	result.workforce_percent = workforce_percent
	result.workforce_le = workforce_le
	result.workforce_eq = workforce_eq
	result.timing = span.finish()

	return result


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func _apply_mortality(
	population: PackedInt64Array,
	education: PackedInt64Array,
	life_expectancy: PackedInt64Array,
	random: SimRandom
) -> int:
	var total_deaths := 0

	for cohort in range(1, POPULATION_COHORTS):
		var count := population[cohort]

		if count == 0:
			continue

		var average_life_expectancy := int(life_expectancy[cohort] / count)
		var survival_ratio := int((average_life_expectancy * 100) / (cohort * 5))

		if survival_ratio >= 100:
			continue

		var scaled_deaths := int(((100 - survival_ratio) * count) / 24)
		var deaths := int(scaled_deaths / 100)

		if random.next_u15() % 100 < scaled_deaths - deaths * 100:
			deaths += 1

		deaths = mini(deaths, count)

		if deaths == 0:
			continue

		education[cohort] -= int((education[cohort] * deaths) / count)
		life_expectancy[cohort] -= int((life_expectancy[cohort] * deaths) / count)
		population[cohort] -= deaths
		total_deaths += deaths

	return total_deaths


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


static func _add_population(
	population: PackedInt64Array,
	education: PackedInt64Array,
	life_expectancy: PackedInt64Array,
	amount: int
) -> void:
	var remaining := amount
	var portion := int(remaining / 16) + 1

	while remaining > 0:
		for cohort in range(4, 8):
			var added := mini(portion, remaining)
			life_expectancy[cohort] += (65 - cohort) * added
			education[cohort] += (90 - cohort) * added
			population[cohort] += added
			remaining -= added

		for cohort in range(0, 12):
			if remaining == 0:
				return

			var added := mini(portion, remaining)
			life_expectancy[cohort] += (65 - cohort) * added
			var education_value := 17 + cohort * 35 if cohort < 3 else 90 - cohort
			education[cohort] += education_value * added
			population[cohort] += added
			remaining -= added


static func _remove_population(
	population: PackedInt64Array,
	education: PackedInt64Array,
	life_expectancy: PackedInt64Array,
	amount: int,
	city_population: int,
	random: SimRandom
) -> Result:
	var remaining := amount
	var pass_count := 0

	while remaining > 0:
		var pass_start := remaining

		for cohort in POPULATION_COHORTS:
			if remaining == 0:
				break

			var count := population[cohort]

			if count == 0:
				continue

			var removed := int((count * pass_start) / (remaining + city_population))

			if removed == 0 and random.next_u15() & 3 == 0:
				removed = 1

			removed = mini(removed, mini(count, remaining))

			if removed == 0:
				continue

			life_expectancy[cohort] -= int((life_expectancy[cohort] * removed) / count)
			education[cohort] -= int((education[cohort] * removed) / count)
			population[cohort] -= removed
			remaining -= removed

		pass_count += 1

		if pass_count > 100000:
			return _failed("demographic removal did not converge")

	var result := Result.new()
	result.ok = true
	result.error = ""

	return result


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


static func _write_tables(
	data: PackedByteArray,
	population: PackedInt64Array,
	education: PackedInt64Array,
	life_expectancy: PackedInt64Array
) -> void:
	for cohort in POPULATION_COHORTS:
		var offset := MISC_POPULATION_TABLE + cohort * POPULATION_STRIDE
		BinaryData.write_u32_be(data, offset + RAW_POPULATION_FIELD, population[cohort])
		BinaryData.write_u32_be(data, offset + EDUCATION_FIELD, education[cohort])
		BinaryData.write_u32_be(data, offset + LIFE_EXPECTANCY_FIELD, life_expectancy[cohort])


static func _u32(value: int) -> int:
	return value & 0xffffffff
