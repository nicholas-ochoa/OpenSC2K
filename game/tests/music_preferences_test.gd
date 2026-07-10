extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var order := MusicShuffle.new()
	order.random.seed = 42
	var previous := -1

	for cycle in 3:
		var seen := {}

		for index in 19:
			var id := order.next_track()
			assert(id >= 10000 and id <= 10018 and not seen.has(id) and id != previous)
			seen[id] = true
			previous = id

	var audio := CityAudioController.new()
	root.add_child(audio)
	audio.setup(ProjectSettings.globalize_path("res://../references/SIMCITY2000"), 0.5, 0.0)
	audio.set_shuffle_music(true)
	assert(audio.play_music_track(10001))
	var first := audio.current_track_id
	var request := audio.music_request
	assert(audio.play_music_track(10004) and audio.current_track_id == first)
	audio.handle_application_focus_out()
	assert(audio.focus_paused and audio.music_player._paused)
	assert(audio.current_track_id == first and audio.music_request == request)
	audio.handle_application_focus_in(true)
	assert(not audio.focus_paused and not audio.music_player._paused)
	assert(audio.current_track_id == first and audio.music_request == request)
	audio._set_music_paused(true)
	audio.handle_application_focus_out()
	audio.handle_application_focus_in(true)
	assert(audio.music_paused and audio.music_player._paused)
	audio._set_music_paused(false)
	audio._on_music_track_finished(first)
	assert(audio.music_gap_remaining_msec == 5000.0 and not audio.dummy_music_active)
	audio.handle_application_focus_out()
	audio.advance(6000.0)
	assert(audio.music_gap_remaining_msec == 5000.0)
	audio.handle_application_focus_in(true)
	audio.advance(4999.0)
	assert(not audio.dummy_music_active and audio.music_gap_remaining_msec == 1.0)
	audio.advance(1.0)
	assert(audio.dummy_music_active and audio.current_track_id != first)
	# Background focus notifications cannot cancel or replace the track,
	# even when the caller has no active city, for example during New City.
	audio.set_background_audio(true)
	var retained_track := audio.current_track_id
	var retained_request := audio.music_request
	audio.handle_application_focus_out()
	audio.handle_application_focus_in(false)
	assert(audio.current_track_id == retained_track and audio.music_request == retained_request)
	assert(not audio.focus_paused and not audio.music_player._paused)
	audio.set_background_audio(false)
	# Exercise a real recording stream with Dummy output, including its cursor.
	audio.set_shuffle_music(false)
	var wav := AudioStreamWAV.new()
	wav.mix_rate = 22050
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	var samples := PackedByteArray()
	samples.resize(22050 * 5)
	samples.fill(128)
	wav.data = samples
	audio.recording_player.stream = wav
	audio.recording_player.play(1.0)
	await create_timer(0.08).timeout
	audio.handle_application_focus_out()
	await create_timer(0.08).timeout
	var position := audio.recording_player.get_playback_position()
	# Allow one audio mix-buffer correction, but reject a running cursor.
	await create_timer(0.3).timeout
	assert(absf(audio.recording_player.get_playback_position() - position) < 0.1)
	assert(audio.recording_player.stream_paused and position >= 1.0)
	audio.handle_application_focus_in(true)
	assert(audio.recording_player.get_playback_position() >= position - 0.1)
	await create_timer(0.08).timeout
	assert(not audio.recording_player.stream_paused and audio.recording_player.stream == wav)
	audio.stop_music()
	# MIDI keeps its synthesized position and sequence during focus pause.
	assert(audio.music_player.play_path(ProjectSettings.globalize_path("res://../references/SIMCITY2000/SOUNDS/10001.MID"), 10001).ok)
	audio.dummy_music_active = true
	audio.current_track_id = 10001
	audio.handle_application_focus_out()
	var paused_metrics: Dictionary = audio.music_player.debug_metrics()
	assert(paused_metrics.paused and paused_metrics.thread_running)
	var midi_position: float = paused_metrics.position_seconds
	await create_timer(0.2).timeout
	assert(audio.music_player.debug_metrics().position_seconds == midi_position)
	audio.handle_application_focus_in(true)
	var resumed_metrics: Dictionary = audio.music_player.debug_metrics()
	assert(resumed_metrics.position_seconds >= midi_position and not resumed_metrics.paused)
	audio.free()
	var config := "user://shuffle-test.cfg"
	assert(AppSettingsStore.save_values(0.5, 0.5, false, config, "auto", "", null, null, null, null, null, null, null, true) == OK)
	assert(AppSettingsStore.load_values(config).shuffle_music)
	DirAccess.remove_absolute(config)
	print("PASS: 19-track shuffle cycles, special-request retention, focus/manual pause, recording/MIDI cursors, settings")
	quit()
