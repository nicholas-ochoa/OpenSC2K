extends SceneTree

const DocumentState = preload("res://tests/support/document_state.gd")

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var defaults := VisualEnhancementOptions.normalize({})
	assert(defaults.day_seconds == 600.0)
	assert(defaults.nature_terrain_strength == 0.5)
	assert(VisualEnhancementOptions.normalize({"nature_terrain_strength": NAN}).nature_terrain_strength == 0.5)
	assert(VisualEnhancementOptions.normalize({"nature_terrain_strength": -1.0}).nature_terrain_strength == 0.0)
	assert(VisualEnhancementOptions.normalize({"nature_terrain_strength": 2.0}).nature_terrain_strength == 1.0)
	assert(defaults.night_light_strength == 100.0)
	assert(not defaults.night_daytime_enabled)
	assert(defaults.disaster_blending)
	assert(VisualEnhancementOptions.normalize({"disaster_blending": "invalid"}).disaster_blending)
	assert(VisualEnhancementOptions.normalize({"night_light_strength": NAN}).night_light_strength == 100.0)
	assert(VisualEnhancementOptions.normalize({"night_light_strength": -10}).night_light_strength == 0.0)
	assert(VisualEnhancementOptions.normalize({"night_light_strength": 150}).night_light_strength == 100.0)
	assert(VisualEnhancementOptions.normalize({"day_seconds": NAN, "weather_fixed": 100}).day_seconds == 600.0)
	var path := "user://visual_environment_%d.cfg" % OS.get_process_id()
	var save := AppSettingsStore.SaveOptions.new()
	save.visual_enhancements = VisualEnhancementOptions.normalize({"day_mode": 1, "day_hour": 7.0, "weather_fixed": 6})
	save.visual_enhancements.day_lut_strength = 0.25
	save.visual_enhancements.nature_terrain_strength = 0.3
	save.visual_enhancements.season_lut_strength = 0.75
	save.visual_enhancements.weather_lut_strength = 0.0
	save.visual_enhancements.night_light_strength = 35.0
	save.visual_enhancements.night_daytime_enabled = true
	save.visual_enhancements.disaster_blending = false
	assert(AppSettingsStore.save_values(0.5, 0.5, false, path, save) == OK)
	assert(AppSettingsStore.load_values(path).visual_enhancements == save.visual_enhancements)
	assert(AppSettingsStore.save_values(0.4, 0.4, false, path) == OK)
	assert(AppSettingsStore.load_values(path).visual_enhancements == save.visual_enhancements)
	var morning := CityVisualEnvironment.light_at_hour(7.0)
	var evening := CityVisualEnvironment.light_at_hour(19.0)
	assert(morning.tint.b > morning.tint.r)
	assert(evening.tint.r > evening.tint.g and evening.tint.g > evening.tint.b)
	assert(CityVisualEnvironment.light_at_hour(12.0).tint == Color.WHITE)
	assert(CitySeasonColors.weights(1.0, 0.35) == Vector4(0, 1, 0, 0))
	assert(CitySeasonColors.weights(3.9, 0.35).x > 0.0)
	for pair in [[6, 5], [7, 1], [9, 6], [10, 3], [11, 4], [1, 0]]:
		assert(CityVisualWeather.from_game(pair[0], false) == pair[1])
	assert(CityVisualWeather.from_game(7, true) == 2)
	_check_brightmaps()
	_check_standard_brightmaps()
	_check_zone_soil_masks()
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	assert(main.city_session.activate_document(EmptyCityTemplate.create(128)))
	var before := DocumentState.capture(main.document_state.city.document)
	var engine := main.simulation_state.simulation_engine
	var random_before := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
	_check_power_warning_clock(main)
	main.preferences.visual_enhancements = defaults.duplicate()
	main.preferences.visual_enhancements.pause_freezes = false
	main.visual_environment.process(0.0)
	for speed in [2, 3, 4, 5]:
		main.simulation_state.speed_controller.speed = speed as GameSpeedController.Speed
		main.visual_environment.phase = 0.0
		main.visual_environment.process(60.0)
		assert(is_equal_approx(main.visual_environment.phase, 0.1 * VisualEnhancementOptions.speed_factor(speed)))
	main.preferences.visual_enhancements.pause_freezes = true
	main.simulation_state.speed_controller.speed = GameSpeedController.Speed.PAUSED
	var paused_phase := main.visual_environment.phase
	main.visual_environment.process(60.0)
	assert(main.visual_environment.phase == paused_phase)
	_check_weather_pause(main)
	main.preferences.visual_enhancements.day_mode = 1
	main.preferences.visual_enhancements.day_hour = 7.0
	main.preferences.visual_enhancements.weather_mode = 2
	main.preferences.visual_enhancements.season_mode = 2
	main.preferences.visual_enhancements.season_fixed = 3
	for kind in range(7):
		main.preferences.visual_enhancements.weather_fixed = kind
		main.visual_environment.process(5.0)
		assert(main.visual_environment.weather.kind == kind)
	main.preferences.visual_enhancements.weather_fixed = 0
	main.visual_environment.process(5.0)
	assert(main.visual_environment.weather.tint == Color.WHITE)
	assert(main.visual_environment.weather.rain == 0.0 and main.visual_environment.weather.snow == 0.0)
	# Select the actual settings controls, starting from disabled Game weather.
	main.preferences.visual_enhancements.weather_enabled = false
	main.preferences.visual_enhancements.weather_mode = 0
	main.settings.open_settings_dialog()
	var tab := main.main_overlays.settings_dialog.visual_tab
	tab.terrain_strength_slider.value = 25.0
	assert(main.preferences.visual_enhancements.nature_terrain_strength == 0.25)
	main.visual_environment.process(0.0)
	assert(main.map_view.layers.environment_parameters.nature_terrain_strength == 0.25)
	_check_menu_dependencies(tab)
	await _check_visual_save(main, tab)
	(tab.controls.disaster_blending as CheckBox).button_pressed = false
	assert(not main.preferences.visual_enhancements.disaster_blending)
	(tab.controls.disaster_blending as CheckBox).button_pressed = true
	assert(main.preferences.visual_enhancements.disaster_blending)
	(tab.controls.weather_enabled as CheckBox).button_pressed = true
	var weather_source := tab.controls.weather_mode as OptionButton
	weather_source.select(2)
	weather_source.item_selected.emit(2)
	(tab.controls.day_lut_strength as SpinBox).value = 20.0
	(tab.controls.season_lut_strength as SpinBox).value = 80.0
	(tab.controls.weather_lut_strength as SpinBox).value = 60.0
	assert(main.preferences.visual_enhancements.day_lut_strength == 0.2)
	assert(main.preferences.visual_enhancements.season_lut_strength == 0.8)
	assert(main.preferences.visual_enhancements.weather_lut_strength == 0.6)
	var fixed := tab.controls.weather_fixed as OptionButton
	assert(not fixed.disabled)
	fixed.select(CityVisualWeather.Kind.HEAVY_RAIN)
	fixed.item_selected.emit(CityVisualWeather.Kind.HEAVY_RAIN)
	assert(main.preferences.visual_enhancements.weather_enabled)
	assert(main.preferences.visual_enhancements.weather_mode == 2)
	main.visual_environment.process(5.0)
	assert(main.visual_environment.weather.kind == CityVisualWeather.Kind.HEAVY_RAIN)
	assert(main.visual_environment.weather.rain == 1.0)
	assert(main.visual_environment.weather.layer.visible)
	# Exercise the real menu action. Water must also leave the vanilla path
	# even when its independent options and the other effects were enabled.
	var before_disable := tab.selected_values()
	for control in tab.find_children("*", "Button", true, false):
		if control.text == "Disable all":
			control.pressed.emit()
	main.visual_environment.process(0.0)
	var parameters := main.map_view.layers.environment_parameters
	assert(not parameters.water_enabled and not parameters.water_reflections_enabled)
	assert(not parameters.water_topography and not parameters.environment_enabled)
	assert(not parameters.cloud_enabled)
	assert(not main.visual_environment.weather.layer.visible)
	assert(main.preferences.visual_enhancements.water_reflections == 0)
	assert(not main.preferences.visual_enhancements.water_topography)
	# Restore the fixture through the menu too, including its saved controls.
	tab.show_values(before_disable)
	tab.changed.emit()
	# LUT feedback must be owned by the exclusive Settings window, so another
	# exclusive child is not incorrectly opened beside it under the root.
	var settings := main.main_overlays.settings_dialog
	main.visual_environment.reload_luts()
	await process_frame
	assert(settings.visual_message_dialog.get_parent() == settings)
	assert(settings.visual_message_dialog.visible)
	assert(settings.visual_message_dialog.dialog_text == "LUT profiles reloaded.")
	settings.visual_message_dialog.hide()
	main.main_overlays.settings_dialog.hide()
	assert(DocumentState.capture(main.document_state.city.document) == before)
	assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == random_before)
	# Change only a disposable fixture; Game weather must observe each change,
	# even while the game is paused, without changing it or consuming its RNG.
	main.preferences.visual_enhancements.weather_mode = 0
	for pair in [[6, 5], [7, 1], [9, 6], [10, 3], [11, 4], [1, 0]]:
		main.document_state.city.document.set_misc_u32(Sc2MiscLayout.WEATHER_TREND, pair[0])
		before = DocumentState.capture(main.document_state.city.document)
		main.visual_environment.weather.random.seed = 20
		main.visual_environment.process(5.0)
		var kind: int = main.visual_environment.weather.kind
		assert(kind == pair[1] or (pair[0] == 7 and kind == 2))
		assert(DocumentState.capture(main.document_state.city.document) == before)
		assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == random_before)
	# Fixed weather overrides the winter restriction; game weather retains it.
	for mode in [0, 2]:
		main.preferences.visual_enhancements.weather_mode = mode
		for pair in [[6, 5, 1], [9, 6, 2]]:
			main.document_state.city.document.set_misc_u32(Sc2MiscLayout.WEATHER_TREND, pair[0])
			main.preferences.visual_enhancements.weather_fixed = pair[1]
			before = DocumentState.capture(main.document_state.city.document)
			main.preferences.visual_enhancements.season_fixed = 3
			main.visual_environment.process(5.0)
			assert(main.visual_environment.weather.kind == pair[1] and main.visual_environment.weather.snow > 0.0)
			for season in range(3):
				main.preferences.visual_enhancements.season_fixed = season
				main.visual_environment.process(0.0)
				if mode == 2:
					assert(main.visual_environment.weather.kind == pair[1])
					assert(main.visual_environment.weather.snow > 0.0 and main.visual_environment.weather.frost > 0.0)
					assert(main.visual_environment.weather.rain == 0.0)
				else:
					assert(main.visual_environment.weather.kind == pair[2])
					assert(main.visual_environment.weather.snow == 0.0 and main.visual_environment.weather.frost == 0.0)
			main.preferences.visual_enhancements.season_fixed = 3
			main.visual_environment.process(5.0)
			assert(main.visual_environment.weather.kind == pair[1] and main.visual_environment.weather.snow > 0.0)
			assert(DocumentState.capture(main.document_state.city.document) == before)
			assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == random_before)
	# Fixed snow also works with seasons disabled. Returning to either automatic
	# source removes the override immediately, without waiting for a new interval.
	main.preferences.visual_enhancements.season_enabled = false
	main.preferences.visual_enhancements.season_fixed = 1
	main.visual_environment.process(5.0)
	assert(main.visual_environment.weather.kind == CityVisualWeather.Kind.HEAVY_SNOW)
	assert(main.visual_environment.weather.snow > 0.0)
	for mode in [0, 1]:
		main.preferences.visual_enhancements.weather_mode = 2
		main.visual_environment.process(5.0)
		assert(main.visual_environment.weather.snow > 0.0)
		main.preferences.visual_enhancements.weather_mode = mode
		if mode == 1:
			main.visual_environment.weather.last_mode = mode
			main.visual_environment.weather.interval = 0.0
		main.visual_environment.process(0.0)
		assert(main.visual_environment.weather.kind == CityVisualWeather.Kind.HEAVY_RAIN)
		assert(main.visual_environment.weather.snow == 0.0 and main.visual_environment.weather.frost == 0.0)
	main.preferences.visual_enhancements.season_enabled = true
	main.preferences.visual_enhancements.season_fixed = 3
	# Surface color stays available with reflection and seabed display off.
	main.preferences.visual_enhancements.water_reflections = 0
	main.preferences.visual_enhancements.water_topography = false
	main.preferences.visual_enhancements.water_waves_enabled = false
	main.visual_environment.configure()
	assert(main.map_view.layers.environment_parameters.water_enabled)
	assert(main.map_view.layers.environment_parameters.water_season_strength == 0.35)
	main.preferences.visual_enhancements.season_enabled = false
	main.visual_environment.configure()
	assert(not main.map_view.layers.environment_parameters.water_enabled)
	assert(main.map_view.layers.environment_parameters.water_season_strength == 0.0)
	# Turning off night lights must leave ambient night saturation intact.
	main.preferences.visual_enhancements.day_hour = 0.0
	main.preferences.visual_enhancements.brightmaps = false
	main.visual_environment.process(0.0)
	assert(is_equal_approx(main.map_view.layers.environment_parameters.environment_saturation, 0.78))
	assert(main.map_view.layers.environment_parameters.environment_night == 0.0)
	main.preferences.visual_enhancements.brightmaps = true
	main.visual_environment.process(0.0)
	assert(is_equal_approx(main.map_view.layers.environment_parameters.environment_saturation, 0.78))
	assert(main.map_view.layers.environment_parameters.environment_night == 1.0)
	var night_tint := main.visual_environment.tint
	main.preferences.visual_enhancements.night_strength = 0.0
	main.visual_environment.process(0.0)
	assert(main.visual_environment.night == 1.0, "Ambient darkness still controls artificial light activation")
	main.preferences.visual_enhancements.night_strength = 1.0
	for strength in [0.0, 35.0, 100.0]:
		main.preferences.visual_enhancements.night_light_strength = strength
		main.visual_environment.process(0.0)
		assert(is_equal_approx(main.visual_environment.night, strength / 100.0))
		assert(is_equal_approx(main.map_view.layers.environment_parameters.environment_night, strength / 100.0))
		assert(main.visual_environment.tint == night_tint)
		assert(is_equal_approx(main.map_view.layers.environment_parameters.environment_saturation, 0.78))
	var prior_options := main.preferences.visual_enhancements.duplicate()
	main.preferences.visual_enhancements.day_hour = 12.0
	main.preferences.visual_enhancements.pause_freezes = true
	main.preferences.visual_enhancements.night_daytime_enabled = false
	main.visual_environment.process(0.0)
	var daylight := main.map_view.layers.environment_parameters.duplicate()
	assert(main.visual_environment.night == 0.0)
	main.preferences.visual_enhancements.night_daytime_enabled = true
	main.visual_environment.process(0.0)
	assert(main.visual_environment.night == 1.0)
	for key in ["environment_tint", "environment_saturation", "environment_ambient_lift", "environment_day_lut_weights", "environment_day_lut_strength"]:
		assert(main.map_view.layers.environment_parameters[key] == daylight[key], "Daytime lights changed ambient grading")
	main.preferences.visual_enhancements.day_enabled = false
	main.preferences.visual_enhancements.season_enabled = false
	main.preferences.visual_enhancements.weather_enabled = false
	main.preferences.visual_enhancements.night_light_strength = 35.0
	main.visual_environment.process(0.0)
	assert(main.map_view.layers.environment_parameters.environment_enabled)
	assert(is_equal_approx(main.visual_environment.night, 0.35))
	assert(main.map_view.layers.environment_parameters.environment_ambient_lift == 0.0)
	main.preferences.visual_enhancements.night_light_strength = 0.0
	main.visual_environment.process(0.0)
	assert(main.visual_environment.night == 0.0)
	main.preferences.visual_enhancements.night_light_strength = 100.0
	main.preferences.visual_enhancements.brightmaps = false
	main.visual_environment.process(0.0)
	assert(main.visual_environment.night == 0.0)
	main.preferences.visual_enhancements.brightmaps = true
	main.preferences.visual_enhancements.night_daytime_enabled = false
	main.visual_environment.process(0.0)
	assert(not main.map_view.layers.environment_parameters.environment_enabled)
	assert(main.visual_environment.night == 0.0)
	main.preferences.visual_enhancements = prior_options
	main.visual_environment.process(0.0)
	assert(DocumentState.capture(main.document_state.city.document) == before)
	assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == random_before)
	# A newly loaded sunny document must not inherit the previous snowstorm.
	await _check_ground_lighting(main)
	main.preferences.visual_enhancements.season_enabled = true
	main.preferences.visual_enhancements.weather_mode = 2
	main.preferences.visual_enhancements.weather_fixed = CityVisualWeather.Kind.HEAVY_SNOW
	main.visual_environment.process(5.0)
	assert(main.visual_environment.weather.snow > 0.0)
	var sunny_document := EmptyCityTemplate.create(128)
	sunny_document.set_misc_u32(Sc2MiscLayout.WEATHER_TREND, 1)
	main.preferences.visual_enhancements.weather_mode = 0
	assert(main.city_session.activate_document(sunny_document))
	main.visual_environment.process(0.0)
	assert(main.visual_environment.weather.tint == Color.WHITE)
	assert(main.visual_environment.weather.rain == 0.0 and main.visual_environment.weather.snow == 0.0 and main.visual_environment.weather.frost == 0.0)
	assert(not main.visual_environment.weather.layer.visible)
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS: cosmetic clocks, speed, pause, grading, seasons, weather mapping, settings preservation and unchanged city/RNG")
	quit()


