extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("OPENSC2K_CITY_RENDERER", "gpu")
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	main.map_view.zoom_factor = 0.25
	assert(main.city_session.activate_document(Sc2File.load_path("res://tests/fixtures/cities/generated-256.sc2x")))
	var deadline := Time.get_ticks_msec() + 30000

	while not main.render_caches.region_cache.ready() and Time.get_ticks_msec() < deadline:
		main.map_render.poll_region_cache()
		await process_frame

	assert(main.render_caches.region_cache.ready())
	main.moving_sprites.refresh_moving_things(main.static_render.city_view_size())
	var sign_scans: int = main.map_view.debug_metrics().sign_scans
	var display_copy := CityState.from_document(main.render_caches.region_cache.display_city.document.duplicate_document())
	main.map_view.set_city_view(display_copy, main.map_view.city_source, main.map_view.palette_index_texture, true, true)
	main.map_view.sign_source_entries()
	assert(main.map_view.debug_metrics().sign_scans == sign_scans, "Equivalent snapshot rebuilt the sign layout")
	main.queue_free()
	await process_frame
	print("PASS: an equivalent city snapshot keeps the sign layout")
	quit()
