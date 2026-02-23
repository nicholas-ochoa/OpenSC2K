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
	assert(SimulationTimingHistory.DAY_SUMMARIES[1] == "Power")
	assert(SimulationTimingHistory.DAY_SUMMARIES[23] == "Statistics-window refresh only")
	var budget := SimulationSliceBudget.new()
	var span := SimulationTimingSpan.new(budget)
	span.mark("test")
	# Simulate equal work-clock and parked-clock offsets without a sleeping test.
	span.started -= 5000
	span.step_started -= 5000
	budget.parked_usec += 5000
	var measured := span.finish()
	assert(measured.work_usec >= 0 and measured.steps.test >= 0)
	assert(measured.work_usec < 5000, "Explicit frame waits do not count as calculation")
	history.clear()
	assert(history.days.is_empty() and history.steps.is_empty())
	print("PASS: simulation timing aggregation, displayed days and wait exclusion")
	quit()
