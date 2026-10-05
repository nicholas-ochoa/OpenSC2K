extends SceneTree

const DocumentState = preload("res://tests/support/document_state.gd")

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var defaults := VisualEnhancementOptions.normalize({})
	assert(defaults.day_seconds == 600.0)
	assert(VisualEnhancementOptions.normalize({"day_seconds": NAN, "weather_fixed": 100}).day_seconds == 600.0)
	var path := "user://visual_environment_%d.cfg" % OS.get_process_id()
	var save := AppSettingsStore.SaveOptions.new()
	save.visual_enhancements = VisualEnhancementOptions.normalize({"day_mode": 1, "day_hour": 7.0, "weather_fixed": 6})
	save.visual_enhancements.day_lut_strength = 0.25
	save.visual_enhancements.season_lut_strength = 0.75
	save.visual_enhancements.weather_lut_strength = 0.0
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
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	assert(main.city_session.activate_document(EmptyCityTemplate.create(128)))
	var before := DocumentState.capture(main.document_state.city.document)
	var engine := main.simulation_state.simulation_engine
	var random_before := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
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
	_check_menu_dependencies(tab)
	(tab.controls.weather_enabled as CheckBox).button_pressed = true
	var weather_source := tab.controls.weather_mode as OptionButton
	weather_source.select(2)
	weather_source.item_selected.emit(2)
	(tab.controls.day_lut_strength as SpinBox).value = 0.2
	(tab.controls.season_lut_strength as SpinBox).value = 0.8
	(tab.controls.weather_lut_strength as SpinBox).value = 0.6
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
	# The same requested snow must react to seasons without a game-weather
	# change, and leaving winter must clear particles even while paused.
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
				assert(main.visual_environment.weather.kind == pair[2])
				assert(main.visual_environment.weather.snow == 0.0 and main.visual_environment.weather.frost == 0.0)
			main.preferences.visual_enhancements.season_fixed = 3
			main.visual_environment.process(5.0)
			assert(main.visual_environment.weather.kind == pair[1] and main.visual_environment.weather.snow > 0.0)
			assert(DocumentState.capture(main.document_state.city.document) == before)
			assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == random_before)
	# Surface color stays available with reflection and seabed display off.
	main.preferences.visual_enhancements.water_reflections = 0
	main.preferences.visual_enhancements.water_topography = false
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
	# A newly loaded sunny document must not inherit the previous snowstorm.
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


func _check_menu_dependencies(tab: VisualEnhancementsTab) -> void:
	var original := tab.selected_values()
	tab.show_values({})
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
	assert(not (tab.controls.day_hour as SpinBox).editable and (tab.controls.day_seconds as SpinBox).editable)
	day_source.select(1)
	day_source.item_selected.emit(1)
	assert((tab.controls.day_hour as SpinBox).editable and not (tab.controls.day_seconds as SpinBox).editable)
	(tab.controls.brightmaps as CheckBox).button_pressed = false
	assert(not (tab.controls.brightmap_folder as LineEdit).editable)
	(tab.controls.day_enabled as CheckBox).button_pressed = false
	assert(day_source.disabled and (tab.controls.brightmaps as CheckBox).disabled)
	(tab.controls.cloud_enabled as CheckBox).button_pressed = false
	assert(not (tab.controls.cloud_density as SpinBox).editable)
	(tab.controls.life_cars_enabled as CheckBox).button_pressed = false
	assert(not (tab.controls.life_car_amount as SpinBox).editable)
	(tab.controls.life_people_enabled as CheckBox).button_pressed = false
	assert(not (tab.controls.life_people_amount as SpinBox).editable)
	tab.show_values(original)
	tab.changed.emit()


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
