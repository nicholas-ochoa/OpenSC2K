class_name ThingData
extends RefCounted
# sclg keeps the 480 original bytes, followed by a 480-byte high plane
# only coordinate fields use that plane. scdh remains byte-exact

const BASE_SIZE := 480
const WIDE_FIELDS := [3, 4, 8, 9]

static func read(data: PackedByteArray, index: int) -> int:
	var value := int(data[index])
	if data.size() == BASE_SIZE * 2 and index % 12 in WIDE_FIELDS:
		value |= int(data[BASE_SIZE + index]) << 8
	return value

static func write(data: PackedByteArray, index: int, value: int) -> void:
	data[index] = value & 0xff
	if data.size() == BASE_SIZE * 2:
		data[BASE_SIZE + index] = (value >> 8) & 0xff if index % 12 in WIDE_FIELDS else 0
