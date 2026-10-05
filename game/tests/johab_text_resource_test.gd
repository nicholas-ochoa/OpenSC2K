extends SceneTree
## Plain Korean TXT records share a file-level encoding and have no opcodes.

const HANGUL := [0x88, 0x61, 0x90, 0x61, 0x94, 0x61, 0x9c, 0x61, 0xa0, 0x61, 0xa4, 0x61,
	0xac, 0x61, 0xb4, 0x61, 0xb8, 0x61, 0xc0, 0x61, 0xc4, 0x61, 0xc8, 0x61, 0xcc, 0x61, 0xd0, 0x61,
	0xd0, 0x65, 0x8a, 0x82, 0xaf, 0xa5, 0xa2, 0x85]
const HANGUL_TEXT := "가나다라마바사아자차카타파하한국신문"


func _initialize() -> void:
	var folder := "user://johab-plain-text-%d" % OS.get_process_id()
	assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
	var long_text := PackedByteArray(HANGUL)
	# ASCII @ and backslash remain literal text, including directly before a pair.
	long_text.append_array(PackedByteArray([0x20, 0x40, 0x88, 0x61, 0x20, 0x5c, 0x88, 0x61,
		0x20, 0xd9, 0x40, 0x84, 0x5c, 0xd9, 0x5e, 0x0d, 0x0a]))
	var expected := HANGUL_TEXT + " @가 \\가 “ㅍ♂\r\n"
	assert(JohabCodec.is_text(long_text))
	assert(JohabCodec.decode_text(long_text) == expected)
	var short_text := PackedByteArray([0xd0, 0x65])
	assert(not JohabCodec.is_text(short_text))
	assert(JohabCodec.decode_text(short_text) == "한")
	var latin := "English: %s @file\\path + - [brackets]\r\n\tEnd".to_ascii_buffer()
	var paths := _store(folder, {10: latin, 20: long_text, 30: short_text, 40: PackedByteArray()})
	# Request only a short record. Unrequested Korean text identifies the file.
	var short_result := TextUsaResource.load_ids(paths[0], paths[1], PackedInt32Array([30]))
	assert(short_result.ok and short_result.strings[30] == "한", short_result.error)
	var all := TextUsaResource.load_ids(paths[0], paths[1], PackedInt32Array([10, 20, 30, 40]))
	assert(all.ok and all.strings == {10: latin.get_string_from_ascii(), 20: expected, 30: "한", 40: ""})
	var data_before := FileAccess.get_file_as_bytes(paths[0])
	var index_before := FileAccess.get_file_as_bytes(paths[1])
	assert(not TextUsaResource.load_ids(paths[0], paths[1], PackedInt32Array([999])).ok)
	assert(FileAccess.get_file_as_bytes(paths[0]) == data_before and FileAccess.get_file_as_bytes(paths[1]) == index_before)
	# Legacy accented bytes remain exactly what the existing ASCII getter returns.
	var extended_latin := latin.duplicate()
	extended_latin.append_array(PackedByteArray([0x80, 0x82, 0x9a, 0xe9, 0xff]))
	assert(not JohabCodec.is_text(extended_latin))
	paths = _store(folder, {10: extended_latin})
	var legacy := TextUsaResource.load_ids(paths[0], paths[1], PackedInt32Array([10]))
	assert(legacy.ok and legacy.strings[10] == extended_latin.get_string_from_ascii())
	# A lone lead or invalid pair must not drop bytes or substitute a glyph.
	for tail in [PackedByteArray([0x88]), PackedByteArray([0xff, 0xff])]:
		var malformed := long_text.duplicate()
		malformed.append_array(tail)
		assert(not JohabCodec.is_text(malformed))
		assert(JohabCodec.decode_text(malformed) == malformed.get_string_from_ascii())
		paths = _store(folder, {10: malformed, 20: short_text})
		# A trailing0x88 and the next record's0xd0 form a valid pair if the
		# resource boundary is ignored. The container must reject that guess.
		var preserved := TextUsaResource.load_ids(paths[0], paths[1], PackedInt32Array([10, 20]))
		assert(preserved.ok and preserved.strings[10] == malformed.get_string_from_ascii())
		assert(preserved.strings[20] == short_text.get_string_from_ascii())
		assert(FileAccess.get_file_as_bytes(paths[0]).slice(0, malformed.size()) == malformed)
	assert(OriginalGameInstaller.remove_tree(ProjectSettings.globalize_path(folder)) == OK)
	print("PASS: whole-file Johab detection, short selected labels, literal ASCII markers, pair trails, legacy Latin and malformed-byte preservation")
	quit()


func _store(folder: String, records: Dictionary[int, PackedByteArray]) -> PackedStringArray:
	var files := Sc2DataConvert.resource_files(records)
	var paths := PackedStringArray([folder.path_join("TEXT.DAT"), folder.path_join("TEXT.IDX")])
	for index in paths.size():
		FileAccess.open(paths[index], FileAccess.WRITE).store_buffer(files[index])
	return paths
