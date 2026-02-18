extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "user://test_soundtrack_settings_%d.cfg" % OS.get_process_id()
	var folder := ProjectSettings.globalize_path("res://../references/OST")
	assert(AppSettingsStore.load_values(path).soundtrack_folder == "")
	assert(AppSettingsStore.save_values(0.5, 0.3, false, path, "auto", "", folder) == OK)
	assert(AppSettingsStore.load_values(path).soundtrack_folder == folder)
	assert(AppSettingsStore.save_values(0.2, 0.3, false, path) == OK)
	assert(AppSettingsStore.load_values(path).soundtrack_folder == folder)
	var dialog := AppSettingsDialog.new()
	root.add_child(dialog)
	dialog.show_values(0.5, 0.3, false)
	assert(not dialog.selected_values().has("soundtrack_folder"))
	dialog.music_pack_edit.text = "/music/pack.json"
	assert(dialog.selected_values().music_pack_folder == "/music/pack.json")
	var controller := CityAudioController.new()
	root.add_child(controller)
	controller.setup("/missing/imported", 0.5, 0.0, false)
	assert(controller.resolve_soundtrack_folder(folder) == folder)
	controller.menu_music = true
	controller.set_soundtrack_folder(folder, true)
	assert(controller.soundtrack_folder == folder and controller.current_track_id == MusicDirector.MAIN_THEME_TRACK)
	assert(controller.music_playback_is_active())
	controller.handle_application_focus_out()
	controller.set_soundtrack_folder("/missing/OST", true)
	assert(not controller.music_playback_is_active())
	assert(AppSettingsStore.save_values(0.2, 0.3, false, path, "auto", "", "") == OK)
	assert(AppSettingsStore.load_values(path).soundtrack_folder == "")
	controller.free()
	dialog.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await process_frame
	print("PASS: soundtrack folder persistence, browse selection, detection, reset, immediate track switch and focus guard")
	quit()
