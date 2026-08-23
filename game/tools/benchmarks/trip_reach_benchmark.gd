extends "res://tools/benchmarks/fixture_paths.gd"

@warning_ignore_start("integer_division")


func _benchmark_initialize() -> void:
	var city := CityState.from_document(Sc2File.load_path(reference_path("CITIES/CAPEQUES.SC2")))
	var samples: Array[Vector2i] = []
	for x in city.map_size:
		for y in city.map_size:
			var tile := city.building_id(x, y)
			if city.zone_id(x, y) in [1, 2, 3, 4, 5, 6] and tile >= 0x70 and tile <= 0xc5:
				samples.append(Vector2i(x, y))
	var traffic := city.document.find_chunk("XTRF").decoded_payload.duplicate()

	if not TransportTripSearch.valid_inputs(city.buildings, city.zones, city.underground,
		city.text_overlays, city.altitude_words, traffic, city.map_size):
		printerr("Capeques transport maps have the wrong size")
		quit(1)
		return

	var started := Time.get_ticks_usec()
	var expanded := 0
	for i in 256:
		var point: Vector2i = samples[(i * samples.size()) / 256]
		var result := TransportTripSearch.trace(city.buildings, city.zones, city.underground,
			city.text_overlays, city.altitude_words, traffic, point, city.zone_id(point.x, point.y),
			GrowthDevelopment.density(city.building_id(point.x, point.y)), SimRandom.new(i + 1))
		expanded += int(result.get("expanded_states", 0))
	print("Capeques 256 trips: %d usec, %d expanded states" % [Time.get_ticks_usec() - started, expanded])
	for edge in [128, 512]:
		var dense := CityState.from_document(EmptyCityTemplate.create(edge))
		var center := Vector2i(edge - 50, edge - 50)
		for x in range(center.x - 40, center.x + 41):
			for y in range(center.y - 40, center.y + 41):
				dense.set_building_id(x, y, 0x2b)
		started = Time.get_ticks_usec()
		var result := TripReachAnalysis.inspect(dense, center)
		var analysis_usec := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		var overlay := TripReachOverlay.new()
		overlay.rebuild(dense, result)
		print("Dense %d: analysis %d usec, vector preparation %d usec, %d states, %d links" % [
			edge, analysis_usec, Time.get_ticks_usec() - started, result.expanded_states, result.links.size()])
	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		reference_path("CITIES/CAPEQUES.SC2"),
	])
