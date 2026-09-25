extends "res://tools/benchmarks/fixture_paths.gd"

## Determinism probe: runs fixed-seed days on populated cities and prints a
## serialized save bytes, ordered day results, and all three RNG states.

const TimingResults = preload("res://tests/support/timing_results.gd")

const CITIES := [128, 256, 384, 512]
const DAYS := 60


func _benchmark_initialize() -> void:
	report_metadata({"days": DAYS, "seeds": [123, 456, 789], "warmup": 0, "samples": 1,
		"annual_budget": "keep funding", "military_proposal": "decline"})
	var lines := PackedStringArray()

	for edge: int in CITIES:
		var path := GeneratedCityFixture.path(edge)
		var name := path.get_file()
		var doc := Sc2File.load_path(path)

		if doc == null or not doc.is_valid():
			printerr("%s LOAD_FAILED" % name)
			quit(1)
			return

		var city := CityState.from_document(doc)
		var engine := SimulationEngine.new(city, 123, 456, 789)
		var day_hashes := PackedStringArray()
		var first_day := city.age_in_days()

		for day in DAYS:
			var result := engine.advance_day()
			if not result.ok:
				printerr("%s day %d failed: %s" % [name, day, result.error])
				quit(1)
				return

			day_hashes.append(JSON.stringify(TimingResults.without_timings(result)))
			while not engine.pending_interaction.is_empty():
				result = _resolve_interaction(engine)
				if not result.ok:
					printerr("%s day %d interaction failed: %s" % [name, day, result.error])
					quit(1)
					return
				day_hashes.append(JSON.stringify(TimingResults.without_timings(result)))

		if city.age_in_days() != first_day + DAYS:
			printerr("%s did not advance %d days" % [name, DAYS])
			quit(1)
			return

		var saved := city.document.serialize(true)
		if not saved.ok:
			printerr("%s serialization failed: %s" % [name, saved.error])
			quit(1)
			return

		lines.append("%s sha256=%s r=%d l=%d g=%d days=%s" % [
			name, bytes_sha256(saved.data), engine.random.state,
			engine.lfsr_random.state, engine.game_random.state,
			_digest(day_hashes),
		])

	for line in lines:
		print(line)

	quit()


func _resolve_interaction(engine: SimulationEngine) -> SimulationDayResult:
	match engine.pending_interaction:
		"annual_budget":
			return engine.resolve_annual_budget(BudgetPhase.funding_values(engine.city), engine.city.auto_budget_enabled())
		"military_proposal":
			return engine.resolve_military_proposal(false)
	return SimulationDayResult.failure("unsupported interaction: " + engine.pending_interaction)


func _digest(values: PackedStringArray) -> String:
	return bytes_sha256("|".join(values).to_utf8_buffer())


static func fixture_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for edge in CITIES:
		paths.append(GeneratedCityFixture.path(edge))
	return paths
