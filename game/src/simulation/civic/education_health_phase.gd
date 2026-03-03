class_name EducationHealthPhase
extends RefCounted

const MISC_SIZE := 4800
const MISC_CITY_POLLUTION := 0x0034
const MISC_WORKFORCE_PERCENT := 0x0044
const MISC_WORKFORCE_LE := 0x0048
const MISC_WORKFORCE_EQ := 0x004c
const MISC_POPULATION_TABLE := 0x007c
const MISC_TILE_COUNTS := 0x01f0
const MISC_ZONE_POPULATIONS := 0x05f0
const MISC_BUDGETS := 0x077c
const MISC_BUDGET_RECORD_SIZE := 0x006c
const MISC_ORDINANCES := 0x0fa0
const MISC_NORMAL_POPULATION := 0x102c

const POPULATION_STRIDE := 12
const POPULATION_COHORTS := 20
const RAW_POPULATION_FIELD := 0
const EDUCATION_FIELD := 4
const LIFE_EXPECTANCY_FIELD := 8

const HOSPITAL_TILE := 0xd1
const SCHOOL_TILE := 0xd6
const COLLEGE_TILE := 0xd9
const BUDGET_HEALTH := 7
const BUDGET_SCHOOL := 8
const BUDGET_COLLEGE := 9

const ORDINANCE_PUBLIC_SMOKING_BAN := 0x0020
const ORDINANCE_FREE_CLINICS := 0x0040
const ORDINANCE_PRO_READING := 0x0100
const ORDINANCE_ANTI_DRUG := 0x0200
const ORDINANCE_CPR_TRAINING := 0x0400


static func run(city: CityState, random) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible random generator is required"}

	var misc := city.document.find_chunk("MISC")

	if misc == null or misc.decoded_payload.size() != MISC_SIZE:
		return {"ok": false, "error": "MISC is missing or has the wrong size"}

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
			return {"ok": false, "error": "cannot store cleared demographic tables"}

		return {
			"ok": true,
			"population": 0,
			"deaths": 0,
			"births": 0,
			"immigrants": 0,
			"emigrants": 0,
			"empty_city": true,
			"error": "",
		}

	var ordinance_flags := city.document.misc_u32(MISC_ORDINANCES)
	var health_capacity := int(
		IntegerMath.div_trunc(int(IntegerMath.div_trunc(_tile_count(city, HOSPITAL_TILE), 9))
		* _budget_funding(city, BUDGET_HEALTH)
		* 25, 100)
	)
	var school_capacity := int(
		IntegerMath.div_trunc(int(IntegerMath.div_trunc(_tile_count(city, SCHOOL_TILE), 9))
		* _budget_funding(city, BUDGET_SCHOOL)
		* 15, 100)
	)
	var college_capacity := int(
		IntegerMath.div_trunc(int(IntegerMath.div_trunc(_tile_count(city, COLLEGE_TILE), 16))
		* _budget_funding(city, BUDGET_COLLEGE)
		* 50, 100)
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
			IntegerMath.div_trunc(city.document.misc_i32(MISC_BUDGETS), 400)
		)

	var deaths := _apply_mortality(population, education, life_expectancy, random)
	var abandoned_population := city.document.misc_u32(MISC_ZONE_POPULATIONS + 7 * 4)
	var pollution_penalty := int(
		IntegerMath.div_trunc(city.document.misc_u32(MISC_CITY_POLLUTION), (city_population + abandoned_population * 10 + 1))
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

	var fertile_population := 0

	for cohort in range(4, 9):
		fertile_population += population[cohort]

	var births := int(IntegerMath.div_trunc(fertile_population, 300))
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
			IntegerMath.div_trunc(births * city.document.misc_u32(MISC_WORKFORCE_EQ), 5)
		)
		population[0] += births

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
			return removal

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
		workforce_percent = int(IntegerMath.div_trunc(workforce_population * 100, (city_population + 1)))
		workforce_eq = int(IntegerMath.div_trunc(workforce_education, workforce_population))
		workforce_le = int(IntegerMath.div_trunc(workforce_life_expectancy, workforce_population))

	var changed: PackedByteArray = misc.decoded_payload.duplicate()
	_write_tables(changed, population, education, life_expectancy)
	_write_u32(changed, MISC_WORKFORCE_PERCENT, workforce_percent)
	_write_u32(changed, MISC_WORKFORCE_LE, workforce_le)
	_write_u32(changed, MISC_WORKFORCE_EQ, workforce_eq)

	if not misc.set_decoded_payload(changed):
		return {"ok": false, "error": "cannot store updated demographic data"}

	return {
		"ok": true,
		"population": _sum(population),
		"deaths": deaths,
		"births": births,
		"immigrants": immigrants,
		"emigrants": emigrants,
		"health_capacity": health_capacity,
		"school_capacity": school_capacity,
		"college_capacity": college_capacity,
		"newborn_life_expectancy": newborn_life_expectancy,
		"pollution_penalty": pollution_penalty,
		"workforce_population": workforce_population,
		"workforce_percent": workforce_percent,
		"workforce_le": workforce_le,
		"workforce_eq": workforce_eq,
		"empty_city": false,
		"error": "",
	}


