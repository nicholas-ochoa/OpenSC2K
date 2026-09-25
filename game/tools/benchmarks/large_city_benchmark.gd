extends "res://tools/benchmarks/fixture_paths.gd"


## Read-only source fixtures. CPU timings are not live FPS or GPU timings.
func _benchmark_initialize() -> void:
	var sprites := Sc2SpriteArchive.load_path(reference_path("DATA/LARGE.DAT"))
	if not (sprites.is_valid()):
		printerr("Benchmark check failed: sprites.is_valid()")
		quit(1)
		return

	for edge in [128, 256, 384, 512]:
		var path := GeneratedCityFixture.path(128) if edge == 128 else large_city_path(edge)
		var city := CityState.from_document(Sc2File.load_path(path))
		if not (city.is_valid()):
			printerr(city.load_error)
			quit(1)
			return
		var begin := Time.get_ticks_usec()
		var rendered := CityIsometricRenderer.create_image(city, Sc2Palette.index_encoding(), sprites, CityIsometricRenderer.VIEW_LARGE, 0, false, true, false, false)
		if not (rendered.ok):
			printerr("Benchmark check failed: rendered.ok")
			quit(1)
			return
		var render_ms := (Time.get_ticks_usec() - begin) / 1000.0
		var point := Vector2i(edge - 12, edge - 12)
		city.set_building_id(point.x, point.y, BuildingTileIds.ROAD_STRAIGHT_1)
		var times := [[], []]

		for trial in 3:
			for mode in 2:
				begin = Time.get_ticks_usec()
				var patch := CityIsometricRenderer.patch_static_image(rendered.image, city, Sc2Palette.index_encoding(), sprites, PackedInt32Array([city.index_of(point.x, point.y)]), CityIsometricRenderer.VIEW_LARGE, 0, mode == 0)
				if not (patch.ok):
					printerr("Benchmark check failed: patch.ok")
					quit(1)
					return
				times[mode].append((Time.get_ticks_usec() - begin) / 1000.0)

		for values in times:
			values.sort()

		city.set_auto_budget_enabled(true)
		city.set_no_disasters_enabled(true)
		var engine := SimulationEngine.new(city, 123, 456, 789)
		var worst := 0.0
		var total := 0.0

		for day in 25:
			begin = Time.get_ticks_usec()
			var result := engine.advance_day()
			if not (result.ok):
				printerr(str(result))
				quit(1)
				return

			if engine.pending_interaction == "military_proposal":
				if not (engine.resolve_military_proposal(false).ok):
					printerr("Benchmark check failed: engine.resolve_military_proposal(false).ok")
					quit(1)
					return

			var elapsed := (Time.get_ticks_usec() - begin) / 1000.0
			total += elapsed
			worst = maxf(worst, elapsed)

		print("SIZE %d render_ms=%.2f patch_copy_median_ms=%.2f patch_in_place_median_ms=%.2f month_ms=%.2f worst_day_ms=%.2f" % [edge, render_ms, times[0][1], times[1][1], total, worst])

	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		reference_path("DATA/LARGE.DAT"), GeneratedCityFixture.path(128), large_city_path(256), large_city_path(384),
		large_city_path(512),
	])
