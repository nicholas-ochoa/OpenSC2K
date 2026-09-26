extends SceneTree
## UI scale choices, window fit, saved settings, and whole-pixel map drawing.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_scale_rules()
	_check_map_pixels()
	_check_pixel_views()
	await _check_pixel_art()
	await _check_settings()
	print("PASS: UI scale fit, saved choice, window scale, and whole-pixel map, minimap, SCURK canvas, and dialog copy")
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

	# screen pixels for each interface pixel, whole screen pixels for each map pixel
	for case in [[1.0, 1], [2.0, 2], [1.5, 2], [1.0, 2], [1.35, 1], [3.615, 4], [1.8075, 2]]:
		var screen: float = case[0]
		var pixels: int = case[1]
		map.zoom_factor = 1.0
		map.set_pixel_scales(screen, pixels)
		assert(map.source_center == center, "The view keeps its center when the interface scale changes")
		assert(map.zoom_percent() == 100, "Map zoom does not follow the interface scale")
		var to_screen := Transform2D.IDENTITY.scaled(Vector2(screen, screen)) * map.get_global_transform_with_canvas()

		for zoom in [1.0, 2.0, 3.0, 4.0]:
			map.zoom_factor = zoom
			var scale := map.camera._view_scale()
			assert(is_equal_approx(scale * screen, zoom * pixels), "Each map pixel covers whole screen pixels")
			var screen_offset := to_screen * map.camera._draw_offset(scale)
			assert(screen_offset.is_equal_approx(screen_offset.round()), "Map pixel edges fall on screen pixel edges")
			var middle := map.camera._camera_rect().get_center()
			assert(map.camera._tile_at(middle).distance_to(tile) <= 1.0, "Picking follows the drawn map scale")

	map.zoom_factor = 1.0
	map.set_pixel_scales(0.0, 1)
	assert(is_equal_approx(map.camera._view_scale(), 1.0))
	map.free()


func _check_pixel_views() -> void:
	assert(ScreenPixels.length(3.0) == 3.0, "Alignment is off until the application sets a scale")
	assert(is_equal_approx(ScreenPixels.length(2.0, 1.5), 2.0) and is_equal_approx(ScreenPixels.length(3.0, 1.5), 5.0 / 1.5))
	assert(is_equal_approx(ScreenPixels.length(0.1, 1.5), 1.0 / 1.5), "A pixel covers at least one screen pixel")
	assert(is_equal_approx(ScreenPixels.whole_cells(300.0, 128, 1.5), 256.0))
	assert(ScreenPixels.whole_cells(50.0, 128, 1.5) == 50.0, "A map smaller than one screen pixel for each cell keeps its size")

	# the main window copies a dialog texture of its screen size rounded up with
	# nearest sampling. the fitted size makes each screen pixel take the next
	# texture pixel
	for screen in [3.615, 2.71125, 1.8075, 1.35]:
		for start in [Vector2i(1703, 270), Vector2i(1206, 268), Vector2i(333, 71)]:
			var fitted := ScreenPixels.window_size(start, Vector2i(420, 530), screen)
			assert(fitted.x >= 420 and fitted.x <= 436 and fitted.y >= 530 and fitted.y <= 546, "The fit only enlarges a dialog a little")

			for axis in 2:
				assert(_copies_one_to_one(start[axis] * screen, fitted[axis] * screen), "%s at %s" % [screen, start])

	ScreenPixels.scale = 1.5
	# the minimap gives each of its 128 map pixels whole screen pixels
	var minimap := CityMapPreviewControl.new()
	minimap.position = Vector2(10.5, 7.25)
	minimap.size = Vector2(301, 290)
	root.add_child(minimap)
	var target := minimap.map_rect()
	var corner := (minimap.get_global_transform_with_canvas() * target.position) * 1.5
	assert(corner.is_equal_approx(corner.round()), "The minimap starts on a screen pixel corner")
	assert(is_equal_approx(fmod(target.size.x * 1.5, 128.0), 0.0) and target.size.x * 1.5 >= 128.0)
	assert(Rect2(Vector2.ZERO, minimap.size).encloses(target.grow(CityMapPreviewControl.BORDER)), "The border stays inside the control")
	minimap.free()

	# the SCURK canvas keeps each sprite pixel on whole screen pixels and
	# picks the pixel that it draws
	var canvas := ScurkPixelCanvas.new()
	canvas.position = Vector2(3.0, 5.0)
	root.add_child(canvas)
	var pixels := PackedInt32Array()
	pixels.resize(16 * 16)
	pixels.fill(1)
	canvas.set_sprite_data(16, 16, pixels, Sc2Palette.new())

	for zoom in [1, 3, 5]:
		canvas.set_zoom(zoom)
		var pixel := canvas.display_pixel()
		assert(is_equal_approx(pixel * 1.5, roundf(zoom * 1.5)), "Zoom %d uses whole screen pixels" % zoom)
		var origin := (canvas.get_global_transform_with_canvas() * canvas.display_origin()) * 1.5
		assert(origin.is_equal_approx(origin.round()))
		assert(canvas.custom_minimum_size.y >= 16 * pixel + (canvas.display_origin().y), "The last sprite row stays inside the canvas")

		for point in [Vector2i(0, 0), Vector2i(7, 3), Vector2i(15, 15)]:
			var middle := canvas.display_origin() + (Vector2(point) + Vector2(0.5, 0.5)) * pixel
			assert(canvas._point_from_position(middle) == point, "Picking follows the drawn sprite pixels")

	canvas.free()
	ScreenPixels.scale = 0.0


