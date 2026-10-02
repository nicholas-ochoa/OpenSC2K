class_name Sc2DataConvert
extends RefCounted
## Convert DOS and Macintosh text and newspaper records to the Windows data files.

const TEXT_RESOURCE_PREFIX := "TXT"
const NEWSPAPER_RESOURCE_PREFIX := "PPDT"
const NEWSPAPER_IDS := [1000, 1001, 1002, 1003, 1004, 1005]
# the game does not read records 1004 and 1005
const REQUIRED_NEWSPAPER_IDS := [1000, 1001, 1002, 1003]
# Windows releases and demos keep the records in index and data file pairs
const TEXT_FILE_NAMES := ["TEXT_USA", "TEXT"]
const NEWSPAPER_FILE_NAMES := ["DATA_USA", "DATA"]
const INDEX_RECORD_SIZE := 8
const BASES_ID := 1000
const COUNTS_ID := 1001
const OFFSETS_ID := 1002
const GRAMMAR_ID := 1003
# DOS and Macintosh tokens 0x80 to 0xb6 select phrases 32 to 86. Windows uses other token bytes.
const SHIFTED_TOKEN_FIRST := 0x80
const SHIFTED_TOKEN_LAST := 0xb6
# Only the shifted encoding uses 0x80 to 0x9d as tokens. Only Windows uses 0xee to 0xff.
const SHIFTED_ONLY_TOKEN_END := 0x9d
const WINDOWS_ONLY_TOKEN_FIRST := 0xee
# The DOS and Macintosh grammar has Macintosh curly quotes. Windows has ASCII quotes.
const QUOTE_BYTES := { 0xd2: 0x22, 0xd3: 0x22, 0xd4: 0x27, 0xd5: 0x27 }
# These grammar opcodes read the next byte as their argument
const ARGUMENT_OPCODES := [0x25, 0x26, 0x2a, 0x3c, 0x40, 0x5b, 0x5c, 0x5e]
const NO_TABLE_BASE := 0xffff
const HEADLINE_END := 0x2b


class Records extends RefCounted:
	var text: Dictionary[int, PackedByteArray] = {}
	var newspaper: Dictionary[int, PackedByteArray] = {}


# DOS keeps TXT and PPDT records in SC2000.DAT. Windows demos keep .DAT and .IDX pairs.
# A Macintosh application keeps TEXT and DATA resources. Take the Macintosh text from the file with the newspaper, because
# each scenario file has its own TEXT 128.
static func find_records(source: Sc2ImportSource) -> Records:
	var records := Records.new()
	var container := ""

	var files: Dictionary[String, PackedByteArray] = {}

	for resource in source.resources:
		if resource.type == "DATA" and resource.id == GRAMMAR_ID and container.is_empty():
			container = resource.source
		elif resource.type.is_empty() and not files.has(resource.name.to_upper()):
			files[resource.name.to_upper()] = resource.bytes

	for pair in [[TEXT_FILE_NAMES, records.text], [NEWSPAPER_FILE_NAMES, records.newspaper]]:
		for name: String in pair[0]:
			if files.has(name + ".DAT") and files.has(name + ".IDX"):
				var indexed := indexed_records(files[name + ".DAT"], files[name + ".IDX"])

				for id: int in indexed:
					_keep(pair[1], id, indexed[id])

	for resource in source.resources:
		if resource.type.is_empty():
			var name := resource.name.get_basename().to_upper()

			if name.begins_with(TEXT_RESOURCE_PREFIX) and name.trim_prefix(TEXT_RESOURCE_PREFIX).is_valid_int():
				_keep(records.text, int(name.trim_prefix(TEXT_RESOURCE_PREFIX)), resource.bytes)
			elif name.begins_with(NEWSPAPER_RESOURCE_PREFIX) and name.trim_prefix(NEWSPAPER_RESOURCE_PREFIX).is_valid_int():
				var id := int(name.trim_prefix(NEWSPAPER_RESOURCE_PREFIX))

				if id in NEWSPAPER_IDS:
					_keep(records.newspaper, id, resource.bytes)
		elif resource.source == container and resource.type == "TEXT" and resource.id >= 0:
			_keep(records.text, resource.id, resource.bytes)
		elif resource.source == container and resource.type == "DATA" and resource.id in NEWSPAPER_IDS:
			_keep(records.newspaper, resource.id, resource.bytes)

	return records


# a Windows .IDX file holds a little-endian ID and data offset for each record, in data order
static func indexed_records(data: PackedByteArray, index: PackedByteArray) -> Dictionary[int, PackedByteArray]:
	var records: Dictionary[int, PackedByteArray] = {}

	if index.is_empty() or index.size() % INDEX_RECORD_SIZE != 0:
		return records

	for offset in range(0, index.size(), INDEX_RECORD_SIZE):
		var start := int(index.decode_u32(offset + 4))
		var end := data.size() if offset + INDEX_RECORD_SIZE >= index.size() else int(index.decode_u32(offset + INDEX_RECORD_SIZE + 4))

		if start > end or end > data.size():
			return {} as Dictionary[int, PackedByteArray]

		records[int(index.decode_u32(offset))] = data.slice(start, end)

	return records


