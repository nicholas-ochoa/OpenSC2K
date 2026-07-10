extends RefCounted

const Music = preload("res://src/audio/music_director.gd")
const MidiFile = preload("res://src/audio/standard_midi_file.gd")
const MidiSynth = preload("res://src/audio/midi_synth_player.gd")
const ToolSounds = preload("res://src/audio/tool_sound_rules.gd")
const WaveSounds = preload("res://src/audio/wave_sound_gate.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const SequenceRandom = TestRandoms.SequenceRandom
const SequenceModuloRandom = TestRandoms.SequenceModuloRandom

var check_callback: Callable


func _init(callback: Callable) -> void:
	check_callback = callback


func test_music(reference_root: String) -> void:
	_test_music_director()
	_test_midi_files(reference_root)
	_test_midi_synth_helpers()
	_test_midi_block_mixing(reference_root)


func test_sound_rules() -> void:
	_test_tool_sound_rules()
	_test_wave_sound_gate()
	_test_ambient_sound_gate()


func _test_music_director() -> void:
	var director := Music.new()
	var general_tracks := PackedInt32Array()

	for index in 7:
		general_tracks.append(director.next_general_track())

	_check(
		general_tracks == PackedInt32Array([
			10001, 10004, 10008, 10012, 10018, 10001, 10004,
		]),
		"General music follows the executable's five-track cycle",
	)
	var monthly_random := SequenceRandom.new([0, 18])
	_check(
		Music.monthly_track(1, false, monthly_random) == 10018
		and monthly_random.position == 2,
		"Paused monthly music uses the Turtle divisor and selects one of all 19 tracks",
	)
	monthly_random = SequenceRandom.new([25])
	_check(
		Music.monthly_track(2, false, monthly_random) == -1
		and monthly_random.position == 1,
		"Turtle monthly music rejects a nonzero modulo-24 gate",
	)
	monthly_random = SequenceRandom.new([0, 0])
	_check(
		Music.monthly_track(5, true, monthly_random) == -1
		and monthly_random.position == 0,
		"Active music prevents a monthly selection without consuming random state",
	)
	var indexed_random := SequenceModuloRandom.new([0, 1, 2, 3, 4])
	_check(
		Music.budget_track(indexed_random) == 10016
		and Music.budget_track(indexed_random) == 10005
		and Music.budget_track(indexed_random) == 10002
		and Music.budget_track(indexed_random) == 10010,
		"Budget music follows the executable's four-track table",
	)
	_check(
		Music.newspaper_track(indexed_random) == 10002,
		"Newspaper music uses its five-track table",
	)
	_check(
		Music.DISASTER_TRACK == 10004 and Music.RECREATION_TRACK == 10010,
		"Mode and Recreation music use the executable's fixed tracks",
	)


func _test_midi_files(reference_root: String) -> void:
	var expected_tracks := [10, 10, 8, 8, 22, 5, 14, 16, 11, 10, 16, 18, 16, 11, 5, 8, 6, 7, 18]
	var expected_divisions := [
		192, 192, 192, 192, 192, 480, 192, 192, 480, 192,
		192, 192, 192, 192, 480, 192, 480, 480, 120,
	]

	for track_offset in Music.TRACK_COUNT:
		var track_id := Music.FIRST_TRACK_ID + track_offset
		var midi := MidiFile.load_path(
			reference_root.path_join("SOUNDS/%d.MID" % track_id)
		)
		_check(midi.is_valid(), "MIDI %d parses: %s" % [track_id, midi.parse_error])

		if not midi.is_valid():
			continue

		_check(
			midi.format_type == 1
			and midi.track_count == expected_tracks[track_offset]
			and midi.ticks_per_quarter == expected_divisions[track_offset],
			"MIDI %d header matches the supplied file" % track_id,
		)
		var note_on_count := 0
		var note_off_count := 0
		var previous_time := -1.0
		var ordered := true

		for event in midi.events:
			var event_time := float(event.time_seconds)

			if event_time < previous_time:
				ordered = false

			previous_time = event_time

			if event.type == "note_on":
				note_on_count += 1
			elif event.type == "note_off":
				note_off_count += 1

		_check(
			note_on_count > 0 and note_off_count > 0,
			"MIDI %d contains playable note events" % track_id,
		)
		_check(
			ordered and midi.duration_seconds > 0.0,
			"MIDI %d has ordered event times and a positive duration" % track_id,
		)

	var missing := MidiFile.load_path(reference_root.path_join("SOUNDS/MISSING.MID"))
	_check(not missing.is_valid(), "MIDI loader rejects a missing file")
	var invalid := MidiFile.new()
	_check(
		not invalid.parse(PackedByteArray([0x4d, 0x54, 0x68, 0x64])),
		"MIDI parser rejects a truncated header",
	)


func _test_midi_synth_helpers() -> void:
	_check(
		is_equal_approx(MidiSynth.note_frequency(69), 440.0)
		and is_equal_approx(MidiSynth.note_frequency(81), 880.0),
		"MIDI synthesizer maps A4 and A5 to their standard frequencies",
	)
	_check(
		absf(MidiSynth.note_frequency(69, 16383) - 493.88) < 0.02
		and absf(MidiSynth.note_frequency(69, 0) - 391.99) < 0.02,
		"MIDI synthesizer applies the default two-semitone pitch-bend range",
	)
	var families := PackedInt32Array()

	for program in [0, 8, 16, 24, 32, 40, 56, 72, 80, 104, 127]:
		families.append(MidiSynth.waveform_family(program))

	_check(
		families == PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 9]),
		"MIDI synthesizer assigns every General MIDI program range",
	)
	_check(
		MidiSynth.BUFFER_LENGTH_SECONDS >= 0.75
		and MidiSynth.PREFILL_SECONDS >= 0.15
		and MidiSynth.PREFILL_SECONDS < MidiSynth.BUFFER_LENGTH_SECONDS,
		"MIDI playback keeps a primed safety buffer",
	)
	var saw_start := MidiSynth.band_limited_saw(0.0, 0.01)
	var saw_end := MidiSynth.band_limited_saw(0.999999, 0.01)
	var square_start := MidiSynth.band_limited_square(0.0, 0.01)
	var square_end := MidiSynth.band_limited_square(0.999999, 0.01)
	_check(
		absf(saw_start - saw_end) < 0.01
		and absf(square_start - square_end) < 0.01,
		"Band-limited MIDI oscillators smooth their wrap edges",
	)


