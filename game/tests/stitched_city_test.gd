extends SceneTree
## Run build_large_city_fixtures.gd first. This test never saves over a fixture.

# Sydney after 300 days at 10f181ae, with seeds 123/456/789.
# A deterministic current-model regression, not proof of Windows parity.
# The a21651a baseline predates the transport, education, military, and crash fixes.
const YEAR_SHA256 := "56f7ee574b94d6392ad2eb72167a14d70a34e2f4ce59defaf1cbe3b00373f62e"


func _init() -> void:
	var selected := OS.get_cmdline_user_args()

	for argument in selected:
		if not _check(argument in ["128", "256", "384", "512"], "unknown test size " + argument):
			return

	for edge in [128, 256, 384, 512]:
		if not selected.is_empty() and str(edge) not in selected:
			continue

		var path := "res://../references/SIMCITY2000/CITIES/SYDNEY.SC2" if edge == 128 else "res://../local/large-cities/stitched-%d.sc2x" % edge
		var digest := FileAccess.get_sha256(path)
		var document := Sc2File.load_path(path)

		if not _check(document.is_valid() and document.map_size == edge, "load %d" % edge):
			return

		var engine := SimulationEngine.new(CityState.from_document(document), 123, 456, 789)
		var start := Time.get_ticks_msec()
		var initial_age := engine.city.age_in_days()
		var phases := {}
		var disaster_ticks := 0
		var controlled_disaster_ends := 0

		for day in 300:
			var episode_ticks := 0

			while engine.active_disaster_type != 0:
				if not _result(engine.advance_moving_things(disaster_ticks * 200), "disaster objects"):
					return

				if not _result(engine.advance_disaster_tick(), "disaster map"):
					return

				disaster_ticks += 1
				episode_ticks += 1

				# This is a capacity/year soak, not a claim that an unattended fire
				# must extinguish itself. Exercise damage, then use the existing
				# player debug cleanup to keep the simulation calendar advancing.
				if edge > 128 and episode_ticks == 512 and engine.active_disaster_type != 0:
					if not _result(CityDebugActions.end_disaster(engine.city, document, engine), "controlled disaster cleanup"):
						return

					controlled_disaster_ends += 1

				if disaster_ticks % 100 == 0:
					print("%d day %d disaster %d tick %d" % [edge, day, engine.active_disaster_type, disaster_ticks])

				if not _check(disaster_ticks < 10000, "disaster did not finish"):
					return

			var result := engine.advance_day()

			if not _result(result, "%d day %d" % [edge, day]):
				return

			for phase in result.get("applied", []):
				phases[phase] = true

			while not engine.pending_interaction.is_empty():
				if engine.pending_interaction == "military_proposal":
					result = engine.resolve_military_proposal(false)
				elif engine.pending_interaction == "annual_budget":
					result = engine.resolve_annual_budget(BudgetPhase.funding_values(engine.city), true)
				else:
					_check(false, "unknown interaction: " + engine.pending_interaction)

					return

				if not _result(result, "resolve interaction"):
					return

				for phase in result.get("applied", []):
					phases[phase] = true

			if not _result(engine.advance_moving_things(day * 200), "moving tick"):
				return

		if not _check(engine.city.age_in_days() == initial_age + 300, "year advanced"):
			return

		var saved := document.serialize()

		if edge == 128:
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(saved.data)

			var actual_hash := hash.finish().hex_encode()
			print("128-map 300-day SHA256: ", actual_hash)
			if not _check(actual_hash == YEAR_SHA256, "300-day output matches the documented current-model baseline"):
				return

		var reloaded := Sc2File.new()

		if not _check(reloaded.parse(saved.data) and reloaded.serialize(true).data == saved.data, "round trip"):
			return

		if not _check(FileAccess.get_sha256(path) == digest, "fixture unchanged"):
			return

		print("Controlled disaster ends: %d" % controlled_disaster_ends)
		print("PASS: populated %d city, 300 days, %d disaster ticks, reload; %d ms; phases %s" % [edge, disaster_ticks, Time.get_ticks_msec() - start, phases.keys()])

	quit()


func _result(result: Dictionary, context: String) -> bool:
	return _check(result.get("ok", false), "%s: %s" % [context, result.get("error", "")])


func _check(condition: bool, context: String) -> bool:
	if not condition:
		push_error("FAIL: " + context)
		quit(1)

	return condition
