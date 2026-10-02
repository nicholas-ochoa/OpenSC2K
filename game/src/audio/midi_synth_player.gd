# gdstyle:ignore-file=quality/max-class-variables
# gdstyle:ignore-file=quality/max-public-methods
class_name MidiSynthPlayer
extends Node
## Plays standard MIDI sequences into an AudioStreamGenerator, so music passes
## through the Godot audio buses. FluidSynth renders with the selected SoundFont.
## Without FluidSynth or a SoundFont that loads, no MIDI music plays.
##
## Threads: a WorkerThreadPool task loads the SoundFont. The main thread then
## gives the loaded FluidMidiSynth to the synth thread with each track and never
## calls it again. The synth thread renders and pushes frames; Godot's audio
## thread only reads the generator ring buffer.

signal track_finished(track_id: int)
## The SoundFont changed. `failed` is true when a SoundFont or FluidSynth failed:
## then the system sound set plays instead, or no MIDI music plays.
signal synth_status_changed(message: String, failed: bool)

const MidiFile = preload("res://src/audio/standard_midi_file.gd")
const SoundFonts = preload("res://src/audio/sound_font_catalog.gd")
const BUFFER_LENGTH_SECONDS := 1.0
const PREFILL_SECONDS := 0.20
const MAX_FRAMES_PER_FILL := 1024
# the synth thread refills once the device has taken the prefill margin, so the
# ring keeps most of its second of slack. godot has no timed semaphore wait, so
# a full buffer costs one paced check every idle_poll_msec, never a spin
const IDLE_POLL_MSEC := 10

const SAMPLE_RATE := float(FluidMidiSynth.SAMPLE_RATE)
const PREFILL_FRAMES := int(PREFILL_SECONDS * SAMPLE_RATE)
const NO_SOUNDFONT := "No General MIDI sound set was found. Select a custom SoundFont in the Audio settings"

# event kinds of the synthesizer, by standard MIDI file event type
const EVENT_KINDS := {
	"note_on": FluidMidiSynth.NOTE_ON,
	"note_off": FluidMidiSynth.NOTE_OFF,
	"program_change": FluidMidiSynth.PROGRAM_CHANGE,
	"control_change": FluidMidiSynth.CONTROL_CHANGE,
	"pitch_bend": FluidMidiSynth.PITCH_BEND,
	"channel_pressure": FluidMidiSynth.CHANNEL_PRESSURE,
	"key_pressure": FluidMidiSynth.KEY_PRESSURE,
}

## The SoundFont that FluidSynth plays, or empty.
var soundfont_path := ""
## A short description of the synthesizer and the last SoundFont error.
var synth_status := ""

# guarded by _mutex. the main thread publishes commands and reads status; the
# synth thread owns every render field below the _playback handover
var current_track_id := -1
var _paused := false
var _mutex := Mutex.new()
var _wake := Semaphore.new()
var _thread: Thread
var _thread_exit := false
var _thread_playing := false
var _pending_start := false
var _stop_requested := false
var _pending_sequence: StandardMidiFile
var _pending_playback: AudioStreamGeneratorPlayback
var _pending_engine: FluidMidiSynth
var _pending_start_seconds := 0.0
var _generation := 0
var _render_generation := -1
var _frames_pushed := 0
var _fill_count := 0
var _idle_polls := 0
var _skips := 0
var _published_position := 0.0
var _audio_player: AudioStreamPlayer
var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _sequence: StandardMidiFile
var _active := false
# the synthesizer of the playing track; only the synth thread renders it.
var _synth: FluidMidiSynth
var _output := PackedVector2Array()
var _track_complete := false

# main thread only. the selected SoundFont and its loaded synthesizer
var _soundfont_choice := SoundFonts.DEFAULT
var _custom_soundfont := ""
var _engine: FluidMidiSynth
var _engine_key := ""
var _load_task := -1
var _load_key := ""
var _load_result: Dictionary = {}
# a track that waits for its SoundFont: [sequence, track id, start seconds]
var _waiting_track: Array = []
var _current_sequence: StandardMidiFile


func _ready() -> void:
	_generator = AudioStreamGenerator.new()
	_generator.buffer_length = BUFFER_LENGTH_SECONDS
	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = _generator
	add_child(_audio_player)


func _exit_tree() -> void:
	stop()
	_stop_thread()
	_finish_load_task()

	if _audio_player != null:
		_audio_player.stream = null


func _process(_delta: float) -> void:
	if _load_task >= 0 and WorkerThreadPool.is_task_completed(_load_task):
		_finish_load_task()