## Changing fill boundaries should leave the mixed samples unchanged.
func _test_midi_block_mixing(reference_root: String) -> void:
	# Track 10000 starts on its first note, so a short render already carries sound.
	var sequence := MidiFile.load_path(
		reference_root.path_join("SOUNDS/%d.MID" % Music.FIRST_TRACK_ID)
	)
	_check(sequence.is_valid(), "Track 10000 loads for the block-mixing check")

	if not sequence.is_valid():
		return

	var block_render := _render_offline(sequence, 11025, 1024)
	var split_render := _render_offline(sequence, 11025, 97)
	var wide_render := _render_offline(sequence, 11025, 4410)
	var scalar_render := _render_offline(sequence, 2205, 1)
	_check(
		block_render.size() == 11025
		and split_render == block_render
		and wide_render == block_render,
		"Block mixing gives the same samples for every fill size",
	)
	_check(
		scalar_render == block_render.slice(0, 2205),
		"A single-sample block matches the block mix sample for sample",
	)
	var peak := 0.0

	for frame in block_render:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))

	_check(peak > 0.05, "The block mix produces audible samples")

	var synthetic := StandardMidiFile.new()
	synthetic.format_type = 1
	synthetic.track_count = 1
	synthetic.ticks_per_quarter = 192
	synthetic.events.assign([
		{"type": "program_change", "channel": 0, "program": 48, "time_seconds": 0.0},
		{"type": "note_on", "channel": 0, "note": 60, "velocity": 100, "time_seconds": 0.0},
		{"type": "note_on", "channel": 9, "note": 36, "velocity": 110, "time_seconds": 0.02},
		{"type": "control_change", "channel": 0, "controller": 10, "value": 20, "time_seconds": 0.05},
		{"type": "note_off", "channel": 0, "note": 60, "velocity": 0, "time_seconds": 0.10},
		{"type": "note_on", "channel": 0, "note": 64, "velocity": 90, "time_seconds": 0.11},
	])
	synthetic.duration_seconds = 0.2
	var tail_render := _render_offline(synthetic, 220500, 1024)
	_check(
		tail_render.size() > 0 and tail_render.size() < 220500,
		"A released track stops inside the tail limit",
	)
	_check(
		tail_render == _render_offline(synthetic, 220500, 97)
		and tail_render == _render_offline(synthetic, 220500, 1),
		"The end-of-track tail stops on the same sample for every fill size",
	)


func _render_offline(
	sequence: StandardMidiFile, max_frames: int, chunk_frames: int
) -> PackedVector2Array:
	var player := MidiSynth.new()
	var rendered := player.render_offline(sequence, max_frames, chunk_frames)
	player.free()

	return rendered



