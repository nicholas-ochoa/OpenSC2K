extends SceneTree

const STORY_TABLE := 2
const STORY_PHRASE := 33
const TOKEN_PHRASE := 32


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	_test_newspaper_conversion()
	_test_record_files()
	_test_macintosh_container()
	_test_dos_import()
	print("PASS: DOS, Macintosh, and demo text and newspaper conversion, optional template and Library texts")
	quit()


func _test_newspaper_conversion() -> void:
	# DOS tokens move to Windows token bytes. Arguments and phrase offsets stay.
	var dos := _newspaper(PackedByteArray([0x48, 0xd2, 0x78, 0xd3, 0x2b, 0x80, 0x2a, 0x85, 0x2e]))
	var converted := Sc2DataConvert.windows_newspaper(dos)
	var grammar := converted[Sc2DataConvert.GRAMMAR_ID]
	var story := _offset(dos, STORY_PHRASE)
	assert(grammar.slice(story, story + 9) == PackedByteArray([0x48, 0x22, 0x78, 0x22, 0x2b, 0x7f, 0x2a, 0x85, 0x2e]))
	assert(grammar.size() == dos[Sc2DataConvert.GRAMMAR_ID].size())
	assert(converted[Sc2DataConvert.OFFSETS_ID] == dos[Sc2DataConvert.OFFSETS_ID])
	assert(BinaryData.read_u16_be(converted[Sc2DataConvert.BASES_ID], 0) == 0)

	# Windows grammar keeps its token bytes
	var windows := _newspaper(PackedByteArray([0x48, 0x2b, 0xee, 0xff, 0x2e]))
	assert(Sc2DataConvert.windows_newspaper(windows)[Sc2DataConvert.GRAMMAR_ID] == windows[Sc2DataConvert.GRAMMAR_ID])

	# The 1993 Macintosh demo grammar has no headline ends
	assert(Sc2DataConvert.windows_newspaper(_newspaper(PackedByteArray([0x48, 0x2d, 0x80]))).is_empty())
	dos.erase(Sc2DataConvert.GRAMMAR_ID)
	assert(Sc2DataConvert.windows_newspaper(dos).is_empty())


func _test_record_files() -> void:
	var records: Dictionary[int, PackedByteArray] = { 3000: "c".to_ascii_buffer(), 128: "ab".to_ascii_buffer() }
	var files := Sc2DataConvert.resource_files(records)
	assert(files[0] == "abc".to_ascii_buffer())
	assert(files[1].decode_u32(0) == 128 and files[1].decode_u32(8) == 3000 and files[1].decode_u32(12) == 2)
	assert(Sc2DataConvert.indexed_records(files[0], files[1]) == records)
	assert(Sc2DataConvert.indexed_records(files[0], files[1].slice(0, 12)).is_empty())

	# Windows demos use renamed or loose index and data file pairs
	var source := Sc2ImportSource.new()
	source.resources.append(Sc2ImportResource.make("TEXT.DAT", files[0], "TEXT.DAT"))
	source.resources.append(Sc2ImportResource.make("TEXT.IDX", files[1], "TEXT.IDX"))
	assert(Sc2DataConvert.find_records(source).text == records)


# Each Macintosh scenario file has its own TEXT 128. The credits come from the application.
func _test_macintosh_container() -> void:
	var source := Sc2ImportSource.new()
	source.resources.append(Sc2ImportResource.make("TEXT/128", "Scenario".to_ascii_buffer(), "Atlanta.rsrc", "TEXT", 128))
	source.resources.append(Sc2ImportResource.make("TEXT/128", "Credits".to_ascii_buffer(), "SimCity.rsrc", "TEXT", 128))
	source.resources.append(Sc2ImportResource.make("DATA/1003", PackedByteArray([0]), "SimCity.rsrc", "DATA", 1003))
	var records := Sc2DataConvert.find_records(source)
	assert(records.text[128] == "Credits".to_ascii_buffer() and records.newspaper.has(1003))


