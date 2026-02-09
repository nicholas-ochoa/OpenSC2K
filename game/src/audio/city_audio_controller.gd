class_name CityAudioController
extends Node

signal music_activity_changed(active: bool)
signal music_notice(message: String)

const Music = preload("res://src/audio/music_director.gd")
const MidiSynth = preload("res://src/audio/midi_synth_player.gd")
const MovingThingAudio = preload("res://src/audio/moving_thing_audio.gd")
const WaveSounds = preload("res://src/audio/wave_sound_gate.gd")

const SOUND_EFFECT_GROUP := &"open_sc2k_sound_effects"

var sound_pack := MediaPack.new()
var music_pack := MediaPack.new()

var reference_root := ""
var original_media_enabled := true
var music_volume := 0.8
var effects_volume := 0.8
var music_director := Music.new()
var music_player: MidiSynthPlayer
var recording_player: AudioStreamPlayer
var soundtrack_folder := ""
var recording_thread: Thread
var music_request := 0
var recording_request := -1
var pending_recording: Dictionary = {}
var dummy_music_active := false
var menu_music := false
var current_track_id := -1
var music_paused := false
var current_track_name := ""
var application_has_focus := true
var background_audio := false
var tool_loop_player: AudioStreamPlayer
var wave_sound_gate := WaveSounds.new()
var wave_stream_cache: Dictionary = {}


func setup(
	root_path: String, initial_music_volume: float, initial_effects_volume: float,
	use_original_media := true,
) -> void:
	reference_root = root_path
	original_media_enabled = use_original_media
	music_volume = initial_music_volume
	effects_volume = initial_effects_volume
	soundtrack_folder = resolve_soundtrack_folder("")
	recording_player = AudioStreamPlayer.new()
	recording_player.finished.connect(func() -> void: _on_music_track_finished(current_track_id))
	add_child(recording_player)
	recording_player.volume_linear = music_volume
	_load_wave_sound_cache()
	music_player = MidiSynth.new()
	music_player.track_finished.connect(_on_music_track_finished)
	add_child(music_player)
	music_player.set_volume_linear(music_volume)


func advance(delta_msec: float) -> void:
	wave_sound_gate.advance(delta_msec)
	if menu_music and audio_allowed() and music_volume > 0.0 and not music_playback_is_active():
		play_music_track(Music.MAIN_THEME_TRACK)


func set_volumes(new_music_volume: float, new_effects_volume: float) -> void:
	music_volume = clampf(new_music_volume, 0.0, 1.0)
	effects_volume = clampf(new_effects_volume, 0.0, 1.0)
	if music_player != null:
		music_player.set_volume_linear(music_volume)
	if recording_player != null:
		recording_player.volume_linear = music_volume


func play_music_track(track_id: int) -> bool:
	if music_paused or not audio_allowed() or music_player == null or track_id < Music.FIRST_TRACK_ID or track_id >= Music.FIRST_TRACK_ID + Music.TRACK_COUNT:
		return false
	var replacement := str(music_pack.files.get(track_id, ""))
	var recordings := RecordedSoundtrack.find_tracks(soundtrack_folder, track_id)
	if not replacement.is_empty():
		recordings = PackedStringArray() if replacement.get_extension().to_lower() in ["mid", "midi"] else PackedStringArray([replacement])
	if recordings.is_empty() and replacement.is_empty() and not original_media_enabled:
		return false
	stop_music()
	current_track_id = track_id
	current_track_name = "Track %d" % track_id
	if not recordings.is_empty():
		current_track_name = recordings[0].get_file().get_basename().trim_prefix("%d - " % track_id)
	music_notice.emit("Playing: " + current_track_name)
	if AudioServer.get_driver_name() == "Dummy":
		dummy_music_active = true
		music_activity_changed.emit(true)
		return true
	if not recordings.is_empty():
		pending_recording = {"paths": recordings, "request": music_request}
		music_activity_changed.emit(true)
		return true
	return _play_midi_fallback()


func _play_midi_fallback() -> bool:
	var midi_path := str(music_pack.files.get(current_track_id, ""))
	if midi_path.get_extension().to_lower() not in ["mid", "midi"]:
		midi_path = reference_root.path_join("SOUNDS/%d.MID" % current_track_id) if original_media_enabled else ""
	if midi_path.is_empty():
		music_activity_changed.emit(false)
		return false
	var result := music_player.play_path(midi_path, current_track_id)
	music_player.set_paused(music_paused)
	music_activity_changed.emit(bool(result.ok))
	return bool(result.ok)


