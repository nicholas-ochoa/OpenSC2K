class_name JohabCodec
extends RefCounted
## Original Korean text uses Johab, whose trail bytes include ASCII characters.
## Newspaper grammar also has opcodes; plain TXT resources do not.

const Table = preload("res://src/assets/text/johab_table.gd")
const ARGUMENT_OPCODES := [0x25, 0x26, 0x2a, 0x3c, 0x40, 0x5b, 0x5c, 0x5e]
const MINIMUM_HANGUL_SYLLABLES := 16
const FIRST_HANGUL_SYLLABLE := 0xac00
const LAST_HANGUL_SYLLABLE := 0xd7a3
const INVALID_PAIR := 0xfffd


# The Unicode code point of the Johab pair at `at`, or 0 for an invalid pair.
static func code_point(bytes: PackedByteArray, at: int) -> int:
	if at < 0 or at + 1 >= bytes.size() or not Table.ROWS.has(int(bytes[at])):
		return 0

	var row: String = Table.ROWS[int(bytes[at])]
	var point := row.unicode_at(int(bytes[at + 1]))

	return point if point != INVALID_PAIR else 0


# Detect the whole text resource file, not only the requested short label.
# Every high byte must form a valid pair. An uncertain or malformed file
# keeps its existing single-byte decoding instead of discarding source bytes.
static func is_text(bytes: PackedByteArray, record_boundaries := PackedInt32Array()) -> bool:
	var cursor := 0
	var syllables := 0
	var ends := record_boundaries.duplicate()
	ends.append(bytes.size())

	for end in ends:
		if end < cursor or end > bytes.size():
			return false

		while cursor < end:
			if bytes[cursor] < 0x80:
				cursor += 1
				continue

			# Two malformed records cannot supply half a character each.
			if cursor + 1 >= end:
				return false

			var point := code_point(bytes, cursor)

			if point == 0:
				return false

			syllables += int(_is_syllable(point))
			cursor += 2

	return syllables >= MINIMUM_HANGUL_SYLLABLES


# The caller has already identified the file. Individual entries can be
# ASCII or shorter than the detection threshold. No byte is a grammar token.
static func decode_text(bytes: PackedByteArray) -> String:
	var text := ""
	var cursor := 0

	while cursor < bytes.size():
		var value := int(bytes[cursor])

		if value < 0x80:
			text += String.chr(value)
			cursor += 1
			continue

		var point := code_point(bytes, cursor)

		if point == 0:
			return bytes.get_string_from_ascii()

		text += String.chr(point)
		cursor += 2

	return text


# Whether newspaper grammar is Johab text. Opcode arguments can be pair trails.
static func is_grammar(grammar: PackedByteArray, offsets: PackedByteArray) -> bool:
	var visited: Dictionary[int, bool] = {}
	var syllables := 0
	var invalid := 0

	for at in range(0, offsets.size() - 3, 4):
		var cursor := BinaryData.read_u32_be(offsets, at)

		if visited.has(cursor):
			continue

		visited[cursor] = true

		while cursor < grammar.size() and grammar[cursor] != 0:
			var value := int(grammar[cursor])

			if value in ARGUMENT_OPCODES:
				cursor += 3 if value == 0x5c and code_point(grammar, cursor + 1) > 0 else 2
				continue

			if value >= 0x80:
				var point := code_point(grammar, cursor)

				if point > 0:
					syllables += int(_is_syllable(point))
					cursor += 2
					continue

				invalid += 1

			cursor += 1

	# Short accidental CP437/token pairs are not enough to select a language.
	# The supplied Korean grammar has over 80,000 complete Hangul pairs and
	# no unmatched high bytes outside explicit opcode arguments.
	return syllables >= MINIMUM_HANGUL_SYLLABLES and invalid == 0


static func _is_syllable(point: int) -> bool:
	return point >= FIRST_HANGUL_SYLLABLE and point <= LAST_HANGUL_SYLLABLE
