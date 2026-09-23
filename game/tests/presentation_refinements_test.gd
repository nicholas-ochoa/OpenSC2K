extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main)
	root.add_child(main)
	await process_frame
	main.main_menu.show_menu(false)
	await process_frame
	await process_frame
	var background: MainMenuCityBackground = main.main_menu.city_background

	for stretch in [0.5, 1.0, 2.0, 2.5, 3.0, 4.0, 6.0, 8.0]:
		for shot in 4:
			var zoom := MainMenuCityBackground.camera_zoom(shot, stretch)
			assert(zoom >= 0.5, "Menu city zoom must stay at or above 50%")
			assert(is_equal_approx(zoom * stretch, roundf(zoom * stretch)))

	assert(background.city_name_label.text == background.demo_city.city_name())
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
	main.new_city.open_new_city_dialog()
	main.new_city.make_new_city_preview()
	while main.new_city_state.preview_job != null:
		await process_frame
	main.new_city.create_new_city_unchecked()
	await process_frame
	main.current_tool.select_tool_group(0)
	assert(main.city_toolbar.child_tool_buttons.has(5))
	assert(not main.city_toolbar.child_tool_buttons[5].disabled)
	main.current_tool.select_tool_group(1)
	assert(main.city_toolbar.child_tool_buttons.has(2) and main.city_toolbar.child_tool_buttons.has(3))
	main.document_state.city.set_sound_enabled(true)
	main.document_state.city.set_music_enabled(true)
	main.new_city.start_city()
	assert(main.city_dialogs.newspaper_dialog.visible and main.newspaper_state.founding_pending)
	assert(main.audio_controller.wave_sound_gate.current_sound_id == 513)
	var age: int = main.document_state.city.age_in_days()
	main._process(1.0)
	assert(main.document_state.city.age_in_days() == age)
	main.city_dialogs.newspaper_dialog.hide()
	assert(not main.newspaper_state.founding_pending)
	assert(main.audio_controller.music_director.general_track_index == 1)
	assert(main.audio_controller.music_playback_is_active())
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	assert(main.city_dialogs.newspaper_dialog.page is NewspaperContent)
	assert(main.city_dialogs.newspaper_dialog.exclusive)
	_check_newspaper_options(main)
	var city := CityState.from_document(main.document_state.current_document.duplicate_document())
	city.set_land_altitude(5, 5, 5)
	city.set_tile_flag(5, 5, 4, false)
	city.set_terrain_id(5, 5, 0)
	city.set_underground_id(5, 5, UndergroundTileIds.SUBWAY_LR)
	city.set_tunnel_levels(5, 5, 5)
	var bytes: PackedByteArray = city.document.serialize().data
	city.visible_altitude_levels = 5
	var subway_and_tunnel := _cutaway(city, main.asset_state.palette, main.asset_state.large_sprites)
	city.visible_altitude_levels = 4
	var tunnel := _cutaway(city, main.asset_state.palette, main.asset_state.large_sprites)
	assert(subway_and_tunnel.get_data() != tunnel.get_data())
	assert(tunnel.get_used_rect().has_area())
	city.visible_altitude_levels = 1
	assert(not _cutaway(city, main.asset_state.palette, main.asset_state.large_sprites).get_used_rect().has_area())
	assert(city.document.serialize().data == bytes)
	main.audio_controller.stop_sound_effects()
	await create_timer(0.1).timeout
	main.queue_free()
	await process_frame
	print("PASS: pixel-aligned wide and close shots, enabled landscape tools, founding sound and paper, paused reading and opening music, HTML-only content, and separate tunnel/subway cutoff depths")
	quit()


func _cutaway(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive) -> Image:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var configuration := CityIsometricRenderer.view_configuration(CityIsometricRenderer.VIEW_LARGE).with_top_margin(128)
	CityUndergroundView.draw_tile(image, city, palette, sprites, {}, configuration, 128, 5, 5, false, true)

	return image


# the newspaper menu toggles the saved subscription and extra-edition options
func _check_newspaper_options(main: Node) -> void:
	var city: CityState = main.document_state.city
	var popup: PopupMenu = main.city_menu_bar.newspaper_menu.get_popup()
	assert(city.newspaper_extras_enabled() and not city.newspaper_subscription_enabled())

	for option in [CityMenuBar.MENU_NEWSPAPER_SUBSCRIPTION, CityMenuBar.MENU_NEWSPAPER_EXTRAS]:
		var offset: int = Sc2MiscLayout.NEWSPAPER_SUBSCRIPTION if option == CityMenuBar.MENU_NEWSPAPER_SUBSCRIPTION else Sc2MiscLayout.NEWSPAPER_EXTRAS
		var before: int = city.document.misc_u32(offset)

		for _toggle in 2:
			main.reports.on_newspaper_menu(option)
			var value: int = city.document.misc_u32(offset)
			assert(value == (1 if before == 0 else 0), "The newspaper option toggles its saved flag")
			assert(popup.is_item_checked(popup.get_item_index(option)) == (value != 0))
			assert(not main.city_dialogs.newspaper_dialog.visible, "A newspaper option does not open a paper")
			before = value
