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
	for kind in range(7):
		main.preferences.visual_enhancements.weather_fixed = kind
		main.visual_environment.process(5.0)
		assert(main.visual_environment.weather.kind == kind)
	main.preferences.visual_enhancements.weather_fixed = 0
	main.visual_environment.process(5.0)
	assert(main.visual_environment.weather.tint == Color.WHITE)
	assert(main.visual_environment.weather.rain == 0.0 and main.visual_environment.weather.snow == 0.0)
	# Select the actual settings control, starting from disabled Game weather.
	main.preferences.visual_enhancements.weather_enabled = false
	main.preferences.visual_enhancements.weather_mode = 0
	main.settings.open_settings_dialog()
	var tab := main.main_overlays.settings_dialog.visual_tab
	(tab.controls.day_lut_strength as SpinBox).value = 0.2
	(tab.controls.season_lut_strength as SpinBox).value = 0.8
	(tab.controls.weather_lut_strength as SpinBox).value = 0.6
	assert(main.preferences.visual_enhancements.day_lut_strength == 0.2)
	assert(main.preferences.visual_enhancements.season_lut_strength == 0.8)
	assert(main.preferences.visual_enhancements.weather_lut_strength == 0.6)
	var fixed := tab.controls.weather_fixed as OptionButton
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
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS: cosmetic clocks, speed, pause, grading, seasons, weather mapping, settings preservation and unchanged city/RNG")
	quit()


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
