extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := CityState.from_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/SYDNEY.SC2"))
	var sprites := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")
	var palette := Sc2Palette.index_encoding()
	var view := CityIsometricRenderer.VIEW_LARGE
	var base := int(CityIsometricRenderer.view_configuration(view).sprite_base)
	for wet in [false, true]:
		for underground in [0, 1, 0x10, 0x1e, 0x1f, 0x20]:
			city.set_underground_id(20, 20, underground)
			city.set_terrain_id(20, 20, 0)
			city.set_tile_flag(20, 20, 0x20, true)
			city.set_tile_flag(20, 20, 0x10, wet)
			var saved: PackedByteArray = city.document.serialize().data
			for pipes in [false, true]:
				for mains in [false, true]:
					var ids := CityUndergroundView.tile_sprite_ids(city, 20, 20, view, pipes, true, mains)
					var overlay := base + (0x1d3 if wet else 0x15f)
					if underground >= 0x10:
						if mains:
							assert(ids == PackedInt32Array([base + 0x13e + underground + (0x74 if wet else 0)]))
						elif underground in [0x1f, 0x20]:
							assert(ids == PackedInt32Array([base + 0x13e + (1 if underground == 0x1f else 2)]))
						else:
							assert(ids == PackedInt32Array([base + 0x131]))
					else:
						assert(ids.has(overlay) == pipes)
					assert(city.document.serialize().data == saved)

	var configuration := CityIsometricRenderer.view_configuration(view)
	var origin := int(configuration.side_margin) + city.map_size * int(configuration.half_width)
	var bounds := Rect2i(origin - 80, int(configuration.top_margin) + 40 * int(configuration.half_height) - city.land_altitude(20, 20) * int(configuration.altitude_step) - 80, 200, 200)
	var cache := CityRegionCache.new()
	cache.gpu_enabled = false
	for pipes in [false, true]:
		for mains in [false, true]:
			var full := CityUndergroundView.create_image(city, palette, sprites, view, true, pipes, true, mains)
			var region := CityRegionRenderer.render(city, palette, sprites, bounds, view, "underground", pipes, true, mains)
			assert(full.ok and region.ok)
			assert(region.image.get_data() == full.image.get_region(bounds).get_data())
			var context := CityGpuBuildContext.new()
			var tile := context.tile(city, palette, sprites, configuration, 20, 20, "underground", pipes, true, mains)
			var recorded := CityGpuDrawList.new()
			CityUndergroundView._draw_tile(recorded, city, palette, sprites, {}, configuration, origin, 20, 20, pipes, true, mains)
			assert(tile.draws.size() == recorded.draws.size())
			for i in recorded.draws.size():
				assert(tile.draws[i].image.get_data() == recorded.draws[i].image.get_data())
			var generation := cache.generation
			cache.configure(city, palette, sprites, [1], view, "underground", {}, pipes, true, Rect2i(), mains)
			assert(cache.generation > generation)
			cache.update_viewport(Rect2(bounds))
			var deadline := Time.get_ticks_msec() + 10000
			while not cache.ready() and Time.get_ticks_msec() < deadline:
				cache.tick()
				await process_frame
			assert(cache.ready() and cache.last_error.is_empty())
	cache.close()

	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.app_settings_path = "user://opensc2k-underground-visibility-test.cfg"
	main.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	root.add_child(main)
	await process_frame
	main._set_overlay("underground")
	var checks: Dictionary = main.city_toolbar.view_visibility_checks
	assert(checks.water_mains.visible and checks.pipes.visible)
	checks.pipes.button_pressed = false
	assert(not main.show_underground_pipes and main.show_underground_water_mains)
	checks.water_mains.button_pressed = false
	assert(not main.show_underground_water_mains)
	main._on_view_menu(main.MENU_VIEW_WATER_MAINS)
	assert(main.show_underground_water_mains and not main.show_underground_pipes)
	main._set_overlay("city")
	assert(not checks.water_mains.visible and not checks.pipes.visible)
	main._ensure_scurk_print()
	main.scurk_print.configure("Water visibility", "underground", {}, false, true)
	assert(main.scurk_print.water_mains_check.visible)
	assert(main.scurk_print.options().show_water_mains)
	assert(not main.scurk_print.options().show_pipes)
	main.scurk_print.water_mains_check.set_pressed_no_signal(false)
	assert(not main.scurk_print.options().show_water_mains)
	main.free()
	print("PASS: independent water mains and building pipes, crossings, pixels, GPU draws, cache and UI")
	quit()
