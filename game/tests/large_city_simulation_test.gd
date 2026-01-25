extends SceneTree

var failures := 0

func _init() -> void:
	for edge in Sc2File.MAP_SIZES:
		check_charts(edge)
		check_flood_order(edge)
		for disaster in range(1, 19):
			print("Checking %d disaster %d" % [edge, disaster])
			var document := EmptyCityTemplate.create(edge)
			var city := CityState.from_document(document)
			var engine := SimulationEngine.new(city, 123, 456, 789)
			var result := engine.start_disaster(disaster, Vector2i(edge - 16, edge - 16))
			check(result.get("ok", false), "%d disaster %d start: %s" % [edge, disaster, result.get("error", "")])
			if disaster == DisasterStartPhase.DISASTER_MONSTER or disaster == DisasterStartPhase.DISASTER_TORNADO:
				var things := document.find_chunk("XTHG").decoded_payload
				var offset := int(result.get("record", 0)) * CityState.THING_RECORD_SIZE
				check(ThingData.read(things, offset + 8) < 128 and ThingData.read(things, offset + 9) < 128, "monster pose bytes")
			for tick in 8:
				check(engine.advance_moving_things(tick * 200).get("ok", false), "moving disaster tick")
				if engine.active_disaster_type != 0:
					check(engine.advance_disaster_tick().get("ok", false), "map disaster tick")
			if engine.active_disaster_type != 0 or engine.pending_disaster_type != 0 or DisasterStartPhase.has_active_object(city, disaster):
				check(CityDebugActions.end_disaster(city, document, engine).get("ok", false), "clear disaster %d" % edge)
			check(not DisasterStartPhase.has_active_object(city, disaster), "objects cleared")
		print("PASS: %d chart data and all 18 disaster entry points" % edge)
	print("Large simulation checks: %d failures" % failures)
	quit(1 if failures else 0)

func check_charts(edge: int) -> void:
	var document := EmptyCityTemplate.create(edge)
	var city := CityState.from_document(document)
	var values := PackedInt64Array()
	for series in 16:
		values.append(100000000 + series)
	check(GraphHistory.advance(city, values).ok, "write graph history")
	for scale in 3:
		for series in 16:
			var history := CityGraphControl.history_for_scale(city, series, scale)
			check(history.size() == (12 if scale == 0 else 20), "history size")
			check(history[-1] == values[series], "history value preserves large totals")
	document.set_misc_u32(PopulationWindowControl.MISC_NORMAL_POPULATION, 100000000)
	document.set_misc_u32(PopulationWindowControl.MISC_POPULATION_TABLE, 100000000)
	var population := PopulationWindowControl.snapshot(city)
	check(population.ok and PopulationWindowControl.chart_values(population, 0)[0] == 600, "large population chart")
	var industry := IndustryWindowControl.snapshot(city)
	for mode in 3:
		check(IndustryWindowControl.values_for_mode(industry, mode).size() == 11, "industry series")
	check(SimNationWindowControl.snapshot(city).display_population == 100000000, "SimNation total")
	for mode in CityMinimap.MODES:
		var index := CityMinimap.color_index(city, edge - 1, edge - 1, mode)
		check(index >= 0 and index <= 255, "far map layer " + mode)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func check_flood_order(edge: int) -> void:
	var legacy := PackedByteArray()
	legacy.resize(128 * 128)
	var enlarged := PackedByteArray()
	enlarged.resize(edge * edge)
	var shift := Vector2i(edge - 128, edge - 128)
	for point in [Vector2i(4, 4), Vector2i(12, 4), Vector2i(4, 12), Vector2i(12, 12), Vector2i(80, 100)]:
		legacy[point.x * 128 + point.y] = 0x20
		var translated: Vector2i = point + shift
		enlarged[translated.x * edge + translated.y] = 0x20
	for origin in [Vector2i(8, 8), Vector2i.ZERO, Vector2i(127, 127), Vector2i(90, 90)]:
		var expected := DisasterStartPhase._find_flood_shore(legacy, origin)
		var actual := DisasterStartPhase._find_flood_shore(enlarged, origin + shift, edge)
		check(actual == expected + shift, "flood search order %d at %s" % [edge, origin])
