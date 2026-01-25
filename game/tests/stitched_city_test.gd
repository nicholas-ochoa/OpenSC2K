extends SceneTree
## Run build_large_city_fixtures.gd first. This test never saves over a fixture.

# Sydney after 300 days on unchanged a21651a, with seeds 123/456/789.
const LEGACY_YEAR_SHA256 := "c25a3c047ed84b14f279ad34c17b925a1e9d333564d276202a48280db1d68fd2"

func _init() -> void:
	var selected := OS.get_cmdline_user_args()
	for argument in selected:
		if not _check(argument in ["128", "256", "384", "512"], "unknown test size " + argument):
			return
	for edge in [128, 256, 384, 512]:
		if not selected.is_empty() and str(edge) not in selected:
			continue
		var path := "res://../references/CITIES/SYDNEY.SC2" if edge == 128 else "res://../local/large-cities/stitched-%d.sc2x" % edge
		var digest := FileAccess.get_sha256(path)
		var document := Sc2File.load_path(path)
		if not _check(document.is_valid() and document.map_size == edge, "load %d" % edge):
			return
		var engine := SimulationEngine.new(CityState.from_document(document), 123, 456, 789)
		var start := Time.get_ticks_msec()
		var initial_age := engine.city.age_in_days()
		var phases := {}
		var disaster_ticks := 0
		for day in 300:
			while engine.active_disaster_type != 0:
				if not _result(engine.advance_moving_things(disaster_ticks * 200), "disaster objects"):
					return
				if not _result(engine.advance_disaster_tick(), "disaster map"):
					return
				disaster_ticks += 1
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
			if not _check(hash.finish().hex_encode() == LEGACY_YEAR_SHA256, "legacy simulation output matches unchanged code"):
				return
		var reloaded := Sc2File.new()
		if not _check(reloaded.parse(saved.data) and reloaded.serialize(true).data == saved.data, "round trip"):
			return
		if not _check(FileAccess.get_sha256(path) == digest, "fixture unchanged"):
			return
		print("PASS: populated %d city, 300 days, %d disaster ticks, reload; %d ms; phases %s" % [edge, disaster_ticks, Time.get_ticks_msec() - start, phases.keys()])
	quit()

func _result(result: Dictionary, context: String) -> bool:
	return _check(result.get("ok", false), "%s: %s" % [context, result.get("error", "")])

func _check(condition: bool, context: String) -> bool:
	if not condition:
		push_error("FAIL: " + context)
		quit(1)
	return condition