func _test_dos_import() -> void:
	var files := { "TXT128": "Credits".to_ascii_buffer(), "TXT3000": "Page".to_ascii_buffer() }
	var newspaper := _newspaper(PackedByteArray([0x48, 0xd2, 0x78, 0xd3, 0x2b, 0x80, 0x2e]))

	for id: int in newspaper:
		files["PPDT%d.RAW" % id] = newspaper[id]

	var temporary := ProjectSettings.globalize_path("res://../local/sc2-import-data-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var source := temporary.path_join("source")
	assert(DirAccess.make_dir_recursive_absolute(source.path_join("CITIES")) == OK)
	_store(source.path_join("SC2000.DAT"), _archive(files))
	var city := FileAccess.get_file_as_bytes("res://tests/fixtures/cities/generated-128.SC2")
	_store(source.path_join("CITIES/TEST.SC2"), city)
	# a city beside a demo, and a Macintosh scenario with its resource fork
	_store(source.path_join("Demo City"), city)
	_store(source.path_join("Atlanta"), city)
	_store(source.path_join("Atlanta.rsrc"), PackedByteArray([0]))
	var imported := Sc2MediaImporter.import_assets(source, temporary.path_join("packs"), PackedStringArray(["data"]))
	assert(imported.ok and imported.platform == "DOS", imported.summary())
	var pack := DataPack.load_folder(imported.data)
	assert(pack.is_loaded() and not pack.has_template(), pack.error)
	assert(pack.text.original_credits == "Credits" and pack.text.library_texts == { 3000: "Page" })
	assert(FileAccess.file_exists(pack.root.path_join("CITIES/TEST.SC2")))
	assert(FileAccess.file_exists(pack.root.path_join("CITIES/Demo City.SC2")))
	assert(not FileAccess.file_exists(pack.root.path_join("CITIES/Atlanta.SC2")))
	var record := NewsQueue.StoryRecord.new(STORY_TABLE, 0, PackedByteArray([255, 255, 255]))
	var story := NewspaperText.render_story(pack.text.newspaper_data, record, 1, "Town", "Pat", PackedStringArray())
	assert(story.ok and story.headline == "H\"X\"" and story.article.strip_edges() == "ok.", story.error)

	# without newspaper records the pack has text only
	for id: int in newspaper:
		files.erase("PPDT%d.RAW" % id)

	_store(source.path_join("SC2000.DAT"), _archive(files))
	imported = Sc2MediaImporter.import_assets(source, temporary.path_join("packs"), PackedStringArray(["data"]))
	pack = DataPack.load_folder(imported.data)
	assert(pack.is_loaded() and pack.text.newspaper_data == null, pack.error)
	assert("\n".join(imported.warnings).contains("no newspaper data"))
	assert(OriginalGameInstaller.remove_tree(temporary) == OK)


# one story table with one phrase. Token 0x80 selects phrase 32. Other tables are empty.
func _newspaper(story: PackedByteArray) -> Dictionary[int, PackedByteArray]:
	var bases := PackedByteArray()
	var counts := PackedByteArray()
	bases.resize(DataUsaResource.TABLE_ENTRY_COUNT * 2)
	counts.resize(DataUsaResource.TABLE_ENTRY_COUNT * 2)
	bases.fill(0xff)
	counts.fill(0)
	bases[STORY_TABLE * 2] = 0
	bases[STORY_TABLE * 2 + 1] = STORY_PHRASE
	counts[STORY_TABLE * 2 + 1] = 1
	var grammar := PackedByteArray([0])
	var token_offset := grammar.size()
	grammar.append_array("ok".to_ascii_buffer())
	grammar.append(0)
	var story_offset := grammar.size()
	grammar.append_array(story)
	grammar.append(0)
	var offsets := PackedByteArray()
	offsets.resize(DataUsaResource.PHRASE_COUNT * 4)
	offsets.fill(0)
	BinaryData.write_u32_be(offsets, TOKEN_PHRASE * 4, token_offset)
	BinaryData.write_u32_be(offsets, STORY_PHRASE * 4, story_offset)

	return {
		Sc2DataConvert.BASES_ID: bases,
		Sc2DataConvert.COUNTS_ID: counts,
		Sc2DataConvert.OFFSETS_ID: offsets,
		Sc2DataConvert.GRAMMAR_ID: grammar,
	}


func _offset(records: Dictionary[int, PackedByteArray], phrase: int) -> int:
	return BinaryData.read_u32_be(records[Sc2DataConvert.OFFSETS_ID], phrase * 4)


# the DOS SC2000.DAT directory: a 12-byte name and an offset for each record
func _archive(files: Dictionary) -> PackedByteArray:
	var archive := PackedByteArray()
	archive.resize(files.size() * 16)
	var record := 0

	for name: String in files:
		var text := name.to_ascii_buffer()

		for index in text.size():
			archive[record * 16 + index] = text[index]

		archive.encode_u32(record * 16 + 12, archive.size())
		archive.append_array(files[name])
		record += 1

	return archive


func _store(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
