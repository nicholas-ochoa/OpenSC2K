class_name MidiSynthPlayer
extends Node

@warning_ignore_start("integer_division")

signal track_finished(track_id: int)

const MidiFile = preload("res://src/audio/standard_midi_file.gd")

const SAMPLE_RATE := 22050.0
const BUFFER_LENGTH_SECONDS := 1.0
const PREFILL_SECONDS := 0.20
const MAX_VOICES := 32
const MAX_TAIL_SECONDS := 2.0
const MAX_FRAMES_PER_FILL := 1024
const PITCH_BEND_RANGE := 2.0
const TAU_VALUE := PI * 2.0
# the synth thread refills once the device has taken the prefill margin, so the
# ring keeps most of its second of slack. godot has no timed semaphore wait, so
# a full buffer costs one paced check every idle_poll_msec, never a spin
const PREFILL_FRAMES := int(PREFILL_SECONDS * SAMPLE_RATE)
const IDLE_POLL_MSEC := 10


class Voice:
	extends RefCounted

	var channel := 0
	var note := 0
	var program := 0
	var family := 0
	var velocity := 0.0
	var frequency := 440.0
	var phase := 0.0
	var secondary_phase := 0.0
	var age_seconds := 0.0
	var envelope := 0.0
	var release_rate := 4.0
	var releasing := false
	var held_by_pedal := false
	var percussion := false
	var noise_state := 1


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
var _event_cursor := 0
var _position_seconds := 0.0
var _tail_start_seconds := -1.0
var _active := false
var _voices: Array[Voice] = []
var _channel_programs := PackedInt32Array()
var _channel_volumes := PackedFloat32Array()
var _channel_expressions := PackedFloat32Array()
var _channel_pans := PackedFloat32Array()
var _channel_sustain := PackedByteArray()
var _channel_pitch_bends := PackedInt32Array()
var _channel_left_gains := PackedFloat32Array()
var _channel_right_gains := PackedFloat32Array()
# Keep the scalar mix's summation order and 64-bit accumulators.
# Narrower accumulators change rounding for each voice.
var _mix_left := PackedFloat64Array()
var _mix_right := PackedFloat64Array()
var _frame_times := PackedFloat64Array()
var _output := PackedVector2Array()
var _track_complete := false


func _init() -> void:
	_reset_channels()


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


func play_path(path: String, track_id: int) -> Dictionary:
	var sequence := MidiFile.load_path(path)

	if not sequence.is_valid():
		return {"ok": false, "error": sequence.parse_error}

	return play_sequence(sequence, track_id)


func play_sequence(sequence: StandardMidiFile, track_id: int) -> Dictionary:
	if sequence == null or not sequence.is_valid():
		return {"ok": false, "error": "MIDI sequence is not valid"}

	if not is_inside_tree() or _audio_player == null:
		return {"ok": false, "error": "MIDI player is not ready"}

	stop()
	_audio_player.play()
	var playback := _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

	if playback == null:
		stop()

		return {"ok": false, "error": "Godot did not create MIDI audio playback"}

	if not _start_thread():
		stop()

		return {"ok": false, "error": "Godot did not start the MIDI synthesizer thread"}

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

	return {
		"ok": true,
		"track_id": track_id,
		"duration_seconds": sequence.duration_seconds,
		"error": "",
	}


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
	_reset_channels()
	_voices.clear()
	_playback = playback
	_sequence = sequence
	_event_cursor = 0
	_position_seconds = 0.0
	_tail_start_seconds = -1.0
	_track_complete = false


func _release_render_state() -> void:
	_render_generation = -1
	_playback = null
	_sequence = null
	_voices.clear()
	_event_cursor = 0
	_position_seconds = 0.0
	_tail_start_seconds = -1.0
	_track_complete = false


func _fill_audio(frame_count: int) -> void:
	if frame_count <= 0 or _playback == null or _sequence == null:
		return

	var frames := _render_frames(frame_count)

	if frames > 0:
		_playback.push_buffer(_output)
		# a growing skip count means the thread fell behind the device
		var skips := _playback.get_skips()
		_mutex.lock()
		_frames_pushed += frames
		_fill_count += 1
		_published_position = _position_seconds
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
	_reset_channels()
	_voices.clear()
	_sequence = sequence
	_event_cursor = 0
	_position_seconds = 0.0
	_tail_start_seconds = -1.0
	_track_complete = false

	while not _track_complete and result.size() < max_frames:
		if _render_frames(mini(chunk, max_frames - result.size())) <= 0:
			break

		result.append_array(_output)

	_sequence = null
	_voices.clear()

	return result