## Selects the music SoundFont: a SoundFontCatalog choice, and the file of the
## custom choice. A playing track continues from its position with the new sound.
func set_soundfont(choice: String, custom_path := "") -> void:
	_soundfont_choice = SoundFonts.normalize(choice)
	_custom_soundfont = custom_path.strip_edges()

	if _selection_key() == _engine_key:
		return

	if _current_sequence == null or not is_track_active():
		return

	# restart the track with the new synthesizer, where it played
	var sequence := _current_sequence
	var track_id := current_track_id
	var position := float(debug_metrics().position_seconds)
	var paused := _paused
	play_sequence(sequence, track_id, position)
	set_paused(paused)


func play_path(path: String, track_id: int) -> PlaybackResult:
	var sequence := MidiFile.load_path(path)

	if not sequence.is_valid():
		return PlaybackResult.failure(sequence.parse_error)

	return play_sequence(sequence, track_id)


## Plays from `start_seconds`, with the programs and controllers of that time.
func play_sequence(sequence: StandardMidiFile, track_id: int, start_seconds := 0.0) -> PlaybackResult:
	if sequence == null or not sequence.is_valid():
		return PlaybackResult.failure("MIDI sequence is not valid")

	if not is_inside_tree() or _audio_player == null:
		return PlaybackResult.failure("MIDI player is not ready")

	stop()
	_current_sequence = sequence
	var key := _selection_key()

	# the SoundFont loads on a worker; the track starts when it is ready
	if key != _engine_key:
		_start_load(key)
		_waiting_track = [sequence, track_id, start_seconds]
		_mutex.lock()
		_active = true
		current_track_id = track_id
		_mutex.unlock()

		return _started(sequence, track_id)

	if _engine == null:
		return PlaybackResult.failure(synth_status)

	var error := _start_playback(sequence, track_id, start_seconds)

	if not error.is_empty():
		return PlaybackResult.failure(error)

	return _started(sequence, track_id)


func _started(sequence: StandardMidiFile, track_id: int) -> PlaybackResult:
	var result := PlaybackResult.new()
	result.ok = true
	result.track_id = track_id
	result.duration_seconds = sequence.duration_seconds
	result.error = ""

	return result


func _start_playback(sequence: StandardMidiFile, track_id: int, start_seconds: float) -> String:
	_generator.mix_rate = SAMPLE_RATE
	_audio_player.play()
	# a pause during the SoundFont load holds the stream that starts after it
	_audio_player.stream_paused = _paused
	var playback := _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

	if playback == null:
		stop()

		return "Godot did not create MIDI audio playback"

	if not _start_thread():
		stop()

		return "Godot did not start the MIDI synthesizer thread"

	# the synth thread primes the ring buffer; the main thread never mixes
	_mutex.lock()
	_pending_sequence = sequence
	_pending_playback = playback
	_pending_engine = _engine
	_pending_start_seconds = start_seconds
	_pending_start = true
	_stop_requested = false
	_thread_playing = true
	_active = true
	current_track_id = track_id
	_generation += 1
	_mutex.unlock()
	_wake.post()

	return ""


func stop() -> void:
	_waiting_track = []
	_mutex.lock()
	_paused = false
	_active = false
	_thread_playing = false
	_pending_start = false
	_stop_requested = true
	_pending_sequence = null
	_pending_playback = null
	_pending_engine = null
	current_track_id = -1
	_published_position = 0.0
	_skips = 0
	_generation += 1
	_mutex.unlock()
	_wake.post()

	if _audio_player != null:
		_audio_player.stop()


func is_track_active() -> bool:
	_mutex.lock()
	var active := _active
	_mutex.unlock()

	return active


# only the main thread owns _audio_player, so the volume needs no lock
func set_volume_linear(value: float) -> void:
	if _audio_player != null:
		_audio_player.volume_linear = clampf(value, 0.0, 1.0)


func debug_metrics() -> Dictionary:
	_mutex.lock()
	var result := {
		"active": _active, "paused": _paused, "track_id": current_track_id,
		"frames_pushed": _frames_pushed, "fills": _fill_count,
		"idle_polls": _idle_polls, "position_seconds": _published_position,
		"skips": _skips,
		"thread_running": _thread != null,
		"soundfont": soundfont_path,
		"loading": _load_task >= 0,
	}
	_mutex.unlock()

	return result


## True while a SoundFont loads. A track that waits for it plays afterward.
func is_loading_soundfont() -> bool:
	return _load_task >= 0


func _selection_key() -> String:
	return "%s|%s" % [_soundfont_choice, _custom_soundfont]


func _start_load(key: String) -> void:
	if _load_task >= 0 and _load_key == key:
		return

	# a newer selection replaces an unfinished load once that load ends
	_finish_load_task()
	_load_key = key
	_load_result = {}
	var candidates := SoundFonts.candidates(_soundfont_choice, _custom_soundfont)
	_load_task = WorkerThreadPool.add_task(_load_engine.bind(candidates), false, "Load music SoundFont")


