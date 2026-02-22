extends SceneTree
## Read-only source fixtures. CPU timings are not live FPS or GPU timings.
func _init() -> void:
	var sprites := Sc2SpriteArchive.load_path("res://../references/DATA/LARGE.DAT")
	assert(sprites.is_valid())
	for edge in [128, 256, 384, 512]:
		var path := "res://../references/CITIES/SYDNEY.SC2" if edge == 128 else "res://../local/large-cities/stitched-%d.sc2x" % edge
		var city := CityState.from_document(Sc2File.load_path(path))
		assert(city.is_valid(), city.load_error)
		var begin := Time.get_ticks_usec()
		var rendered := CityIsometricRenderer.create_image(city, Sc2Palette.index_encoding(), sprites, CityIsometricRenderer.VIEW_LARGE, 0, false, true, false, false)
		assert(rendered.ok)
		var render_ms := (Time.get_ticks_usec() - begin) / 1000.0
		var point := Vector2i(edge - 12, edge - 12)
		city.set_building_id(point.x, point.y, 0x1d)
		var times := [[], []]
		for trial in 3:
			for mode in 2:
				begin = Time.get_ticks_usec()
				var patch := CityIsometricRenderer.patch_static_image(rendered.image, city, Sc2Palette.index_encoding(), sprites, PackedInt32Array([city.index_of(point.x, point.y)]), CityIsometricRenderer.VIEW_LARGE, 0, mode == 0)
				assert(patch.ok)
				times[mode].append((Time.get_ticks_usec() - begin) / 1000.0)
		for values in times: values.sort()
		city.set_auto_budget_enabled(true)
		city.set_no_disasters_enabled(true)
		var engine := SimulationEngine.new(city, 123, 456, 789)
		var worst := 0.0
		var total := 0.0
		for day in 25:
			begin = Time.get_ticks_usec()
			var result := engine.advance_day()
			assert(result.ok, str(result))
			if engine.pending_interaction == "military_proposal":
				assert(engine.resolve_military_proposal(false).ok)
			var elapsed := (Time.get_ticks_usec() - begin) / 1000.0
			total += elapsed
			worst = maxf(worst, elapsed)
		print("SIZE %d render_ms=%.2f patch_copy_median_ms=%.2f patch_in_place_median_ms=%.2f month_ms=%.2f worst_day_ms=%.2f" % [edge, render_ms, times[0][1], times[1][1], total, worst])
	quit()