func _check_weather_pause(main: CityApplication) -> void:
	var saved := main.preferences.visual_enhancements.duplicate()
	var environment := main.visual_environment
	var weather := environment.weather
	for freeze_cycles in [true, false]:
		main.preferences.visual_enhancements = VisualEnhancementOptions.normalize({
			"weather_mode": 2, "weather_fixed": CityVisualWeather.Kind.RAIN_STORM,
			"season_mode": 2, "season_fixed": 3, "pause_freezes": freeze_cycles})
		for kind in [CityVisualWeather.Kind.RAIN_STORM, CityVisualWeather.Kind.HEAVY_SNOW]:
			main.simulation_state.speed_controller.speed = GameSpeedController.Speed.TURTLE
			main.preferences.visual_enhancements.weather_fixed = kind
			environment.process(0.25)
			var frozen := _weather_snapshot(environment)
			main.simulation_state.speed_controller.speed = GameSpeedController.Speed.PAUSED
			for frame in 3:
				environment.process(20.0)
			assert(_weather_snapshot(environment) == frozen, "Pause advanced weather particles, a front, lightning, clouds or fog")
			assert(weather.material.get_shader_parameter("clock") == weather.clock)
			main.simulation_state.speed_controller.speed = GameSpeedController.Speed.TURTLE
			environment.process(0.1)
			assert(is_equal_approx(weather.clock, float(frozen[0]) + 0.1), "Weather caught up paused time")
		main.simulation_state.speed_controller.speed = GameSpeedController.Speed.PAUSED
		main.preferences.visual_enhancements.weather_mode = 1
		environment.process(0.0)
		var selection := [weather.selected_kind, weather.interval, weather.random.state]
		environment.process(600.0)
		assert([weather.selected_kind, weather.interval, weather.random.state] == selection, "Paused automation chose new weather")
	main.preferences.visual_enhancements = saved
	environment.process(0.0)


