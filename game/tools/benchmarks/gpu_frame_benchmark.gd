extends SceneTree
## Native frame pacing. Run without --headless and with --audio-driver Dummy.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Frame benchmark requires native rendering")
	OS.set_environment("OPENSC2K_CITY_RENDERER", "gpu")
	root.size = Vector2i(1920, 1080)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.set_script(load("res://tools/benchmarks/profiled_city.gd"))
	main.asset_state.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	root.add_child(main)
	await process_frame
	main.main_menu.city_background.set_process(false)
	var full_size_graphics := OS.get_environment("CITY_BENCH_HIRES") != "0"
	main.preferences.zoom_graphics = AppSettingsStore.normalize_zoom_graphics([2, 2, 2, 2, 2, 2] if full_size_graphics else [0, 1, 2, 2, 2, 2])
	var seconds := float(OS.get_environment("CITY_BENCH_SECONDS")) if OS.has_environment("CITY_BENCH_SECONDS") else 30.0

	for speed in [GameSpeedController.Speed.PAUSED, GameSpeedController.Speed.CHEETAH]:
		if OS.has_environment("CITY_BENCH_SPEED") and speed != int(OS.get_environment("CITY_BENCH_SPEED")):
			continue

		for zoom in CityMapControl.ZOOM_LEVELS:
			if OS.has_environment("CITY_BENCH_ZOOM") and zoom != float(OS.get_environment("CITY_BENCH_ZOOM")):
				continue

			main.map_view.zoom_factor = zoom
			var load_started := Time.get_ticks_usec()
			assert(main.city_session.activate_document(Sc2File.load_path("res://../local/large-cities/stitched-512.sc2x")))
			main.menus.set_overlay(CityViewMode.Mode.CITY)
			main.frame.select_speed(GameSpeedController.Speed.PAUSED)
			var deadline := Time.get_ticks_msec() + 60000

			while not main.render_caches.region_cache.ready() and Time.get_ticks_msec() < deadline:
				await process_frame

			assert(main.render_caches.region_cache.ready())
			print("LOAD zoom=%.2f hires=%s visible_ms=%.2f" % [zoom, full_size_graphics, (Time.get_ticks_usec() - load_started) / 1000.0])
			main.frame.select_speed(speed)
			var warm_until := Time.get_ticks_msec() + 2000

			while Time.get_ticks_msec() < warm_until:
				await process_frame

			main.frame_profile.clear()
			var samples: Array[float] = []
			var previous := Time.get_ticks_usec()
			var finish := previous + int(seconds * 1000000)
			var late := 0

			while Time.get_ticks_usec() < finish:
				await process_frame
				var now := Time.get_ticks_usec()
				var elapsed := (now - previous) / 1000.0
				previous = now
				samples.append(elapsed)

				if elapsed > 16.667:
					late += 1

			var total := 0.0

			for value in samples:
				total += value

			samples.sort()
			assert(main.overlay_mode == CityViewMode.Mode.CITY, "Benchmark view changed during measurement")
			print("CACHE ", main.render_caches.region_cache.metrics(), " DYNAMIC ", main.map_view.debug_metrics())
			print("PROFILE ", main.frame_profile)
			print("STATE date=%d/%d/%d blocked=%s" % [main.document_state.city.current_year(), main.document_state.city.current_month(), main.document_state.city.current_day(), main.speed_controller.interaction_blocked or main.speed_controller.terminal_blocked])
			print("FRAME speed=%d zoom=%.2f hires=%s viewport=%s frames=%d avg_fps=%.2f p95_ms=%.2f p99_ms=%.2f max_ms=%.2f over_60_budget_pct=%.2f" % [speed, zoom, full_size_graphics, main.map_view.size, samples.size(), samples.size() * 1000.0 / total, samples[int(samples.size() * 0.95)], samples[int(samples.size() * 0.99)], samples.back(), 100.0 * late / samples.size()])

	main.queue_free()
	await process_frame
	quit()
