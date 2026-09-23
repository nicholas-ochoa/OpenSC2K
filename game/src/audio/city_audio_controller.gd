class_name CityAudioController
extends Node

signal music_activity_changed(active: bool)
signal music_notice(message: String)

const Music = preload("res://src/audio/music_director.gd")
const MidiSynth = preload("res://src/audio/midi_synth_player.gd")
const MovingThingAudio = preload("res://src/audio/moving_thing_audio.gd")
const WaveSounds = preload("res://src/audio/wave_sound_gate.gd")

const MUSIC_GAP_MSEC := 15000.0

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
var pending_recording: RecordedSoundtrack.Request
var dummy_music_active := false
var menu_music := false
var startup_theme_pending := false
var current_track_id := -1
var music_paused := false
var music_gap_remaining_msec := 0.0
var queued_music_track := -1
var queued_choose_shuffle := true
var focus_paused := false
var shuffle_music := false
var shuffle_order := MusicShuffle.new()
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
	recording_player.finished.connect(func() -> void:
		_on_music_track_finished(current_track_id))
	add_child(recording_player)
	recording_player.volume_linear = music_volume
	_load_wave_sound_cache()
	music_player = MidiSynth.new()
	music_player.track_finished.connect(_on_music_track_finished)
	add_child(music_player)
	music_player.set_volume_linear(music_volume)


func advance(delta_msec: float) -> void:
	wave_sound_gate.advance(delta_msec)

	if music_gap_remaining_msec > 0.0:
		if not audio_allowed() or music_paused or music_volume <= 0.0:
			return

		music_gap_remaining_msec = maxf(0.0, music_gap_remaining_msec - maxf(0.0, delta_msec))

		if music_gap_remaining_msec > 0.0:
			return

		var next_track := queued_music_track
		var choose_shuffle := queued_choose_shuffle
		queued_music_track = -1

		if next_track >= 0:
			play_music_track(next_track, choose_shuffle)
		else:
			music_activity_changed.emit(false)

	if menu_music and audio_allowed() and music_volume > 0.0 and not music_playback_is_active():
		play_music_track(Music.MAIN_THEME_TRACK)


func set_volumes(new_music_volume: float, new_effects_volume: float) -> void:
	music_volume = clampf(new_music_volume, 0.0, 1.0)
	effects_volume = clampf(new_effects_volume, 0.0, 1.0)

	if music_player != null:
		music_player.set_volume_linear(music_volume)

	if recording_player != null:
		recording_player.volume_linear = music_volume


func play_music_track(track_id: int, choose_shuffle := true, immediate := false) -> bool:
	if music_paused or not audio_allowed() or music_player == null or track_id < Music.FIRST_TRACK_ID or track_id >= Music.FIRST_TRACK_ID + Music.TRACK_COUNT:
		return false

	if startup_theme_pending:
		if music_volume <= 0.0:
			return false

		# keep the first request on the title track, including focus recovery,
		# city loading, and asynchronous recording preparation
		if music_playback_is_active():
			return true

		track_id = Music.MAIN_THEME_TRACK
		choose_shuffle = false

	if music_gap_remaining_msec > 0.0 and not immediate:
		queued_music_track = track_id
		queued_choose_shuffle = choose_shuffle
		music_activity_changed.emit(true)

		return true

	if shuffle_music and choose_shuffle:
		if music_playback_is_active():
			return true

		track_id = shuffle_order.next_track()

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
		_music_started()
		music_activity_changed.emit(true)

		return true

	if not recordings.is_empty():
		pending_recording = RecordedSoundtrack.Request.new(recordings, music_request)
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
	music_player.set_paused(music_paused or focus_paused)

	if result.ok:
		_music_started()

	music_activity_changed.emit(bool(result.ok))

	return bool(result.ok)


func _music_started() -> void:
	if startup_theme_pending:
		startup_theme_pending = false
		shuffle_order.last_track = current_track_id
		shuffle_order.remaining.erase(current_track_id)


func _process(_delta: float) -> void:
	if recording_thread != null and not recording_thread.is_alive():
		var result: RecordedSoundtrack.Result = recording_thread.wait_to_finish()
		recording_thread = null

		if recording_request == music_request:
			recording_player.stream = result.stream

			if recording_player.stream != null:
				recording_player.play()
				recording_player.stream_paused = music_paused or focus_paused
				_music_started()
			else:
				push_warning("Cannot decode soundtrack recording; trying MIDI. FLAC requires FFmpeg.")
				_play_midi_fallback()

	if recording_thread == null and pending_recording != null:
		recording_request = int(pending_recording.request)
		var paths: PackedStringArray = pending_recording.paths
		pending_recording = null
		recording_thread = Thread.new()

		if recording_thread.start(RecordedSoundtrack.load_track.bind(paths), Thread.PRIORITY_LOW) != OK:
			recording_thread = null
			_play_midi_fallback()


func _exit_tree() -> void:
	if recording_thread != null:
		recording_thread.wait_to_finish()
		recording_thread = null


func music_playback_is_active() -> bool:
	if music_gap_remaining_msec > 0.0 or queued_music_track >= 0:
		return true

	if AudioServer.get_driver_name() == "Dummy":
		return dummy_music_active or (recording_player != null and recording_player.stream != null and (recording_player.playing or recording_player.stream_paused))

	return (pending_recording != null
		or (recording_thread != null and recording_request == music_request)
		or (recording_player != null and recording_player.stream != null and (recording_player.playing or recording_player.stream_paused))
		or (music_player != null and music_player.is_track_active()))


func audio_allowed() -> bool:
	return application_has_focus or background_audio


