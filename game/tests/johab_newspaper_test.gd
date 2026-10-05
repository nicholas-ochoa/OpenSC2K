extends SceneTree
## Johab pairs and grammar operands must never become shifted DOS tokens.

const KOREAN := [0x88, 0x61, 0x90, 0x61, 0x94, 0x61, 0x9c, 0x61, 0xa0, 0x61, 0xa4, 0x61,
	0xac, 0x61, 0xb4, 0x61, 0xb8, 0x61, 0xc0, 0x61, 0xc4, 0x61, 0xc8, 0x61, 0xcc, 0x61, 0xd0, 0x61,
	0xd0, 0x65, 0x8a, 0x82, 0xaf, 0xa5, 0xa2, 0x85]
const KOREAN_TEXT := "가나다라마바사아자차카타파하한국신문"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(JohabCodec.code_point(PackedByteArray([0xd0, 0x65]), 0) == "한".unicode_at(0))
	assert(JohabCodec.code_point(PackedByteArray([0xd9, 0x40]), 0) == "“".unicode_at(0))
	assert(JohabCodec.code_point(PackedByteArray([0x84, 0x5c]), 0) == "ㅍ".unicode_at(0))
	assert(JohabCodec.code_point(PackedByteArray([0xff, 0xff]), 0) == 0)
	assert(JohabCodec.code_point(PackedByteArray([0x88]), 0) == 0)
	var grammar := PackedByteArray([0])
	grammar.append_array(PackedByteArray(KOREAN))
	# Pair trails coincide with @, backslash and ^ grammar opcodes.
	grammar.append_array(PackedByteArray([0xd9, 0x40, 0x84, 0x5c, 0xd9, 0x5e, 0x2b, 0x2d]))
	grammar.append_array(PackedByteArray(KOREAN))
	grammar.append_array(PackedByteArray([0x20, 0x3d, 0x20, 0x7e, 0x20, 0x24, 0x20, 0x2a, 200,
		0x20, 0x5c, 0x88, 0x61, 0x20, 0x5c, 0x2b, 0]))
	var subphrase := grammar.size()
	grammar.append_array(PackedByteArray([0x8b, 0xa1, 0xac, 0x61, 0]))
	var offsets := PackedByteArray()
	offsets.resize(DataUsaResource.PHRASE_COUNT * 4)
	BinaryData.write_u32_be(offsets, 100 * 4, 1)
	BinaryData.write_u32_be(offsets, 101 * 4, subphrase)
	var bases := PackedByteArray()
	var counts := PackedByteArray()
	bases.resize(DataUsaResource.TABLE_ENTRY_COUNT * 2)
	counts.resize(DataUsaResource.TABLE_ENTRY_COUNT * 2)
	BinaryData.write_u16_be(bases, 2 * 2, 100)
	BinaryData.write_u16_be(counts, 2 * 2, 1)
	BinaryData.write_u16_be(bases, 200 * 2, 101)
	BinaryData.write_u16_be(counts, 200 * 2, 1)
	var records: Dictionary[int, PackedByteArray] = {1000: bases, 1001: counts, 1002: offsets, 1003: grammar}
	assert(JohabCodec.is_grammar(grammar, offsets))
	assert(not Sc2DataConvert.uses_shifted_tokens(records))
	var converted := Sc2DataConvert.windows_newspaper(records)
	assert(not converted.is_empty())
	assert(converted[1003] == grammar and converted[1002] == offsets, "Korean source bytes and offsets must remain exact")
	var pair := Sc2DataConvert.resource_files(converted)
	var folder := "user://johab-test-%d" % OS.get_process_id()
	assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
	_store(folder.path_join("DATA.DAT"), pair[0])
	_store(folder.path_join("DATA.IDX"), pair[1])
	var source := DataUsaResource.load_path(folder.path_join("DATA.DAT"), folder.path_join("DATA.IDX"))
	assert(source.is_valid() and source.is_johab, source.load_error)
	var record := NewsQueue.StoryRecord.new(2, 27, PackedByteArray([255, 255, 255]))
	var before := source.grammar.duplicate()
	var result := NewspaperText.render_story(source, record, 471, "서울", "김시장", PackedStringArray())
	assert(result.ok, result.error)
	assert(result.headline == KOREAN_TEXT + "“ㅍ♂", result.headline)
	assert(result.article.strip_edges() == KOREAN_TEXT + " 서울 김시장 27 기사 가 +", result.article)
	assert(source.grammar == before and record.auxiliary == PackedByteArray([255, 255, 255]))
	var again := NewspaperText.render_story(source, record, 471, "서울", "김시장", PackedStringArray())
	assert(again.headline == result.headline and again.article == result.article and again.random_state == result.random_state)
	var headline := NewspaperText.render_headline(source, record, 471, "서울", "김시장", PackedStringArray())
	assert(headline.ok and headline.headline == result.headline)
	# A short accented/token sequence cannot switch an English resource to Johab.
	assert(not JohabCodec.is_grammar(PackedByteArray([0, 0x80, 0x20, 0xee, 0xff, 0]), offsets))
	source.grammar[1] = 0xff
	assert(not NewspaperText.render_story(source, record, 471, "서울", "김시장", PackedStringArray()).ok)
	assert(OriginalGameInstaller.remove_tree(ProjectSettings.globalize_path(folder)) == OK)
	print("PASS: Johab detection, pair/opcode collisions, byte-exact import, Korean names, grammar arguments, deterministic rendering and malformed-pair rejection")
	quit()


func _store(path: String, bytes: PackedByteArray) -> void:
	FileAccess.open(path, FileAccess.WRITE).store_buffer(bytes)
