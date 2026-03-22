extends SceneTree


class DrawProbe extends Control:
	var overlay: ServiceQueryOverlay
	var samples: Array[int] = []

	func _draw() -> void:
		if overlay == null:
			return
		var started := Time.get_ticks_usec()
		overlay.draw_on(self, 1.0, Vector2(640, 60))
		samples.append(Time.get_ticks_usec() - started)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := CityState.from_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/CAPEQUES.SC2"))
	for building in [PollutionPhase.POLICE_STATION, PollutionPhase.FIRE_STATION]:
		var origin := Vector2i(-1, -1)
		for x in city.map_size:
			for y in city.map_size:
				if city.building_id(x, y) == building:
					origin = Vector2i(x, y)
		for all_stations in [false, true]:
			await _measure("Capeques %s all=%s" % [building, all_stations], city, origin, all_stations)

	var document := EmptyCityTemplate.create(512)
	document.enable_full_resolution_maps()
	var dense := CityState.from_document(document)
	for x in range(16, 497, 24):
		for y in range(16, 497, 24):
			for dx in 3:
				for dy in 3:
					var index := dense.index_of(x + dx, y + dy)
					dense.buildings[index] = PollutionPhase.FIRE_STATION
					dense.zones[index] = 0
					dense.tile_flags[index] |= PollutionPhase.FLAG_POWERED
			dense.zones[dense.index_of(x, y)] = 0x10
			dense.zones[dense.index_of(x + 2, y)] = 0x20
			dense.zones[dense.index_of(x + 2, y + 2)] = 0x40
			dense.zones[dense.index_of(x, y + 2)] = 0x80
	await _measure("Dense 512 fire all=true", dense, Vector2i(16, 16), true)
	quit()


func _measure(label: String, city: CityState, origin: Vector2i, all_stations: bool) -> void:
	var started := Time.get_ticks_usec()
	var result := ServiceQueryAnalysis.inspect(city, origin, all_stations)
	assert(result.ok)
	var analysis_usec := Time.get_ticks_usec() - started
	var overlay := ServiceQueryOverlay.new()
	started = Time.get_ticks_usec()
	overlay.rebuild(city, result)
	var rebuild_usec := Time.get_ticks_usec() - started
	var probe := DrawProbe.new()
	probe.size = Vector2(1280, 720)
	probe.overlay = overlay
	root.add_child(probe)
	for frame in 35:
		probe.queue_redraw()
		await process_frame
	var samples: Array[int] = probe.samples.slice(5)
	samples.sort()
	assert(not samples.is_empty())
	print("%s stations=%d tiles=%d analysis_ms=%.3f rebuild_ms=%.3f draw_median_ms=%.3f samples=%d" % [label,
		result.sites.size(), result.values.size(), analysis_usec / 1000.0, rebuild_usec / 1000.0,
		samples[IntegerMath.div_trunc(samples.size(), 2)] / 1000.0, samples.size()])
	probe.free()
