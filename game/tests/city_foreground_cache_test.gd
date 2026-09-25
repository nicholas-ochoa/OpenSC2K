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
	assert(not main.render_caches.sign_foreground_cache.is_empty())
	var saved := _foreground_values(main.render_caches.sign_foreground_cache)
	main.moving_sprites.refresh_moving_things(main.static_render.city_view_size())
	assert(_foreground_values(main.render_caches.sign_foreground_cache) == saved, "Unchanged foreground replaced cached masks or textures")
	var previous: Dictionary[int, CitySignVisual] = {}

	for key in main.map_view.sign_occlusion_visuals:
		previous[key] = main.map_view.sign_occlusion_visuals[key].copy()

	assert(not previous.is_empty())
	main.render_caches.sign_foreground_cache.clear()
	main.map_render.refresh_sign_occlusion(main.static_render.city_view_size())

	for key in previous:
		assert(main.map_view.sign_occlusion_visuals[key].texture == previous[key].texture, "Identical pixels caused another texture upload")
		assert(main.map_view.sign_occlusion_visuals[key].indices == previous[key].indices)

	var key: int = previous.keys()[0]
	# Simulate a retained foreground from an earlier region with different pixels.
	var stale: Image = previous[key].indices.duplicate()
	stale.fill(Color.TRANSPARENT)
	main.map_view.sign_occlusion_visuals[key].indices = stale
	main.render_caches.sign_foreground_cache.clear()
	main.map_render.refresh_sign_occlusion(main.static_render.city_view_size())
	assert(main.map_view.sign_occlusion_visuals[key].texture != previous[key].texture, "Changed foreground kept the old texture")
	var indexed := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	indexed.set_pixel(0, 0, Color8(161, 161, 161, 255))
	indexed.set_pixel(1, 0, Color.TRANSPARENT)
	var mapping: PackedInt32Array = main.asset_state.palette.animation_index_map(0)
	mapping[161] = 17
	var colored: Image = main.map_render.sign_palette_image(indexed, mapping)
	assert(colored.get_pixel(0, 0) == main.asset_state.palette.color(17))
	assert(colored.get_pixel(1, 0).a == 0.0)
	assert(indexed.get_pixel(0, 0).r8 == 161, "Palette update changed cached indices")
	var sign_bounds: Rect2i = main.render_caches.sign_foreground_cache[key].signature[1]
	var moving := CityDynamicVisual.new(null, Vector2(sign_bounds.position), Vector2(indexed.get_size()))
	moving.depth_order = 1000000
	moving.image = indexed
	var candidates: Array[CityDynamicVisual] = [moving]
	main.render_caches.dynamic_sign_occluders = candidates
	main.render_caches.dynamic_sign_occlusion_grid = CityDynamicVisual.build_grid(candidates)
	main.map_render.refresh_sign_occlusion(main.static_render.city_view_size())
	var with_moving := _foreground_values(main.render_caches.sign_foreground_cache)
	var repeated_candidates: Array[CityDynamicVisual] = [moving.copy()]
	main.render_caches.dynamic_sign_occluders = repeated_candidates
	main.map_render.refresh_sign_occlusion(main.static_render.city_view_size())
	assert(_foreground_values(main.render_caches.sign_foreground_cache) == with_moving,
		"Equivalent moving visual values must retain sign masks and textures across distinct records")
	main.static_render.invalidate_rendered_city()
	assert(main.render_caches.sign_foreground_cache.is_empty())
	main.queue_free()
	await process_frame
	print("PASS: unchanged sign foreground reuse, palette remapping, transparency and artwork invalidation")
	quit()


# Capture every field by value so later mutations cannot alter the expected state.
func _foreground_values(cache: Dictionary[int, RenderCaches.SignForeground]) -> Dictionary:
	var values := {}

	for key in cache:
		var entry := cache[key]
		var visual: Array = []

		if entry.visual != null:
			visual = [entry.visual.indexed, entry.visual.indices, entry.visual.texture,
				entry.visual.position, entry.visual.size]

		values[key] = [entry.signature.duplicate(true), entry.indices,
			entry.palette_signature, entry.used_indices.duplicate(), visual]

	return values
