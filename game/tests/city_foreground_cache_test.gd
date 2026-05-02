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
	assert(main._activate_document(Sc2File.load_path("res://../local/large-cities/stitched-256.sc2x")))
	var deadline := Time.get_ticks_msec() + 30000

	while not main.region_cache.ready() and Time.get_ticks_msec() < deadline:
		main._poll_region_cache()
		await process_frame

	assert(main.region_cache.ready())
	main._refresh_moving_things(main._city_view_size())
	var sign_scans: int = main.map_view.debug_metrics().sign_scans
	var display_copy := CityState.from_document(main.region_cache.display_city.document.duplicate_document())
	main.map_view.set_city_view(display_copy, main.map_view.city_texture, main.map_view.palette_index_texture, true, true)
	main.map_view.sign_source_entries()
	assert(main.map_view.debug_metrics().sign_scans == sign_scans, "Equivalent snapshot rebuilt the sign layout")
	assert(not main.sign_foreground_cache.is_empty())
	var saved: Dictionary = main.sign_foreground_cache.duplicate(true)
	main._refresh_moving_things(main._city_view_size())
	assert(main.sign_foreground_cache == saved, "Unchanged foreground replaced cached masks or textures")
	var previous: Dictionary = main.map_view.sign_occlusion_visuals.duplicate(true)
	assert(not previous.is_empty())
	main.sign_foreground_cache.clear()
	main._refresh_sign_occlusion(main._city_view_size())

	for key in previous:
		assert(main.map_view.sign_occlusion_visuals[key].texture == previous[key].texture, "Identical pixels caused another texture upload")
		assert(main.map_view.sign_occlusion_visuals[key].indices == previous[key].indices)

	var key: int = previous.keys()[0]
	# Simulate a retained foreground from an earlier region with different pixels.
	var stale: Image = previous[key].indices.duplicate()
	stale.fill(Color.TRANSPARENT)
	main.map_view.sign_occlusion_visuals[key].indices = stale
	main.sign_foreground_cache.clear()
	main._refresh_sign_occlusion(main._city_view_size())
	assert(main.map_view.sign_occlusion_visuals[key].texture != previous[key].texture, "Changed foreground kept the old texture")
	var indexed := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	indexed.set_pixel(0, 0, Color8(161, 161, 161, 255))
	indexed.set_pixel(1, 0, Color.TRANSPARENT)
	var mapping: PackedInt32Array = main.palette.animation_index_map(0)
	mapping[161] = 17
	var colored: Image = main._sign_palette_image(indexed, mapping)
	assert(colored.get_pixel(0, 0) == main.palette.color(17))
	assert(colored.get_pixel(1, 0).a == 0.0)
	assert(indexed.get_pixel(0, 0).r8 == 161, "Palette update changed cached indices")
	main._invalidate_sprite_art()
	assert(main.sign_foreground_cache.is_empty())
	main.queue_free()
	await process_frame
	print("PASS: unchanged sign foreground reuse, palette remapping, transparency and artwork invalidation")
	quit()
