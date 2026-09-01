extends SceneTree
const TimingResults = preload("res://tests/support/timing_results.gd")


func _initialize() -> void:
	var history := SimulationTimingHistory.new()

	for sample in [[2, 4000], [27, 8000], [27, 2000]]:
		history.consume(TimingResults.tick_fixture({"day_results": [{"ok": true, "day": sample[0],
			"timing": {"work_usec": sample[1], "steps": {"pollution": sample[1]}}}]}))

	assert(history.days[2].count == 2)
	assert(history.days[2].total_usec == 14000 and history.days[2].last_usec == 10000)
	assert(history.days[2].max_usec == 10000)
	assert(history.steps["Day 03 / pollution"].count == 3)
	assert(SimulationTimingHistory.DAY_SUMMARIES.size() == 25)
	var budget := SimulationSliceBudget.new()
	var span := SimulationTimingSpan.new(budget)
	span.mark("test")
	# Simulate equal work-clock and parked-clock offsets without a sleeping test.
	span.started -= 5000
	span.step_started -= 5000
	budget.parked_usec += 5000
	var lower := Time.get_ticks_usec() - budget.parked_usec - span.started
	var measured := span.finish()
	var upper := Time.get_ticks_usec() - budget.parked_usec - span.started
	assert(measured.work_usec >= 0 and measured.steps.test >= 0)
	assert(measured.work_usec >= lower and measured.work_usec <= upper, "Work time excludes parked time without a scheduler deadline")
	var indexed := SimulationTimingSpan.new(budget, PackedStringArray(["scan", "trips", "unused"]))
	indexed.mark_index(0)
	indexed.mark_index(1)
	indexed.mark_index(0)
	indexed.started -= 1000000
	indexed.step_started -= 1000000
	budget.parked_usec += 1000000
	lower = Time.get_ticks_usec() - budget.parked_usec - indexed.started
	var detail := indexed.finish()
	upper = Time.get_ticks_usec() - budget.parked_usec - indexed.started
	assert(detail.steps.size() == 3 and detail.steps.unused == 0)
	assert(detail.steps.scan >= 0 and detail.steps.trips >= 0)
	assert(detail.steps.scan + detail.steps.trips <= detail.work_usec)
	assert(detail.work_usec >= lower and detail.work_usec <= upper, "Indexed timings also exclude worker waits")
	history.clear()
	assert(history.days.is_empty() and history.steps.is_empty())
	_check_phase_timings(history)
	_check_growth_detail_flag()
	print("PASS: simulation timing aggregation, phase detail, displayed days and wait exclusion")
	quit()


## The growth scan reports one per-tile total until the debug window asks for the
## fine steps. Neither mode may change the city, the counters, or the generators.
func _check_growth_detail_flag() -> void:
	const PER_TILE_LABELS := ["tile scan and eligibility", "surface maintenance",
		"facility updates and spawning", "subway maintenance",
		"airport, seaport and military growth", "transport trips",
		"population and abandonment", "construction completion",
		"abandoned building recovery", "density growth"]
	var samples := []

	for detailed in [false, true]:
		SimulationTimingSpan.detailed = detailed
		var city := CityState.from_document(EmptyCityTemplate.create())
		var budget := SimulationSliceBudget.new()
		budget.grant(60000000)
		city.simulation_slice = budget

		for y in range(8, 24):
			city.set_zone_id(12, y, 1)
			city.set_building_id(12, y, 0x70)
			city.set_building_corners(12, y, 0x80)
			city.set_tile_flag(12, y, 0xe0, true)

		var random := SimRandom.new(123)
		var lfsr := SimLfsrRandom.new(456)
		var game := GameLcgRandom.new(789)
		var growth := GrowthScan.run(city, random, 0, 0, lfsr, game)
		assert(growth.ok, growth.error)
		assert(budget.metrics().slices >= 1, "The growth scan still parks the worker")
		var steps: Dictionary = growth.timing.steps
		var fine := 0

		for label: String in PER_TILE_LABELS:
			fine += int(steps[label])

		if detailed:
			assert(steps["all per-tile growth work"] == 0)
			assert(fine > 0, "Detailed timing splits the tile loop into its steps")
		else:
			assert(fine == 0, "The per-tile steps are not measured by default")
			assert(steps["all per-tile growth work"] > 0)

		assert(growth.scanned_tiles == 1024 and growth.rci_tiles == 4)
		var comparable := growth.to_dictionary()
		comparable.erase("timing")
		samples.append([comparable, city.document.serialize().data,
			random.state, lfsr.state, game.state])

	SimulationTimingSpan.detailed = false
	assert(samples[0] == samples[1], "Detailed timing does not change the growth result")


