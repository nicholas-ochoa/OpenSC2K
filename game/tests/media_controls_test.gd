extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var audio := CityAudioController.new()
	root.add_child(audio)
	audio.setup(ProjectSettings.globalize_path("res://../references/SIMCITY2000"), 0.5, 0.5)
	assert(audio.play_music_track(10018))
	assert(audio.handle_media_key(KEY_MEDIANEXT) and audio.current_track_id == 10000)
	assert(audio.handle_media_key(KEY_MEDIAPREVIOUS) and audio.current_track_id == 10018)
	assert(audio.handle_media_key(KEY_MEDIAPLAY) and audio.music_paused)
	assert(audio.music_player._paused)
	assert(not audio.play_music_track(10004), "Automatic requests cannot interrupt manual pause")
	audio.advance(5000)
	assert(audio.current_track_id == 10018)
	assert(audio.handle_media_key(KEY_MEDIAPLAY) and not audio.music_paused)
	assert(audio.current_track_id == 10018)
	assert(audio.handle_media_key(KEY_MEDIASTOP) and audio.music_paused)
	assert(audio.handle_media_key(KEY_MEDIAPLAY) and audio.current_track_id == MusicDirector.MAIN_THEME_TRACK)
	assert(not audio.handle_media_key(KEY_A))
	var bar := CityStatusBar.new()
	root.add_child(bar)
	bar.set_reports(PackedStringArray(["Test report"]))
	bar.show_music_notice("Playing: Test track")
	assert(bar.reports_label.text == "Playing: Test track")
	bar.update_report_rotation(5.1)
	assert(bar.reports_label.text == "News: Test report")

	for tile in range(0xfb, 0xff):
		assert(QueryNeighborhood.zoom_for_tile(tile) == 2.0)

	assert(QueryNeighborhood.zoom_for_tile(0xc9) == 2.5)
	assert(ToolSoundRules.success_events(2, 0) == [506])
	assert(ToolSoundRules.success_events(2, 1) == [509])
	assert(ToolSoundRules.success_events(2, 2) == [506])
	audio.queue_free()
	bar.queue_free()
	await process_frame
	print("PASS: media controls, pause retention, track wrap, news restoration, arcology zoom and dispatch sounds")
	quit()
