# gdstyle:ignore-file=quality/max-class-variables
class_name MidiSynthPlayer
extends Node

signal track_finished(track_id: int)

const MidiFile = preload("res://src/audio/standard_midi_file.gd")
const SAMPLE_RATE := 22050.0
const BUFFER_LENGTH_SECONDS := 1.0
const PREFILL_SECONDS := 0.20
const MAX_FRAMES_PER_FILL := 1024
# the synth thread refills once the device has taken the prefill margin, so the
# ring keeps most of its second of slack. godot has no timed semaphore wait, so
# a full buffer costs one paced check every idle_poll_msec, never a spin
const PREFILL_FRAMES := int(PREFILL_SECONDS * SAMPLE_RATE)
const IDLE_POLL_MSEC := 10

# event kinds of the native synthesizer, by standard MIDI file event type
const EVENT_KINDS := {
	"note_on": NativeMidiSynth.NOTE_ON,
	"note_off": NativeMidiSynth.NOTE_OFF,
	"program_change": NativeMidiSynth.PROGRAM_CHANGE,
	"control_change": NativeMidiSynth.CONTROL_CHANGE,
	"pitch_bend": NativeMidiSynth.PITCH_BEND,
}

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
# the native synthesizer renders the frames; only the synth thread uses it
var _synth: NativeMidiSynth
var _output := PackedVector2Array()
var _track_complete := false


func _ready() -> void:
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = SAMPLE_RATE
	_generator.buffer_length = BUFFER_LENGTH_SECONDS
	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = _generator
	add_child(_audio_player)


func _exit_tree() -> void:
	stop()
	_stop_thread()

	if _audio_player != null:
		_audio_player.stream = null


func play_path(path: String, track_id: int) -> PlaybackResult:
	var sequence := MidiFile.load_path(path)

	if not sequence.is_valid():
		return PlaybackResult.failure(sequence.parse_error)

	return play_sequence(sequence, track_id)


func play_sequence(sequence: StandardMidiFile, track_id: int) -> PlaybackResult:
	if sequence == null or not sequence.is_valid():
		return PlaybackResult.failure("MIDI sequence is not valid")

	if not is_inside_tree() or _audio_player == null:
		return PlaybackResult.failure("MIDI player is not ready")

	stop()
	_audio_player.play()
	var playback := _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

	if playback == null:
		stop()

		return PlaybackResult.failure("Godot did not create MIDI audio playback")

	if not _start_thread():
		stop()

		return PlaybackResult.failure("Godot did not start the MIDI synthesizer thread")

	# the synth thread primes the ring buffer; the main thread never mixes
	_mutex.lock()
	_pending_sequence = sequence
	_pending_playback = playback
	_pending_start = true
	_stop_requested = false
	_thread_playing = true
	_active = true
	current_track_id = track_id
	_generation += 1
	_mutex.unlock()
	_wake.post()

	var result := PlaybackResult.new()
	result.ok = true
	result.track_id = track_id
	result.duration_seconds = sequence.duration_seconds
	result.error = ""

	return result


func stop() -> void:
	_mutex.lock()
	_paused = false
	_active = false
	_thread_playing = false
	_pending_start = false
	_stop_requested = true
	_pending_sequence = null
	_pending_playback = null
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
	}
	_mutex.unlock()

	return result


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
		var generation := _generation
		_pending_start = false
		_stop_requested = false
		_pending_sequence = null
		_pending_playback = null
		_mutex.unlock()

		if exiting:
			_release_render_state()

			return

		if stopping and not starting:
			_release_render_state()
			playing = false

		if starting:
			_begin_render(sequence, playback, generation)
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
	sequence: StandardMidiFile, playback: AudioStreamGeneratorPlayback, generation: int
) -> void:
	_render_generation = generation
	_playback = playback
	_sequence = sequence
	_synth = native_synth(sequence)
	_track_complete = false


func _release_render_state() -> void:
	_render_generation = -1
	_playback = null
	_sequence = null
	_synth = null
	_track_complete = false


# a native synthesizer at the start of the sequence
static func native_synth(sequence: StandardMidiFile) -> NativeMidiSynth:
	var times := PackedFloat64Array()
	var fields := PackedInt32Array()

	for event in sequence.events:
		var kind: int = EVENT_KINDS.get(event.type, NativeMidiSynth.OTHER)
		times.append(float(event.time_seconds))

		match kind:
			NativeMidiSynth.NOTE_ON, NativeMidiSynth.NOTE_OFF:
				fields.append_array([kind, event.channel, event.note, event.velocity])
			NativeMidiSynth.PROGRAM_CHANGE:
				fields.append_array([kind, event.channel, event.program, 0])
			NativeMidiSynth.CONTROL_CHANGE:
				fields.append_array([kind, event.channel, event.controller, event.value])
			NativeMidiSynth.PITCH_BEND:
				fields.append_array([kind, event.channel, event.value, 0])
			_:
				fields.append_array([kind, event.channel, 0, 0])

	var synth := NativeMidiSynth.new()
	synth.start(times, fields, sequence.duration_seconds)

	return synth


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


# renders a sequence without an audio device. automated checks use this
func render_offline(
	sequence: StandardMidiFile, max_frames: int, chunk_frames := MAX_FRAMES_PER_FILL
) -> PackedVector2Array:
	var result := PackedVector2Array()

	if sequence == null or not sequence.is_valid() or max_frames <= 0:
		return result

	if _thread != null:
		return result

	var chunk := maxi(chunk_frames, 1)
	var synth := native_synth(sequence)

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
