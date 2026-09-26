extends SceneTree
## UI scale choices, window fit, saved settings, and whole-pixel map drawing.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_scale_rules()
	_check_map_pixels()
	await _check_settings()
	print("PASS: UI scale fit, saved choice, window scale, and whole-pixel map")
	quit()


func _check_scale_rules() -> void:
	var base := Vector2i(1280, 800)
	assert(AppUiScale.normalize(1.7) == 1.5)
	assert(AppUiScale.normalize(1) == 1.0)
	assert(AppUiScale.normalize(9.0) == 2.0)
	assert(AppUiScale.normalize("invalid") == AppUiScale.DEFAULT)
	assert(AppUiScale.DEFAULT == 2.0, "2.0 is the fitted size that the interface used before the option")

	# window, choice, screen pixels for each interface pixel
	for case in [
		[Vector2i(2560, 1600), 2.0, 2.0], [Vector2i(2560, 1600), 1.5, 1.5], [Vector2i(2560, 1600), 1.0, 1.0],
		[Vector2i(7680, 2892), 2.0, 3.615], [Vector2i(7680, 2892), 1.5, 2.71125], [Vector2i(7680, 2892), 1.0, 1.8075],
		[Vector2i(1920, 1080), 2.0, 1.35], [Vector2i(1920, 1080), 1.0, 1.0], [Vector2i(1280, 800), 1.5, 1.0],
		[Vector2i(1024, 700), 1.0, 0.8],
	]:
		var window: Vector2i = case[0]
		var screen := AppUiScale.screen_scale(case[1], window, base)
		assert(is_equal_approx(screen, case[2]), "%s at %s" % [case[1], window])

		# the layout is never smaller than the base size unless the window is
		var layout := Vector2(window) / screen
		assert(layout.x >= minf(base.x, window.x) - 0.01 and layout.y >= minf(base.y, window.y) - 0.01)
		assert(is_equal_approx(
			AppUiScale.content_scale_factor(case[1], window, base) * AppUiScale.fit_scale(window, base), screen))

	# the map follows the fitted size in whole pixels, not the UI scale
	assert(AppUiScale.map_pixels(2.0) == 2 and AppUiScale.map_pixels(3.615) == 4 and AppUiScale.map_pixels(1.35) == 1)
	assert(AppUiScale.map_pixels(0.8) == 1)


func _check_map_pixels() -> void:
	var map := CityMapControl.new()
	map.position = Vector2(12, 31)
	map.size = Vector2(1000, 700)
	root.add_child(map)
	map.city = CityState.from_document(EmptyCityTemplate.create(128))
	var tile := Vector2i(64, 64)
	assert(map.camera.center_on_tile(tile))
	var center := map.source_center

	# screen pixels for each interface pixel, whole screen pixels for each map
	# pixel. Godot can round the two window axes to different scales
	for case in [[Vector2(1.0, 1.0), 1], [Vector2(2.0, 2.0), 2], [Vector2(1.5, 1.5), 2], [Vector2(1.0, 1.0), 2],
			[Vector2(1.35, 1.35), 1], [Vector2(3.615819, 3.615), 4], [Vector2(1.80791, 1.8075), 2], [Vector2(1.5, 1.5003), 2]]:
		var screen: Vector2 = case[0]
		var pixels: int = case[1]
		map.zoom_factor = 1.0
		map.set_pixel_scales(screen, pixels)
		assert(map.source_center == center, "The view keeps its center when the interface scale changes")
		assert(map.zoom_percent() == 100, "Map zoom does not follow the interface scale")
		assert(map.scale.x >= 1.0 and map.scale.y >= 1.0, "The correction never leaves a gap at the map edge")
		var to_screen := Transform2D.IDENTITY.scaled(screen) * map.get_global_transform_with_canvas()

		for zoom in [1.0, 2.0, 3.0, 4.0]:
			map.zoom_factor = zoom
			var scale := map.camera._view_scale()
			var source_pixel := to_screen.basis_xform(Vector2(scale, scale))
			assert(source_pixel.is_equal_approx(Vector2(zoom * pixels, zoom * pixels)), "Each map pixel covers whole screen pixels")
			var screen_offset := to_screen * map.camera._draw_offset(scale)
			assert(screen_offset.is_equal_approx(screen_offset.round()), "Map pixel edges fall on screen pixel edges")
			var middle := map.camera._camera_rect().get_center()
			assert(map.camera._tile_at(middle).distance_to(tile) <= 1.0, "Picking follows the drawn map scale")

	map.zoom_factor = 1.0
	map.set_pixel_scales(Vector2.ZERO, 1)
	assert(map.scale == Vector2.ONE)
	map.free()


func _check_settings() -> void:
	var path := "user://ui-scale-test-%d.cfg" % OS.get_process_id()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert(AppSettingsStore.load_values(path).ui_scale == AppUiScale.DEFAULT)
	assert(AppSettingsStore.save_values(0.8, 0.8, false, path, "", "", null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, 1.5) == OK)
	assert(AppSettingsStore.load_values(path).ui_scale == 1.5)
	var config := ConfigFile.new()
	assert(config.load(path) == OK)
	config.set_value("general", "ui_scale", "invalid")
	assert(config.save(path) == OK)
	assert(AppSettingsStore.load_values(path).ui_scale == AppUiScale.DEFAULT)

	# a 1280x800 window at 2x screen pixels, as on a high-density display
	var window_size := root.size
	root.size = Vector2i(2560, 1600)
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("user://missing-test-art"))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.asset_state.reference_root = ProjectSettings.globalize_path("user://missing-test-originals")
	main.preferences.settings_path = path
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	assert(is_equal_approx(root.content_scale_factor, 1.0), "The default scale keeps the earlier interface size")

	var newspaper := NewspaperWebView.new()
	root.add_child(newspaper)

	for index in [0, 1, 2]:
		main.settings.open_settings_dialog()
		var dialog: AppSettingsDialog = main.main_overlays.settings_dialog
		assert(dialog.ui_scale_selector.selected == AppUiScale.option_index(main.preferences.ui_scale))
		dialog.ui_scale_selector.select(index)
		main.settings.apply_settings()
		dialog.hide()
		var selected: float = AppUiScale.OPTIONS[index]
		assert(main.preferences.ui_scale == selected)
		assert(AppSettingsStore.load_values(path).ui_scale == selected)
		assert(absf(root.get_final_transform().get_scale().x - selected) < 0.01)
		assert(root.get_visible_rect().size.distance_to(Vector2(2560, 1600) / selected) < 1.0)
		assert(is_equal_approx(newspaper.page_zoom(), DisplayServer.screen_get_scale() * selected / AppUiScale.DEFAULT),
			"The newspaper page keeps its earlier zoom at 2.0 and follows smaller choices")

	# a smaller window fits the base layout size
	main.settings.open_settings_dialog()
	main.main_overlays.settings_dialog.ui_scale_selector.select(2)
	main.settings.apply_settings()
	main.main_overlays.settings_dialog.hide()
	root.size = Vector2i(1920, 1080)
	await process_frame
	assert(absf(root.get_final_transform().get_scale().x - 1.35) < 0.01, "Godot rounds the layout to whole interface pixels")
	main.free()
	newspaper.free()
	root.size = window_size
	root.content_scale_factor = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await process_frame
