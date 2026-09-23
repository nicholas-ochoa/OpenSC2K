extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_menu_shortcuts()
	var motion := CityCameraMotion.new()
	var moved := Vector2.ZERO

	for frame in 60:
		moved += motion.step(Vector2.RIGHT, 1.0 / 60.0)

	assert(motion.velocity == Vector2.RIGHT * motion.SPEED)
	assert(moved.x > 500 and moved.x < 650)
	assert(motion.step(Vector2.ZERO, 1.0 / 60.0).x > 0, "Release should have brief momentum")

	for frame in 10:
		motion.step(Vector2.ZERO, 1.0 / 60.0)

	assert(motion.velocity.is_zero_approx())
	motion.step(Vector2.ONE, 1.0)
	assert(motion.velocity.length() <= motion.SPEED)
	assert(motion.step(Vector2.RIGHT, 0.016, false) == Vector2.ZERO)
	assert(motion.velocity == Vector2.ZERO)
	# Hold a key for several seconds without sending repeat events.
	motion.press(KEY_W)
	var first_speed := motion.step(motion.held_direction(), 1.0 / 60.0).length()

	for frame in 180:
		assert(motion.step(motion.held_direction(), 1.0 / 60.0).y < 0)

	assert(motion.velocity.length() > first_speed * 60.0)
	motion.press(KEY_D)
	assert(is_equal_approx(motion.held_direction().length(), 1.0))
	motion.release(KEY_W)
	assert(motion.held_direction() == Vector2.RIGHT)

	for frame in 60:
		motion.step(motion.held_direction(), 1.0 / 60.0)

	motion.release(KEY_D)
	assert(motion.step(motion.held_direction(), 1.0 / 60.0).x > 0)

	for frame in 12:
		motion.step(motion.held_direction(), 1.0 / 60.0)

	assert(motion.velocity == Vector2.ZERO)
	motion.press(KEY_A)
	motion.step(motion.held_direction(), 0.016, false)
	assert(motion.held_keys.is_empty(), "Blocked input left held keys active")
	var path := "user://background_audio_test_%d.cfg" % OS.get_process_id()
	assert(not AppSettingsStore.load_values(path).background_audio)
	assert(AppSettingsStore.save_values(0.5, 0.5, false, path, "", "", null, null, true) == OK)
	assert(AppSettingsStore.load_values(path).background_audio)
	assert(AppSettingsStore.save_values(0.4, 0.4, false, path) == OK)
	assert(AppSettingsStore.load_values(path).background_audio)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var audio := CityAudioController.new()
	root.add_child(audio)
	audio.setup(ProjectSettings.globalize_path("res://../references/SIMCITY2000"), 0.5, 0.5)
	audio.set_background_audio(true)
	assert(audio.play_music_track(10000))
	audio.handle_application_focus_out()
	assert(audio.music_playback_is_active() and audio.audio_allowed())
	audio.play_sound_ids([500], true, CityViewMode.Mode.CITY, 2)
	assert(audio.wave_sound_gate.accepted_count == 1)
	var track := audio.current_track_id
	audio.handle_application_focus_in(true)
	assert(audio.current_track_id == track, "Returning focus changed the music track")
	audio.handle_application_focus_out()
	audio.set_background_audio(false)
	assert(audio.music_playback_is_active() and audio.focus_paused and not audio.audio_allowed())
	assert(not audio.play_music_track(10001))
	audio.play_sound_ids([503], true, CityViewMode.Mode.CITY, 2)
	assert(audio.wave_sound_gate.accepted_count == 1)
	audio.queue_free()
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, "--preview" not in OS.get_cmdline_user_args())
	root.add_child(main)
	await process_frame
	main.city_session.activate_document(EmptyCityTemplate.create())
	main.interface.hide_main_menu()
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	var saved: PackedByteArray = main.document_state.city.document.serialize().data
	var center: Vector2 = main.map_view.source_center
	var scale: float = main.map_view.camera._view_scale()
	main.map_view.pan_screen(Vector2(10, -10))
	assert(main.map_view.source_center.is_equal_approx(center + Vector2(10, -10) / scale))
	main.map_view.pan_screen(Vector2(-10, 10))
	assert(main.document_state.city.document.serialize().data == saved, "Panning changed saved data")
	assert(main.options_menu.get_popup().get_item_index(CityMenuBar.MENU_SETTINGS) >= 0)
	var settings_key := InputEventKey.new()
	settings_key.keycode = KEY_COMMA
	settings_key.pressed = true
	settings_key.meta_pressed = OS.has_feature("macos")
	settings_key.ctrl_pressed = not OS.has_feature("macos")
	assert(main.city_menu_bar.handle_shortcut(settings_key))
	assert(main.main_overlays.settings_dialog.visible)


	assert(not main.camera_input.camera_keys_allowed())
	main.main_overlays.settings_dialog.background_audio_check.button_pressed = true
	assert(main.main_overlays.settings_dialog.selected_values().background_audio)
	main.main_overlays.settings_dialog.hide()
	var details := "Police Station\n\nOfficers: 42\nAnnual cost: $100\nFunding: 100%\n\nAdvanced tile data\nTile ID: 211\nXBIT: 0x00"
	main.city_dialogs.query_dialog.show_query("Police Station", "Central Police", true, details, "")
	assert(main.city_dialogs.query_dialog.tabs.current_tab == 0)
	assert(main.city_dialogs.query_dialog.summary_rows.get_child_count() == 3)
	assert(not main.camera_input.camera_keys_allowed())
	main.city_dialogs.query_dialog._enable_rename()
	main.city_dialogs.query_dialog.name_input.text = "North Police"
	assert(main.city_dialogs.query_dialog.facility_name() == "North Police")

	if "--preview" in OS.get_cmdline_user_args():
		main.city_dialogs.query_dialog.name_input.editable = false
		main.city_dialogs.query_dialog.ok_button.grab_focus()
		main.map_view.viewport_changed.connect(func() -> void:
			print("CAMERA center=%s zoom=%d" % [main.map_view.source_center, main.map_view.zoom_percent()]))
		print("PREVIEW ready center=%s" % main.map_view.source_center)

		return

	main.city_dialogs.query_dialog.close_query()
	main.queue_free()
	await process_frame
	print("PASS: camera momentum, query overview, settings access, Settings renderer and background audio")
	quit()