# DOS, Macintosh, and the Windows 3.x demo use tokens 0x80 to 0x9d often. In Windows
# grammar those bytes are rare CP437 letters, and tokens 0xee to 0xff are common.
static func uses_shifted_tokens(records: Dictionary[int, PackedByteArray]) -> bool:
	var shifted := 0
	var windows := 0

	for start: int in _phrase_starts(records[OFFSETS_ID]):
		var grammar := records[GRAMMAR_ID]
		var cursor := start

		while cursor < grammar.size() and grammar[cursor] != 0:
			var value := int(grammar[cursor])

			if value in ARGUMENT_OPCODES:
				cursor += 2
				continue

			if value >= SHIFTED_TOKEN_FIRST and value <= SHIFTED_ONLY_TOKEN_END:
				shifted += 1
			elif value >= WINDOWS_ONLY_TOKEN_FIRST:
				windows += 1

			cursor += 1

	return shifted > windows


# Keep the record layout and phrase offsets. Change only the shifted token bytes, the
# Macintosh quotes, and the base of each empty table. In CP437 those quote bytes are box lines.
static func windows_newspaper(records: Dictionary[int, PackedByteArray]) -> Dictionary[int, PackedByteArray]:
	var converted: Dictionary[int, PackedByteArray] = {}

	for id: int in REQUIRED_NEWSPAPER_IDS:
		if not records.has(id):
			return converted

	var bases := records[BASES_ID].duplicate()
	var counts := records[COUNTS_ID]
	var offsets := records[OFFSETS_ID]
	var grammar := records[GRAMMAR_ID].duplicate()

	if bases.size() != counts.size() or bases.size() % 2 != 0 or offsets.size() % 4 != 0 or not has_headline_ends(records):
		return converted

	for offset in range(0, bases.size(), 2):
		if BinaryData.read_u16_be(counts, offset) == 0 and BinaryData.read_u16_be(bases, offset) == NO_TABLE_BASE:
			bases[offset] = 0
			bases[offset + 1] = 0

	var shifted := uses_shifted_tokens(records)

	for start: int in _phrase_starts(offsets):
		var cursor := start

		while cursor < grammar.size() and grammar[cursor] != 0:
			var value := int(grammar[cursor])

			if value in ARGUMENT_OPCODES:
				cursor += 2
				continue

			if shifted and value >= SHIFTED_TOKEN_FIRST and value <= SHIFTED_TOKEN_LAST:
				grammar[cursor] = NewspaperText.EXTENDED_TOKEN_BYTES[value - SHIFTED_TOKEN_FIRST]
			elif QUOTE_BYTES.has(value):
				grammar[cursor] = QUOTE_BYTES[value]

			cursor += 1

	for id: int in NEWSPAPER_IDS:
		if records.has(id):
			converted[id] = records[id]

	converted[BASES_ID] = bases
	converted[GRAMMAR_ID] = grammar

	return converted


# The Windows .DAT file holds the records in ID order. Each .IDX record holds a
# little-endian ID and data offset.
static func resource_files(records: Dictionary[int, PackedByteArray]) -> Array[PackedByteArray]:
	var ids := records.keys()
	ids.sort()
	var data := PackedByteArray()
	var index := PackedByteArray()
	index.resize(ids.size() * 8)

	for position in ids.size():
		index.encode_u32(position * 8, ids[position])
		index.encode_u32(position * 8 + 4, data.size())
		data.append_array(records[ids[position]])

	return [data, index]


# The 1993 Macintosh demo grammar has no headline ends and numbers its stories in
# another order, so the game cannot use it.
static func has_headline_ends(records: Dictionary[int, PackedByteArray]) -> bool:
	var bases := records[BASES_ID]
	var counts := records[COUNTS_ID]
	var offsets := records[OFFSETS_ID]
	var stories := 0
	var marked := 0

	for table in mini(NewsQueue.STORY_PRIORITIES.size(), counts.size() / 2):
		if NewsQueue.STORY_PRIORITIES[table] <= 0:
			continue

		for phrase in BinaryData.read_u16_be(counts, table * 2):
			var phrase_id := BinaryData.read_u16_be(bases, table * 2) + phrase

			if phrase_id * 4 + 4 <= offsets.size():
				stories += 1

				if _top_level_byte(records[GRAMMAR_ID], BinaryData.read_u32_be(offsets, phrase_id * 4), HEADLINE_END) >= 0:
					marked += 1

	return marked * 2 >= stories


static func _top_level_byte(grammar: PackedByteArray, start: int, wanted: int) -> int:
	var cursor := start

	while cursor < grammar.size() and grammar[cursor] != 0:
		if grammar[cursor] == wanted:
			return cursor

		cursor += 2 if grammar[cursor] in ARGUMENT_OPCODES else 1

	return -1


static func _phrase_starts(offsets: PackedByteArray) -> Array[int]:
	var starts: Dictionary[int, bool] = {}

	for offset in range(0, offsets.size() - 3, 4):
		starts[BinaryData.read_u32_be(offsets, offset)] = true

	var result: Array[int] = []
	result.assign(starts.keys())

	return result


static func _keep(target: Dictionary[int, PackedByteArray], id: int, bytes: PackedByteArray) -> void:
	if not target.has(id):
		target[id] = bytes
