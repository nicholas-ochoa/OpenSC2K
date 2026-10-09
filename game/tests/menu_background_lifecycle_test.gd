extends "res://tests/support/scene_test_case.gd"
## Hiding the menu frees its private city and buffers, late workers are drained, and reopening loads a city again.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_random_conditions()
	var sprites := FixtureGraphics.pack().large_sprites
	var palette := FixtureGraphics.pack().palette
	var folder := "user://menu-background-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder.path_join("CITIES"))
	var file := FileAccess.open(folder.path_join("CITIES/MENU.SC2"), FileAccess.WRITE)
	var fixture := CityState.from_document(EmptyCityTemplate.create(128))
	fixture.set_building_id(64, 64, 112)
	fixture.set_building_corners(64, 64, 0xf0)
	fixture.set_tile_flag(64, 64, Sc2TileFlags.POWERED, true)
	file.store_buffer(fixture.document.serialize().data)
	file.close()

	var background := MainMenuCityBackground.new()
	var launch := background.launch_conditions.duplicate()
	root.add_child(background)
	background.configure(folder, palette, sprites)
	_check_menu_conditions(background, launch)
	assert(background.demo_city != null and background.source_path.ends_with("MENU.SC2"))
	await _drain(background)
	assert(background.static_image != null and background.demo_texture != null)
	background.set_process(false)
	await _check_options(background)
	background.set_process(true)
	var expected := background.static_image.get_data()
	var view_reference: WeakRef = weakref(background.presentation.map)
	var city_reference: WeakRef = weakref(background.demo_city)
	var engine_reference: WeakRef = weakref(background.controller.engine)
	var image_reference: WeakRef = weakref(background.static_image)
	var texture_reference: WeakRef = weakref(background.demo_texture)

	background.hide()
	background.release_city()
	await process_frame
	assert(city_reference.get_ref() == null and engine_reference.get_ref() == null,
		"The hidden menu must not retain its private city or simulation")
	assert(image_reference.get_ref() == null and texture_reference.get_ref() == null,
		"The hidden menu must not retain its CPU image or GPU texture")
	assert(background.demo_city == null and background.controller == null and background.source_path.is_empty())
	assert(background.demo_palette == null and background.demo_sprites == null and background.elapsed == 0.0)
	assert(background.presentation == null and view_reference.get_ref() == null, "All menu effect layers must be freed")
	background.replace_graphics(palette, sprites)
	assert(background.render_thread == null and background.demo_sprites == null,
		"Replacing hidden menu artwork must not restart rendering or keep graphics")

	background.configure(folder, palette, sprites)
	background.show()
	_check_menu_conditions(background, launch)
	assert(background.demo_city != null and background.demo_sprites == sprites)
	await _drain(background)
	assert(background.static_image.get_data() == expected, "Reopened menu must draw a newly loaded city")

	# Hiding while a worker is running must return without joining it. Its result
	# must not recreate the released buffers when _process later collects it.
	background._start_render()
	var pending := background.render_thread
	background.hide()
	background.release_city()
	assert(background.render_thread == pending)
	await _drain(background)
	assert(background.demo_texture == null and background.static_image == null and background.presentation == null)

	# Reopening before the released city's worker finishes must discard its image
	# and render the new city after the worker is drained.
	background.configure(folder, palette, sprites)
	pending = background.render_thread
	background.release_city()
	background.configure(folder, palette, sprites)
	var city := background.demo_city
	assert(city != null and background.render_thread == pending)
	await _drain(background)
	assert(background.demo_city == city and background.static_image.get_data() == expected)

	background.queue_free()
	await process_frame
	DirAccess.remove_absolute(folder.path_join("CITIES/MENU.SC2"))
	DirAccess.remove_absolute(folder.path_join("CITIES"))
	DirAccess.remove_absolute(folder)
	print("PASS: hidden menu city and buffer release, late worker disposal and new city on return")
	quit()


func _drain(background: MainMenuCityBackground) -> void:
	var deadline := Time.get_ticks_msec() + 15000

	while background.render_thread != null and Time.get_ticks_msec() < deadline:
		await process_frame

	assert(background.render_thread == null, "Menu rendering did not finish")