func _check_phase_timings(history: SimulationTimingHistory) -> void:
	for pair in [[300, "budget"], [300, "annual_microsim"], [1, "power"],
		[3, "growth"], [19, "traffic"], [20, "water"], [21, "rci_demand"],
		[21, "rci_aftermath"], [21, "education_health"], [21, "graphs"], [24, "weather_disaster"]]:
		history.clear()
		var city := CityState.from_document(EmptyCityTemplate.create())
		city.set_age_in_days(pair[0] - 1)
		city.document.set_misc_u32(BudgetPhase.MISC_AUTO_BUDGET, 1)
		city.document.set_misc_u32(BudgetPhase.MISC_YEAR_END, 1)
		city.document.set_misc_u32(EducationHealthPhase.MISC_NORMAL_POPULATION, 1000)
		city.document.set_misc_u32(RciDemandPhase.ZONE_POPULATION_OFFSET + 4, 100)
		city.set_building_id(10, 10, 0xcf)
		city.set_building_id(10, 11, 0xdc)
		city.set_building_id(10, 12, 0x70)

		for y in range(10, 13):
			city.set_tile_flag(10, y, 0xe0, true)

		var engine := SimulationEngine.new(city, 123, 456, 789)
		engine.developed_tiles = 3
		engine.power_usage_percent = 50
		engine.water_usage_percent = 50
		var day := engine.advance_day()
		assert(day.ok)
		var phase: PhaseResult = day.phase_results[pair[1]]
		assert(phase.timing.steps.size() >= 3)
		var total := 0

		for value: int in phase.timing.steps.values():
			assert(value >= 0)
			total += value

		assert(total <= phase.timing.work_usec)
		var before: PackedByteArray = city.document.serialize().data
		var states := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
		history.consume(TimingResults.tick_fixture({"day_results": [day]}))
		history.consume(TimingResults.tick_fixture({"day_results": [day]}))

		var parent_key := "Day %02d / %s" % [posmod(pair[0], 25) + 1, pair[1]]
		assert(history.steps[parent_key].count == 2, "Phase totals are not counted again when details arrive")
		assert(history.steps[parent_key].total_usec == day.timing.steps[pair[1]] * 2)

		for label: String in phase.timing.steps:
			var key := "Day %02d / %s / %s" % [posmod(pair[0], 25) + 1, pair[1], label]
			assert(history.steps.has(key), "Phase details retain their own group and displayed day")
			assert(history.steps[key].count == 2, "Repeated inner calls aggregate once per phase execution")
			assert(history.steps[key].total_usec == phase.timing.steps[label] * 2)

		assert(city.document.serialize().data == before, "Timing history never changes save data")
		assert(states == [engine.random.state, engine.lfsr_random.state, engine.game_random.state])

	# Preserve the existing data-map group while accepting other timed phases.
	var map_phase := PhaseResult.new()
	map_phase.timing = {"steps": {"smoothing": 300}}
	history.consume(TimingResults.tick_fixture({"day_results": [{"ok": true, "day": 2,
		"timing": {"work_usec": 500, "steps": {"pollution_terrain_land_value": 450}},
		"phase_results": {"pollution_terrain_land_value":
			map_phase}}]}))
	assert(history.steps["Day 03 / data maps / smoothing"].last_usec == 300)
	assert(history.steps["Day 03 / data maps"].last_usec == 450)
	# A resumed proposal has a phase total but no separate scheduler step.
	var proposal_city := CityState.from_document(EmptyCityTemplate.create())
	var proposal := MilitaryProposalPhase.resolve(proposal_city, true, GameLcgRandom.new(789))
	assert(proposal.ok and proposal.timing.steps.has("naval site search"))
	history.consume(TimingResults.tick_fixture({"day_results": [{"ok": true, "day": 22,
		"timing": {"work_usec": proposal.timing.work_usec, "steps": {}},
		"phase_results": {"military_proposal": proposal}}]}))
	assert(history.steps["Day 23 / military_proposal"].count == 1)
	assert(history.steps["Day 23 / military_proposal"].last_usec == proposal.timing.work_usec)
	history.consume(TimingResults.tick_fixture({"day_results": [{"ok": false, "day": 1,
		"timing": {"work_usec": 999, "steps": {"rejected": 999}}}]}))
	assert(not history.steps.has("Day 02 / rejected"))
