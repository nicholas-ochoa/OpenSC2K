extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
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
	audio.setup(ProjectSettings.globalize_path("res://../references"), 0.5, 0.5)
	audio.set_background_audio(true)
	assert(audio.play_music_track(10000))
	audio.handle_application_focus_out()
	assert(audio.music_playback_is_active() and audio.audio_allowed())
	audio.play_sound_events([500], true, "city", 2)
	assert(audio.wave_sound_gate.accepted_count == 1)
	var track := audio.current_track_id
	audio.handle_application_focus_in(true)
	assert(audio.current_track_id == track, "Returning focus changed the music track")
	audio.handle_application_focus_out()
	audio.set_background_audio(false)
	assert(not audio.music_playback_is_active() and not audio.audio_allowed())
	assert(not audio.play_music_track(10001))
	audio.play_sound_events([503], true, "city", 2)
	assert(audio.wave_sound_gate.accepted_count == 1)
	audio.queue_free()
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main._activate_document(EmptyCityTemplate.create())
	main._hide_main_menu()
	main._select_speed(GameSpeedController.Speed.PAUSED)
	var saved: PackedByteArray = main.city.document.serialize().data
	var center: Vector2 = main.map_view.source_center
	var scale: float = main.map_view._view_scale()
	main.map_view.pan_screen(Vector2(10, -10))
	assert(main.map_view.source_center.is_equal_approx(center + Vector2(10, -10) / scale))
	main.map_view.pan_screen(Vector2(-10, 10))
	assert(main.city.document.serialize().data == saved, "Panning changed saved data")
	assert(main.options_menu.get_popup().get_item_index(CityMenuBar.MENU_SETTINGS) >= 0)
	assert(main.options_menu.get_popup().get_item_index(CityMenuBar.MENU_RENDERER_GPU) < 0)
	assert(main.city_menu_bar.renderer_menu.get_item_index(CityMenuBar.MENU_RENDERER_GPU) >= 0)
	main._on_options_menu(CityMenuBar.MENU_SETTINGS)
	assert(main.settings_dialog.visible)
	assert(not main._camera_keys_allowed())
	main.settings_dialog.background_audio_check.button_pressed = true
	assert(main.settings_dialog.selected_values().background_audio)
	main.settings_dialog.hide()
	var details := "Police Station\n\nOfficers: 42\nAnnual cost: $100\nFunding: 100%\n\nAdvanced tile data\nTile ID: 211\nXBIT: 0x00"
	main.query_dialog.show_query("Police Station", "Central Police", true, details, "", "Police Station", null, "")
	assert(main.query_dialog.tabs.current_tab == 0)
	assert(main.query_dialog.summary_rows.get_child_count() == 3)
	assert(main.query_dialog.details_grid.columns == 4)
	assert(not main._camera_keys_allowed())
	main.query_dialog._enable_rename()
	main.query_dialog.name_input.text = "North Police"
	assert(main.query_dialog.facility_name() == "North Police")
	if "--preview" in OS.get_cmdline_user_args():
		main.query_dialog.name_input.editable = false
		main.query_dialog.ok_button.grab_focus()
		main.map_view.viewport_changed.connect(func() -> void: print("CAMERA center=%s zoom=%d" % [main.map_view.source_center, main.map_view.zoom_percent()]))
		print("PREVIEW ready center=%s" % main.map_view.source_center)
		return
	main.query_dialog.close_query()
	main.queue_free()
	await process_frame
	print("PASS: camera momentum, query overview, settings access, renderer submenu and background audio")
	quit()