# runs on a worker thread. FluidSynth reads and decodes the whole SoundFont here
func _load_engine(candidates: PackedStringArray) -> void:
	var result := load_engine(candidates)
	_mutex.lock()
	_load_result = result
	_mutex.unlock()


## A FluidMidiSynth with the first SoundFont that loads, and the errors of the
## others. Without one, "engine" is null and no MIDI music plays.
static func load_engine(candidates: PackedStringArray) -> Dictionary:
	var errors := PackedStringArray()

	if candidates.is_empty():
		errors.append(NO_SOUNDFONT)

		return { "engine": null, "path": "", "errors": errors }

	var library_error := FluidMidiSynth.library_error()

	if not library_error.is_empty():
		errors.append(library_error)

		return { "engine": null, "path": "", "errors": errors }

	var engine := FluidMidiSynth.new()

	for path in candidates:
		var error := engine.load_soundfont(path)

		if error.is_empty():
			return { "engine": engine, "path": path, "errors": errors }

		errors.append(error)

	return { "engine": null, "path": "", "errors": errors }


func _finish_load_task() -> void:
	if _load_task < 0:
		return

	WorkerThreadPool.wait_for_task_completion(_load_task)
	_load_task = -1
	_mutex.lock()
	var result := _load_result
	_load_result = {}
	_mutex.unlock()

	# a selection that changed during the load starts its own load
	if _load_key != _selection_key():
		if not _waiting_track.is_empty():
			_start_load(_selection_key())

		return

	_apply_load_result(result)

	if _waiting_track.is_empty():
		return

	var waiting := _waiting_track
	_waiting_track = []
	var error := synth_status if _engine == null else _start_playback(waiting[0], waiting[1], waiting[2])

	if not error.is_empty():
		push_warning(error)
		_end_waiting_track(int(waiting[1]))


# a track that cannot start ends at once, so the music rules move on
func _end_waiting_track(track_id: int) -> void:
	_mutex.lock()
	_active = false
	current_track_id = -1
	_generation += 1
	_mutex.unlock()
	track_finished.emit(track_id)


func _apply_load_result(result: Dictionary) -> void:
	_engine = result.get("engine") as FluidMidiSynth
	_engine_key = _load_key
	soundfont_path = str(result.get("path", ""))
	_publish_status(result.get("errors", PackedStringArray()))


func _publish_status(errors: PackedStringArray) -> void:
	synth_status = "No MIDI music"

	if _engine != null:
		synth_status = "FluidSynth %s: %s" % [FluidMidiSynth.library_version(), soundfont_path.get_file()]

	if not errors.is_empty():
		synth_status += ". " + "; ".join(errors)
		push_warning("Music: " + "; ".join(errors))

	synth_status_changed.emit(synth_status, not errors.is_empty())


func _start_thread() -> bool:
	if _thread != null:
		return true

	_mutex.lock()
	_thread_exit = false
	_mutex.unlock()
	var thread := Thread.new()

	if thread.start(_synth_loop) != OK:
		return false

	_thread = thread

	return true


func _stop_thread() -> void:
	if _thread == null:
		return

	_mutex.lock()
	_thread_exit = true
	_mutex.unlock()
	_wake.post()
	_thread.wait_to_finish()
	_thread = null


# the synth thread. it parks on the semaphore while no track plays and sleeps
# between top-ups while one does, so an idle or undrained buffer costs nothing
func _synth_loop() -> void:
	while true:
		_mutex.lock()
		var exiting := _thread_exit
		var starting := _pending_start
		var stopping := _stop_requested
		var paused := _paused
		var playing := _thread_playing
		var sequence := _pending_sequence
		var playback := _pending_playback
		var engine := _pending_engine
		var start_seconds := _pending_start_seconds
		var generation := _generation
		_pending_start = false
		_stop_requested = false
		_pending_sequence = null
		_pending_playback = null
		_pending_engine = null
		_mutex.unlock()

		if exiting:
			_release_render_state()

			return

		if stopping and not starting:
			_release_render_state()
			playing = false

		if starting:
			_begin_render(sequence, playback, generation, engine, start_seconds)
			playing = true

		if not playing or paused or _playback == null or _sequence == null:
			_wake.wait()

			continue

		var available := _playback.get_frames_available()

		if available >= PREFILL_FRAMES:
			_fill_audio(mini(available, MAX_FRAMES_PER_FILL))

			continue

		_mutex.lock()
		_idle_polls += 1
		_mutex.unlock()
		OS.delay_msec(IDLE_POLL_MSEC)


