extends "res://tests/support/core_test_suite.gd"

## Simulation: services checks.

@warning_ignore_start("integer_division")

const Random = preload("res://src/simulation/random/sim_random.gd")
const SimNation = preload("res://src/simulation/civic/simnation_phase.gd")
const Industries = preload("res://src/simulation/growth/industry_phase.gd")
const EducationHealth = preload("res://src/simulation/civic/education_health_phase.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const SequenceLfsrRandom = TestRandoms.SequenceLfsrRandom
const SequenceRandom = TestRandoms.SequenceRandom


func test_simnation(reference_root: String) -> void:
	_check(
		SimNation.economy_level(44) == 0
		and SimNation.economy_level(45) == 1
		and SimNation.economy_level(60) == 2
		and SimNation.economy_level(75) == 3,
		"SimNation uses the recovered national-value level boundaries",
	)

	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x0050, 1_200_000],
		[0x0054, 3_000_000],
		[0x0058, 4],
		[0x005c, 2],
		[0x06dc, 1_200_000],
		[0x06e0, 600_000],
		[0x06ec, 0],
		[0x06f0, 0],
		[0x06fc, 6_000_000],
		[0x0700, 4_000_000],
		[0x070c, 1],
		[0x0710, 0],
	]:
		_check(document.set_misc_u32(setting[0], setting[1]), "SimNation fixture sets MISC 0x%x" % setting[0])

	var random := SequenceRandom.new([1, 0, 0, 2, 4, 0, 1, 0, 1])
	var result := SimNation.run(CityModel.from_document(document), random)
	_check(result.ok, "SimNation phase completes: %s" % result.error)

	if result.ok:
		_check(
			result.national_population == 1_202_000
			and result.national_value == 3_000_000,
			"SimNation moves national population and value about their centers",
		)
		_check(
			result.neighbor_populations == PackedInt64Array([1_202_000, 0, 5_980_000, 2]),
			"SimNation updates each non-ocean neighbor population in compass order",
		)
		_check(
			result.neighbor_values == PackedInt64Array([597_500, 0, 4_006_666, 0]),
			"SimNation updates neighbor values with federal and local economy factors",
		)
		_check(result.news_items.is_empty(), "A quiet SimNation month emits no report")
		_check(random.position == 9, "The quiet neighbor update consumes nine process-random values")
		_check(
			document.misc_u32(0x0050) == 1_202_000
			and document.misc_u32(0x06e0) == 597_500
			and document.misc_u32(0x0700) == 4_006_666,
			"SimNation stores the national and neighbor fields in MISC",
		)

	var news_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x0050, 1_000_000],
		[0x0054, 800_000],
		[0x0058, 3],
		[0x005c, 0],
		[0x06dc, 0], [0x06ec, 0], [0x06fc, 0], [0x070c, 0],
	]:
		_check(news_document.set_misc_u32(setting[0], setting[1]), "SimNation news fixture sets MISC 0x%x" % setting[0])

	var news_random := SequenceRandom.new([0, 0, 0, 99, 0, 1])
	var news_result := SimNation.run(CityModel.from_document(news_document), news_random)
	_check(news_result.ok, "Controlled SimNation news phase completes: %s" % news_result.error)

	if news_result.ok:
		_check(
			NewsEvent.same_arrays(news_result.news_items, [
				NewsEvent.new(9, 4),
				NewsEvent.new(10, 3),
				NewsEvent.new(7, 3),
			]),
			"SimNation emits federal-rate and national-economy reports in native order",
		)
		_check(
			news_result.national_value == 804_000
			and news_result.federal_rate == 3
			and news_result.economy_trend == 3,
			"SimNation applies the controlled national-news update",
		)
		_check(news_random.position == 6, "The national-news path consumes six process-random values")

	var shock_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x0050, 1_000_000], [0x0054, 1_000_000], [0x0058, 3], [0x005c, 0],
		[0x06dc, 1200], [0x06e0, 1200],
		[0x06ec, 0], [0x06fc, 0], [0x070c, 0],
	]:
		_check(shock_document.set_misc_u32(setting[0], setting[1]), "Regional shock fixture sets MISC 0x%x" % setting[0])

	var shock_random := SequenceRandom.new([1, 0, 0, 0, 0, 0])
	var shock_result := SimNation.run(CityModel.from_document(shock_document), shock_random)
	_check(shock_result.ok, "Regional shock phase completes: %s" % shock_result.error)

	if shock_result.ok:
		_check(
			shock_result.shocked_neighbor == 0
			and shock_result.neighbor_populations[0] == 900
			and shock_result.neighbor_values[0] == 600,
			"The one-in-64 regional shock keeps 75 percent population and 50 percent value",
		)
		_check(shock_random.position == 6, "The regional-shock path consumes six process-random values")


