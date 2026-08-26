extends "res://tools/benchmarks/fixture_paths.gd"
## Fixed-seed save-byte proof and whole-day CPU timing. Pass a city and days
## after --. The defaults are the 512 fixture and 20 days.

@warning_ignore_start("integer_division")

func _benchmark_initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path := input_path(large_city_path(512))
	var days := int(args[1]) if args.size() > 1 else 20
	var document := Sc2File.load_path(path)
	if document == null or not document.is_valid():
		printerr("Invalid fixture")
		quit(1)
		return
	var city := CityState.from_document(document)
	city.set_auto_budget_enabled(true)
	city.set_no_disasters_enabled(true)
	var engine := SimulationEngine.new(city, 123, 456, 789)
	var times: Array[int] = []
	for day in days:
		var begin := Time.get_ticks_usec()
		var result := engine.advance_day()
		times.append(Time.get_ticks_usec() - begin)
		if not result.ok:
			printerr("Day failed: ", day, " ", result)
			quit(1)
			return
		if engine.pending_interaction == "military_proposal":
			if not engine.resolve_military_proposal(false).ok:
				quit(1)
				return
	var saved := document.serialize(true)
	if not saved.ok:
		quit(1)
		return
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(saved.data)
	print("PROOF %s days=%s sha256=%s r=%d l=%d g=%d" % [path.get_file(), str(days), hashing.finish().hex_encode(), engine.random.state, engine.lfsr_random.state, engine.game_random.state])
	var total := 0
	for elapsed in times:
		total += elapsed
	times.sort()
	print("TIME mean_us=%.1f median_us=%d min_us=%d max_us=%d" % [float(total) / times.size(), times[times.size() / 2], times[0], times[-1]])
	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([input_path(large_city_path(512))])
