class_name CityAudioController
extends Node

signal music_activity_changed(active: bool)

const Music = preload("res://src/audio/music_director.gd")
const MidiSynth = preload("res://src/audio/midi_synth_player.gd")
const MovingThingAudio = preload("res://src/audio/moving_thing_audio.gd")
const WaveSounds = preload("res://src/audio/wave_sound_gate.gd")

const SOUND_EFFECT_GROUP := &"open_sc2k_sound_effects"

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
var application_has_focus := true
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
	if menu_music and application_has_focus and music_volume > 0.0 and not music_playback_is_active():
		play_music_track(Music.MAIN_THEME_TRACK)


func set_volumes(new_music_volume: float, new_effects_volume: float) -> void:
	music_volume = clampf(new_music_volume, 0.0, 1.0)
	effects_volume = clampf(new_effects_volume, 0.0, 1.0)
	if music_player != null:
		music_player.set_volume_linear(music_volume)
	if recording_player != null:
		recording_player.volume_linear = music_volume


func play_music_track(track_id: int) -> bool:
	if music_player == null or track_id < Music.FIRST_TRACK_ID or track_id >= Music.FIRST_TRACK_ID + Music.TRACK_COUNT:
		return false
	var recordings := RecordedSoundtrack.find_tracks(soundtrack_folder, track_id)
	if recordings.is_empty() and not original_media_enabled:
		return false
	stop_music()
	current_track_id = track_id
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
	if not original_media_enabled:
		music_activity_changed.emit(false)
		return false
	var result := music_player.play_path(reference_root.path_join("SOUNDS/%d.MID" % current_track_id), current_track_id)
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


func handle_application_focus_out() -> void:
	application_has_focus = false
	stop_music()
	stop_sound_effects()


func handle_application_focus_in(music_enabled: bool) -> void:
	var regained_focus := not application_has_focus
	application_has_focus = true
	if not regained_focus or not music_enabled:
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
	if not sound_enabled:
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
	if not sound_enabled:
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
	if not original_media_enabled:
		return
	for sound_id in range(WaveSounds.SOUND_FIRST, WaveSounds.SOUND_LAST + 1):
		var sound_path := reference_root.path_join("SOUNDS/%d.WAV" % sound_id)
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
	if enabled and application_has_focus and music_volume > 0.0:
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
	if restart_music and application_has_focus and music_volume > 0.0:
		play_music_track(track_id if track_id >= 0 else Music.MAIN_THEME_TRACK if menu_music else music_director.next_general_track())
