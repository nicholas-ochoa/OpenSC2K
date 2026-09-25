extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var reference := ProjectSettings.globalize_path("res://../references/SIMCITY2000")

	for shuffle in [false, true]:
		var audio := CityAudioController.new()
		root.add_child(audio)
		audio.setup(reference, 0.0, 0.0, false)
		audio.startup_theme_pending = true
		audio.set_shuffle_music(shuffle)
		audio.shuffle_order.remaining.assign([10004])
		assert(not audio.play_music_track(10004) and audio.startup_theme_pending, "Mute cleared the pending title track")
		audio.set_volumes(0.5, 0.0)
		audio.music_pack.files[10004] = reference.path_join("SOUNDS/10004.MID")
		assert(not audio.play_music_track(10004) and audio.startup_theme_pending, "Missing title cannot start a different song")
		audio.music_pack.files[MusicDirector.MAIN_THEME_TRACK] = reference.path_join("SOUNDS/10001.MID")
		audio.handle_application_focus_out()
		assert(not audio.play_music_track(10004) and audio.startup_theme_pending)
		audio.handle_application_focus_in(true)
		assert(audio.current_track_id == MusicDirector.MAIN_THEME_TRACK and not audio.startup_theme_pending)
		audio.set_menu_music(true)
		audio._on_music_track_finished(MusicDirector.MAIN_THEME_TRACK)
		audio.advance(15000)
		assert(audio.current_track_id == (10004 if shuffle else MusicDirector.MAIN_THEME_TRACK), "Normal menu/shuffle behavior resumes after the title")
		audio.free()

	# Read an actual saved shuffle preference through the application startup path.
	var settings_path := "user://title-music-startup-test.cfg"
	var settings := ConfigFile.new()
	settings.set_value("audio", "music_pack_folder", ProjectSettings.globalize_path("res://../ext/music"))
	settings.set_value("audio", "sound_pack_folder", ProjectSettings.globalize_path("res://../ext/sound"))
	settings.set_value("audio", "music_volume", 0.5)
	settings.set_value("audio", "shuffle_music", true)
	settings.set_value("audio", "background_audio", true)
	settings.set_value("graphics", "source", "folder")
	settings.set_value("graphics", "folder", ProjectSettings.globalize_path("res://../ext/graphics"))
	assert(settings.save(settings_path) == OK)
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	OS.set_environment("OPENSC2K_DATA_PACK", ProjectSettings.globalize_path("res://../ext/data"))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.asset_state.reference_root = reference
	main.preferences.settings_path = settings_path
	root.add_child(main)
	# Put a known non-title song next in the bag before the first process frame.
	main.audio_controller.shuffle_order.remaining.assign([10004])
	await process_frame
	await process_frame
	assert(main.preferences.shuffle_music and main.main_menu.visible)
	assert(main.audio_controller.current_track_id == MusicDirector.MAIN_THEME_TRACK)
	assert(not main.audio_controller.startup_theme_pending)
	assert(main.audio_controller.shuffle_order.remaining == [10004])
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	print("PASS: title first despite saved shuffle, mute/focus delay, missing media and normal follow-up music")
	quit()