func _weather_snapshot(environment: CityVisualEnvironment) -> Array:
	var weather := environment.weather
	var clouds := environment.clouds
	return [weather.clock, weather.rain, weather.snow, weather.frost, weather.tint, weather.flash,
		weather.lightning.wait, weather.lightning.age, weather.lightning.thunder_wait,
		weather.lightning.random.state, environment.profiles.weather_weights.duplicate(),
		clouds.drift, clouds.density, clouds.fog, clouds.weather_clock, clouds.opacity]


func _check_ground_lighting(main: CityApplication) -> void:
	# This cache regression explicitly exercises lights at every zoom level.
	main.preferences.visual_enhancements.detail_lights_min_zoom = 0
	var city := load("res://tests/city_life_test.gd").fixture() as CityState
	assert(main.city_session.activate_document(city.document))
	var ground := CityNightGround.new()
	root.add_child(ground)
	var tile := Vector2i(64, 64)
	var before := DocumentState.capture(city.document)
	var lights := ground.sources(city, tile)
	assert(not lights.is_empty())
	var surface := ground._build(main, tile)
	var image: Image = surface.texture.get_image()
	assert(not surface.fixtures.get_image().is_invisible(), "Street poles and lamp heads are missing")
	assert(surface.signals.size() == 4, "A connected four-way junction needs four signal faces")
	for seconds in 28:
		var a := CityNightFixtures.signal_lens(tile, 0, seconds * 0.5)
		var b := CityNightFixtures.signal_lens(tile, 1, seconds * 0.5)
		assert(a == 0 or b == 0, "Crossing cosmetic signals showed conflicting green or amber")
	assert(CityNightFixtures.signal_directions(city, Vector2i(64, 65)).is_empty(), "Straight road received junction signals")
	var lit := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).r > 0.0:
				lit += 1
	assert(lit > 5 and lit < 800, "Local light failed to stay inside the narrow road receiver")
	var cover := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	cover.fill(Color.WHITE)
	for axis in 2:
		ground.masker._occluders[Vector3i(64, 64, axis)] = [{"origin": surface.origin, "image": cover}]
	var hidden_surface := ground._build(main, tile)
	var hidden: Image = hidden_surface.texture.get_image()
	assert(hidden_surface.fixtures.get_image().is_invisible(), "Street fixture painted over an opaque foreground surface")
	for signal_light: Dictionary in hidden_surface.signals:
		for lens: Texture2D in signal_light.lenses:
			assert(lens.get_image().is_invisible(), "Junction signal leaked through foreground geometry")
	for y in hidden.get_height():
		for x in hidden.get_width():
			assert(hidden.get_pixel(x, y).r == 0.0, "Ground light painted over an opaque foreground surface")
	assert(DocumentState.capture(city.document) == before)
	# Only ordinary junctions receive signals, never grade-separated crossings.
	var junctions := load("res://tests/city_life_test.gd").fixture() as CityState
	junctions.set_building_id(64, 64, BuildingTileIds.ROAD_JUNCTION_1)
	assert(CityNightFixtures.signal_directions(junctions, tile).size() == 3)
	for id in [BuildingTileIds.HIGHWAY_INTERSECTION, BuildingTileIds.HIGHWAY_ROAD_CROSSING_1,
		BuildingTileIds.ROAD_RAIL_CROSSING_1, BuildingTileIds.ROAD_BRIDGE]:
		junctions.set_building_id(64, 64, id)
		assert(CityNightFixtures.signal_directions(junctions, tile).is_empty())
	junctions.set_building_id(0, 0, BuildingTileIds.ROAD_CROSSROADS)
	assert(CityNightFixtures.signal_directions(junctions, Vector2i.ZERO).is_empty())
	# Every highway family has lamps, while rail and empty terrain do not.
	for id in [BuildingTileIds.HIGHWAY_STRAIGHT_1, BuildingTileIds.HIGHWAY_STRAIGHT_2,
		BuildingTileIds.HIGHWAY_ROAD_CROSSING_1, BuildingTileIds.HIGHWAY_POWER_CROSSING_2,
		BuildingTileIds.HIGHWAY_ONRAMP_1, BuildingTileIds.HIGHWAY_SLOPE_1,
		BuildingTileIds.HIGHWAY_CURVE_1, BuildingTileIds.HIGHWAY_INTERSECTION,
		BuildingTileIds.HIGHWAY_BRIDGE, BuildingTileIds.REINFORCED_HIGHWAY_BRIDGE]:
		junctions.set_building_id(64, 64, id)
		assert(not CityNightFixtures.street_layout(junctions, tile, 2).is_empty(), "Missing highway lamps: %d" % id)
	for id in [0, BuildingTileIds.RAIL_STRAIGHT_1]:
		junctions.set_building_id(64, 64, id)
		assert(CityNightFixtures.street_layout(junctions, tile, 2).is_empty())
	# Road and raised highway receivers follow each of the four terrain inclines.
	for road in [BuildingTileIds.ROAD_STRAIGHT_1, BuildingTileIds.HIGHWAY_STRAIGHT_1]:
		for shape in range(1, 5):
			var enter := 0 if shape % 2 == 0 else 1
			junctions.set_building_id(64, 64, road + enter)
			junctions.set_terrain_id(64, 64, shape)
			var receiver := CityLifeLights.new()
			var samples := 0
			for patch: Dictionary in receiver._road_patches(junctions, tile, enter):
				var pixels: Image = patch.image
				for y in pixels.get_height():
					for x in pixels.get_width():
						var sample := pixels.get_pixel(x, y)
						if sample.a <= 0.0:
							continue
						var offset := Vector2(sample.r, sample.g) - Vector2(tile)
						var t := 0.5 - offset.dot(Vector2(CityLifePaths.DIRECTIONS[enter]))
						var height := lerpf(CityLifePaths.edge_height(junctions, tile, enter), CityLifePaths.edge_height(junctions, tile, (enter + 2) % 4), t)
						var expected := CityLifeLights._project(junctions, tile, offset, height)
						assert(expected.distance_to(Vector2(patch.origin) + Vector2(x + 0.5, y + 0.5)) < 0.01, "Light receiver left the sloping road")
						samples += 1
			assert(samples > 20)
	# Lamp feet also follow the bent grade between a road and a raised onramp.
	junctions.set_terrain_id(64, 64, 0)
	for ramp in range(BuildingTileIds.HIGHWAY_ONRAMP_1, BuildingTileIds.HIGHWAY_ONRAMP_4 + 1):
		junctions.set_building_id(64, 64, ramp)
		var high := CityLifePaths.ramp_highway_direction(junctions, tile)
		var low := CityLifePaths.ramp_road_direction(junctions, tile)
		for direction in [high, low]:
			var offset := Vector2(CityLifePaths.DIRECTIONS[direction]) * 0.32
			var height := 0.82 if direction == high else 0.18
			var expected := Vector2i(CityLifeLights._project(junctions, tile, offset, height).round())
			assert(CityNightFixtures._foot(junctions, tile, offset, high) == expected, "Lamp foot floats above its onramp")
	await _check_ground_buffer(main, ground)
	load("res://tests/support/night_template_checks.gd").run(main)
	ground.queue_free()
	await process_frame


