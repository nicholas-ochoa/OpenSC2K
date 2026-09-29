extends "res://tools/benchmarks/fixture_paths.gd"
## Simulation days and moving-thing ticks on read-only cities. Each city loads
## once, runs DAYS days with fixed seeds, and then TICKS moving-thing ticks.
## Pass city paths after "--" to use other inputs. The input files stay unchanged.

const DAYS := 25
const TICKS := 200


func _benchmark_initialize() -> void:
	report_metadata({"days": DAYS, "moving_ticks": TICKS, "seeds": [123, 456, 789],
		"annual_budget": "keep funding", "military_proposal": "decline"})

	for path in _paths():
		var document := Sc2File.load_path(path)

		if document == null or not document.is_valid():
			printerr("Cannot load %s" % path)
			quit(1)
			return

		var city := CityState.from_document(document)
		var engine := SimulationEngine.new(city, 123, 456, 789)
		var steps := {}
		var worst := 0.0
		var begin := Time.get_ticks_usec()

		for day in DAYS:
			var day_begin := Time.get_ticks_usec()
			var result := engine.advance_day()

			if not result.ok:
				printerr("%s day %d failed: %s" % [path.get_file(), day, result.error])
				quit(1)
				return

			for step: String in result.timing.steps:
				steps[step] = int(steps.get(step, 0)) + result.timing.steps[step]

			while not engine.pending_interaction.is_empty():
				if engine.pending_interaction == "annual_budget":
					engine.resolve_annual_budget(BudgetPhase.funding_values(city), city.auto_budget_enabled())
				else:
					engine.resolve_military_proposal(false)

			worst = maxf(worst, (Time.get_ticks_usec() - day_begin) / 1000.0)

		var days_ms := (Time.get_ticks_usec() - begin) / 1000.0
		begin = Time.get_ticks_usec()

		for tick in TICKS:
			engine.advance_moving_things(tick * 200)

		var ticks_ms := (Time.get_ticks_usec() - begin) / 1000.0
		print("CITY %s edge=%d days=%d total_ms=%.1f day_mean_ms=%.2f worst_day_ms=%.2f moving_tick_mean_ms=%.3f" % [
			path.get_file(), city.map_size, DAYS, days_ms, days_ms / DAYS, worst, ticks_ms / TICKS])
		var names := steps.keys()
		names.sort_custom(func(a: String, b: String) -> bool: return steps[a] > steps[b])

		for name: String in names.slice(0, 8):
			print("  %-32s %9.1f ms" % [name, steps[name] / 1000.0])

	quit()


func _paths() -> PackedStringArray:
	var arguments := OS.get_cmdline_user_args()
	var paths := PackedStringArray()

	for argument in arguments:
		if not argument.begins_with("--"):
			paths.append(argument)

	return paths if not paths.is_empty() else fixture_paths()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([GeneratedCityFixture.path(256), large_city_path(512)])
