class_name Crc32
extends RefCounted
## CRC-32 used by PNG and ZIP records.

# Readers never modify this table.
static var _table: PackedInt64Array = _make_table()


static func calculate(bytes: PackedByteArray) -> int:
	var value := 0xffffffff
	for byte in bytes:
		value = (value >> 8) ^ _table[(value ^ byte) & 255]
	return value ^ 0xffffffff


static func _make_table() -> PackedInt64Array:
	var table := PackedInt64Array()
	table.resize(256)
	for byte in 256:
		var value := byte
		for _bit in 8:
			value = (value >> 1) ^ (0xedb88320 if value & 1 else 0)
		table[byte] = value
	return table