func _check_ground_buffer(main: CityApplication, ground: CityNightGround) -> void:
	var regions := main.render_caches.region_cache
	main.render_caches.region_cache = null
	var map := main.map_view
	var old_source := map.city_source
	map.set_city_view(main.document_state.city, CityMapTexture.create(Image.create(4160, 2944, false, Image.FORMAT_RGBA8)))
	ground.reset()
	map.center_on_tile(Vector2i(64, 64))
	for frame in 160:
		ground.sync(main, 0.0, 0.0, true)
	assert(not ground.visible and not ground.cache.is_empty(), "Daytime failed to prepare hidden night receivers")
	var daytime := ground.cache.duplicate()
	ground.sync(main, 0.45)
	for tile in daytime:
		assert(ground.cache[tile].texture == daytime[tile].texture, "Night discarded a prepared GPU texture")
	for i in 160:
		ground.sync(main, 0.45)
	assert(ground.cache.size() > 10)
	var saved := ground.cache.duplicate()
	var old_zoom := map.zoom_factor
	var selected := ground.visible_tiles.duplicate()
	for zoom in [0.5, 0.25, 1.0, 2.0]:
		map.zoom_factor = zoom
		map.center_on_tile(Vector2i(64, 64))
		ground.sync(main, 0.45)
		for tile in selected:
			var point := CityLifePaths.point(main.document_state.city, tile, 0, 2, 0.5, false)
			if ground.bounds.has_point(Vector2i(point)):
				assert(ground.visible_tiles.has(tile), "Zoom removed a street fixture inside the visible area")
			if ground.cache.has(tile) and saved.has(tile):
				assert(ground.cache[tile].origin == saved[tile].origin, "Zoom moved a street fixture in world space")
	map.zoom_factor = old_zoom
	map.center_on_tile(Vector2i(64, 64))
	ground.sync(main, 0.45)
	saved = ground.cache.duplicate()
	# A new streamed source and render epoch must never empty complete receivers.
	for i in 4:
		main.static_render_state.epoch += 1
		map.city_source = CityMapTexture.create(Image.create(4160, 2944, false, Image.FORMAT_RGBA8))
		ground.sync(main, 0.45)
		for tile in saved:
			assert(ground.cache.has(tile) and ground.cache[tile].texture == saved[tile].texture, "Source publication discarded stable street lights")
	map.city_source = old_source
	map.pan_screen(Vector2(240, 0))
	ground.sync(main, 0.45)
	map.pan_screen(Vector2(-240, 0))
	ground.sync(main, 0.45)
	for tile in saved:
		assert(ground.cache.has(tile) and ground.cache[tile].texture == saved[tile].texture, "Short camera pan discarded the light buffer")
	var tile: Vector2i = saved.keys()[0]
	ground.invalidate_regions([Rect2i(saved[tile].origin, Vector2i(64, 64))])
	assert(ground.dirty.has(tile) and ground.cache[tile].texture == saved[tile].texture, "Refresh blanked a complete receiver")
	for i in 160:
		ground.sync(main, 0.45)
	assert(is_same(ground.cache[tile], saved[tile]) and not ground.dirty.has(tile), "Unchanged foreground rebuilt completed lighting")
	ground.invalidate_all()
	for i in 160:
		ground.sync(main, 0.45)
	assert(not is_same(ground.cache[tile], saved[tile]), "Forced geometry refresh reused an incompatible receiver")
	assert(ground.pending.is_empty() and ground.queued.is_empty(), "Stable receivers kept pending work")
	for frame in 8:
		ground.sync(main, 0.45, 1.0)
	assert(ground.pending.is_empty() and ground.queued.is_empty(), "Signal phases scheduled static rebuilds")
	# Demolition and rebuilding change the visible fixtures while an unrelated
	# cached street retains its complete entry.
	var demolished := Vector2i(64, 64)
	var city := main.document_state.city
	var road := city.building_id(demolished.x, demolished.y)
	var distant := Vector2i(64, 60)
	var retained: Dictionary = ground.cache[distant]
	city.set_building_id(demolished.x, demolished.y, 0)
	ground.sync(main, 0.45)
	assert(not ground.visible_keys.has(demolished), "Demolished road retained its lamp")
	assert(is_same(ground.cache[distant], retained), "Local road edit discarded distant lighting")
	city.set_building_id(demolished.x, demolished.y, road)
	for frame in 160:
		ground.sync(main, 0.45)
	assert(ground.visible_keys.has(demolished) and not ground.dirty.has(demolished), "Rebuilt road never regained its lighting")
	_check_changed_light_occlusion(main, ground, demolished)
	map.city_source = old_source
	main.render_caches.region_cache = regions
	_check_resident_lights()
	_check_light_graphics_caches(main)
	print("PASS: street light buffer survives source publications and panning; dirty receivers replace atomically")