func _process(_delta: float) -> void:
	if recording_thread != null and not recording_thread.is_alive():
		var result: Dictionary = recording_thread.wait_to_finish()
		recording_thread = null
		if recording_request == music_request:
			recording_player.stream = result.stream
			if recording_player.stream != null:
				recording_player.play()
				recording_player.stream_paused = music_paused
			else:
				push_warning("Cannot decode soundtrack recording; trying MIDI. FLAC requires FFmpeg.")
				_play_midi_fallback()
	if recording_thread == null and not pending_recording.is_empty():
		recording_request = int(pending_recording.request)
		var paths: PackedStringArray = pending_recording.paths
		pending_recording.clear()
		recording_thread = Thread.new()
		if recording_thread.start(RecordedSoundtrack.load_track.bind(paths), Thread.PRIORITY_LOW) != OK:
			recording_thread = null
			_play_midi_fallback()


func _exit_tree() -> void:
	if recording_thread != null:
		recording_thread.wait_to_finish()
		recording_thread = null


func music_playback_is_active() -> bool:
	if AudioServer.get_driver_name() == "Dummy":
		return dummy_music_active
	return (not pending_recording.is_empty()
		or (recording_thread != null and recording_request == music_request)
		or (recording_player != null and recording_player.playing)
		or (music_player != null and music_player.is_track_active()))


func audio_allowed() -> bool:
	return application_has_focus or background_audio


func set_background_audio(enabled: bool) -> void:
	background_audio = enabled
	if not audio_allowed():
		stop_music()
		stop_sound_effects()


func handle_application_focus_out() -> void:
	application_has_focus = false
	if not background_audio:
		stop_music()
		stop_sound_effects()


func handle_application_focus_in(music_enabled: bool) -> void:
	var regained_focus := not application_has_focus
	application_has_focus = true
	if background_audio or not regained_focus or not music_enabled:
		return
	if not music_playback_is_active():
		play_music_track(Music.MAIN_THEME_TRACK if menu_music else music_director.next_general_track())


func stop_music() -> void:
	music_request += 1
	pending_recording.clear()
	if recording_player != null:
		recording_player.stop()
		recording_player.stream = null
	current_track_id = -1
	dummy_music_active = false
	if music_player != null:
		music_player.stop()
	music_activity_changed.emit(false)


func stop_sound_effects() -> void:
	wave_sound_gate.stop()
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(SOUND_EFFECT_GROUP):
		var player := node as AudioStreamPlayer
		if player == null:
			continue
		player.stop()
		player.queue_free()
	tool_loop_player = null


func play_sound_events(
	sound_events: Array, sound_enabled: bool, overlay_mode: String, view_size: int
) -> void:
	if not sound_enabled or not audio_allowed():
		return
	for sound_event in sound_events:
		var sound_id := MovingThingAudio.event_sound_id(
			sound_event, overlay_mode, view_size
		)
		if sound_id < 0:
			continue
		var stream := wave_stream_cache.get(sound_id) as AudioStreamWAV
		if stream == null or not wave_sound_gate.request(
			sound_id, sound_event is Dictionary and sound_event.has("thing_type")
		):
			continue
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_linear = effects_volume
		player.finished.connect(player.queue_free)
		add_child(player)
		player.add_to_group(SOUND_EFFECT_GROUP)
		player.play()


func start_tool_loop_sound(sound_id: int, sound_enabled: bool) -> void:
	stop_tool_loop_sound()
	if not sound_enabled or not audio_allowed():
		return
	var cached_stream := wave_stream_cache.get(sound_id) as AudioStreamWAV
	if cached_stream == null:
		return
	var stream := cached_stream.duplicate() as AudioStreamWAV
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = maxi(1, roundi(stream.get_length() * stream.mix_rate))
	tool_loop_player = AudioStreamPlayer.new()
	tool_loop_player.stream = stream
	tool_loop_player.volume_linear = effects_volume
	add_child(tool_loop_player)
	tool_loop_player.add_to_group(SOUND_EFFECT_GROUP)
	tool_loop_player.play()


func stop_tool_loop_sound() -> void:
	if not is_instance_valid(tool_loop_player):
		tool_loop_player = null
		return
	tool_loop_player.stop()
	tool_loop_player.queue_free()
	tool_loop_player = null


func debug_metrics() -> Dictionary:
	return {
		"wave_sound_id": wave_sound_gate.current_sound_id,
		"wave_sound_ticks": wave_sound_gate.remaining_ticks,
		"wave_sound_accepted": wave_sound_gate.accepted_count,
		"wave_sound_suppressed": wave_sound_gate.suppressed_count,
		"wave_stream_cache": wave_stream_cache.size(),
	}