# fills _output with up to frame_count frames. the render splits the request at
# every event, tail and end-of-track boundary, then mixes each block one voice at
# a time instead of one sample at a time
func _render_frames(frame_count: int) -> int:
	_track_complete = false
	_prepare_buffers(frame_count)
	var filled := 0

	while filled < frame_count:
		_apply_due_events()
		var block := _block_length(filled, frame_count - filled)
		var empty_at := _mix_block(filled, block)
		var used := block
		var in_tail := _tail_start_seconds >= 0.0 and _event_cursor >= _sequence.events.size()

		if in_tail and empty_at >= 0:
			used = empty_at + 1
			_track_complete = true

		_position_seconds = _frame_times[filled + used - 1]
		filled += used

		if _track_complete or _event_cursor < _sequence.events.size():
			if _track_complete:
				break

			continue

		if _tail_start_seconds < 0.0 and _position_seconds >= _sequence.duration_seconds:
			_tail_start_seconds = _position_seconds
			_release_all_voices()

		if (
			_tail_start_seconds >= 0.0
			and (
				_voices.is_empty()
				or _position_seconds - _tail_start_seconds >= MAX_TAIL_SECONDS
			)
		):
			_track_complete = true

			break

	_write_output(filled)

	return filled


# precomputes every frame time by the same repeated addition the scalar mix used,
# so a block boundary lands on the sample the per-sample loop would have chosen
func _prepare_buffers(frame_count: int) -> void:
	if _mix_left.size() < frame_count:
		_mix_left.resize(frame_count)
		_mix_right.resize(frame_count)
		_frame_times.resize(frame_count)

	_mix_left.fill(0.0)
	_mix_right.fill(0.0)
	var step := 1.0 / SAMPLE_RATE
	var position := _position_seconds

	for frame_index in frame_count:
		position += step
		_frame_times[frame_index] = position


# returns the number of frames that can mix before the next boundary needs work
func _block_length(offset: int, remaining: int) -> int:
	var mode := 2
	var threshold := _sequence.duration_seconds

	if _event_cursor < _sequence.events.size():
		mode = 0
		threshold = float(_sequence.events[_event_cursor].time_seconds)
	elif _tail_start_seconds >= 0.0:
		mode = 1
		threshold = _tail_start_seconds

	if not _boundary_reached(mode, threshold, _frame_times[offset + remaining - 1]):
		return remaining

	var low := 1
	var high := remaining

	while low < high:
		var middle := (low + high) / 2

		if _boundary_reached(mode, threshold, _frame_times[offset + middle - 1]):
			high = middle
		else:
			low = middle + 1

	return low


func _boundary_reached(mode: int, threshold: float, position: float) -> bool:
	if mode == 0:
		return threshold <= position + 0.000001

	if mode == 1:
		return position - threshold >= MAX_TAIL_SECONDS

	return position >= threshold


# mixes one event-free block. the reverse voice order matches the scalar mix, so
# the accumulated sums stay bit-identical. returns the frame that emptied the
# voice list, or -1 while any voice survives the block
func _mix_block(offset: int, count: int) -> int:
	if _voices.is_empty():
		return 0

	var empty_at := -1
	var survivors := 0

	for voice_index in range(_voices.size() - 1, -1, -1):
		var removed_at := _mix_voice(_voices[voice_index], offset, count)

		if removed_at < 0:
			survivors += 1

			continue

		_voices.remove_at(voice_index)
		empty_at = maxi(empty_at, removed_at)

	return -1 if survivors > 0 else empty_at