func _check_changed_light_occlusion(main: CityApplication, ground: CityNightGround, tile: Vector2i) -> void:
	var old_large := main.asset_state.large_sprites
	var old_small := main.asset_state.small_medium_sprites
	var old_commands := main.render_caches.static_occlusion_commands.duplicate()
	var old_grid := main.render_caches.static_occlusion_grid
	var archive := Sc2SpriteArchive.new()
	main.asset_state.large_sprites = archive
	main.asset_state.small_medium_sprites = archive
	for frame in 160:
		ground.sync(main, 0.45)
	var original: Dictionary = ground.cache[tile]
	var pixels: PackedByteArray = original.texture.get_image().get_data()
	var divisor := CityIsometricRenderer.view_configuration(main.static_render.city_view_size()).divisor
	var cover := CityStaticCommand.new()
	cover.sprite_id = 42
	cover.position = (original.origin - Vector2i(32, 32)) / divisor
	cover.size = Vector2i(128, 128) / divisor
	cover.depth_order = 10000000
	var resource := CitySpriteResource.new()
	resource.image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	resource.image.fill(Color.WHITE)
	var resource_key := "42:0:%d:1:%d" % [divisor, archive.get_instance_id()]
	main.render_caches.dynamic_sprite_cache[resource_key] = resource
	var changed: Array[Rect2i] = [Rect2i(original.origin, Vector2i(64, 64))]
	# Streamed publications report possible changes. A new actual silhouette
	# must replace the complete receiver, while repeat publications retain it.
	main.render_caches.static_occlusion_commands.assign([cover])
	main.render_caches.static_occlusion_grid = CityIsometricRenderer.build_occlusion_grid(main.render_caches.static_occlusion_commands, divisor)
	ground.invalidate_regions(changed)
	for frame in 160:
		ground.sync(main, 0.45)
	var hidden: Dictionary = ground.cache[tile]
	assert(not is_same(hidden, original) and hidden.texture.get_image().get_data() != pixels)
	assert(hidden.fixtures.get_image().is_invisible(), "Reused lights leaked through a new foreground building")
	ground.invalidate_regions(changed)
	for frame in 160:
		ground.sync(main, 0.45)
	assert(is_same(ground.cache[tile], hidden), "Identical silhouettes rebuilt their mask")
	main.render_caches.static_occlusion_commands.assign(old_commands)
	main.render_caches.static_occlusion_grid = old_grid
	ground.invalidate_regions(changed)
	for frame in 160:
		ground.sync(main, 0.45)
	assert(ground.cache[tile].texture.get_image().get_data() == pixels, "Removed building left stale light occlusion")
	main.render_caches.dynamic_sprite_cache.erase(resource_key)
	main.asset_state.large_sprites = old_large
	main.asset_state.small_medium_sprites = old_small


func _check_resident_lights() -> void:
	var ground := CityNightGround.new()
	var pixels := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(pixels)
	var entry := {"texture": texture, "fixtures": texture, "signals": [], "origin": Vector2i.ZERO}
	for i in 5000:
		ground._store(Vector2i(i, 0), entry)
	ground._trim_cache()
	assert(ground.cache.size() == 5000, "Cheap shared light textures were evicted at the old tile limit")
	assert(ground.texture_bytes == 64 * 64 * 4, "Shared GPU textures were counted repeatedly")
	ground._release(Vector2i.ZERO)
	assert(ground.texture_bytes == 64 * 64 * 4)
	ground.reset()
	assert(ground.texture_bytes == 0 and ground.texture_users.is_empty())
	# The real byte cap removes oldest offscreen output, protecting the visible light.
	for i in 25:
		var large := ImageTexture.create_from_image(Image.create(1024, 1024, false, Image.FORMAT_RGBA8))
		ground._store(Vector2i(i, 0), {"texture": large, "fixtures": large, "signals": [], "origin": Vector2i.ZERO})
		ground.last_used[Vector2i(i, 0)] = i
	ground.visible_keys[Vector2i.ZERO] = true
	ground._trim_cache()
	assert(ground.texture_bytes <= CityNightGround.MAX_TEXTURE_BYTES)
	assert(ground.cache.has(Vector2i.ZERO) and not ground.cache.has(Vector2i(1, 0)))
	ground.free()


