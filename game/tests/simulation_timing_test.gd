extends SceneTree


func _initialize() -> void:
	var history := SimulationTimingHistory.new()

	for sample in [[2, 4000], [27, 8000], [27, 2000]]:
		history.consume({"day_results": [{"ok": true, "day": sample[0],
			"timing": {"work_usec": sample[1], "steps": {"pollution": sample[1]}}}]})

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
	print("PASS: simulation timing aggregation, phase detail, displayed days and wait exclusion")
	quit()


func _check_phase_timings(history: SimulationTimingHistory) -> void:
	for pair in [[1, "power"], [3, "growth"], [19, "traffic"], [20, "water"]]:
		var city := CityState.from_document(EmptyCityTemplate.create())
		city.set_age_in_days(pair[0] - 1)
		city.set_building_id(10, 10, 0xcf)
		city.set_building_id(10, 11, 0xdc)
		city.set_building_id(10, 12, 0x70)

		for y in range(10, 13):
			city.set_tile_flag(10, y, 0xe0, true)

		var engine := SimulationEngine.new(city, 123, 456, 789)
		var day := engine.advance_day()
		assert(day.ok)
		var phase: Dictionary = day.phase_results[pair[1]]
		assert(phase.timing.steps.size() >= 4)
		var total := 0

		for value: int in phase.timing.steps.values():
			assert(value >= 0)
			total += value

		assert(total <= phase.timing.work_usec)
		var before: PackedByteArray = city.document.serialize().data
		var states := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
		history.consume({"day_results": [day]})
		history.consume({"day_results": [day]})

		for label: String in phase.timing.steps:
			var key := "Day %02d / %s / %s" % [pair[0] + 1, pair[1], label]
			assert(history.steps.has(key), "Phase details retain their own group and displayed day")
			assert(history.steps[key].count == 2, "Repeated inner calls aggregate once per phase execution")
			assert(history.steps[key].total_usec == phase.timing.steps[label] * 2)

		assert(city.document.serialize().data == before, "Timing history never changes save data")
		assert(states == [engine.random.state, engine.lfsr_random.state, engine.game_random.state])

	# Preserve the existing data-map group while accepting other timed phases.
	history.consume({"day_results": [{"ok": true, "day": 2,
		"timing": {"work_usec": 500, "steps": {}},
		"phase_results": {"pollution_terrain_land_value": {"timing": {"steps": {"smoothing": 300}}}}}]})
	assert(history.steps["Day 03 / data maps / smoothing"].last_usec == 300)
	history.consume({"day_results": [{"ok": false, "day": 1,
		"timing": {"work_usec": 999, "steps": {"rejected": 999}}}]})
	assert(not history.steps.has("Day 02 / rejected"))