func _check_pixel_art() -> void:
	var screen := 2.71125
	ScreenPixels.set_scale(screen)
	var image := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var art := PixelArtTexture.wrap(ImageTexture.create_from_image(image)) as PixelArtTexture
	assert(PixelArtTexture.wrap(art) == art and PixelArtTexture.unwrap(art).get_width() == 16)

	# at its own size each artwork pixel covers the nearest whole screen pixels
	var own := art.whole_rect(Rect2(Vector2(5, 5), art.get_size()), Vector2(16, 12))
	assert(is_equal_approx(own.size.x * screen, 48.0) and is_equal_approx(own.size.y * screen, 36.0))
	assert(Rect2(Vector2(5, 5), art.get_size()).encloses(own.grow(-0.001)), "The drawing stays in the reported size")

	# a larger request uses the largest whole scale that fits inside it
	var fitted := art.whole_rect(Rect2(0, 0, 64, 48), Vector2(16, 12))
	assert(is_equal_approx(fitted.size.x * screen, 16.0 * 10.0) and Rect2(0, 0, 64, 48).encloses(fitted))

	# a covered part fills its rectangle with fewer, whole-pixel artwork pixels
	var covered := art.covered_region(Rect2(0, 0, 64, 48), Rect2(4, 3, 8, 6), false)
	assert(is_equal_approx(64.0 * screen / covered.size.x, 22.0) and covered.size.x <= 8.0)
	assert(covered.get_center().is_equal_approx(Vector2(8, 6)))

	# artwork smaller than one screen pixel for each artwork pixel is unchanged
	assert(art.whole_rect(Rect2(0, 0, 4, 3), Vector2(16, 12)) == Rect2(0, 0, 4, 3))

	# a scale change resizes the controls that show the artwork
	var button := Button.new()
	button.icon = art
	root.add_child(button)
	var before := button.get_combined_minimum_size()
	ScreenPixels.set_scale(1.35)
	await process_frame
	assert(art.get_width() == 12 and button.get_combined_minimum_size().x < before.x)
	button.free()

	# freed artwork leaves the scale-change list, as palette cycling replaces
	# toolbar icons several times each second
	for index in 300:
		PixelArtTexture.wrap(ImageTexture.create_from_image(image))

	assert(ScreenPixels._textures.size() < 200)

	# tinted theme icons stay scalable, so they stay sharp at every UI scale
	var dark := AppUiThemeDefinitions.build("dark")

	for pair in [["unchecked", "CheckBox"], ["radio_unchecked_disabled", "CheckBox"], ["unchecked", "CheckButton"], ["unchecked_disabled_mirrored", "CheckButton"]]:
		var icon := dark.get_icon(pair[0], pair[1])
		assert(icon is DPITexture, "%s %s" % pair)

	var tinted := dark.get_icon("unchecked", "CheckBox").get_image()
	var center := tinted.get_pixel(8, 8)
	var expected := Color("aeb8c4")
	assert(Vector4(center.r, center.g, center.b, center.a).distance_to(Vector4(expected.r, expected.g, expected.b, 1.0)) < 0.02,
		"The tint keeps its color and full opacity")

		# an embedded dialog grows a little so that the main window copies it one
	# pixel for one, and a moved dialog fits again from its own size
	ScreenPixels.set_scale(3.615)
	var dialog := Window.new()
	dialog.size = Vector2i(420, 530)
	dialog.position = Vector2i(1206, 213)
	root.add_child(dialog)
	dialog.show()
	assert(dialog.is_embedded())

	for position in [Vector2i(1206, 213), Vector2i(333, 71), Vector2i(1703, 270)]:
		dialog.position = position
		WindowPixelFit.fit(dialog)
		WindowPixelFit.fit(dialog)
		assert(dialog.size.x >= 420 and dialog.size.x <= 436 and dialog.size.y >= 530 and dialog.size.y <= 546, "The fit does not grow the dialog each time")

		for axis in 2:
			assert(_copies_one_to_one(dialog.position[axis] * 3.615, dialog.size[axis] * 3.615))

	var fitted_size := dialog.size
	WindowPixelFit.fit(dialog)
	assert(dialog.size == fitted_size, "A still dialog keeps its fitted size")
	dialog.free()
	ScreenPixels.set_scale(0.0)


func _copies_one_to_one(start: float, pixels: float) -> bool:
	var texture := ceili(pixels - 0.0001)
	var first := floori(start + 0.5)
	var offset := -1

	for screen_pixel in range(first, floori(start + pixels + 0.5)):
		var texel := floori((screen_pixel + 0.5 - start) * texture / pixels)

		if offset < 0:
			offset = screen_pixel - texel
		elif screen_pixel - texel != offset:
			return false

	return true


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
	assert(is_equal_approx(root.get_final_transform().get_scale().x, 2.0), "The default scale keeps the earlier interface size")
	assert(root.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST, "Dialogs copy to whole screen pixels")
	assert(main.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "Application contents keep linear sampling")

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
		assert(root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED, "The window uses one exact scale on both axes")
		var applied := root.get_final_transform().get_scale()
		assert(is_equal_approx(applied.x, applied.y))
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
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_factor = 1.0
	root.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await process_frame
