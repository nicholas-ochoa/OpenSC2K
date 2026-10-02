extends SceneTree
## FluidSynth music: library and SoundFont errors, MIDI rendering, the
## fallback order, runtime SoundFont switching, and the saved preference.
## The generated test SoundFont plays a sine at bank 0 program 0, a square at
## program 80 and a noise drum kit at bank 128 for keys 35 to 81.

const MidiFile = preload("res://src/audio/standard_midi_file.gd")
const SoundFonts = preload("res://src/audio/sound_font_catalog.gd")
const FIXTURE := "res://tests/fixtures/soundfonts/opensc2k_test_gm.sf2"
const SQUARE_PROGRAM := 80
const DRUM_CHANNEL := 9
const BASS_DRUM := 36

var finished_tracks := PackedInt32Array()
var temporary_folder := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(AudioServer.get_driver_name() == "Dummy", "Automated audio checks use the Dummy driver")
	temporary_folder = OS.get_temp_dir().path_join("opensc2k_fluidsynth_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(temporary_folder)

	_test_library()
	_test_soundfont_errors()
	_test_midi_parsing()
	_test_rendering()
	_test_fallback_order()
	_test_preferences()
	await _test_player()

	for file in DirAccess.get_files_at(temporary_folder):
		DirAccess.remove_absolute(temporary_folder.path_join(file))

	DirAccess.remove_absolute(temporary_folder)
	print("PASS: FluidSynth loads SoundFonts, renders MIDI, falls back, switches and saves its choice")
	quit()


func _fixture() -> String:
	return ProjectSettings.globalize_path(FIXTURE)


func _test_library() -> void:
	assert(FluidMidiSynth.library_error().is_empty(), FluidMidiSynth.library_error())
	assert(FluidMidiSynth.library_version().begins_with("2."))
	assert(FileAccess.file_exists(FluidMidiSynth.library_path()), "The game finds FluidSynth beside the audio extension")

	var missing := FluidMidiSynth.probe_library(temporary_folder.path_join("libfluidsynth-missing"))
	assert(missing.begins_with("The FluidSynth shared library could not be loaded"), missing)


func _test_soundfont_errors() -> void:
	var engine := FluidMidiSynth.new()
	assert(not engine.has_soundfont())
	assert(not engine.start(PackedFloat64Array(), PackedInt32Array(), 1.0), "A synthesizer without a SoundFont does not start")

	var missing := engine.load_soundfont(temporary_folder.path_join("missing.sf2"))
	assert(missing.begins_with("The SoundFont does not exist"), missing)

	var text_path := temporary_folder.path_join("text.sf2")
	_write(text_path, "not a SoundFont".to_utf8_buffer())
	var unsupported := engine.load_soundfont(text_path)
	assert(unsupported.begins_with("Unsupported SoundFont"), unsupported)

	assert(engine.load_soundfont(_fixture()).is_empty())
	assert(engine.has_soundfont() and engine.soundfont_path() == _fixture())

	var truncated_path := temporary_folder.path_join("truncated.sf2")
	_write(truncated_path, FileAccess.get_file_as_bytes(_fixture()).slice(0, 200))
	var truncated := engine.load_soundfont(truncated_path)
	assert(truncated.begins_with("The SoundFont failed to load"), truncated)
	assert(engine.soundfont_path() == _fixture(), "A failed load keeps the SoundFont that already plays")


func _test_midi_parsing() -> void:
	var sequence := MidiFile.new()
	assert(sequence.parse(_midi_bytes()), sequence.parse_error)
	var types := sequence.events.map(func(event: StandardMidiFile.Event) -> String: return event.type)
	assert(types == ["program_change", "note_on", "channel_pressure", "key_pressure", "note_off", "note_on", "note_off"],
		str(types))

	var malformed := MidiFile.new()
	var bytes := _midi_bytes()
	bytes.resize(bytes.size() - 6)
	assert(not malformed.parse(bytes) and not malformed.parse_error.is_empty(), "A truncated track is rejected")

	var player := MidiSynthPlayer.new()
	root.add_child(player)
	var result := player.play_path(temporary_folder.path_join("missing.mid"), 10001)
	assert(not result.ok and result.error.begins_with("File does not exist"))
	assert(not player.is_track_active())
	player.free()


func _test_rendering() -> void:
	var sequence := MidiFile.new()
	sequence.parse(_midi_bytes())
	var player := MidiSynthPlayer.new()
	var rendered := player.render_offline(_engine(), sequence, 88200, 1024)
	assert(rendered.size() > 4410 and rendered.size() < 88200, "The track ends after a short release tail")
	assert(_energy(rendered.slice(0, 4410)) > 1e-4, "FluidSynth renders audible PCM")

	# FluidSynth starts events on 64-frame blocks, so every request size gives the same track length
	assert(player.render_offline(_engine(), sequence, 88200, 97).size() == rendered.size())

	var square := _note_sequence(0, 69, SQUARE_PROGRAM)
	var sine := _note_sequence(0, 69, 0)
	assert(player.render_offline(_engine(), square, 4410, 1024) != player.render_offline(_engine(), sine, 4410, 1024),
		"A program change selects another preset")

	var drum := player.render_offline(_engine(), _note_sequence(DRUM_CHANNEL, BASS_DRUM, 0), 4410, 1024)
	var outside_kit := player.render_offline(_engine(), _note_sequence(DRUM_CHANNEL, 100, 0), 4410, 1024)
	assert(_energy(drum) > 1e-4 and _energy(outside_kit) < 1e-9, "Channel 10 plays the drum kit")

	var looping := _engine()
	looping.set_looping(true)
	var arrays := MidiSynthPlayer.event_arrays(sine)
	assert(looping.start(arrays[0], arrays[1], sine.duration_seconds))
	looping.render(int(sine.duration_seconds * FluidMidiSynth.SAMPLE_RATE) * 3)
	assert(not looping.is_complete(), "A looping track does not complete")

	looping.seek(0.05)
	assert(absf(looping.position_seconds() - 0.05) < 0.001)
	player.free()


func _test_fallback_order() -> void:
	# a custom SoundFont falls back to the operating system sound set, where one exists
	var system := SoundFonts.system_path()
	var with_system := PackedStringArray() if system.is_empty() else PackedStringArray([system])
	var custom := SoundFonts.candidates(SoundFonts.CUSTOM, "/music/custom.sf2")
	assert(custom == PackedStringArray(["/music/custom.sf2"]) + with_system)
	assert(SoundFonts.candidates(SoundFonts.SYSTEM, "/music/custom.sf2") == with_system)
	assert(SoundFonts.candidates(SoundFonts.CUSTOM, "") == with_system)
	assert(SoundFonts.choices() == PackedStringArray([SoundFonts.SYSTEM, SoundFonts.CUSTOM]))

	# choices that earlier versions saved
	for removed in ["default", "fluidr3mono", "builtin"]:
		assert(SoundFonts.normalize(removed) == SoundFonts.SYSTEM)

	if not system.is_empty():
		var engine := FluidMidiSynth.new()
		assert(engine.load_soundfont(system).is_empty(), "FluidSynth reads the system sound set")
		var player := MidiSynthPlayer.new()
		assert(_energy(player.render_offline(engine, _note_sequence(0, 69, 0), 4410)) > 1e-4)
		player.free()

	var missing := temporary_folder.path_join("deleted.sf2")
	var loaded := MidiSynthPlayer.load_engine(PackedStringArray([missing, _fixture()]))
	assert(loaded.engine != null and loaded.path == _fixture() and loaded.errors.size() == 1)
	assert(str(loaded.errors[0]).contains("does not exist"), "The status names the missing custom SoundFont")

	var none := MidiSynthPlayer.load_engine(PackedStringArray([missing]))
	assert(none.engine == null and none.errors.size() == 1, "Without a SoundFont no MIDI music plays")
	var empty := MidiSynthPlayer.load_engine(PackedStringArray())
	assert(empty.engine == null and empty.errors == PackedStringArray([MidiSynthPlayer.NO_SOUNDFONT]))


func _test_preferences() -> void:
	var path := temporary_folder.path_join("settings.cfg")
	var options := AppSettingsStore.SaveOptions.new()
	options.music_soundfont = SoundFonts.CUSTOM
	options.music_soundfont_path = "/music/custom.sf2"
	assert(AppSettingsStore.save_values(0.5, 0.5, false, path, options) == OK)
	var values := AppSettingsStore.load_values(path, 0.5, 0.5, false)
	assert(values.music_soundfont == SoundFonts.CUSTOM and values.music_soundfont_path == "/music/custom.sf2")

	var config := ConfigFile.new()
	config.set_value("audio", "music_soundfont", "removed_soundfont")
	config.save(path)
	assert(AppSettingsStore.load_values(path, 0.5, 0.5, false).music_soundfont == SoundFonts.DEFAULT)


func _test_player() -> void:
	var player := MidiSynthPlayer.new()
	root.add_child(player)
	player.track_finished.connect(func(track_id: int) -> void: finished_tracks.append(track_id))
	player.set_soundfont(SoundFonts.CUSTOM, _fixture())

	var long_sequence := _note_sequence(0, 69, 0, 4.0)
	assert(player.play_sequence(long_sequence, 10001).ok)
	assert(player.is_track_active() and player.is_loading_soundfont(), "The track waits while the SoundFont loads")
	await _wait_until(func() -> bool: return player.debug_metrics().frames_pushed > 4410)
	var metrics := player.debug_metrics()
	assert(metrics.soundfont == _fixture(), str(metrics))
	assert(player.synth_status.begins_with("FluidSynth 2."), player.synth_status)

	# switching continues the same track with the new SoundFont
	var copy := temporary_folder.path_join("copy.sf2")
	_write(copy, FileAccess.get_file_as_bytes(_fixture()))
	player.set_soundfont(SoundFonts.CUSTOM, copy)
	assert(player.is_track_active() and player.current_track_id == 10001)
	await _wait_until(func() -> bool: return player.soundfont_path == copy and player.debug_metrics().frames_pushed > 0)
	assert(player.is_track_active() and player.current_track_id == 10001)

	player.stop()
	assert(not player.is_track_active())

	# a missing custom SoundFont plays the system sound set, or, without one, the
	# waiting track ends and later tracks fail at once
	var system := SoundFonts.system_path()
	player.set_soundfont(SoundFonts.CUSTOM, temporary_folder.path_join("moved.sf2"))
	assert(player.play_sequence(_note_sequence(0, 60, 0, 0.1), 10002).ok)
	await _wait_until(func() -> bool: return not player.is_loading_soundfont())
	assert(player.synth_status.contains("does not exist"), player.synth_status)

	if system.is_empty():
		assert(finished_tracks == PackedInt32Array([10002]) and not player.is_track_active())
		assert(not player.play_sequence(_note_sequence(0, 60, 0, 0.1), 10002).ok)
	else:
		assert(player.soundfont_path == system)
		await _wait_until(func() -> bool: return finished_tracks.size() == 1)

	# a short track reports its end on the main thread
	player.set_soundfont(SoundFonts.CUSTOM, _fixture())
	assert(player.play_sequence(_note_sequence(0, 60, 0, 0.1), 10003).ok)
	await _wait_until(func() -> bool: return finished_tracks.size() == 2)
	assert(player.soundfont_path == _fixture() and finished_tracks[1] == 10003)

	player.queue_free()
	await process_frame


func _wait_until(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 5000

	while not condition.call():
		assert(Time.get_ticks_msec() < deadline, "Timed out waiting for the music player")
		await process_frame


func _engine() -> FluidMidiSynth:
	var engine := FluidMidiSynth.new()
	assert(engine.load_soundfont(_fixture()).is_empty())

	return engine


func _energy(frames: PackedVector2Array) -> float:
	var total := 0.0

	for frame in frames:
		total += frame.x * frame.x + frame.y * frame.y

	return total / maxf(1.0, float(frames.size()))


## One note with reverb and chorus off, so silence is exact.
func _note_sequence(channel: int, note: int, program: int, seconds := 0.1) -> StandardMidiFile:
	var sequence := StandardMidiFile.new()
	sequence.format_type = 0
	sequence.track_count = 1
	sequence.ticks_per_quarter = 96
	var events: Array[StandardMidiFile.Event] = []

	for controller in [91, 93]:
		events.append(_event("control_change", channel, 0.0, { "controller": controller, "value": 0 }))

	events.append(_event("program_change", channel, 0.0, { "program": program }))
	events.append(_event("note_on", channel, 0.0, { "note": note, "velocity": 100 }))
	events.append(_event("note_off", channel, seconds * 0.8, { "note": note }))
	sequence.events.assign(events)
	sequence.duration_seconds = seconds

	return sequence


func _event(type: String, channel: int, time: float, fields: Dictionary) -> StandardMidiFile.Event:
	var event := StandardMidiFile.Event.new()
	event.type = type
	event.channel = channel
	event.time_seconds = time

	for field in fields:
		event.set(field, fields[field])

	return event


## A format 0 file: program 80, a note with channel and key pressure, then a drum hit.
func _midi_bytes() -> PackedByteArray:
	var track := PackedByteArray([
		0x00, 0xc0, SQUARE_PROGRAM,
		0x00, 0x90, 69, 100,
		0x30, 0xd0, 64,
		0x00, 0xa0, 69, 40,
		0x30, 0x80, 69, 0,
		0x00, 0x99, BASS_DRUM, 100,
		0x30, 0x89, BASS_DRUM, 0,
		0x00, 0xff, 0x2f, 0x00,
	])
	var bytes := "MThd".to_ascii_buffer()
	bytes.append_array([0, 0, 0, 6, 0, 0, 0, 1, 0, 96])
	bytes.append_array("MTrk".to_ascii_buffer())
	bytes.append_array([0, 0, 0, track.size()])
	bytes.append_array(track)

	return bytes


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