# advances one voice across a whole block from local state. returns the frame
# that released and removed the voice, or -1 when the voice survives the block
func _mix_voice(voice: Voice, offset: int, count: int) -> int:
	var left_gain := _channel_left_gains[voice.channel]
	var right_gain := _channel_right_gains[voice.channel]
	var velocity := voice.velocity
	var envelope := voice.envelope
	var releasing := voice.releasing
	var age_seconds := voice.age_seconds
	var phase := voice.phase
	var secondary_phase := voice.secondary_phase
	var noise_state := voice.noise_state
	var percussion := voice.percussion
	var family := voice.family
	var note := voice.note

	var age_step := 1.0 / SAMPLE_RATE
	var phase_step := minf(voice.frequency / SAMPLE_RATE, 0.49)
	var secondary_step := phase_step * 1.006
	var release_step := voice.release_rate / SAMPLE_RATE
	var attack_step := 1.0 / (_attack_seconds(voice.program, percussion) * SAMPLE_RATE)
	# a 1.0 factor keeps the sustained families exact and avoids a per-sample branch
	var sustain_decay := 0.9990 if percussion else (
		0.99994 if family == 0 or family == 1 or family == 3 else 1.0
	)
	var frame_index := offset
	var end_index := offset + count

	while frame_index < end_index:
		age_seconds += age_step

		if releasing:
			envelope = maxf(envelope - release_step, 0.0)
		else:
			envelope = minf(envelope + attack_step, 1.0) * sustain_decay

			if percussion and age_seconds > 0.45:
				releasing = true

		if envelope <= 0.0 and releasing:
			return frame_index - offset

		phase = fmod(phase + phase_step, 1.0)
		secondary_phase = fmod(secondary_phase + secondary_step, 1.0)
		var sample := 0.0

		if percussion:
			noise_state = (noise_state * 1103515245 + 12345) & 0x7fffffff
			sample = _percussion_sample(
				note, phase, age_seconds,
				float((noise_state >> 8) & 0xffff) / 32767.5 - 1.0, phase_step
			)
		else:
			sample = _family_sample(family, phase, secondary_phase, phase_step)

		var voice_gain := velocity * envelope
		_mix_left[frame_index] += sample * voice_gain * left_gain
		_mix_right[frame_index] += sample * voice_gain * right_gain
		frame_index += 1

	voice.envelope = envelope
	voice.releasing = releasing
	voice.age_seconds = age_seconds
	voice.phase = phase
	voice.secondary_phase = secondary_phase
	voice.noise_state = noise_state

	return -1


func _write_output(frame_count: int) -> void:
	_output.resize(frame_count)

	for frame_index in frame_count:
		_output[frame_index] = Vector2(
			clampf(_mix_left[frame_index] * 0.18, -0.95, 0.95),
			clampf(_mix_right[frame_index] * 0.18, -0.95, 0.95)
		)


func _apply_due_events() -> void:
	while _event_cursor < _sequence.events.size():
		var event: Dictionary = _sequence.events[_event_cursor]

		if float(event.time_seconds) > _position_seconds + 0.000001:
			break

		_apply_event(event)
		_event_cursor += 1


func _apply_event(event: Dictionary) -> void:
	var event_type := String(event.get("type", ""))

	if event_type == "tempo":
		return

	var channel := clampi(int(event.get("channel", 0)), 0, 15)

	match event_type:
		"note_on":
			_start_voice(channel, int(event.note), int(event.velocity))
		"note_off":
			_stop_voice(channel, int(event.note))
		"program_change":
			_channel_programs[channel] = clampi(int(event.program), 0, 127)
		"control_change":
			_apply_control_change(channel, int(event.controller), int(event.value))
		"pitch_bend":
			_channel_pitch_bends[channel] = clampi(int(event.value), 0, 16383)
			_update_channel_pitch(channel)


func _start_voice(channel: int, note: int, midi_velocity: int) -> void:
	if midi_velocity <= 0:
		_stop_voice(channel, note)

		return

	if _voices.size() >= MAX_VOICES:
		_steal_voice()

	var voice := Voice.new()
	voice.channel = channel
	voice.note = clampi(note, 0, 127)
	voice.program = _channel_programs[channel]
	voice.family = waveform_family(voice.program)
	voice.velocity = clampf(float(midi_velocity) / 127.0, 0.0, 1.0)
	voice.frequency = note_frequency(voice.note, _channel_pitch_bends[channel])
	voice.percussion = channel == 9
	voice.noise_state = ((voice.note + 1) * 1103515245 + _event_cursor + 1) & 0x7fffffff
	voice.release_rate = _release_rate(voice.program, voice.percussion)
	_voices.append(voice)


