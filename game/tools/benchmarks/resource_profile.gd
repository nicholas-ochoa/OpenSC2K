extends "res://tools/benchmarks/fixture_paths.gd"
## Fixed native workload for CPU and memory profiling. Use Dummy audio.

var main: CityApplication


func _benchmark_initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() != "Dummy":
		printerr("Resource profiling requires native rendering and Dummy audio")
		quit(1)
		return
	seed(42)
	OS.set_environment("OPENSC2K_CITY_RENDERER", "gpu")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1920, 1080)
	var city_path := input_path(GeneratedCityFixture.path(128))
	report_metadata({"city": city_path, "window": root.size, "audio": "Dummy"})
	await _measure("engine", 2.0)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	main.set_script(load("res://tools/benchmarks/profiled_city.gd"))
	preload("res://tests/support/app_fixture.gd").configure(main)
	root.add_child(main)
	if not main.asset_state.assets_ready:
		printerr(main.asset_state.asset_source.error)
		quit(1)
		return
	await create_timer(6.0).timeout
	await _measure("menu", 3.0)
	var document := Sc2File.load_path(city_path)
	if not document.is_valid():
		printerr("Cannot load profiling city: ", city_path)
		quit(1)
		return
	main.preferences.original_compatibility = not document.is_extended()
	var large_artwork := OS.get_environment("CITY_BENCH_LARGE_ARTWORK") == "1"
	main.preferences.overview_graphics = 2 if large_artwork else 0
	main.preferences.zoom_graphics = AppSettingsStore.normalize_zoom_graphics(
		[2, 2, 2, 2, 2, 2] if large_artwork else [0, 1, 2, 2, 2, 2])
	var overview_comparison := OS.get_environment("CITY_BENCH_OVERVIEW_COMPARISON") == "1"
	main.map_view.zoom_factor = 0.1 if overview_comparison else 1.0
	if not main.city_session.activate_document(document):
		quit(1)
		return
	main.menus.set_overlay(CityViewMode.Mode.CITY)
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	await _settle()
	if overview_comparison:
		await _measure("large_paused_10", 6.0)
		main.frame.select_speed(GameSpeedController.Speed.TURTLE)
		await _measure("large_turtle_10", 12.0)
		main.frame.select_speed(GameSpeedController.Speed.PAUSED)
		main.preferences.overview_graphics = 0
		if not main.city_session.activate_document(Sc2File.load_path(city_path)):
			quit(1)
			return
		main.frame.select_speed(GameSpeedController.Speed.PAUSED)
		await _settle()
		await _measure("small_paused_10", 6.0)
		main.frame.select_speed(GameSpeedController.Speed.TURTLE)
		await _measure("small_turtle_10", 12.0)
		main.queue_free()
		main = null
		await process_frame
		quit()
		return
	await _measure("paused_100", 8.0)
	main.frame.select_speed(GameSpeedController.Speed.TURTLE)
	await _measure("turtle_100", 12.0)
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	main.map_view.zoom_factor = 0.1
	main.map_render.refresh_map()
	await _settle()
	await _measure("paused_10", 8.0)
	main.frame.select_speed(GameSpeedController.Speed.TURTLE)
	await _measure("turtle_10", 12.0)
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	main.map_view.zoom_factor = 1.0
	main.map_render.refresh_map()
	await _settle()
	await _measure("return_100", 6.0)
	Engine.max_fps = 60
	await _measure("cap_60fps_100", 6.0)
	root.size = Vector2i(3840, 2160)
	await _settle()
	await _measure("large_window_100", 6.0)
	root.size = Vector2i(1920, 1080)
	await _settle()
	# Diagnostic release: quantify the hidden menu's retained city and artwork.
	main.main_menu.city_background.queue_free()
	await create_timer(2.0).timeout
	await _measure("menu_released", 6.0)
	main.queue_free()
	main = null
	await create_timer(2.0).timeout
	await _measure("app_released", 3.0)
	quit()


