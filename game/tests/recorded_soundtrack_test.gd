extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var folder := ProjectSettings.globalize_path("user://soundtrack-test")
	DirAccess.make_dir_recursive_absolute(folder)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(44100)

	for i in 22050:
		samples.encode_s16(i * 2, roundi(sin(i * TAU * 440.0 / 22050.0) * 2000))

	wav.data = samples
	assert(wav.save_to_wav(folder.path_join("source.wav")) == OK)

	for extension in ["mp3", "ogg", "flac"]:
		var path := folder.path_join("10001 - Test." + extension)
		assert(OS.execute(RecordedSoundtrack.ffmpeg_executable(), PackedStringArray(["-nostdin", "-v", "error", "-y", "-i", folder.path_join("source.wav"), "-ac", "2", "-strict", "-2", "-c:a", {"ogg": "vorbis", "mp3": "libmp3lame", "flac": "flac"}[extension], path])) == 0)
		var loaded := RecordedSoundtrack.load_track(PackedStringArray([path]))
		assert(loaded.stream != null and loaded.stream.get_length() >= 0.9)

	var matches := RecordedSoundtrack.find_tracks(folder, 10001)
	assert(matches.size() == 3 and matches[0].ends_with("flac"))
	assert(RecordedSoundtrack.find_tracks(folder, 10000).is_empty())
	var reference := ProjectSettings.globalize_path("res://../references/SIMCITY2000/OST")

	if DirAccess.dir_exists_absolute(reference):
		for track_id in range(10000, 10019):
			var files := RecordedSoundtrack.find_tracks(reference, track_id)
			assert(files.size() == 1)

		var source := RecordedSoundtrack.find_tracks(reference, 10001)[0]
		var hash_before := FileAccess.get_sha256(source)
		var actual := RecordedSoundtrack.load_track(PackedStringArray([source]))
		assert(actual.stream != null and actual.stream.get_length() > 10)
		assert(FileAccess.get_sha256(source) == hash_before)

	var controller := CityAudioController.new()
	root.add_child(controller)
	controller.setup("", 0.25, 0.0, false)
	controller.soundtrack_folder = folder
	# Exercise the asynchronous path with Dummy output, without bypassing decode.
	controller.current_track_id = 10001
	controller.pending_recording = RecordedSoundtrack.Request.new(matches, controller.music_request)
	var deadline := Time.get_ticks_msec() + 15000

	while not controller.recording_player.playing and Time.get_ticks_msec() < deadline:
		await process_frame

	assert(controller.recording_player.playing)
	controller.set_volumes(0.1, 0.0)
	assert(is_equal_approx(controller.recording_player.volume_linear, 0.1))
	controller.handle_application_focus_out()
	assert(controller.recording_player.stream != null and controller.recording_player.stream_paused and controller.pending_recording == null)
	# Stop the request before its worker finishes; check that playback stays stopped.
	controller.pending_recording = RecordedSoundtrack.Request.new(matches, controller.music_request)
	controller._process(0)
	controller.stop_music()

	while controller.recording_thread != null:
		await process_frame

	assert(not controller.recording_player.playing)
	controller.free()
	await create_timer(0.1).timeout
	print("PASS: MP3/Ogg/FLAC decode, track mapping, supplied FLAC, source preservation, asynchronous playback, volume, focus and cancellation")
	quit()