func set_background_audio(enabled: bool) -> void:
	background_audio = enabled
	focus_paused = not audio_allowed() and music_playback_is_active()
	_sync_music_pause()

	if not audio_allowed():
		stop_sound_effects()


func handle_application_focus_out() -> void:
	application_has_focus = false

	if not background_audio:
		focus_paused = music_playback_is_active()
		_sync_music_pause()
		stop_sound_effects()


func handle_application_focus_in(music_enabled: bool) -> void:
	var regained_focus := not application_has_focus
	application_has_focus = true

	if background_audio:
		return

	focus_paused = false

	if not music_enabled:
		stop_music()

		return

	_sync_music_pause()

	if not regained_focus or music_paused:
		return

	if not music_playback_is_active():
		play_music_track(Music.MAIN_THEME_TRACK if menu_music else music_director.next_general_track())


func _sync_music_pause() -> void:
	var paused := music_paused or focus_paused or not audio_allowed()

	if recording_player != null:
		recording_player.stream_paused = paused

	if music_player != null:
		music_player.set_paused(paused)


func set_shuffle_music(enabled: bool) -> void:
	if shuffle_music != enabled:
		shuffle_order.remaining.clear()
		shuffle_order.last_track = current_track_id

	shuffle_music = enabled


func stop_music(clear_gap := true) -> void:
	if clear_gap:
		music_gap_remaining_msec = 0.0

	queued_music_track = -1
	queued_choose_shuffle = true
	focus_paused = false
	music_request += 1
	pending_recording = null

	if recording_player != null:
		recording_player.stop()
		recording_player.stream = null

	current_track_id = -1
	dummy_music_active = false

	if music_player != null:
		music_player.stop()

	music_activity_changed.emit(false)


func stop_sound_effects() -> void:
	CityAudioEffects.stop_sound_effects(self)


func play_sound_ids(
	sound_ids: Array[int], sound_enabled: bool, overlay_mode: CityViewMode.Mode, view_size: int
) -> void:
	play_sound_events(SoundEvent.from_ids(sound_ids), sound_enabled, overlay_mode, view_size)


# `simulation` paces sounds from simulation events. see `WaveSoundGate.request`
func play_sound_events(
	sound_events: Array[SoundEvent], sound_enabled: bool, overlay_mode: CityViewMode.Mode, view_size: int,
	simulation := false
) -> void:
	CityAudioEffects.play_sound_events(self, sound_events, sound_enabled, overlay_mode, view_size, simulation)


func start_tool_loop_sound(sound_id: int, sound_enabled: bool) -> void:
	CityAudioEffects.start_tool_loop_sound(self, sound_id, sound_enabled)


func stop_tool_loop_sound() -> void:
	CityAudioEffects.stop_tool_loop_sound(self)


func debug_metrics() -> Dictionary:
	return CityAudioEffects.debug_metrics(self)


func _on_music_track_finished(track_id: int) -> void:
	if track_id != current_track_id:
		return

	stop_music()
	music_gap_remaining_msec = MUSIC_GAP_MSEC

	if shuffle_music or menu_music:
		queued_music_track = Music.MAIN_THEME_TRACK

	# Reserve the gap between tracks so simulation music requests cannot skip it.
	music_activity_changed.emit(true)


func _load_wave_sound_cache() -> void:
	CityAudioEffects._load_wave_sound_cache(self)


func set_menu_music(enabled: bool) -> void:
	if menu_music == enabled:
		return

	menu_music = enabled

	if shuffle_music and music_playback_is_active():
		return

	stop_music(false)

	if music_gap_remaining_msec > 0.0:
		music_activity_changed.emit(true)

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
	stop_music(false)
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

			if shuffle_music:
				stop_music(false)
				play_music_track(Music.MAIN_THEME_TRACK)
			else:
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
	_sync_music_pause()

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


# refresh fallback media when the graphics pack changes its support folder
func set_original_media_source(root_path: String, enabled: bool) -> void:
	if reference_root == root_path and original_media_enabled == enabled:
		return

	reference_root = root_path
	original_media_enabled = enabled
	_apply_media_packs(sound_pack, music_pack)


func set_media_packs(sound_folder: String, music_folder: String) -> bool:
	var sounds := MediaPack.load_folder(sound_folder, "sound")
	var music := MediaPack.load_folder(music_folder, "music")

	if not sounds.error.is_empty() or not music.error.is_empty():
		music_notice.emit(sounds.error + music.error)

		return false

	_apply_media_packs(sounds, music)
	return true


# change one pack without reloading or replacing the other active category
func set_media_pack(kind: String, folder: String) -> bool:
	if kind not in ["sound", "music"]:
		return false

	var pack := MediaPack.load_folder(folder, kind)

	if not pack.error.is_empty():
		music_notice.emit(pack.error)
		return false

	_apply_media_packs(pack if kind == "sound" else sound_pack, pack if kind == "music" else music_pack)
	return true


func _apply_media_packs(sounds: MediaPack, music: MediaPack) -> void:
	var track := current_track_id
	var queued_track := queued_music_track
	var choose_shuffle := queued_choose_shuffle
	var restart := music_playback_is_active()
	stop_sound_effects()
	stop_music(false)
	sound_pack = sounds
	music_pack = music
	_load_wave_sound_cache()

	if restart:
		if queued_track >= 0:
			play_music_track(queued_track, choose_shuffle)
		elif track >= 0:
			play_music_track(track, false)
		elif music_gap_remaining_msec > 0.0:
			music_activity_changed.emit(true)


func play_toolbar_click(sound_enabled: bool) -> void:
	CityAudioEffects.play_toolbar_click(self, sound_enabled)