func test_industries(reference_root: String) -> void:
	_check(
		Industries.world_demands(1900, 25)
		== PackedInt32Array([25, 20, 25, 10, 17, 22, 10, 17, 12, 5, 15]),
		"Industry world demand interpolates between the executable's 50-year rows",
	)
	_check(
		Industries.world_demands(2100, 0)
		== PackedInt32Array([10, 20, 10, 10, 20, 20, 50, 30, 20, 80, 50]),
		"Industry world demand retains the final executable row after 2100",
	)

	var stable_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x000c, 1900], [0x0010, 0], [0x004c, 80], [0x0fa0, 0],
		[0x0604, 40], [0x0608, 60],
	]:
		_check(stable_document.set_misc_u32(setting[0], setting[1]), "Industry fixture sets MISC 0x%x" % setting[0])

	var stable_ratios := [30, 10, 10, 0, 0, 10, 0, 0, 0, 0, 40]
	var initial_demands := [20, 20, 10, 10, 15, 5, 0, 15, 8, 0, 10]

	for industry in 11:
		var base := 0x016c + industry * 0x0c
		_check(stable_document.set_misc_u32(base, initial_demands[industry]), "Industry fixture sets demand %d" % industry)
		_check(stable_document.set_misc_u32(base + 4, 0), "Industry fixture clears tax %d" % industry)
		_check(stable_document.set_misc_u32(base + 8, stable_ratios[industry]), "Industry fixture sets ratio %d" % industry)

	var stable_lfsr_values: Array[int] = []
	stable_lfsr_values.resize(44)
	stable_lfsr_values.fill(64)
	var stable_random := SequenceRandom.new([])
	var stable_lfsr := SequenceLfsrRandom.new(stable_lfsr_values)
	var stable_result := Industries.run(
		CityModel.from_document(stable_document), stable_random, stable_lfsr, 0
	)
	_check(stable_result.ok, "Stable industry phase completes: %s" % stable_result.error)

	if stable_result.ok:
		_check(
			stable_result.demands == PackedInt32Array(initial_demands),
			"Four midpoint LFSR values retain each matching world demand",
		)
		_check(
			stable_result.ratios == PackedInt64Array(stable_ratios)
			and stable_result.ratio_total_after == 100,
			"Matching industry population leaves all eleven ratios unchanged",
		)
		_check(
			stable_result.pollution_share == 59
			and stable_result.pollution_bonus == 1
			and stable_result.maximum_share == 39
			and stable_result.mix_bonus == 3,
			"Industry ratios produce both recovered industrial-mix bonuses",
		)
		_check(stable_lfsr.position == 44, "Industry demand consumes four LFSR values per industry")
		_check(stable_random.position == 0, "Balanced industry ratios consume no process-random values")
		_check(
			stable_document.misc_u32(0x1030) == 3
			and stable_document.misc_u32(0x1034) == 1,
			"Industry phase stores both industrial-mix bonuses",
		)

	var growth_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x000c, 1900], [0x0010, 0], [0x004c, 131], [0x0fa0, 0x00080000],
		[0x0604, 44], [0x0608, 44],
	]:
		_check(growth_document.set_misc_u32(setting[0], setting[1]), "Industry growth fixture sets MISC 0x%x" % setting[0])

	for industry in 11:
		var base := 0x016c + industry * 0x0c
		_check(growth_document.set_misc_u32(base, 100), "Industry growth fixture sets demand %d" % industry)
		_check(growth_document.set_misc_u32(base + 4, 70), "Industry growth fixture sets tax %d" % industry)
		_check(growth_document.set_misc_u32(base + 8, 0), "Industry growth fixture clears ratio %d" % industry)

	var growth_lfsr := SequenceLfsrRandom.new(stable_lfsr_values)
	var growth_random := SequenceRandom.new([1, 1, 1, 1, 1, 1, 1, 1, 1])
	var growth_result := Industries.run(
		CityModel.from_document(growth_document), growth_random, growth_lfsr, 1
	)
	_check(growth_result.ok, "Growing industry phase completes: %s" % growth_result.error)

	if growth_result.ok:
		_check(
			growth_result.demands == PackedInt32Array([80, 80, 77, 77, 78, 76, 75, 78, 77, 75, 77]),
			"Industry demand smooths the old and random world values",
		)
		_check(
			growth_result.adjusted_demands
			== PackedInt32Array([2, 2, 0, 7, 15, 0, 20, 8, 7, 20, 7]),
			"Clean Industry, population growth, workforce EQ, and taxes adjust exact sectors",
		)
		_check(
			growth_result.ratios
			== PackedInt64Array([2, 2, 0, 7, 15, 0, 20, 8, 7, 20, 7]),
			"Positive industry demand distributes the full population shortage",
		)
		_check(growth_random.position == 9, "Nine positive industries consume nine rounding values")
		_check(growth_lfsr.position == 44, "Growing industry demand preserves the LFSR call count")

	var excess_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x000c, 1900], [0x0010, 0], [0x004c, 80], [0x0fa0, 0],
		[0x0604, 50], [0x0608, 50],
	]:
		_check(excess_document.set_misc_u32(setting[0], setting[1]), "Industry excess fixture sets MISC 0x%x" % setting[0])

	for industry in 11:
		var base := 0x016c + industry * 0x0c
		_check(excess_document.set_misc_u32(base, initial_demands[industry]), "Industry excess fixture sets demand %d" % industry)
		_check(excess_document.set_misc_u32(base + 4, 0), "Industry excess fixture clears tax %d" % industry)
		_check(excess_document.set_misc_u32(base + 8, 100), "Industry excess fixture sets ratio %d" % industry)

	var excess_lfsr := SequenceLfsrRandom.new(stable_lfsr_values)
	var excess_random := SequenceRandom.new([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	var excess_result := Industries.run(
		CityModel.from_document(excess_document), excess_random, excess_lfsr, 0
	)
	_check(excess_result.ok, "Excess industry phase completes: %s" % excess_result.error)

	if excess_result.ok:
		_check(
			excess_result.ratios == PackedInt64Array([9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9])
			and excess_result.ratio_total_after == 99,
			"Excess industry ratios use proportional removal and random rounding",
		)
		_check(excess_random.position == 11, "Excess removal consumes one rounding value per industry")


func test_education_health(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for cohort in 20:
		for field in [0, 4, 8]:
			_check(
				document.set_misc_u32(0x007c + cohort * 12 + field, 0),
				"Demographic fixture clears cohort %d field %d" % [cohort, field],
			)

	for setting in [
		[0x102c, 600],
		[0x0034, 0],
		[0x0044, 0],
		[0x0048, 0],
		[0x004c, 60],
		[0x060c, 0],
		[0x077c, 400],
		[0x0fa0, 0x0760],
		[0x01f0 + 0xd1 * 4, 9],
		[0x01f0 + 0xd6 * 4, 9],
		[0x01f0 + 0xd9 * 4, 16],
		[0x077c + 7 * 0x006c + 4, 100],
		[0x077c + 8 * 0x006c + 4, 100],
		[0x077c + 9 * 0x006c + 4, 100],
		[0x007c + 2 * 12, 300],
		[0x0080 + 2 * 12, 18000],
		[0x0084 + 2 * 12, 24000],
		[0x007c + 10 * 12, 300],
		[0x0080 + 10 * 12, 18000],
		[0x0084 + 10 * 12, 24000],
	]:
		_check(
			document.set_misc_u32(setting[0], setting[1]),
			"Demographic fixture sets MISC 0x%x" % setting[0],
		)

	var city := CityModel.from_document(document)
	var result := EducationHealth.run(city, Random.new(1))
	_check(result.ok, "Education and health phase completes: %s" % result.error)

	if not result.ok:
		return

	_check(result.population == 600, "Demographic phase preserves the controlled population")
	_check(result.deaths == 0 and result.births == 0, "Healthy fixture has no deaths or births")
	_check(result.immigrants == 0 and result.emigrants == 0, "Balanced fixture needs no migration")
	_check(result.health_capacity == 26, "Hospitals and free clinics calculate health capacity")
	_check(result.school_capacity == 15, "Funded schools calculate education capacity")
	_check(result.college_capacity == 50, "Funded colleges calculate education capacity")
	_check(result.newborn_life_expectancy == 100, "Health ordinances raise newborn life expectancy")
	_check(document.misc_u32(0x007c + 2 * 12) == 295, "One sixtieth of a cohort ages each month")
	_check(document.misc_u32(0x007c + 3 * 12) == 5, "Aged residents enter the next cohort")
	_check(document.misc_u32(0x0080 + 2 * 12) == 17700, "Aging transfers source education points")
	_check(document.misc_u32(0x0080 + 3 * 12) == 450, "College capacity increases transferred education")
	_check(document.misc_u32(0x0084 + 2 * 12) == 23600, "Aging transfers source life points")
	_check(document.misc_u32(0x0084 + 3 * 12) == 400, "The next cohort receives life points")
	_check(result.workforce_population == 295, "Workforce uses cohorts four through ten")
	_check(document.misc_u32(0x0044) == 49, "Demographic phase stores workforce percentage")
	_check(document.misc_u32(0x0048) == 80, "Demographic phase stores workforce life expectancy")
	_check(document.misc_u32(0x004c) == 60, "Demographic phase stores workforce education quotient")

	var empty_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(empty_document.set_misc_u32(0x102c, 0), "Empty demographic fixture clears city population")
	_check(empty_document.set_misc_u32(0x007c, 99), "Empty demographic fixture installs a stale cohort")
	var empty_result := EducationHealth.run(CityModel.from_document(empty_document), Random.new(1))
	_check(empty_result.ok and empty_result.empty_city, "Zero population takes the empty-city path")
	_check(empty_document.misc_u32(0x007c) == 0, "Empty-city path clears demographic tables")

	var mortality_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for cohort in 20:
		for field in [0, 4, 8]:
			_check(
				mortality_document.set_misc_u32(0x007c + cohort * 12 + field, 0),
				"Mortality fixture clears cohort %d field %d" % [cohort, field],
			)

	_check(mortality_document.set_misc_u32(0x102c, 230), "Mortality fixture sets city population")
	_check(mortality_document.set_misc_u32(0x007c + 19 * 12, 240), "Mortality fixture sets oldest population")
	_check(mortality_document.set_misc_u32(0x0080 + 19 * 12, 24000), "Mortality fixture sets education points")
	var mortality_result := EducationHealth.run(
		CityModel.from_document(mortality_document), Random.new(1)
	)
	_check(mortality_result.ok, "Mortality fixture completes: %s" % mortality_result.error)

	if mortality_result.ok:
		_check(mortality_result.deaths == 10, "Mortality uses the recovered two-stage divisor")
		_check(mortality_document.misc_u32(0x007c + 19 * 12) == 230, "Mortality removes residents")
		_check(mortality_document.misc_u32(0x0080 + 19 * 12) == 23000, "Mortality removes education in proportion")

	var migration_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for cohort in 20:
		for field in [0, 4, 8]:
			_check(
				migration_document.set_misc_u32(0x007c + cohort * 12 + field, 0),
				"Migration fixture clears cohort %d field %d" % [cohort, field],
			)

	_check(migration_document.set_misc_u32(0x102c, 16), "Migration fixture sets city population")
	var migration_result := EducationHealth.run(
		CityModel.from_document(migration_document), Random.new(1)
	)
	_check(migration_result.ok, "Migration fixture completes: %s" % migration_result.error)

	if migration_result.ok:
		_check(migration_result.immigrants == 16, "Demographic phase adds missing residents")

		for cohort in range(0, 8):
			_check(
				migration_document.misc_u32(0x007c + cohort * 12) == 2,
				"Migration uses recovered cohort order at cohort %d" % cohort,
			)

		_check(migration_document.misc_u32(0x0044) == 47, "Migration updates workforce percentage")
		_check(migration_document.misc_u32(0x0048) == 59, "Migration installs default workforce life points")
		_check(migration_document.misc_u32(0x004c) == 84, "Migration installs default workforce education points")