static func _apply_mortality(
	population: PackedInt64Array,
	education: PackedInt64Array,
	life_expectancy: PackedInt64Array,
	random
) -> int:
	var total_deaths := 0

	for cohort in range(1, POPULATION_COHORTS):
		var count := population[cohort]

		if count == 0:
			continue

		var average_life_expectancy := int(IntegerMath.div_trunc(life_expectancy[cohort], count))
		var survival_ratio := int(IntegerMath.div_trunc(average_life_expectancy * 100, (cohort * 5)))

		if survival_ratio >= 100:
			continue

		var scaled_deaths := int(IntegerMath.div_trunc((100 - survival_ratio) * count, 24))
		var deaths := int(IntegerMath.div_trunc(scaled_deaths, 100))

		if random.next_u15() % 100 < scaled_deaths - deaths * 100:
			deaths += 1

		deaths = mini(deaths, count)

		if deaths == 0:
			continue

		education[cohort] -= int(IntegerMath.div_trunc(education[cohort] * deaths, count))
		life_expectancy[cohort] -= int(IntegerMath.div_trunc(life_expectancy[cohort] * deaths, count))
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
	random
) -> void:
	for target_cohort in range(POPULATION_COHORTS - 1, 0, -1):
		var source_cohort := target_cohort - 1
		var source_population := population[source_cohort]

		if source_population == 0:
			continue

		var moved_population := int(IntegerMath.div_trunc(source_population, 60))

		if random.next_u15() % 60 < source_population % 60:
			moved_population += 1

		moved_population = mini(moved_population, source_population)

		if moved_population == 0:
			continue

		var moved_education := int(
			IntegerMath.div_trunc(education[source_cohort] * moved_population, source_population)
		)
		education[source_cohort] -= moved_education

		if target_cohort < 3:
			moved_education += mini(moved_population, school_capacity) * 35
		elif target_cohort == 3:
			var educated_population := mini(moved_population, college_capacity)
			moved_education += int(
				IntegerMath.div_trunc(int(IntegerMath.div_trunc(educated_population * moved_education, moved_population)), 2)
			)

		if ordinance_flags & ORDINANCE_PRO_READING == 0:
			# decay cannot turn the transferred education into unsigned debt
			moved_education = maxi(moved_education - moved_population, 0)

		education[target_cohort] = _u32(education[target_cohort] + moved_education)

		var moved_life_expectancy := int(
			IntegerMath.div_trunc(life_expectancy[source_cohort] * moved_population, source_population)
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
	var portion := int(IntegerMath.div_trunc(remaining, 16)) + 1

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
	random
) -> Dictionary:
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

			var removed := int(IntegerMath.div_trunc(count * pass_start, (remaining + city_population)))

			if removed == 0 and random.next_u15() & 3 == 0:
				removed = 1

			removed = mini(removed, mini(count, remaining))

			if removed == 0:
				continue

			life_expectancy[cohort] -= int(IntegerMath.div_trunc(life_expectancy[cohort] * removed, count))
			education[cohort] -= int(IntegerMath.div_trunc(education[cohort] * removed, count))
			population[cohort] -= removed
			remaining -= removed

		pass_count += 1

		if pass_count > 100000:
			return {"ok": false, "error": "demographic removal did not converge"}

	return {"ok": true, "error": ""}


static func _tile_count(city: CityState, tile_id: int) -> int:
	return city.document.misc_i32(MISC_TILE_COUNTS + tile_id * 4)


static func _budget_funding(city: CityState, budget_id: int) -> int:
	return city.document.misc_i32(
		MISC_BUDGETS + budget_id * MISC_BUDGET_RECORD_SIZE + 4
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
		_write_u32(data, offset + RAW_POPULATION_FIELD, population[cohort])
		_write_u32(data, offset + EDUCATION_FIELD, education[cohort])
		_write_u32(data, offset + LIFE_EXPECTANCY_FIELD, life_expectancy[cohort])


static func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	var encoded := _u32(value)
	data[offset] = (encoded >> 24) & 0xff
	data[offset + 1] = (encoded >> 16) & 0xff
	data[offset + 2] = (encoded >> 8) & 0xff
	data[offset + 3] = encoded & 0xff


static func _u32(value: int) -> int:
	return value & 0xffffffff