func _stop_voice(channel: int, note: int) -> void:
	for voice in _voices:
		if voice.channel != channel or voice.note != note or voice.releasing:
			continue

		if _channel_sustain[channel] != 0:
			voice.held_by_pedal = true
		else:
			voice.releasing = true

		return


func _apply_control_change(channel: int, controller: int, value: int) -> void:
	var normalized := clampf(float(value) / 127.0, 0.0, 1.0)

	match controller:
		7:
			_channel_volumes[channel] = normalized
			_refresh_channel_gain(channel)
		10:
			_channel_pans[channel] = normalized
			_refresh_channel_gain(channel)
		11:
			_channel_expressions[channel] = normalized
			_refresh_channel_gain(channel)
		64:
			var was_sustained := _channel_sustain[channel] != 0
			_channel_sustain[channel] = 1 if value >= 64 else 0

			if was_sustained and value < 64:
				_release_sustained_voices(channel)
		120:
			_remove_channel_voices(channel)
		121:
			_reset_channel_controls(channel)
		123:
			_release_channel_voices(channel)


static func _family_sample(
	family: int, phase: float, secondary_phase: float, phase_step: float
) -> float:
	match family:
		0:
			return sin(TAU_VALUE * phase) * 0.72 + sin(TAU_VALUE * phase * 2.0) * 0.20 + sin(TAU_VALUE * phase * 3.0) * 0.08
		1:
			return sin(TAU_VALUE * phase) * 0.65 + sin(TAU_VALUE * phase * 3.01) * 0.35
		2:
			return sin(TAU_VALUE * phase) * 0.65 + sin(TAU_VALUE * phase * 2.0) * 0.25 + sin(TAU_VALUE * phase * 4.0) * 0.10
		3:
			return _triangle(phase) * 0.70 + band_limited_saw(phase, phase_step) * 0.30
		4:
			return _triangle(phase) * 0.80 + band_limited_square(phase, phase_step) * 0.20
		5:
			return (
				band_limited_saw(phase, phase_step) * 0.52
				+ band_limited_saw(secondary_phase, phase_step * 1.006) * 0.48
			)
		6:
			return band_limited_saw(phase, phase_step) * 0.45 + sin(TAU_VALUE * phase) * 0.55
		7:
			return sin(TAU_VALUE * phase) * 0.88 + sin(TAU_VALUE * phase * 2.0) * 0.12
		8:
			return (
				band_limited_square(phase, phase_step) * 0.55
				+ band_limited_saw(phase, phase_step) * 0.45
			)
		_:
			return _triangle(phase) * 0.55 + sin(TAU_VALUE * phase * 2.0) * 0.45


static func _percussion_sample(
	note: int, phase: float, age_seconds: float, noise: float, phase_step: float
) -> float:
	if note == 35 or note == 36:
		var drop := maxf(0.35, 1.0 - age_seconds * 2.5)

		return sin(TAU_VALUE * phase * drop) * 0.85 + noise * 0.15

	if note >= 42 and note <= 46:
		return noise * 0.82 + band_limited_square(phase, phase_step) * 0.18

	if note == 38 or note == 40:
		return noise * 0.72 + sin(TAU_VALUE * phase) * 0.28

	return noise * 0.55 + sin(TAU_VALUE * phase) * 0.45


func _release_sustained_voices(channel: int) -> void:
	for voice in _voices:
		if voice.channel == channel and voice.held_by_pedal:
			voice.held_by_pedal = false
			voice.releasing = true


func _release_channel_voices(channel: int) -> void:
	for voice in _voices:
		if voice.channel == channel:
			voice.held_by_pedal = false
			voice.releasing = true


func _release_all_voices() -> void:
	for voice in _voices:
		voice.held_by_pedal = false
		voice.releasing = true


func _remove_channel_voices(channel: int) -> void:
	for voice_index in range(_voices.size() - 1, -1, -1):
		if _voices[voice_index].channel == channel:
			_voices.remove_at(voice_index)


func _update_channel_pitch(channel: int) -> void:
	for voice in _voices:
		if voice.channel == channel:
			voice.frequency = note_frequency(voice.note, _channel_pitch_bends[channel])