func _check_light_graphics_caches(main: CityApplication) -> void:
	var lights := main.visual_environment.night_lighting
	var pixels := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(pixels)
	var tile := Vector2i(64, 64)
	var original_view := main.static_render.city_view_size()
	for view in 3:
		lights._select_ground(view)
		lights.ground._store(tile, {"texture": texture, "fixtures": texture, "signals": [], "origin": Vector2i.ZERO})
		lights.ground.visible_keys[tile] = true
		lights.ground.show()
	var large := lights.ground_views[2]
	var entry: Dictionary = large.cache[tile]
	for view in [1, 2, 0, 2, 1, 2]:
		var previous := lights.ground
		lights._select_ground(view)
		assert(not previous.visible, "An inactive graphics-size light layer stayed visible")
		assert(lights.ground.cache[tile].texture == texture)
		assert(is_same(large.cache[tile], entry), "Graphics-size switching discarded a completed light entry")
	assert(lights.ground_views.size() == 3)
	lights.invalidate_regions([Rect2i(0, 0, 64, 64)])
	for receiver in lights.ground_views.values():
		assert(receiver.dirty.has(tile), "A hidden graphics-size variant missed a local edit")
	lights.reset()
	for receiver in lights.ground_views.values():
		assert(receiver.cache.is_empty() and receiver.texture_bytes == 0)
	lights._select_ground(original_view)
	var old_source := main.map_view.city_source
	main.map_view.set_city_view(main.document_state.city, CityMapTexture.create(Image.create(4160, 2944, false, Image.FORMAT_RGBA8)))
	var options := main.preferences.visual_enhancements.duplicate()
	options.night_ground = 45.0
	var old_sizes := main.preferences.zoom_graphics.duplicate()
	var old_zoom := main.map_view.zoom_factor
	var regions := main.render_caches.region_cache
	main.render_caches.region_cache = null
	main.preferences.zoom_graphics = [1, 2, 2, 2, 2, 2]
	var snapshots := {}
	var old_large := main.asset_state.large_sprites
	var old_small := main.asset_state.small_medium_sprites
	main.asset_state.large_sprites = Sc2SpriteArchive.new()
	main.asset_state.small_medium_sprites = Sc2SpriteArchive.new()
	var old_traffic := main.asset_state.large_sprites.visual_city_life_traffic
	for zoom in [0.5, 0.25, 0.5, 1.0, 2.0, 0.25, 0.5]:
		main.map_view.zoom_factor = zoom
		main.map_view.center_on_tile(tile)
		# The real frame switches decorative traffic at 50%, increasing both
		# archive revisions. A bare lighting call misses this reset regression.
		main.city_life._sync_traffic(zoom >= 0.5)
		main.render_caches.region_cache = null
		var view := main.static_render.city_view_size()
		assert(view == (1 if zoom == 0.25 else 2))
		lights.process(true, 0.45, options)
		if snapshots.has(view):
			assert(is_same(lights.ground.cache[tile], snapshots[view]), "25/50 zoom transition rebuilt an unchanged receiver")
		else:
			for frame in 160:
				lights.process(true, 0.45, options)
			assert(lights.ground.cache.has(tile))
			snapshots[view] = lights.ground.cache[tile]
	main.city_life._sync_traffic(old_traffic)
	main.asset_state.large_sprites = old_large
	main.asset_state.small_medium_sprites = old_small
	main.map_view.city_source = old_source
	main.preferences.zoom_graphics = old_sizes
	main.map_view.zoom_factor = old_zoom
	main.render_caches.region_cache = regions
	lights.reset()
	lights._select_ground(original_view)


func _check_power_warning_clock(main: CityApplication) -> void:
	var clock := main.palette_clock
	clock.cycle_ticks = 0
	clock.elapsed_msec = 0.0
	main.static_render.update_palette_cycle_texture()
	main.simulation_state.speed_controller.speed = GameSpeedController.Speed.TURTLE
	main.preferences.visual_enhancements.disaster_enabled = false
	main.preferences.visual_enhancements.disaster_blending = true
	main.frame._advance_palette_animation(GameSpeedController.BASE_TICK_MSEC / 2000.0, false)
	assert(is_equal_approx(main.map_view.layers._power_warning_blend, 0.5))
	var ticks := clock.cycle_ticks
	var elapsed := clock.elapsed_msec
	main.frame._advance_palette_animation(1.0, true)
	assert(clock.cycle_ticks == ticks and clock.elapsed_msec == elapsed)
	main.simulation_state.speed_controller.speed = GameSpeedController.Speed.PAUSED
	main.frame._advance_palette_animation(1.0, false)
	assert(clock.cycle_ticks == ticks and clock.elapsed_msec == elapsed)
	main.preferences.visual_enhancements.disaster_blending = false
	main.frame._advance_palette_animation(0.0, true)
	assert(main.map_view.layers._power_warning_blend == 0.0)
	main.preferences.visual_enhancements.disaster_blending = true
	main.frame._advance_palette_animation(0.0, true)
	assert(is_equal_approx(main.map_view.layers._power_warning_blend, 0.5))