func _test_menu_shortcuts() -> void:
	var menu := CityMenuBar.new()
	root.add_child(menu)
	var actions: Array[int] = []
	menu.file_menu_requested.connect(func(id: int) -> void: actions.append(id))
	var key := InputEventKey.new()
	key.pressed = true
	key.meta_pressed = OS.has_feature("macos")
	key.ctrl_pressed = not OS.has_feature("macos")
	for pair in [[KEY_N, 0], [KEY_O, 1], [KEY_S, CityMenuBar.MENU_SAVE_CITY]]:
		key.keycode = pair[0]
		assert(menu.handle_shortcut(key))
		assert(actions.back() == pair[1])
	key.shift_pressed = true
	assert(menu.handle_shortcut(key) and actions.back() == 2)
	var popup := menu.file_menu.get_popup() as ScurkContextMenu
	popup.set_item_disabled(popup.get_item_index(2), true)
	assert(not menu.handle_shortcut(key) and actions.size() == 4)
	popup.set_item_disabled(popup.get_item_index(2), false)
	menu.file_menu.disabled = true
	assert(not menu.handle_shortcut(key) and actions.size() == 4)
	menu.file_menu.disabled = false
	key.echo = true
	assert(not menu.handle_shortcut(key))
	key.echo = false
	key.pressed = false
	assert(not menu.handle_shortcut(key))
	key.pressed = true
	popup._shortcut_input(key)
	assert(actions.size() == 5 and actions.back() == 2)
	menu.set_scenario_available(true)
	var debug_actions: Array[int] = []
	menu.windows_menu_requested.connect(func(id: int) -> void: debug_actions.append(id))
	key.meta_pressed = false
	key.ctrl_pressed = false
	key.shift_pressed = false
	key.keycode = KEY_F12
	assert(menu.handle_shortcut(key) and debug_actions == [7])
	menu.set_scenario_available(false)
	assert(menu.handle_shortcut(key) and debug_actions == [7, 7])
	menu.free()