func _on_music_track_finished(_track_id: int) -> void:
	dummy_music_active = false
	music_activity_changed.emit(false)


func _load_wave_sound_cache() -> void:
	wave_stream_cache.clear()
	for sound_id in range(WaveSounds.SOUND_FIRST, WaveSounds.SOUND_LAST + 1):
		var sound_path := str(sound_pack.files.get(sound_id, reference_root.path_join("SOUNDS/%d.WAV" % sound_id) if original_media_enabled else ""))
		if not FileAccess.file_exists(sound_path):
			continue
		var stream := AudioStreamWAV.load_from_file(sound_path)
		if stream != null:
			wave_stream_cache[sound_id] = stream


func set_menu_music(enabled: bool) -> void:
	if menu_music == enabled:
		return
	menu_music = enabled
	stop_music()
	if enabled and audio_allowed() and music_volume > 0.0:
		play_music_track(Music.MAIN_THEME_TRACK)


func resolve_soundtrack_folder(selected_folder: String) -> String:
	if not selected_folder.strip_edges().is_empty():
		return selected_folder.strip_edges()
	var environment_folder := OS.get_environment("OPENSC2K_SOUNDTRACK_DIR")
	return environment_folder if not environment_folder.is_empty() else reference_root.path_join("OST")


func set_soundtrack_folder(selected_folder: String, restart_music := false) -> void:
	var resolved := resolve_soundtrack_folder(selected_folder)
	if soundtrack_folder == resolved:
		return
	var track_id := current_track_id
	stop_music()
	soundtrack_folder = resolved
	if restart_music and audio_allowed() and music_volume > 0.0:
		play_music_track(track_id if track_id >= 0 else Music.MAIN_THEME_TRACK if menu_music else music_director.next_general_track())


func handle_media_key(key: int) -> bool:
	match key:
		KEY_MEDIAPLAY:
			if music_paused:
				_set_music_paused(false)
			elif music_playback_is_active():
				_set_music_paused(true)
			else:
				play_music_track(Music.MAIN_THEME_TRACK)
		KEY_MEDIANEXT, KEY_MEDIAPREVIOUS:
			var offset := 1 if key == KEY_MEDIANEXT else -1
			var track := current_track_id if current_track_id >= Music.FIRST_TRACK_ID else Music.MAIN_THEME_TRACK
			music_paused = false
			play_music_track(Music.FIRST_TRACK_ID + posmod(track - Music.FIRST_TRACK_ID + offset, Music.TRACK_COUNT))
		KEY_MEDIASTOP:
			stop_music()
			music_paused = true
			music_notice.emit("Music stopped")
		_:
			return false
	return true


func _set_music_paused(value: bool) -> void:
	music_paused = value
	if recording_player != null:
		recording_player.stream_paused = value
	if music_player != null:
		music_player.set_paused(value)
	if not value and not music_playback_is_active():
		play_music_track(Music.MAIN_THEME_TRACK)
	else:
		music_notice.emit(("Paused: " if value else "Playing: ") + current_track_name)


static func validate_media_packs(sound_folder: String, music_folder: String) -> String:
	for pair in [[sound_folder, "sound"], [music_folder, "music"]]:
		var pack := MediaPack.load_folder(pair[0], pair[1])
		if not pack.error.is_empty():
			return pack.error
	return ""


func set_media_packs(sound_folder: String, music_folder: String) -> bool:
	var sounds := MediaPack.load_folder(sound_folder, "sound")
	var music := MediaPack.load_folder(music_folder, "music")
	if not sounds.error.is_empty() or not music.error.is_empty():
		music_notice.emit(sounds.error + music.error)
		return false
	var track := current_track_id
	var restart := music_playback_is_active()
	stop_sound_effects()
	stop_music()
	sound_pack = sounds
	music_pack = music
	_load_wave_sound_cache()
	if restart:
		play_music_track(track)
	return true


func play_toolbar_click(sound_enabled: bool) -> void:
	if not sound_enabled or not audio_allowed():
		return
	var stream := wave_stream_cache.get(ToolSoundRules.SOUND_CENTER) as AudioStreamWAV
	if stream == null:
		return
	# each button activation gets feedback, including rapid consecutive clicks
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_linear = effects_volume
	player.finished.connect(player.queue_free)
	add_child(player)
	player.add_to_group(SOUND_EFFECT_GROUP)
	player.play()