func _check_menu_dependencies(tab: VisualEnhancementsTab) -> void:
	var original := tab.selected_values()
	# Navigation is presentation-only, and percentage displays round-trip every option.
	var notifications := [0]
	var count_change := func() -> void: notifications[0] += 1
	tab.changed.connect(count_change)
	for category in tab.pages.size():
		tab.category_buttons[category].pressed.emit()
		assert(tab.pages[category].visible)
		assert(tab.pages.filter(func(page: VBoxContainer) -> bool: return page.visible).size() == 1)
		assert(tab.selected_values() == original)
	assert(notifications[0] == 0, "Category navigation changed settings")
	tab.changed.disconnect(count_change)
	for field in VisualEnhancementOptions.FIELDS:
		if field[0] == "lut_folder":
			continue
		assert(tab.controls.has(field[0]), "An option is missing from the settings pages")
		if field[0] in VisualEnhancementsTab.PERCENT_FIELDS:
			assert(is_equal_approx((tab.controls[field[0]] as SpinBox).value, float(original[field[0]]) * 100.0))
	assert(tab.controls.size() == VisualEnhancementOptions.FIELDS.size() - 1)
	var saved := VisualEnhancementOptions.normalize({"lut_folder": "user://authored_luts", "disaster_strength": 0.35, "disaster_lights": 0.25, "disaster_shake": 0.0})
	tab.show_values(saved)
	assert(tab.selected_values() == saved, "Settings pages lost stored values")
	(tab.controls.disaster_strength as SpinBox).value = 0.0
	assert(not (tab.controls.disaster_lights as SpinBox).editable)
	assert((tab.controls.disaster_crowds as CheckBox).disabled and (tab.controls.disaster_dust as CheckBox).disabled)
	assert(not (tab.controls.disaster_motion as CheckBox).disabled)
	assert((tab.controls.disaster_shake as SpinBox).editable)
	(tab.controls.disaster_strength as SpinBox).value = 70.0
	assert((tab.controls.disaster_lights as SpinBox).editable)
	(tab.controls.disaster_enabled as CheckBox).button_pressed = false
	assert(not (tab.controls.disaster_blending as CheckBox).disabled, "Power-warning blending must remain available without disaster effects")
	assert(not (tab.controls.disaster_strength as SpinBox).editable)
	assert(not (tab.controls.disaster_shake as SpinBox).editable)
	assert((tab.controls.disaster_motion as CheckBox).disabled)
	assert(tab.selected_values().disaster_lights == 0.25)
	assert(tab.selected_values().lut_folder == saved.lut_folder, "Unrelated edits lost the hidden profile path")
	tab.show_values({})
	assert(tab.selected_values().lut_folder.is_empty(), "Defaults must still clear custom profiles")
	var fixed := tab.controls.season_fixed as OptionButton
	var source := tab.controls.season_mode as OptionButton
	assert(fixed.disabled and not (tab.controls.season_seconds as SpinBox).editable)
	source.select(2)
	source.item_selected.emit(2)
	assert(not fixed.disabled and not (tab.controls.season_transition as SpinBox).editable)
	fixed.select(3)
	fixed.item_selected.emit(3)
	source.select(1)
	source.item_selected.emit(1)
	assert(fixed.disabled and (tab.controls.season_seconds as SpinBox).editable)
	assert(tab.selected_values().season_fixed == 3, "Changing source lost the saved fixed season")
	(tab.controls.season_enabled as CheckBox).button_pressed = false
	assert(source.disabled and not (tab.controls.season_seconds as SpinBox).editable)
	assert(not (tab.controls.season_water_strength as SpinBox).editable)
	assert((tab.controls.weather_fixed as OptionButton).disabled)
	assert(not (tab.controls.weather_seconds as SpinBox).editable)
	var weather_source := tab.controls.weather_mode as OptionButton
	weather_source.select(1)
	weather_source.item_selected.emit(1)
	assert((tab.controls.weather_seconds as SpinBox).editable)
	weather_source.select(2)
	weather_source.item_selected.emit(2)
	assert(not (tab.controls.weather_fixed as OptionButton).disabled)
	assert(not (tab.controls.weather_seconds as SpinBox).editable)
	(tab.controls.weather_enabled as CheckBox).button_pressed = false
	assert((tab.controls.weather_fixed as OptionButton).disabled and weather_source.disabled)
	var day_source := tab.controls.day_mode as OptionButton
	assert(not (tab.controls.day_hour as VisualTimeEdit).editable and (tab.controls.day_seconds as SpinBox).editable)
	day_source.select(1)
	day_source.item_selected.emit(1)
	assert((tab.controls.day_hour as VisualTimeEdit).editable and not (tab.controls.day_seconds as SpinBox).editable)
	(tab.controls.brightmaps as CheckBox).button_pressed = false
	assert(not (tab.controls.brightmap_folder as LineEdit).editable)
	assert(not (tab.controls.night_light_strength as SpinBox).editable)
	assert(not (tab.controls.night_glow as SpinBox).editable)
	assert(not (tab.controls.night_ground as SpinBox).editable)
	(tab.controls.brightmaps as CheckBox).button_pressed = true
	assert((tab.controls.night_light_strength as SpinBox).editable)
	(tab.controls.night_light_strength as SpinBox).value = 35.0
	assert(tab.selected_values().night_light_strength == 35.0)
	(tab.controls.day_enabled as CheckBox).button_pressed = false
	assert(day_source.disabled and not (tab.controls.brightmaps as CheckBox).disabled)
	assert(not (tab.controls.night_light_strength as SpinBox).editable)
	var daytime := tab.controls.night_daytime_enabled as CheckBox
	assert(not daytime.disabled)
	daytime.button_pressed = true
	assert((tab.controls.night_light_strength as SpinBox).editable)
	assert((tab.controls.night_ground as SpinBox).editable)
	assert(not (tab.controls.night_ambient as SpinBox).editable)
	(tab.controls.brightmaps as CheckBox).button_pressed = false
	assert(daytime.disabled and not (tab.controls.night_ground as SpinBox).editable)
	(tab.controls.brightmaps as CheckBox).button_pressed = true
	daytime.button_pressed = false
	assert(not (tab.controls.night_ground as SpinBox).editable)
	(tab.controls.cloud_enabled as CheckBox).button_pressed = false
	assert(not (tab.controls.cloud_density as SpinBox).editable)
	(tab.controls.life_cars_enabled as CheckBox).button_pressed = false
	assert(not (tab.controls.life_car_amount as SpinBox).editable)
	(tab.controls.life_people_enabled as CheckBox).button_pressed = false
	assert(not (tab.controls.life_people_amount as SpinBox).editable)
	tab.show_values(original)
	tab.changed.emit()


func _check_zone_soil_masks() -> void:
	var pack := FixtureGraphics.pack()
	for archive: Sc2SpriteArchive in [pack.large_sprites, pack.small_medium_sprites]:
		CitySeasonColors.prepare(archive, pack.palette)
		for id: int in archive.entries_by_id:
			if id % 500 < 291 or id % 500 > 299:
				continue
			assert(archive.visual_seasons.has(id), "Zoned soil has no seasonal mask: %d" % id)
			var entry := archive.find_sprite(id)
			var indices: PackedInt32Array = entry.decode_indices().pixels
			var flat: PackedInt32Array = archive.find_sprite(id - id % 500 + 256).decode_indices().pixels
			var mask: Image = archive.visual_seasons[id]
			var markings := 0
			for at in indices.size():
				# Original zoning uses soil shade124 for its darker tile borders.
				if indices[at] == 124:
					assert(mask.get_pixel(at % entry.width, int(at / entry.width)).g == 1.0, "Zoned soil border stayed brown")
				elif indices[at] >= 0 and not flat.has(indices[at]):
					markings += 1
					assert(mask.get_pixel(at % entry.width, int(at / entry.width)).a == 0.0, "Season mask recolors a zoning mark")
			assert(markings > 0, "Zone fixture lacks distinctive markings")


