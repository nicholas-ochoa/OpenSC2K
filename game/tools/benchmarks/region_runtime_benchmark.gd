extends SceneTree
## Headless CPU and readiness timing. This does not measure native FPS or GPU time.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	main.app_zoom_graphics = AppSettingsStore.normalize_zoom_graphics([0, 1, 2, 2, 2, 2])
	main.map_view.zoom_factor = float(OS.get_environment("CITY_BENCH_ZOOM")) if OS.has_environment("CITY_BENCH_ZOOM") else 1.0
	for edge in [256, 384, 512]:
		if OS.has_environment("CITY_BENCH_SIZE") and edge != int(OS.get_environment("CITY_BENCH_SIZE")):
			continue
		var document := Sc2File.load_path("res://../local/large-cities/stitched-%d.sc2x" % edge)
		var started := Time.get_ticks_usec()
		assert(main._activate_document(document))
		var activation_ms := (Time.get_ticks_usec() - started) / 1000.0
		var cache: CityRegionCache = main.region_cache
		started = Time.get_ticks_usec()
		var first_ms := -1.0
		var visible_ms := -1.0
		var max_poll_usec := 0
		var deadline := Time.get_ticks_msec() + 30000
		while Time.get_ticks_msec() < deadline:
			var poll_started := Time.get_ticks_usec()
			main._poll_region_cache()
			max_poll_usec = maxi(max_poll_usec, Time.get_ticks_usec() - poll_started)
			assert(cache.last_error.is_empty())
			if cache.completed_regions > 0 and first_ms < 0:
				first_ms = (Time.get_ticks_usec() - started) / 1000.0
			if cache.ready() and visible_ms < 0:
				visible_ms = (Time.get_ticks_usec() - started) / 1000.0
			assert(cache.entries.size() <= cache.visible.size() + cache.offscreen_limit())
			if cache.prefetch_ready() and cache.ready():
				break
			await process_frame
		assert(cache.ready() and cache.prefetch_ready())
		var dynamic_start := Time.get_ticks_usec()
		main._refresh_moving_things(main._city_view_size())
		print("WARM dynamic_ms=%.2f zoom=%.2f" % [(Time.get_ticks_usec() - dynamic_start) / 1000.0, main.map_view.zoom_factor])
		var metrics := cache.metrics()
		print("BACKEND %s atlas_MiB=%.2f" % ["GPU" if metrics.gpu else "CPU", metrics.atlas_bytes / 1048576.0])
		var full_size := CityIsometricRenderer.output_size_for_view(2, edge)
		print("SIZE %d viewport=%s activation_ms=%.2f first_region_ms=%.2f visible_ready_ms=%.2f main_poll_max_ms=%.2f resident=%d visible=%d cpu_images_MiB=%.2f texture_MiB_estimate=%.2f old_full_index_MiB=%.2f" % [edge, main.map_view.size, activation_ms, first_ms, visible_ms, max_poll_usec / 1000.0, metrics.resident, metrics.visible, metrics.cpu_image_bytes / 1048576.0, metrics.texture_bytes_estimate / 1048576.0, full_size.x * full_size.y * 2 / 1048576.0])
	main.queue_free()
	await process_frame
	quit()