func _settle() -> void:
	var deadline := Time.get_ticks_msec() + 60000
	while not main.render_caches.region_cache.ready() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not main.render_caches.region_cache.ready():
		printerr("Timed out waiting for visible regions")
		quit(1)
		return
	await create_timer(2.0).timeout


func _measure(stage: String, seconds: float) -> void:
	print("BEGIN ", stage, " pid=", OS.get_process_id())
	if main != null:
		main.frame_profile.clear()
		# Keep day history: the SC2X worker uses it to pace subsequent days.
		main.timing_state.simulation_timings.steps.clear()
		main.timing_state.simulation_timings.step_after.clear()
	var samples: Array[float] = []
	var render_cpu := 0.0
	var render_gpu := 0.0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec() - start < seconds * 1000000.0:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		render_gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		previous = now
	samples.sort()
	var result := {"stage": stage, "seconds": (previous - start) / 1000000.0, "frames": samples.size(),
		"p95_ms": samples[int(samples.size() * 0.95)], "p99_ms": samples[int(samples.size() * 0.99)],
		"memory_static": Performance.get_monitor(Performance.MEMORY_STATIC),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"buffer_bytes": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"root_render_cpu_ms": render_cpu / samples.size(), "root_render_gpu_ms": render_gpu / samples.size(),
		"window": [root.size.x, root.size.y], "max_fps": Engine.max_fps}
	# Some backend counters wrap after texture destruction. Preserve availability,
	# rather than reporting an impossible allocation as a measured size.
	if result.texture_bytes > 1e15:
		result.texture_bytes = null
	if render_gpu == 0.0:
		result.root_render_gpu_ms = null
	if main != null:
		result["profile"] = main.frame_profile.duplicate(true)
		if main.render_caches.region_cache != null:
			result["cache"] = main.render_caches.region_cache.metrics()
		result["dynamic"] = main.map_view.debug_metrics()
		result["viewport"] = [main.map_view.size.x, main.map_view.size.y]
		result["zoom_graphics"] = main.preferences.zoom_graphics
		result["overview_graphics"] = main.preferences.overview_graphics
		result["actual_artwork_size"] = main.static_render.city_view_size() if main.document_state.city != null else -1
		result["moving_fps"] = 1000.0 / GameSpeedController.BASE_TICK_MSEC
		result["original_compatibility"] = main.preferences.original_compatibility
		if main.document_state.city != null:
			result["map_edge"] = main.document_state.city.map_size
			result["simulation_worker"] = main.simulation_state.frame_simulation != null
			if main.simulation_state.frame_simulation != null:
				result["worker_metrics"] = main.simulation_state.frame_simulation.metrics()
		var steps := {}
		for label in main.timing_state.simulation_timings.steps:
			var row: SimulationTimingHistory.Sample = main.timing_state.simulation_timings.steps[label]
			steps[label] = {"count": row.count, "total_usec": row.total_usec, "max_usec": row.max_usec}
		result["simulation_steps"] = steps
	var acknowledgement := OS.get_environment("CITY_BENCH_ACK")
	var previously_paused := paused
	if not acknowledgement.is_empty():
		paused = true
	print("RESULT ", JSON.stringify(result))
	if not acknowledgement.is_empty():
		var deadline := Time.get_ticks_msec() + 30000
		while Time.get_ticks_msec() < deadline:
			if FileAccess.file_exists(acknowledgement) and FileAccess.get_file_as_string(acknowledgement) == stage:
				# Consume the frame that includes the external snapshot pause.
				await process_frame
				paused = previously_paused
				return
			await process_frame
		printerr("Timed out waiting for the memory snapshot")
		quit(1)


static func fixture_paths() -> PackedStringArray:
	var paths := application_paths()
	paths.append(input_path(GeneratedCityFixture.path(128)))
	return paths