func _test_tool_sound_rules() -> void:
	_check(
		ToolSounds.success_events(1, 0) == [503]
		and ToolSounds.success_events(1, 1) == [511],
		"Landscape tools use the recovered tree and water sounds",
	)
	_check(
		ToolSounds.success_events(3, 0) == [514]
		and ToolSounds.success_events(3, 2) == [500],
		"Power lines and power plants use their recovered success sounds",
	)
	_check(
		ToolSounds.success_events(6, 4) == [521]
		and ToolSounds.success_events(7, 2) == [524, 500],
		"Bus and rail depots keep their special dispatcher sounds",
	)

	for zone_type in range(1, 10):
		_check(ToolSounds.zone_success_events(zone_type) == [503],
			"RCI, military, airport and seaport zones share sound 503")

	_check(ToolSounds.zone_success_events(0).is_empty(), "De-zone does not add a placement sound")

	for group in [8, 9, 10, 11]:
		for subtool in [0, 1]:
			_check(ToolSounds.success_events(group, subtool) == [503],
				"All zone tools use the industrial placement sound")

	_check(
		ToolSounds.success_events(12, 0) == [523]
		and ToolSounds.success_events(13, 0) == [506]
		and ToolSounds.success_events(13, 1) == [509]
		and ToolSounds.success_events(13, 3) == [522],
		"Education and city-service buildings use their dispatcher sounds",
	)
	_check(
		ToolSounds.success_events(14, 0) == [513]
		and ToolSounds.success_events(14, 2) == [527]
		and ToolSounds.success_events(17, 0) == [505],
		"Recreation, Zoo, and Center use their recovered sounds",
	)
	_check(
		ToolSounds.success_events(0, 0).is_empty()
		and ToolSounds.success_events(2, 0) == [506]
		and ToolSounds.success_events(2, 1) == [509]
		and ToolSounds.success_events(2, 2) == [506]
		and ToolSounds.success_events(3, 1).is_empty()
		and ToolSounds.success_events(5, 4).is_empty()
		and ToolSounds.success_events(16, 0).is_empty(),
		"Dispatch uses service effects while looping, chooser and Query paths stay separate",
	)
	_check(
		ToolSounds.failure_events(3, 0) == [501]
		and ToolSounds.failure_events(14, 4) == [501]
		and ToolSounds.failure_events(1, 0, "insufficient funds") == [501]
		and ToolSounds.failure_events(1, 0, "no landscape tile changed").is_empty()
		and ToolSounds.failure_events(0, 0).is_empty(),
		"Failure sound rules preserve the dispatcher and Landscape exceptions",
	)


func _test_wave_sound_gate() -> void:
	_check(
		WaveSounds.duration_ticks(500) == 3
		and WaveSounds.duration_ticks(501) == 1
		and WaveSounds.duration_ticks(512) == 14
		and WaveSounds.duration_ticks(529) == 9
		and WaveSounds.duration_ticks(499) == 0
		and WaveSounds.duration_ticks(530) == 0,
		"WAVE durations use the supplied table and 200 ms conversion",
	)
	var gate := WaveSounds.new()
	_check(
		gate.request(504)
		and not gate.request(504)
		and gate.accepted_count == 1
		and gate.suppressed_count == 1,
		"An immediate repeated WAVE request is suppressed",
	)
	gate.advance(599.0)
	_check(
		not gate.request(504) and gate.remaining_ticks == 4,
		"A repeated WAVE request stays suppressed before three base ticks",
	)
	gate.advance(1.0)
	_check(
		gate.request(504) and gate.remaining_ticks == 6,
		"A repeated WAVE request can restart after three base ticks",
	)
	_check(
		gate.request(501) and gate.current_sound_id == 501,
		"A different WAVE request replaces the active gate state",
	)
	gate.advance(200.0)
	_check(
		gate.current_sound_id == -1 and gate.remaining_ticks == 0,
		"The WAVE gate clears after the recovered duration",
	)
	gate.request(512)
	gate.stop()
	_check(
		gate.current_sound_id == -1
		and gate.remaining_ticks == 0
		and gate.accepted_count == 4
		and gate.suppressed_count == 2,
		"Stopping WAVE playback clears state and preserves debug counters",
	)


func _test_ambient_sound_gate() -> void:
	var gate := WaveSounds.new()
	_check(gate.request(510, true) and gate.request(517, true),
		"Helicopter and ship ambient sounds can each start immediately")
	gate.request(500)
	_check(not gate.request(510, true) and not gate.request(517, true),
		"Other sounds cannot bypass per-sound ambient debounce")
	gate.advance(14999.0)
	_check(not gate.request(510, true), "Ambient sound waits for the full 15 seconds")
	gate.advance(1.0)
	_check(gate.request(510, true), "Ambient sound can repeat at exactly 15 seconds")
	gate.advance(600.0)
	_check(gate.request(510), "Player feedback bypasses the ambient delay")
	gate.stop()
	_check(gate.request(510, true), "Stopping effects clears ambient replay state")


func _check(condition: bool, message: String) -> void:
	check_callback.call(condition, message)