func _steal_voice() -> void:
	var quietest_index := 0
	var quietest_level := INF

	for voice_index in _voices.size():
		var voice := _voices[voice_index]
		var level := voice.envelope * voice.velocity

		if voice.releasing:
			level *= 0.5

		if level < quietest_level:
			quietest_level = level
			quietest_index = voice_index

	_voices.remove_at(quietest_index)


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
		_active = false
		_thread_playing = false

	_mutex.unlock()

	if publish:
		_finish_on_main.call_deferred(finished_id, generation)


func _finish_on_main(track_id: int, generation: int) -> void:
	_mutex.lock()
	var stale := generation != _generation
	_mutex.unlock()

	if stale:
		return

	if _audio_player != null:
		_audio_player.stop()

	track_finished.emit(track_id)


func _reset_channels() -> void:
	_channel_programs.resize(16)
	_channel_programs.fill(0)
	_channel_volumes.resize(16)
	_channel_volumes.fill(1.0)
	_channel_expressions.resize(16)
	_channel_expressions.fill(1.0)
	_channel_pans.resize(16)
	_channel_pans.fill(0.5)
	_channel_sustain.resize(16)
	_channel_sustain.fill(0)
	_channel_pitch_bends.resize(16)
	_channel_pitch_bends.fill(8192)
	_channel_left_gains.resize(16)
	_channel_right_gains.resize(16)

	for channel in 16:
		_refresh_channel_gain(channel)


func _reset_channel_controls(channel: int) -> void:
	_channel_volumes[channel] = 1.0
	_channel_expressions[channel] = 1.0
	_channel_pans[channel] = 0.5
	_channel_sustain[channel] = 0
	_channel_pitch_bends[channel] = 8192
	_refresh_channel_gain(channel)
	_release_sustained_voices(channel)
	_update_channel_pitch(channel)


func _refresh_channel_gain(channel: int) -> void:
	var gain := _channel_volumes[channel] * _channel_expressions[channel]
	_channel_left_gains[channel] = gain * sqrt(1.0 - _channel_pans[channel])
	_channel_right_gains[channel] = gain * sqrt(_channel_pans[channel])


static func note_frequency(note: int, pitch_bend := 8192) -> float:
	var bend_semitones := (float(clampi(pitch_bend, 0, 16383)) - 8192.0) / 8192.0 * PITCH_BEND_RANGE

	return 440.0 * pow(2.0, (float(clampi(note, 0, 127)) - 69.0 + bend_semitones) / 12.0)


static func waveform_family(program: int) -> int:
	var clamped := clampi(program, 0, 127)

	if clamped < 8:
		return 0

	if clamped < 16:
		return 1

	if clamped < 24:
		return 2

	if clamped < 32:
		return 3

	if clamped < 40:
		return 4

	if clamped < 56:
		return 5

	if clamped < 72:
		return 6

	if clamped < 80:
		return 7

	if clamped < 104:
		return 8

	return 9


static func _attack_seconds(program: int, percussion: bool) -> float:
	if percussion:
		return 0.001

	var family := waveform_family(program)

	if family == 5:
		return 0.08

	if family == 6 or family == 7:
		return 0.025

	return 0.006


static func _release_rate(program: int, percussion: bool) -> float:
	if percussion:
		return 10.0

	var family := waveform_family(program)

	if family == 2 or family == 5:
		return 1.8

	if family == 6 or family == 7:
		return 2.6

	return 4.0


static func band_limited_saw(phase: float, phase_step: float) -> float:
	return phase * 2.0 - 1.0 - _poly_blep(phase, phase_step)


static func band_limited_square(phase: float, phase_step: float) -> float:
	var value := 1.0 if phase < 0.5 else -1.0
	value += _poly_blep(phase, phase_step)
	value -= _poly_blep(fmod(phase + 0.5, 1.0), phase_step)

	return value


static func _triangle(phase: float) -> float:
	return 1.0 - 4.0 * absf(phase - 0.5)


static func _poly_blep(phase: float, phase_step: float) -> float:
	var step := clampf(phase_step, 0.000001, 0.49)

	if phase < step:
		var position := phase / step

		return position + position - position * position - 1.0

	if phase > 1.0 - step:
		var position := (phase - 1.0) / step

		return position * position + position + position + 1.0

	return 0.0


func set_paused(value: bool) -> void:
	_mutex.lock()
	_paused = value
	_mutex.unlock()
	_wake.post()

	if _audio_player != null:
		_audio_player.stream_paused = value
