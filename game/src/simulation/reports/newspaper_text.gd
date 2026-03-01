class_name NewspaperText
extends RefCounted

const Random = preload("res://src/simulation/random/sim_random.gd")

const MAX_OUTPUT_BYTES := 2047
const MAX_RECURSION_DEPTH := 128
const PUBLISHED_SEED_OFFSETS := [28, 49, 56, 63, 70, -1, -1, 42, 35]
const EXTENDED_TOKEN_BYTES := [
	0x7f, 0x9e, 0x9f, 0xa9, 0xaa, 0xab, 0xac, 0xae, 0xaf, 0xb0,
	0xb1, 0xb2, 0xb3, 0xb4, 0xb8, 0xb9, 0xba, 0xbb, 0xbc, 0xbd,
	0xbe, 0xbf, 0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc8, 0xc9,
	0xca, 0xcb, 0xcc, 0xcd, 0xce, 0xcf, 0xd9, 0xda, 0xdb, 0xdc,
	0xdd, 0xdf, 0xee, 0xef, 0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5,
	0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff,
]
const CP437_LITERALS := {
	0x80: "Ç", 0x81: "ü", 0x82: "é", 0x83: "â", 0x84: "ä", 0x85: "à",
	0x86: "å", 0x87: "ç", 0x88: "ê", 0x89: "ë", 0x8a: "è", 0x8b: "ï",
	0x8c: "î", 0x8d: "ì", 0x8e: "Ä", 0x8f: "Å", 0x90: "É", 0x91: "æ",
	0x92: "Æ", 0x93: "ô", 0x94: "ö", 0x95: "ò", 0x96: "û", 0x97: "ù",
	0x98: "ÿ", 0x99: "Ö", 0x9a: "Ü", 0x9b: "¢", 0x9c: "£", 0x9d: "¥",
	0xa0: "á", 0xa1: "í", 0xa2: "ó", 0xa3: "ú", 0xa4: "ñ", 0xa5: "Ñ",
	0xa6: "ª", 0xa7: "º", 0xa8: "¿", 0xad: "¡",
}

var source: DataUsaResource
var random: SimRandom
var story_type := 0
var argument := 0
var auxiliary := PackedByteArray([0xff, 0xff, 0xff])
var city_name := ""
var mayor_name := ""
var team_names := PackedStringArray()
var shared_choices := PackedInt32Array()
var output := PackedByteArray()
var error := ""


static func published_seed(
	session_seed: int, city_days: int, paper_index: int, story_slot: int
) -> int:
	if paper_index < 0 or paper_index >= 6:
		return -1

	if story_slot < 0 or story_slot >= PUBLISHED_SEED_OFFSETS.size():
		return -1

	var story_offset := int(PUBLISHED_SEED_OFFSETS[story_slot])

	if story_offset < 0:
		return -1

	return session_seed + int(city_days / 25) + paper_index * 500 + story_offset


static func token_phrase_id(value: int) -> int:
	var token := value & 0xff

	if token >= 1 and token <= 31:
		return token

	var index := EXTENDED_TOKEN_BYTES.find(token)

	return index + 32 if index >= 0 else 0


static func render_story(
	data: DataUsaResource,
	record: Dictionary,
	seed: int,
	city_text: String,
	mayor_text: String,
	teams: PackedStringArray
) -> Dictionary:
	var renderer := NewspaperText.new()
	var setup := renderer._setup(data, record, city_text, mayor_text, teams)

	if not setup.ok:
		return setup

	renderer.shared_choices.resize(DataUsaResource.TABLE_ENTRY_COUNT)
	renderer.shared_choices.fill(-1)
	renderer.random = Random.new(seed)
	var headline_bytes := renderer._render_selected(0)

	if not renderer.error.is_empty():
		return renderer._failure(renderer.error)

	var headline := renderer._title_case(renderer._decode_oem(headline_bytes, true))

	renderer.random = Random.new(seed)
	var article_bytes := renderer._render_selected(1)

	if not renderer.error.is_empty():
		return renderer._failure(renderer.error)

	renderer._capitalize_article(article_bytes)
	var article := renderer._decode_oem(article_bytes, false)

	return {
		"ok": true,
		"error": "",
		"headline": headline,
		"article": article,
		"argument": renderer.argument,
		"auxiliary": renderer.auxiliary.duplicate(),
		"random_state": renderer.random.state,
	}


