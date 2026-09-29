class_name Sc2LabelLayout
extends RefCounted
## XLAB stores a length byte, up to 23 text bytes, and a zero terminator.

@warning_ignore_start("integer_division")

const ORIGINAL_COUNT := 256
const LENGTH_OFFSET := 0
const TEXT_OFFSET := 1
const MAX_TEXT_BYTES := 23
const RECORD_SIZE := TEXT_OFFSET + MAX_TEXT_BYTES + 1
const ORIGINAL_SIZE := ORIGINAL_COUNT * RECORD_SIZE
# An SC2X version 4 working document uses wide records: a big-endian u16 byte
# length and up to 256 UTF-8 bytes. The wide table is runtime state only.
const WIDE_LENGTH_OFFSET := 0
const WIDE_TEXT_OFFSET := 2
const WIDE_MAX_TEXT_BYTES := 256
const WIDE_RECORD_SIZE := WIDE_TEXT_OFFSET + WIDE_MAX_TEXT_BYTES
const WIDE_MAX_CHARACTERS := 64


# A wide table is never whole 25-byte records; see Sc2xDocument
static func is_wide_table(labels: PackedByteArray) -> bool:
	return labels.size() % RECORD_SIZE != 0


static func record_size_of(labels: PackedByteArray) -> int:
	return WIDE_RECORD_SIZE if is_wide_table(labels) else RECORD_SIZE


static func record_count(labels: PackedByteArray) -> int:
	return labels.size() / record_size_of(labels)


# the text of one label, or an empty string outside the table
static func read(labels: PackedByteArray, label_id: int) -> String:
	var size := record_size_of(labels)
	var offset := label_id * size

	if label_id < 0 or offset + size > labels.size():
		return ""

	if size == WIDE_RECORD_SIZE:
		var length := mini(BinaryData.read_u16_be(labels, offset), WIDE_MAX_TEXT_BYTES)
		var start := offset + WIDE_TEXT_OFFSET

		return labels.slice(start, start + length).get_string_from_utf8()

	var declared_length: int = mini(labels[offset + LENGTH_OFFSET], MAX_TEXT_BYTES)
	var start := offset + TEXT_OFFSET
	var end := start

	while end < start + declared_length and labels[end] != 0:
		end += 1

	return labels.slice(start, end).get_string_from_ascii()


# Store `value`: 23 ASCII bytes in a legacy table, or 64 characters of UTF-8
# text in a wide table. Returns false outside the table. With `clear_record`
# false, a legacy write keeps the record bytes after its terminator, as the
# label editor of the original does.
static func write(labels: PackedByteArray, label_id: int, value: String, clear_record := true) -> bool:
	var size := record_size_of(labels)
	var offset := label_id * size

	if label_id < 0 or offset + size > labels.size():
		return false

	if clear_record or size == WIDE_RECORD_SIZE:
		for index in size:
			labels[offset + index] = 0

	if size == WIDE_RECORD_SIZE:
		var encoded := Sc2xMetadata.limit_name(value).to_utf8_buffer()
		BinaryData.write_u16_be(labels, offset + WIDE_LENGTH_OFFSET, encoded.size())

		for index in encoded.size():
			labels[offset + WIDE_TEXT_OFFSET + index] = encoded[index]

		return true

	var ascii := value.to_ascii_buffer()

	if ascii.size() > MAX_TEXT_BYTES:
		ascii = ascii.slice(0, MAX_TEXT_BYTES)

	labels[offset + LENGTH_OFFSET] = ascii.size()

	for index in ascii.size():
		labels[offset + TEXT_OFFSET + index] = ascii[index]

	labels[offset + TEXT_OFFSET + ascii.size()] = 0

	return true


# true when the record has no length, as the original checks before naming
static func is_empty_record(labels: PackedByteArray, label_id: int) -> bool:
	var size := record_size_of(labels)
	var offset := label_id * size

	if label_id < 0 or offset + size > labels.size():
		return true

	return labels[offset] == 0 and (size != WIDE_RECORD_SIZE or labels[offset + 1] == 0)


# clear the length, as the original does when a sign or facility goes away
static func clear(labels: PackedByteArray, label_id: int) -> void:
	var size := record_size_of(labels)
	var offset := label_id * size

	if label_id < 0 or offset + size > labels.size():
		return

	labels[offset] = 0

	if size == WIDE_RECORD_SIZE:
		labels[offset + 1] = 0
