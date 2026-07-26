class_name PeStringResource
extends RefCounted

@warning_ignore_start("integer_division")

const PE_SIGNATURE := 0x00004550
const PE32_MAGIC := 0x010b
const RESOURCE_DIRECTORY_INDEX := 2
const RESOURCE_TYPE_STRING := 6
const STRINGS_PER_BLOCK := 16


static func load_ids(path: String, resource_ids: PackedInt32Array) -> Dictionary:
	var wanted_ids := {}
	var wanted_blocks := {}

	for resource_id in resource_ids:
		if resource_id < 0 or resource_id > 0xffff:
			return _failure("string resource ID is outside the valid range")

		wanted_ids[resource_id] = true
		wanted_blocks[int(resource_id / STRINGS_PER_BLOCK) + 1] = true

	if wanted_ids.is_empty():
		return {"ok": true, "strings": {}, "error": ""}

	var bytes := FileAccess.get_file_as_bytes(path)

	if bytes.is_empty():
		return _failure("cannot read PE file: %s" % path)

	if bytes.size() < 0x40 or _read_u16(bytes, 0) != 0x5a4d:
		return _failure("file does not have an MZ header")

	var pe_offset := _read_u32(bytes, 0x3c)

	if not _has_range(bytes, pe_offset, 24) or _read_u32(bytes, pe_offset) != PE_SIGNATURE:
		return _failure("file does not have a valid PE header")

	var section_count := _read_u16(bytes, pe_offset + 6)
	var optional_size := _read_u16(bytes, pe_offset + 20)
	var optional_offset := pe_offset + 24

	if not _has_range(bytes, optional_offset, optional_size):
		return _failure("PE optional header is truncated")

	if _read_u16(bytes, optional_offset) != PE32_MAGIC:
		return _failure("only PE32 resources are supported")

	var data_directories := optional_offset + 96
	var resource_entry := data_directories + RESOURCE_DIRECTORY_INDEX * 8

	if not _has_range(bytes, resource_entry, 8):
		return _failure("PE resource directory entry is missing")

	var resource_rva := _read_u32(bytes, resource_entry)
	var resource_size := _read_u32(bytes, resource_entry + 4)

	if resource_rva == 0 or resource_size == 0:
		return _failure("PE file does not contain resources")

	var section_offset := optional_offset + optional_size
	var root_offset := _rva_to_offset(bytes, resource_rva, section_offset, section_count)

	if root_offset < 0:
		return _failure("PE resource directory is outside its sections")

	var type_directory := _numeric_child_directory(
		bytes, root_offset, root_offset, RESOURCE_TYPE_STRING
	)

	if type_directory < 0:
		return _failure("PE file does not contain string resources")

	var result := {}

	for block_key in wanted_blocks:
		var block_id := int(block_key)
		var language_directory := _numeric_child_directory(
			bytes, root_offset, type_directory, block_id
		)

		if language_directory < 0:
			return _failure("PE string block %d is missing" % block_id)

		var data_entry := _first_child_data(bytes, root_offset, language_directory)

		if data_entry < 0 or not _has_range(bytes, data_entry, 16):
			return _failure("PE string block %d has no language data" % block_id)

		var data_rva := _read_u32(bytes, data_entry)
		var data_size := _read_u32(bytes, data_entry + 4)
		var data_offset := _rva_to_offset(bytes, data_rva, section_offset, section_count)

		if data_offset < 0 or not _has_range(bytes, data_offset, data_size):
			return _failure("PE string block %d data is truncated" % block_id)

		var decoded := _decode_block(bytes, data_offset, data_size, block_id)

		if not decoded.ok:
			return decoded

		for slot in STRINGS_PER_BLOCK:
			var resource_id := (block_id - 1) * STRINGS_PER_BLOCK + slot

			if wanted_ids.has(resource_id):
				result[resource_id] = decoded.strings[slot]

	return {"ok": true, "strings": result, "error": ""}


static func _decode_block(
	bytes: PackedByteArray, offset: int, size: int, block_id: int
) -> Dictionary:
	var strings: Array[String] = []
	var cursor := offset
	var end := offset + size

	for _slot in STRINGS_PER_BLOCK:
		if cursor > end - 2:
			return _failure("PE string block %d is truncated" % block_id)

		var length := _read_u16(bytes, cursor)
		cursor += 2

		if length > int((end - cursor) / 2):
			return _failure("PE string block %d text is truncated" % block_id)

		var value := ""

		for character_index in length:
			value += String.chr(_read_u16(bytes, cursor + character_index * 2))

		strings.append(value)
		cursor += length * 2

	return {"ok": true, "strings": strings, "error": ""}


static func _numeric_child_directory(
	bytes: PackedByteArray, root_offset: int, directory_offset: int, wanted_id: int
) -> int:
	if not _has_range(bytes, directory_offset, 16):
		return -1

	var entry_count := (
		_read_u16(bytes, directory_offset + 12)
		+ _read_u16(bytes, directory_offset + 14)
	)
	var entry_offset := directory_offset + 16

	if not _has_range(bytes, entry_offset, entry_count * 8):
		return -1

	for index in entry_count:
		var name := _read_u32(bytes, entry_offset + index * 8)

		if name & 0x80000000 or (name & 0xffff) != wanted_id:
			continue

		var target := _read_u32(bytes, entry_offset + index * 8 + 4)

		if not target & 0x80000000:
			return -1

		return root_offset + int(target & 0x7fffffff)

	return -1


static func _first_child_data(
	bytes: PackedByteArray, root_offset: int, directory_offset: int
) -> int:
	if not _has_range(bytes, directory_offset, 24):
		return -1

	var entry_count := (
		_read_u16(bytes, directory_offset + 12)
		+ _read_u16(bytes, directory_offset + 14)
	)

	if entry_count < 1:
		return -1

	var target := _read_u32(bytes, directory_offset + 20)

	if target & 0x80000000:
		return -1

	return root_offset + int(target)


static func _rva_to_offset(
	bytes: PackedByteArray, rva: int, section_offset: int, section_count: int
) -> int:
	if section_count < 0 or not _has_range(bytes, section_offset, section_count * 40):
		return -1

	for index in section_count:
		var header := section_offset + index * 40
		var virtual_size := _read_u32(bytes, header + 8)
		var virtual_address := _read_u32(bytes, header + 12)
		var raw_size := _read_u32(bytes, header + 16)
		var raw_offset := _read_u32(bytes, header + 20)
		var mapped_size := maxi(virtual_size, raw_size)

		if rva >= virtual_address and rva < virtual_address + mapped_size:
			var result := raw_offset + rva - virtual_address

			return result if result >= 0 and result < bytes.size() else -1

	return -1


static func _has_range(bytes: PackedByteArray, offset: int, size: int) -> bool:
	return offset >= 0 and size >= 0 and offset <= bytes.size() - size


static func _read_u16(bytes: PackedByteArray, offset: int) -> int:
	if not _has_range(bytes, offset, 2):
		return 0

	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8)


static func _read_u32(bytes: PackedByteArray, offset: int) -> int:
	if not _has_range(bytes, offset, 4):
		return 0

	return (
		int(bytes[offset])
		| (int(bytes[offset + 1]) << 8)
		| (int(bytes[offset + 2]) << 16)
		| (int(bytes[offset + 3]) << 24)
	)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