static func render_headline(
	data: DataUsaResource,
	record: Dictionary,
	seed: int,
	city_text: String,
	mayor_text: String,
	teams: PackedStringArray
) -> Dictionary:
	var renderer := NewspaperText.new()
	var setup := renderer._setup(data, record, city_text, mayor_text, teams)

	if not setup.ok:
		return setup

	renderer.shared_choices.resize(DataUsaResource.TABLE_ENTRY_COUNT)
	renderer.shared_choices.fill(-1)
	renderer.random = Random.new(seed)
	var headline_bytes := renderer._render_selected(0)

	if not renderer.error.is_empty():
		return renderer._failure(renderer.error)

	return {
		"ok": true,
		"error": "",
		"headline": renderer._title_case(renderer._decode_oem(headline_bytes, true)),
		"argument": renderer.argument,
		"auxiliary": renderer.auxiliary.duplicate(),
		"random_state": renderer.random.state,
	}


func _setup(
	data: DataUsaResource,
	record: Dictionary,
	city_text: String,
	mayor_text: String,
	teams: PackedStringArray
) -> Dictionary:
	if data == null or not data.is_valid():
		return _failure("newspaper grammar data is invalid")

	if not record.has("type") or not record.has("argument") or not record.has("auxiliary"):
		return _failure("newspaper story record is incomplete")

	var saved_story_type := int(record.type)

	if (
		saved_story_type < 0
		or saved_story_type >= data.bases.size()
		or data.counts[saved_story_type] <= 0
	):
		return _failure("newspaper story type is outside the grammar tables")

	var saved_auxiliary: PackedByteArray = record.auxiliary

	if saved_auxiliary.size() != 3:
		return _failure("newspaper story auxiliary data has the wrong size")

	source = data
	story_type = saved_story_type
	argument = int(record.argument) & 0xff
	auxiliary = saved_auxiliary.duplicate()
	city_name = city_text
	mayor_name = mayor_text
	team_names = teams.duplicate()

	return {"ok": true, "error": ""}


func _render_selected(mode: int) -> PackedByteArray:
	output = PackedByteArray()
	var count := int(source.counts[story_type])
	var phrase_id := int(source.bases[story_type]) + random.next_u15() % count
	_expand_phrase(phrase_id, mode, 0)

	return output


func _expand_phrase(phrase_id: int, mode: int, depth: int) -> void:
	if not error.is_empty():
		return

	if depth > MAX_RECURSION_DEPTH:
		error = "newspaper grammar recursion is too deep"

		return

	if phrase_id < 0 or phrase_id >= source.offsets.size():
		error = "newspaper grammar phrase is out of range"

		return

	var phrase := source.phrase_bytes(phrase_id)
	var cursor := 0
	var active_mode := mode

	if active_mode == 1:
		while cursor < phrase.size() and phrase[cursor] != 0x2b:
			cursor += 1

		if cursor == phrase.size():
			return

		cursor += 1
		active_mode = 2

	while cursor < phrase.size() and error.is_empty():
		var token := int(phrase[cursor])

		if active_mode == 0 and token == 0x2b:
			return

		match token:
			0x24:
				_append_number(argument)
			0x25:
				cursor = _next_argument(phrase, cursor)

				if cursor >= 0:
					var limit := int(phrase[cursor])
					_append_number(random.next_u15() % (limit - 1) + 2 if limit > 1 else 0)
			0x26:
				cursor = _next_argument(phrase, cursor)

				if cursor >= 0:
					var table_id := int(phrase[cursor])
					var count := _table_count(table_id)

					if count > 0:
						if argument >= count:
							argument = 0

						_expand_phrase(int(source.bases[table_id]) + argument, active_mode, depth + 1)
			0x2a:
				cursor = _next_argument(phrase, cursor)

				if cursor >= 0:
					_expand_random_table(int(phrase[cursor]), active_mode, depth)
			0x2d:
				_append_bytes(PackedByteArray([0x0a, 0x20, 0x20, 0x20, 0x20, 0x20]))
			0x3c:
				cursor = _next_argument(phrase, cursor)

				if cursor >= 0:
					var limit := int(phrase[cursor])
					var generated := random.next_u15() % (limit - 1) + 2 if limit > 1 else 0

					if auxiliary[2] == 0xff:
						auxiliary[2] = generated

					_append_number(auxiliary[2])
			0x3d:
				_append_text(city_name)
			0x3e:
				_append_text(team_names[argument] if argument < team_names.size() else "")
			0x40:
				cursor = _next_argument(phrase, cursor)

				if cursor >= 0:
					_expand_saved_table(int(phrase[cursor]), 1, active_mode, depth)
			0x5b:
				cursor = _next_argument(phrase, cursor)

				if cursor >= 0:
					_expand_shared_table(int(phrase[cursor]), active_mode, depth)
			0x5c:
				cursor = _next_argument(phrase, cursor)

				if cursor >= 0:
					_append_byte(phrase[cursor])
			0x5e:
				cursor = _next_argument(phrase, cursor)

				if cursor >= 0:
					_expand_saved_table(int(phrase[cursor]), 0, active_mode, depth)
			0x7e:
				_append_text(mayor_name)
			_:
				var token_phrase := token_phrase_id(token)

				if token_phrase == 0:
					_append_byte(token)
				else:
					_expand_phrase(token_phrase, active_mode, depth + 1)

		cursor += 1


