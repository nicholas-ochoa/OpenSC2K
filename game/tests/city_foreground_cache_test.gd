extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.set_environment("OPENSC2K_CITY_RENDERER", "gpu")
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	main.map_view.zoom_factor = 0.25
	assert(main._activate_document(Sc2File.load_path("res://../local/large-cities/stitched-512.sc2x")))
	var deadline := Time.get_ticks_msec() + 30000
	while not main.region_cache.ready() and Time.get_ticks_msec() < deadline:
		main._poll_region_cache()
		await process_frame
	assert(main.region_cache.ready())
	main._refresh_moving_things(main._city_view_size())
	assert(not main.sign_foreground_cache.is_empty())
	var saved: Dictionary = main.sign_foreground_cache.duplicate(true)
	main._refresh_moving_things(main._city_view_size())
	assert(main.sign_foreground_cache == saved, "Unchanged foreground replaced cached masks or textures")
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