func _begin_render(
	sequence: StandardMidiFile, playback: AudioStreamGeneratorPlayback, generation: int,
	engine: FluidMidiSynth, start_seconds: float,
) -> void:
	_render_generation = generation
	_playback = playback
	_sequence = sequence
	_synth = fluid_synth(engine, sequence, start_seconds)
	_track_complete = false


func _release_render_state() -> void:
	_render_generation = -1
	_playback = null
	_sequence = null
	_synth = null
	_track_complete = false


## The event times and the kind, channel, a and b fields of each event, as
## FluidMidiSynth.start takes them.
static func event_arrays(sequence: StandardMidiFile) -> Array:
	var times := PackedFloat64Array()
	var fields := PackedInt32Array()

	for event in sequence.events:
		var kind: int = EVENT_KINDS.get(event.type, FluidMidiSynth.OTHER)
		times.append(float(event.time_seconds))

		match kind:
			FluidMidiSynth.NOTE_ON, FluidMidiSynth.NOTE_OFF, FluidMidiSynth.KEY_PRESSURE:
				fields.append_array([kind, event.channel, event.note, event.velocity])
			FluidMidiSynth.PROGRAM_CHANGE:
				fields.append_array([kind, event.channel, event.program, 0])
			FluidMidiSynth.CONTROL_CHANGE:
				fields.append_array([kind, event.channel, event.controller, event.value])
			FluidMidiSynth.PITCH_BEND, FluidMidiSynth.CHANNEL_PRESSURE:
				fields.append_array([kind, event.channel, event.value, 0])
			_:
				fields.append_array([kind, event.channel, 0, 0])

	return [times, fields]


## Starts `sequence` on a FluidMidiSynth that has a SoundFont, at `start_seconds`.
static func fluid_synth(engine: FluidMidiSynth, sequence: StandardMidiFile, start_seconds := 0.0) -> FluidMidiSynth:
	var arrays := event_arrays(sequence)
	engine.start(arrays[0], arrays[1], sequence.duration_seconds)

	if start_seconds > 0.0:
		engine.seek(start_seconds)

	return engine


func _fill_audio(frame_count: int) -> void:
	if frame_count <= 0 or _playback == null or _synth == null:
		return

	_output = _synth.render(frame_count)
	_track_complete = _synth.is_complete()
	var frames := _output.size()

	if frames > 0:
		_playback.push_buffer(_output)
		# a growing skip count means the thread fell behind the device
		var skips := _playback.get_skips()
		_mutex.lock()
		_frames_pushed += frames
		_fill_count += 1
		_published_position = _synth.position_seconds()
		_skips = skips
		_mutex.unlock()

	if _track_complete:
		_finish_track()


# renders a sequence on a FluidMidiSynth with a SoundFont, without an audio
# device. automated checks use this
func render_offline(
	engine: FluidMidiSynth, sequence: StandardMidiFile, max_frames: int, chunk_frames := MAX_FRAMES_PER_FILL,
) -> PackedVector2Array:
	var result := PackedVector2Array()

	if engine == null or sequence == null or not sequence.is_valid() or max_frames <= 0:
		return result

	if _thread != null:
		return result

	var chunk := maxi(chunk_frames, 1)
	var synth := fluid_synth(engine, sequence)

	while not synth.is_complete() and result.size() < max_frames:
		var frames: PackedVector2Array = synth.render(mini(chunk, max_frames - result.size()))

		if frames.is_empty():
			break

		result.append_array(frames)

	return result


# runs on the synth thread. track_finished reaches nodes, so it must arrive on
# the main thread, and only while this track is still the selected one
func _finish_track() -> void:
	var generation := _render_generation
	_release_render_state()
	_mutex.lock()
	# a track the main thread already replaced must not clear the new status
	var finished_id := current_track_id
	var publish := generation == _generation

	if publish:
		current_track_id = -1
		_thread_playing = false

	_mutex.unlock()

	if publish:
		_finish_on_main.call_deferred(finished_id, generation)


func _finish_on_main(track_id: int, generation: int) -> void:
	# stay active until track_finished, so no new track can skip the music gap
	_mutex.lock()
	var stale := generation != _generation

	if not stale:
		_active = false

	_mutex.unlock()

	if stale:
		return

	if _audio_player != null:
		_audio_player.stop()

	track_finished.emit(track_id)


func set_paused(value: bool) -> void:
	_mutex.lock()
	_paused = value
	_mutex.unlock()
	_wake.post()

	if _audio_player != null:
		_audio_player.stream_paused = value


class PlaybackResult extends RefCounted:
	var ok := false
	var error := ""
	var track_id := -1
	var duration_seconds := 0.0

	static func failure(message: String) -> PlaybackResult:
		var result := PlaybackResult.new()
		result.error = message

		return result
