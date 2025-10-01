class_name MidiSynthPlayer
extends Node

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


var current_track_id := -1
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


func _init() -> void:
	_reset_channels()


func _ready() -> void:
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = SAMPLE_RATE
	_generator.buffer_length = BUFFER_LENGTH_SECONDS
	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = _generator
	add_child(_audio_player)
	set_process(false)


func _exit_tree() -> void:
	stop()
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
	_reset_channels()
	_sequence = sequence
	current_track_id = track_id
	_event_cursor = 0
	_position_seconds = 0.0
	_tail_start_seconds = -1.0
	_active = true
	_audio_player.play()
	_playback = _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _playback == null:
		stop()
		return {"ok": false, "error": "Godot did not create MIDI audio playback"}
	_fill_audio(mini(
		_playback.get_frames_available(), int(PREFILL_SECONDS * SAMPLE_RATE)
	))
	set_process(true)
	return {
		"ok": true,
		"track_id": track_id,
		"duration_seconds": sequence.duration_seconds,
		"error": "",
	}


func stop() -> void:
	_active = false
	set_process(false)
	_voices.clear()
	_sequence = null
	_event_cursor = 0
	_position_seconds = 0.0
	_tail_start_seconds = -1.0
	current_track_id = -1
	if _playback != null:
		_playback.stop()
		_playback.clear_buffer()
	_playback = null
	if _audio_player != null:
		_audio_player.stop()


func is_track_active() -> bool:
	return _active


func _process(_delta: float) -> void:
	if not _active or _playback == null or _sequence == null:
		return
	var available := mini(_playback.get_frames_available(), MAX_FRAMES_PER_FILL)
	if available <= 0:
		return
	_fill_audio(available)


func _fill_audio(frame_count: int) -> void:
	if frame_count <= 0 or not _active or _playback == null or _sequence == null:
		return
	var output := PackedVector2Array()
	output.resize(frame_count)
	for frame_index in frame_count:
		_apply_due_events()
		var mixed := _mix_frame()
		output[frame_index] = mixed
		_position_seconds += 1.0 / SAMPLE_RATE
		if _event_cursor >= _sequence.events.size():
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
				output.resize(frame_index + 1)
				_playback.push_buffer(output)
				_finish_track()
				return
	_playback.push_buffer(output)


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


func _mix_frame() -> Vector2:
	var left := 0.0
	var right := 0.0
	for voice_index in range(_voices.size() - 1, -1, -1):
		var voice := _voices[voice_index]
		_advance_envelope(voice)
		if voice.envelope <= 0.0 and voice.releasing:
			_voices.remove_at(voice_index)
			continue
		var sample := _voice_sample(voice)
		var voice_gain := voice.velocity * voice.envelope
		left += sample * voice_gain * _channel_left_gains[voice.channel]
		right += sample * voice_gain * _channel_right_gains[voice.channel]
	return Vector2(clampf(left * 0.18, -0.95, 0.95), clampf(right * 0.18, -0.95, 0.95))


func _advance_envelope(voice: Voice) -> void:
	voice.age_seconds += 1.0 / SAMPLE_RATE
	if voice.releasing:
		voice.envelope = maxf(voice.envelope - voice.release_rate / SAMPLE_RATE, 0.0)
		return
	var attack := _attack_seconds(voice.program, voice.percussion)
	voice.envelope = minf(voice.envelope + 1.0 / (attack * SAMPLE_RATE), 1.0)
	if voice.percussion:
		voice.envelope *= 0.9990
		if voice.age_seconds > 0.45:
			voice.releasing = true
	elif voice.family == 0 or voice.family == 1 or voice.family == 3:
		voice.envelope *= 0.99994


func _voice_sample(voice: Voice) -> float:
	var phase_step := minf(voice.frequency / SAMPLE_RATE, 0.49)
	voice.phase = fmod(voice.phase + phase_step, 1.0)
	voice.secondary_phase = fmod(voice.secondary_phase + phase_step * 1.006, 1.0)
	if voice.percussion:
		return _percussion_sample(voice)
	var phase := voice.phase
	match voice.family:
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
				+ band_limited_saw(voice.secondary_phase, phase_step * 1.006) * 0.48
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


func _percussion_sample(voice: Voice) -> float:
	voice.noise_state = (voice.noise_state * 1103515245 + 12345) & 0x7fffffff
	var noise := float((voice.noise_state >> 8) & 0xffff) / 32767.5 - 1.0
	if voice.note == 35 or voice.note == 36:
		var drop := maxf(0.35, 1.0 - voice.age_seconds * 2.5)
		return sin(TAU_VALUE * voice.phase * drop) * 0.85 + noise * 0.15
	if voice.note >= 42 and voice.note <= 46:
		return (
			noise * 0.82
			+ band_limited_square(
				voice.phase, minf(voice.frequency / SAMPLE_RATE, 0.49)
			) * 0.18
		)
	if voice.note == 38 or voice.note == 40:
		return noise * 0.72 + sin(TAU_VALUE * voice.phase) * 0.28
	return noise * 0.55 + sin(TAU_VALUE * voice.phase) * 0.45


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


func _finish_track() -> void:
	var finished_id := current_track_id
	_active = false
	set_process(false)
	_voices.clear()
	_sequence = null
	current_track_id = -1
	_playback = null
	_audio_player.stop()
	track_finished.emit(finished_id)


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
