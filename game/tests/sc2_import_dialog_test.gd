extends SceneTree
## Real background import, selective activation and repeat imports through the scene.

var completed := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var temporary := ProjectSettings.globalize_path("res://../local/sc2-import-dialog-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var source := temporary.path_join("source")
	assert(DirAccess.make_dir_recursive_absolute(source) == OK)
	var voice := Sc2ImportAudio.pcm_wave(PackedByteArray([128, 130, 128, 125]), 11025, 1, 8).bytes
	_write(source.path_join("500.wav"), voice)
	# One note with a standard end-of-track; no external sound or font required.
	var midi := PackedByteArray([77, 84, 104, 100, 0, 0, 0, 6, 0, 0, 0, 1, 0, 60,
		77, 84, 114, 107, 0, 0, 0, 12, 0, 144, 60, 80, 60, 128, 60, 0, 0, 255, 47, 0])
	_write(source.path_join("10001.mid"), midi)
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", temporary.path_join("missing-graphics"))
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	main.preferences.settings_path = temporary.path_join("settings.cfg")
	root.add_child(main)
	await process_frame
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", "")
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	assert(not main.asset_state.assets_ready)
	var dialog := main.reference_import_dialog
	dialog.packs_root = temporary.path_join("packs")
	dialog.packs_imported.connect(func(_result: Sc2MediaImportResult) -> void: completed += 1)
	main.settings.open_import_settings()
	main.main_overlays.settings_dialog.get_node("%ImportButton").pressed.emit()
	assert(dialog.visible and not main.main_overlays.settings_dialog.visible)
	assert(dialog.selected_categories() == PackedStringArray(["graphics", "sound", "music"]))
	assert(main.main_overlays.blocking_windows.has(dialog))
	dialog._select_source(source)
	assert(not dialog.import_button.disabled)
	var prior_graphics := main.preferences.graphics_folder
	var prior_mode := main.preferences.graphics_source
	dialog.import_button.pressed.emit()
	assert(dialog.busy and dialog.import_button.disabled and dialog.close_button.disabled)
	dialog.close_requested.emit()
	assert(dialog.visible, "Do not close while an import writes packs")
	dialog.start_import()
	await _finish(dialog)
	assert(completed == 1 and dialog.last_result.ok and dialog.last_result.partial)
	assert(dialog.last_result.failures.has("graphics"))
	assert(main.preferences.graphics_folder == prior_graphics and main.preferences.graphics_source == prior_mode)
	assert(main.preferences.sound_pack_folder == dialog.last_result.sound)
	assert(main.preferences.music_pack_folder == dialog.last_result.music)
	assert(main.audio_controller.sound_pack.files.has(500) and main.audio_controller.music_pack.files.has(10001))
	var first := dialog.last_result
	var retained_music: MediaPack = main.audio_controller.music_pack
	var music_preference := main.preferences.music_pack_folder
	main.preferences.soundtrack_folder = "custom-recordings"
	dialog.graphics_check.button_pressed = false
	dialog.music_check.button_pressed = false
	assert(dialog.selected_categories() == PackedStringArray(["sound"]))
	dialog.import_button.pressed.emit()
	await _finish(dialog)
	assert(completed == 2 and dialog.last_result.ok and dialog.last_result.music.is_empty())
	assert(dialog.last_result.root != first.root and FileAccess.file_exists(first.sound))
	assert(main.audio_controller.music_pack == retained_music and main.preferences.music_pack_folder == music_preference)
	assert(main.preferences.soundtrack_folder == "custom-recordings")
	var retained_sound: MediaPack = main.audio_controller.sound_pack
	var sound_preference := main.preferences.sound_pack_folder
	# A failed import keeps both active packs and saved preferences unchanged.
	dialog._select_source(temporary.path_join("does-not-exist"))
	dialog.import_button.pressed.emit()
	await _finish(dialog)
	assert(completed == 2 and not dialog.last_result.ok)
	assert(main.audio_controller.sound_pack == retained_sound and main.preferences.sound_pack_folder == sound_preference)
	assert(main.audio_controller.music_pack == retained_music)
	assert(not main.audio_controller.set_media_pack("sound", temporary.path_join("bad-pack")))
	assert(main.audio_controller.sound_pack == retained_sound and main.audio_controller.music_pack == retained_music)
	dialog.sound_check.button_pressed = false
	assert(dialog.import_button.disabled)
	var saved := AppSettingsStore.load_values(main.preferences.settings_path)
	assert(saved.sound_pack_folder == sound_preference and saved.music_pack_folder == music_preference)
	dialog.close_button.pressed.emit()
	assert(not dialog.visible and main.main_overlays.settings_dialog.visible)
	assert(FileAccess.get_file_as_bytes(source.path_join("500.wav")) == voice)
	assert(FileAccess.get_file_as_bytes(source.path_join("10001.mid")) == midi)
	main.queue_free()
	await process_frame
	assert(OriginalGameInstaller.remove_tree(temporary) == OK)
	print("PASS: import scene, background completion, busy close guard, all/selective categories, partial failure, activation, preserved preferences and coexistence")
	quit()


func _finish(dialog: Sc2AssetImportDialog) -> void:
	var deadline := Time.get_ticks_msec() + 10000

	while dialog.busy and Time.get_ticks_msec() < deadline:
		await process_frame

	assert(not dialog.busy and dialog.last_result != null, "Background import did not finish")


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(bytes)
