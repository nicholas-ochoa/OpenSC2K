extends SceneTree
## Synthetic timing, PCM and transactional pack tests do not need source games.


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var voice := _voc([PackedByteArray([1, 5, 0, 0, 166, 0, 0, 128, 255])])
	var converted := Sc2ImportVoc.convert(voice)
	assert(converted.ok, converted.error)
	assert(converted.bytes.decode_u32(24) == 11111)
	assert(converted.bytes.slice(44, 47) == PackedByteArray([0, 128, 255]))
	assert(not Sc2ImportVoc.convert(voice.slice(0, 29)).ok)
	var unsupported := voice.duplicate()
	unsupported[31] = 1
	assert(not Sc2ImportVoc.convert(unsupported).ok)
	var looped := Sc2ImportVoc.convert(_voc([
		PackedByteArray([6, 2, 0, 0, 255, 255]),
		PackedByteArray([1, 5, 0, 0, 166, 0, 0, 128, 255]),
		PackedByteArray([7, 0, 0, 0])]))
	assert(looped.ok, looped.error)
	var loop_stream := AudioStreamWAV.load_from_buffer(looped.bytes)
	assert(loop_stream != null and loop_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(loop_stream.loop_begin == 0 and loop_stream.loop_end > 0)
	var repeated := Sc2ImportVoc.convert(_voc([
		PackedByteArray([6, 2, 0, 0, 2, 0]),
		PackedByteArray([1, 3, 0, 0, 166, 0, 77]),
		PackedByteArray([7, 0, 0, 0])]))
	assert(repeated.ok and repeated.bytes.slice(44, 47) == PackedByteArray([77, 77, 77]))
	var continuation := Sc2ImportVoc.convert(_voc([
		PackedByteArray([1, 3, 0, 0, 166, 0, 77]),
		PackedByteArray([2, 2, 0, 0, 88, 99]),
		PackedByteArray([3, 3, 0, 0, 1, 0, 166])]))
	assert(continuation.ok and continuation.bytes.slice(44, 49) == PackedByteArray([77, 88, 99, 128, 128]))
	# Overlapping notes use additive delays: 100 + 20 is 120 ticks, not a VLQ.
	# The tempo event has no effect on XMIDI's fixed clock.
	var sequence := _xmi(PackedByteArray([
		0xff, 0x51, 3, 3, 0xd0, 0x90, 0xc0, 4,
		0x90, 60, 100, 0x81, 0x70,
		100, 20, 0x90, 64, 80, 60,
		0xff, 0x2f, 0]))
	var music := Sc2ImportXmi.convert(sequence)
	assert(music.ok, music.error)
	var midi := StandardMidiFile.new()
	assert(midi.parse(music.bytes), midi.parse_error)
	var notes: Array[StandardMidiFile.Event] = []

	for event in midi.events:
		if event.type in ["note_on", "note_off"]:
			notes.append(event)

	assert(notes.size() == 4)
	assert(notes[0].note == 60 and notes[0].tick == 0)
	assert(notes[1].note == 64 and notes[1].tick == 120 and is_equal_approx(notes[1].time_seconds, 1.0))
	assert(notes[2].note == 64 and notes[2].tick == 180 and notes[2].type == "note_off")
	assert(notes[3].note == 60 and notes[3].tick == 240 and is_equal_approx(midi.duration_seconds, 2.0))
	assert(not Sc2ImportXmi.convert(sequence.slice(0, sequence.size() - 2)).ok)
	assert(not Sc2ImportXmi.convert(_xmi(PackedByteArray([0x90, 60, 100, 0x80, 0x80, 0x80, 0x80, 0xff, 0x2f, 0]))).ok)
	assert(not Sc2ImportXmi.convert(_xmi(PackedByteArray([0xb0, 116, 0, 0xff, 0x2f, 0]))).ok)
	_test_import(voice, sequence)
	_test_resource_types(music.bytes)
	print("PASS: VOC samples, repeats, loops, XMIDI timing and notes, selective packs, partial failure, coexistence and source preservation")
	quit()


func _test_resource_types(midi: PackedByteArray) -> void:
	var temporary := ProjectSettings.globalize_path("res://../local/sc2-import-ids-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var source := Sc2ImportSource.new()
	# Resource type takes priority over a MIDI-range ID.
	source.platform = "Macintosh"
	source.resources = [
		Sc2ImportResource.make("snd/10001", PackedByteArray([0]), "synthetic", "snd ", 10001),
		Sc2ImportResource.make("MIDI/10001", midi, "synthetic", "MIDI", 10001),
	]
	var result := Sc2MediaImportResult.new()
	Sc2MediaImporter._import_audio(source, "music", temporary.path_join("music"), "Synthetic Mac", result)
	assert(result.counts.music == 1 and result.warnings.size() == 1)
	assert(OriginalGameInstaller.remove_tree(temporary) == OK)


func _test_import(voice: PackedByteArray, sequence: PackedByteArray) -> void:
	var temporary := ProjectSettings.globalize_path("res://../local/sc2-import-audio-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var source := temporary.path_join("source")
	var packs := temporary.path_join("packs")
	_write(source.path_join("500.VOC"), voice)
	_write(source.path_join("501.VOC"), PackedByteArray([1, 2, 3]))
	_write(source.path_join("10001.XMI"), sequence)
	# Detect the source without a known executable hash.
	_write(source.path_join("SC2000.EXE"), PackedByteArray([77, 90, 1, 2]))
	# Only import the selected installer, not neighboring files in Downloads.
	_write(source.path_join("gog-installer.pkg"), PackedByteArray([1, 2, 3]))
	var installer := Sc2MediaImporter.import_assets(source.path_join("gog-installer.pkg"), packs)
	assert(not installer.ok and installer.counts.is_empty() and installer.root.is_empty())
	assert(not installer.error.is_empty())
	var sound := Sc2MediaImporter.import_assets(source, packs, PackedStringArray(["sound"]))
	assert(sound.ok and sound.partial and sound.counts.sound == 1, sound.summary())
	assert(sound.music.is_empty() and sound.graphics.is_empty())
	assert(not DirAccess.dir_exists_absolute(sound.root.path_join("music")))
	assert(not DirAccess.dir_exists_absolute(sound.root.path_join("graphics")))
	assert(MediaPack.load_folder(sound.sound, "sound").files.has(500))
	var all := Sc2MediaImporter.import_assets(source, packs)
	assert(all.ok and all.partial and all.failures.has("graphics"), all.summary())
	assert(all.counts.sound == 1 and all.counts.music == 1)
	assert(sound.root != all.root and FileAccess.file_exists(sound.sound))
	assert(FileAccess.get_file_as_bytes(source.path_join("500.VOC")) == voice)
	assert(FileAccess.get_file_as_bytes(source.path_join("10001.XMI")) == sequence)
	var music := Sc2MediaImporter.import_assets(source.path_join("10001.XMI"), packs, PackedStringArray(["music"]))
	assert(music.ok and music.sound.is_empty() and music.counts.music == 1, music.summary())
	assert(not Sc2MediaImporter.import_assets(source, source.path_join("output")).ok)
	assert(not Sc2MediaImporter.import_assets(source, packs, PackedStringArray()).ok)
	assert(not Sc2MediaImporter.import_assets(source, packs, PackedStringArray(["invalid"])).ok)
	assert(not Sc2MediaImporter.import_assets(source, packs, PackedStringArray(["graphics"])).ok)
	assert(OriginalGameInstaller.remove_tree(temporary) == OK)


func _write(path: String, bytes: PackedByteArray) -> void:
	assert(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(bytes)


func _voc(blocks: Array[PackedByteArray]) -> PackedByteArray:
	var data := "Creative Voice File".to_ascii_buffer() + PackedByteArray([26, 26, 0, 10, 1, 41, 17])

	for block in blocks:
		data.append_array(block)

	data.append(0)
	return data


func _xmi(events: PackedByteArray) -> PackedByteArray:
	var body := "XMIDEVNT".to_ascii_buffer()
	_put_be32(body, events.size())
	body.append_array(events)

	if events.size() % 2 != 0:
		body.append(0)

	var data := "FORM".to_ascii_buffer()
	_put_be32(data, body.size())
	data.append_array(body)
	return data


func _put_be32(data: PackedByteArray, value: int) -> void:
	for shift in [24, 16, 8, 0]:
		data.append((value >> shift) & 255)