func _check_options(background: MainMenuCityBackground) -> void:
	var view := background.presentation
	var app := view.app
	assert(not app.is_inside_tree() and app.document_state.current_document == null
		and app.document_state.current_save_path.is_empty(), "Menu presentation must have no player/save session")
	assert(app.asset_state.large_sprites != background.demo_sprites, "Menu options must not mutate the player's graphics")
	var source := FileAccess.get_file_as_bytes(background.source_path)
	var before := background.demo_city.document.content_snapshot()
	var engine := background.controller.engine
	var random_before := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
	var options := VisualEnhancementOptions.normalize({"day_mode": 1, "day_hour": 12.0,
		"season_enabled": false, "weather_enabled": false, "cloud_enabled": false,
		"water_reflections": 0, "water_waves_enabled": false, "water_topography": false,
		"life_cars_enabled": false, "life_people_enabled": false, "brightmaps": false})
	var saved_options := options.duplicate()
	background.set_visual_options(options)
	assert(options == saved_options, "Menu randomness must not overwrite player preferences")
	_check_menu_conditions(background, background.launch_conditions)
	assert(not app.preferences.visual_enhancements.weather_enabled and not app.preferences.visual_enhancements.brightmaps)
	# Exercise the shared renderer at known conditions independently of the menu's
	# random launch selection, so the native pixel checks remain deterministic.
	view.set_options(options)
	var camera := background._camera()
	view.advance(0.0, camera.offset, camera.scale)
	assert(app.visual_environment.tint == Color.WHITE and app.visual_environment.night == 0.0)
	var native := DisplayServer.get_name() != "headless"
	var day: Image
	if native:
		await RenderingServer.frame_post_draw
		day = root.get_texture().get_image()
	options.day_hour = 0.0
	view.set_options(options)
	view.advance(0.0, camera.offset, camera.scale)
	assert(app.visual_environment.tint.b > app.visual_environment.tint.r)
	var dark: Image
	if native:
		await RenderingServer.frame_post_draw
		dark = root.get_texture().get_image()
		assert(_brighter_pixels(day, dark) > 1000, "Menu night setting must visibly darken the rendered city")
	options.brightmaps = true
	options.night_glow = 0.0
	options.night_ground = 0.0
	view.set_options(options)
	view.advance(0.0, camera.offset, camera.scale)
	assert(app.visual_environment.night > 0.99 and view.map.city_source.emission != null)
	if native:
		await RenderingServer.frame_post_draw
		assert(_brighter_pixels(root.get_texture().get_image(), dark) > 10,
			"Included building masks must produce visible light in the menu")
	options.weather_enabled = true
	options.weather_mode = 2
	options.weather_fixed = CityVisualWeather.Kind.HEAVY_RAIN
	options.cloud_enabled = true
	options.water_reflections = 1
	options.water_waves_enabled = true
	options.season_enabled = true
	options.season_mode = 2
	options.season_fixed = 3
	view.set_options(options)
	view.advance(20.0, camera.offset, camera.scale)
	assert(app.visual_environment.weather.rain > 0.99 and app.visual_environment.weather.layer.visible)
	assert(app.visual_environment.clouds.parameters.cloud_enabled and view.map.layers.environment_parameters.water_enabled)
	assert(view.map.layers.environment_parameters.environment_seasons.w > 0.99)
	options.day_enabled = false
	options.weather_enabled = false
	options.season_enabled = false
	options.cloud_enabled = false
	options.water_reflections = 0
	options.water_waves_enabled = false
	view.set_options(options)
	view.advance(0.0, camera.offset, camera.scale)
	assert(not view.map.layers.environment_parameters.environment_enabled)
	assert(not app.visual_environment.weather.layer.visible and (app.visual_environment.clouds.layer == null or not app.visual_environment.clouds.layer.visible))
	assert(not view.map.layers.environment_parameters.water_enabled)
	assert(background.demo_city.document.content_snapshot() == before)
	assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == random_before)
	assert(FileAccess.get_file_as_bytes(background.source_path) == source)
	background.set_visual_options(VisualEnhancementOptions.normalize({}))
	_check_menu_conditions(background, background.launch_conditions)


func _check_menu_conditions(background: MainMenuCityBackground, expected: Dictionary) -> void:
	assert(background.launch_conditions == expected, "Menu re-entry must keep this launch's conditions")
	for key: String in expected:
		assert(background.visual_options[key] == expected[key])
		assert(background.presentation.app.preferences.visual_enhancements[key] == expected[key])


func _check_random_conditions() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 20261007
	var hours := {}
	var seasons := {}
	var weather := {}
	for sample in 256:
		var conditions := MainMenuCityBackground.random_conditions(random)
		assert(conditions.day_hour >= 0.0 and conditions.day_hour <= 23.99)
		assert(conditions.season_fixed in [0, 1, 2, 3])
		assert(conditions.weather_fixed >= CityVisualWeather.Kind.SUNNY and conditions.weather_fixed <= CityVisualWeather.Kind.HEAVY_SNOW)
		if conditions.weather_fixed in [CityVisualWeather.Kind.LIGHT_SNOW, CityVisualWeather.Kind.HEAVY_SNOW]:
			assert(conditions.season_fixed == 3, "Random menu snow must be seasonal")
		hours[int(conditions.day_hour / 6.0)] = true
		seasons[conditions.season_fixed] = true
		weather[conditions.weather_fixed] = true
	assert(hours.size() == 4 and seasons.size() == 4 and weather.size() == 7,
		"Menu launches must be able to select every day period, season and weather kind")


func _brighter_pixels(first: Image, second: Image) -> int:
	var count := 0
	for y in first.get_height():
		for x in first.get_width():
			if first.get_pixel(x, y).get_luminance() > second.get_pixel(x, y).get_luminance() + 0.03:
				count += 1
	return count