func _expand_random_table(table_id: int, mode: int, depth: int) -> void:
	var count := _table_count(table_id)

	if count <= 0:
		return

	var choice := random.next_u15() % count
	_expand_phrase(int(source.bases[table_id]) + choice, mode, depth + 1)


func _expand_saved_table(table_id: int, auxiliary_index: int, mode: int, depth: int) -> void:
	var count := _table_count(table_id)

	if count <= 0:
		return

	var generated := random.next_u15() % count

	if auxiliary[auxiliary_index] >= count:
		auxiliary[auxiliary_index] = generated

	_expand_phrase(
		int(source.bases[table_id]) + auxiliary[auxiliary_index], mode, depth + 1
	)


func _expand_shared_table(table_id: int, mode: int, depth: int) -> void:
	var count := _table_count(table_id)

	if count <= 0:
		return

	var generated := random.next_u15() % count

	if shared_choices[table_id] < 0:
		shared_choices[table_id] = generated

	_expand_phrase(int(source.bases[table_id]) + shared_choices[table_id], mode, depth + 1)


func _table_count(table_id: int) -> int:
	if table_id < 0 or table_id >= source.counts.size():
		error = "newspaper grammar table is out of range"

		return 0

	var count := int(source.counts[table_id])

	if count <= 0:
		error = "newspaper grammar table is empty"

	return count


func _next_argument(phrase: PackedByteArray, cursor: int) -> int:
	if cursor + 1 >= phrase.size():
		error = "newspaper grammar opcode has no argument"

		return -1

	return cursor + 1


func _append_number(value: int) -> void:
	_append_text(str(value & 0xff))


func _append_text(value: String) -> void:
	_append_bytes(value.to_ascii_buffer())


func _append_bytes(values: PackedByteArray) -> void:
	for value in values:
		_append_byte(value)


func _append_byte(value: int) -> void:
	if output.size() >= MAX_OUTPUT_BYTES:
		error = "newspaper grammar output is too long"

		return

	output.append(value & 0xff)


func _decode_oem(values: PackedByteArray, headline: bool) -> String:
	var result := ""

	for value in values:
		var byte := int(value)

		if headline and byte == 0xd5:
			result += "'"
		elif not headline and (byte == 0xd4 or byte == 0xd5):
			result += "'"
		elif not headline and (byte == 0xd2 or byte == 0xd3):
			result += "\""
		elif byte < 0x80:
			result += String.chr(byte)
		else:
			result += str(CP437_LITERALS.get(byte, "�"))

	return result


func _title_case(value: String) -> String:
	var result := ""
	var in_word := false

	for index in value.length():
		var character := value.substr(index, 1)

		if character == "'":
			if index > 0 and value.substr(index - 1, 1) == "L":
				in_word = false
		elif not in_word and _is_lower(character):
			character = character.to_upper()
			in_word = true
		else:
			in_word = _is_alphanumeric(character)

		result += character

	return result


func _capitalize_article(values: PackedByteArray) -> void:
	var delimiter_count := 0

	for index in values.size():
		var value := int(values[index])

		if delimiter_count >= 2 and value >= 0x61 and value <= 0x7a:
			values[index] = value - 0x20
			delimiter_count = 0
		elif value in [0x20, 0x2e, 0x21, 0x3f, 0xd2, 0x22]:
			delimiter_count += 1
		else:
			delimiter_count = -1 if value == 0x2c else 0


static func _is_lower(value: String) -> bool:
	return value.to_lower() == value and value.to_upper() != value


static func _is_alphanumeric(value: String) -> bool:
	if value.length() != 1:
		return false

	var code := value.unicode_at(0)

	return (
		(code >= 0x30 and code <= 0x39)
		or (code >= 0x41 and code <= 0x5a)
		or (code >= 0x61 and code <= 0x7a)
		or value.to_lower() != value.to_upper()
	)


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
