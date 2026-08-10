extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var reference := ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	var settings_path := "user://about-music-%d.cfg" % OS.get_process_id()
	var settings := ConfigFile.new()
	settings.set_value("audio", "music_volume", 0.5)
	settings.set_value("audio", "shuffle_music", true)
	settings.set_value("audio", "background_audio", true)
	settings.set_value("graphics", "source", "folder")
	settings.set_value("graphics", "folder", ProjectSettings.globalize_path("res://../ext/graphics"))
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	assert(settings.save(settings_path) == OK)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.asset_state.reference_root = reference
	main.preferences.settings_path = settings_path
	root.add_child(main)
	await process_frame
	await process_frame
	var audio: CityAudioController = main.audio_controller
	assert(audio.current_track_id == MusicDirector.MAIN_THEME_TRACK)
	var shuffle_before := audio.shuffle_order.remaining.duplicate()
	main.interface.open_about_dialog()
	assert(main.about_dialog.visible and audio.current_track_id == 10011)
	assert(audio.shuffle_order.remaining == shuffle_before)
	main.about_dialog.hide()
	assert(audio.current_track_id == 10011, "Closing About leaves the selected song playing")

	audio._on_music_track_finished(10011)
	assert(audio.music_gap_remaining_msec > 0.0)
	main.interface.open_about_dialog()
	assert(audio.current_track_id == 10011 and audio.music_gap_remaining_msec == 0.0)
	assert(audio.queued_music_track == -1)
	main.about_dialog.hide()

	audio.play_music_track(10004, false)
	audio.set_volumes(0.0, 0.0)
	main.interface.open_about_dialog()
	assert(audio.current_track_id == 10004, "Music track changed while muted")
	main.about_dialog.hide()
	audio.set_volumes(0.5, 0.0)
	audio._set_music_paused(true)
	main.interface.open_about_dialog()
	assert(audio.current_track_id == 10004 and audio.music_paused)
	main.about_dialog.hide()
	audio._set_music_paused(false)
	audio.set_background_audio(false)
	audio.handle_application_focus_out()
	main.interface.open_about_dialog()
	assert(audio.current_track_id == 10004, "About respects focus pause")
	main.about_dialog.hide()
	audio.handle_application_focus_in(true)
	audio.set_background_audio(true)

	main.city_files._load_city_unchecked(reference.path_join("CITIES/CAPEQUES.SC2"))
	assert(main.document_state.city != null and main.document_state.city.set_music_enabled(false))
	audio.stop_music()
	main.interface.open_about_dialog()
	assert(audio.current_track_id == -1, "The city's disabled Music option is respected")
	main.about_dialog.hide()
	assert(main.document_state.city.set_music_enabled(true))
	main.interface.open_about_dialog()
	assert(audio.current_track_id == 10011)
	main.about_dialog.hide()

	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	print("PASS: About selects 10011 from menu/city, overrides shuffle/gap, and respects mute, pause, focus and city Music")
	quit()
