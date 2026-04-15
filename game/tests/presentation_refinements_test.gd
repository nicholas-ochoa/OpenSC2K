extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.main_menu.show_menu(false)
	await process_frame
	await process_frame
	var panel: PanelContainer = main.main_menu.new_city_button.get_parent().get_parent()
	assert(is_equal_approx(panel.size.y, panel.get_combined_minimum_size().y))
	var background: MainMenuCityBackground = main.main_menu.city_background

	for stretch in [0.5, 1.0, 2.0, 2.5, 3.0, 4.0, 6.0, 8.0]:
		for shot in 4:
			var zoom := MainMenuCityBackground.camera_zoom(shot, stretch)
			assert(zoom >= 0.5, "Menu city zoom must stay at or above 50%")
			assert(is_equal_approx(zoom * stretch, roundf(zoom * stretch)))

	assert(MainMenuCityBackground.SHOT_MAGNIFICATIONS[0] > MainMenuCityBackground.SHOT_MAGNIFICATIONS[1])
	assert(MainMenuCityBackground.SHOT_MAGNIFICATIONS[1] > MainMenuCityBackground.SHOT_MAGNIFICATIONS[2])
	assert(background.city_name_label.text == background.demo_city.city_name())
	assert(background.city_name_label.get_theme_color("font_color") == Color.WHITE)
	assert(background.city_name_label.get_theme_color("font_shadow_color").a > 0.9)
	assert(background.city_name_label.anchor_bottom == 1.0 and background.city_name_label.anchor_left == 0.0)
	var magnifications := {}

	for time in [0.0, 0.017, 24.0, 48.0, 72.0]:
		background.elapsed = time
		var camera := background._camera()
		var pixel_scale := background.get_viewport_transform().get_scale().x
		var magnification := float(camera.scale) * pixel_scale
		assert(is_equal_approx(magnification, roundf(magnification)))
		var position: Vector2 = camera.offset * pixel_scale
		assert(position.is_equal_approx(position.round()))
		magnifications[roundi(magnification)] = true

	assert(magnifications.has(1) and magnifications.has(2) and magnifications.has(3))
	main._open_new_city_dialog()
	main._make_new_city_preview()
	while main.new_city_preview_job != null:
		await process_frame
	main._create_new_city_unchecked()
	await process_frame
	main._select_tool_group(0)
	assert(main.city_toolbar.child_tool_buttons.has(5))
	assert(not main.city_toolbar.child_tool_buttons[5].disabled)
	main._select_tool_group(1)
	assert(main.city_toolbar.child_tool_buttons.has(2) and main.city_toolbar.child_tool_buttons.has(3))
	main.city.set_sound_enabled(true)
	main.city.set_music_enabled(true)
	main._start_city()
	assert(main.newspaper_dialog.visible and main.founding_newspaper_pending)
	assert(main.audio_controller.wave_sound_gate.current_sound_id == 513)
	var age: int = main.city.age_in_days()
	main._process(1.0)
	assert(main.city.age_in_days() == age)
	main.newspaper_dialog.hide()
	assert(not main.founding_newspaper_pending)
	assert(main.audio_controller.music_director.general_track_index == 1)
	assert(main.audio_controller.music_playback_is_active())
	main._select_speed(GameSpeedController.Speed.PAUSED)
	assert(main.newspaper_dialog.page is NewspaperContent)
	assert(main.newspaper_dialog.exclusive)
	var city := CityState.from_document(main.current_document.duplicate_document())
	city.set_land_altitude(5, 5, 5)
	city.set_tile_flag(5, 5, 4, false)
	city.set_terrain_id(5, 5, 0)
	city.set_underground_id(5, 5, 1)
	city.set_tunnel_levels(5, 5, 5)
	var bytes: PackedByteArray = city.document.serialize().data
	city.visible_altitude_levels = 5
	var subway_and_tunnel := _cutaway(city, main.palette, main.large_sprites)
	city.visible_altitude_levels = 4
	var tunnel := _cutaway(city, main.palette, main.large_sprites)
	assert(subway_and_tunnel.get_data() != tunnel.get_data())
	assert(tunnel.get_used_rect().has_area())
	city.visible_altitude_levels = 1
	assert(not _cutaway(city, main.palette, main.large_sprites).get_used_rect().has_area())
	assert(city.document.serialize().data == bytes)
	main.audio_controller.stop_sound_effects()
	await create_timer(0.1).timeout
	main.queue_free()
	await process_frame
	print("PASS: fitted menu, pixel-aligned wide and close shots, enabled landscape tools, founding sound and paper, paused reading and opening music, HTML-only content, and separate tunnel/subway cutoff depths")
	quit()


func _cutaway(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive) -> Image:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var configuration := CityIsometricRenderer.view_configuration(CityIsometricRenderer.VIEW_LARGE).duplicate()
	configuration.top_margin = 128
	CityUndergroundView._draw_tile(image, city, palette, sprites, {}, configuration, 128, 5, 5, false, true)

	return image