func _check_brightmaps() -> void:
	var folder := "user://brightmaps_test_%d" % OS.get_process_id()
	folder = ProjectSettings.globalize_path(folder)
	var archive := Sc2SpriteArchive.new()
	var entry := Sc2SpriteArchive.entry_from_indices(1006, 2, 1, PackedInt32Array([20, -1]))
	archive.entries.append(entry)
	archive.entries_by_id[1006] = entry
	var assets := OriginalGameAssets.new()
	assets.large_sprites = archive
	assets.small_medium_sprites = Sc2SpriteArchive.new()
	assets.palette = Sc2Palette.new()
	assets.palette.colors.resize(256)
	assets.palette.colors.fill(Color(0.2, 0.7, 0.2))
	assert(CityBrightmaps.export_originals(assets, folder).is_empty())
	var filename := folder.path_join("brightmaps/large/1006.png")
	var mask := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	mask.set_pixel(0, 0, Color(1.0, 0.15, 0.05, 0.5))
	mask.set_pixel(1, 0, Color(0.1, 0.3, 1.0, 1.0))
	assert(mask.save_png(filename) == OK)
	var authored := FileAccess.get_file_as_bytes(filename)
	assert(CityBrightmaps.export_originals(assets, folder).is_empty())
	assert(FileAccess.get_file_as_bytes(filename) == authored, "Export overwrote an authored mask")
	CityBrightmaps.load_archive(archive, folder, "large")
	assert(archive.visual_emission.has(1006))
	var transformed := CityBrightmaps.transform_mask(archive.visual_emission[1006], entry.create_image(assets.palette).image, false)
	assert(transformed.get_pixel(0, 0).r == 1.0 and transformed.get_pixel(0, 0).a > 0.49)
	assert(transformed.get_pixel(1, 0).a == 0.0)
	_check_portable_brightmaps(assets, mask, folder)
	CitySeasonColors.prepare(archive, assets.palette)
	assert(archive.visual_seasons[1006].get_pixel(0, 0).r == 1.0)
	var catalog_path := folder.path_join("catalog.json")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	catalog.sprites["large/1006"].indices_sha256 = "different-artwork"
	var file := FileAccess.open(catalog_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog))
	file.close()
	CityBrightmaps.load_archive(archive, folder, "large")
	assert(archive.visual_emission.is_empty(), "Brightmap bound to different source pixels")


func _check_portable_brightmaps(assets: OriginalGameAssets, mask: Image, external: String) -> void:
	var previous_root := AppPaths.root()
	var previous_portable := AppPaths.is_portable()
	var first := ProjectSettings.globalize_path("user://brightmap_move_%d" % OS.get_process_id())
	var moved := first + "_moved"
	assert(DirAccess.make_dir_recursive_absolute(first.path_join("data")) == OK)
	AppPaths.use_executable_folder(first, true)
	var relative := "brightmaps-standard"
	var full := AppPaths.path(relative)
	assert(VisualEnhancementOptions.normalize({"brightmap_folder": full}).brightmap_folder == relative)
	assert(VisualEnhancementOptions.normalize({"brightmap_folder": external}).brightmap_folder == external)
	assert(CityBrightmaps.export_originals(assets, relative).is_empty())
	assert(mask.save_png(full.path_join("brightmaps/large/1006.png")) == OK)
	var save := AppSettingsStore.SaveOptions.new()
	save.visual_enhancements = {"brightmap_folder": full}
	assert(AppSettingsStore.save_values(0.5, 0.5, false, AppPaths.path("settings.cfg"), save) == OK)
	var config := ConfigFile.new()
	assert(config.load(AppPaths.path("settings.cfg")) == OK)
	assert(config.get_value("visual_enhancements", "options").brightmap_folder == relative)
	assert(DirAccess.rename_absolute(first, moved) == OK)
	AppPaths.use_executable_folder(moved, true)
	var loaded := AppSettingsStore.load_values(AppPaths.path("settings.cfg"))
	assert(loaded.visual_enhancements.brightmap_folder == relative)
	CityBrightmaps.load_archive(assets.large_sprites, relative, "large")
	assert(assets.large_sprites.visual_emission[1006].get_data() == mask.get_data())
	assert(CityBrightmaps.export_originals(assets, relative).is_empty())
	assert(Image.load_from_file(AppPaths.path(relative).path_join("brightmaps/large/1006.png")).get_data() == mask.get_data())
	CityBrightmaps.load_archive(assets.large_sprites, "missing-brightmaps", "large")
	assert(assets.large_sprites.visual_emission.is_empty())
	assert(CityBrightmaps.resolve_folder("").is_empty())
	CityBrightmaps.load_archive(assets.large_sprites, external, "large")
	assert(assets.large_sprites.visual_emission[1006].get_data() == mask.get_data())
	AppPaths.use_executable_folder(previous_root.get_base_dir(), previous_portable)


func _check_standard_brightmaps() -> void:
	var pack := FixtureGraphics.pack()
	for pair in [[pack.large_sprites, "large", 103], [pack.small_medium_sprites, "small-medium", 205]]:
		var archive: Sc2SpriteArchive = pair[0]
		CityBrightmaps.load_archive(archive, "", pair[1])
		assert(archive.visual_emission.size() == pair[2], "Default masks must load for matching standard artwork")
		for id: int in archive.visual_emission:
			var mask: Image = archive.visual_emission[id]
			var entry := archive.find_sprite(id)
			assert(mask.get_size() == Vector2i(entry.width, entry.height) and not mask.is_invisible())
		CityBrightmaps.load_archive(archive, "user://missing-custom-masks", pair[1])
		assert(archive.visual_emission.is_empty(), "An explicit custom folder replaces the built-in set")
	var custom := Sc2SpriteArchive.new()
	var different := Sc2SpriteArchive.entry_from_indices(1112, 2, 1, PackedInt32Array([20, 30]))
	custom.entries.append(different)
	custom.entries_by_id[1112] = different
	CityBrightmaps.load_archive(custom, "", "large")
	assert(custom.visual_emission.is_empty(), "Default masks must not attach to changed custom artwork")


func _check_visual_save(main: CityApplication, tab: VisualEnhancementsTab) -> void:
	var original := tab.selected_values()
	var dialog := main.main_overlays.settings_dialog
	main.settings.flush_visual_save()
	var saved := FileAccess.get_file_as_bytes(main.preferences.settings_path)
	var strength := tab.controls.day_lut_strength as SpinBox
	strength.value = 15.0
	strength.value = 25.0
	strength.value = 35.0
	assert(main.preferences.visual_enhancements.day_lut_strength == 0.35)
	assert(main.settings._visual_save_pending)
	assert(FileAccess.get_file_as_bytes(main.preferences.settings_path) == saved)
	await create_timer(0.4).timeout
	assert(not main.settings._visual_save_pending)
	assert(AppSettingsStore.load_values(main.preferences.settings_path).visual_enhancements.day_lut_strength == 0.35)
	strength.value = 45.0
	dialog.hide()
	assert(not main.settings._visual_save_pending)
	assert(AppSettingsStore.load_values(main.preferences.settings_path).visual_enhancements.day_lut_strength == 0.45)
	main.settings.open_settings_dialog()
	# No-op/non-visual changes must not rerun visual configuration.
	var configured := main.visual_environment._options
	main.settings.apply_settings()
	assert(is_same(configured, main.visual_environment._options))
	dialog.default_mayor_edit.text = "UI regression mayor"
	dialog.default_mayor_edit.text_submitted.emit(dialog.default_mayor_edit.text)
	assert(is_same(configured, main.visual_environment._options))
	tab.show_values(original)
	tab.changed.emit()
	main.settings.flush_visual_save()
