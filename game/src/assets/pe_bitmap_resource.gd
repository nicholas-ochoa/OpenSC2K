class_name PeBitmapResource
extends RefCounted

const PE_SIGNATURE := 0x00004550
const PE32_MAGIC := 0x010b
const RESOURCE_DIRECTORY_INDEX := 2
const RESOURCE_TYPE_BITMAP := 2


static func load_numeric(path: String, resource_id: int) -> Dictionary:
	if resource_id < 0 or resource_id > 0xffff:
		return _failure("bitmap resource ID is outside the valid range")
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
	var root_offset := _rva_to_offset(
		bytes, resource_rva, section_offset, section_count
	)
	if root_offset < 0:
		return _failure("PE resource directory is outside its sections")
	var type_directory := _numeric_child_directory(
		bytes, root_offset, root_offset, RESOURCE_TYPE_BITMAP
	)
	if type_directory < 0:
		return _failure("PE file does not contain bitmap resources")
	var language_directory := _numeric_child_directory(
		bytes, root_offset, type_directory, resource_id
	)
	if language_directory < 0:
		return _failure("PE bitmap resource %d is missing" % resource_id)
	var data_entry := _first_child_data(bytes, root_offset, language_directory)
	if data_entry < 0 or not _has_range(bytes, data_entry, 16):
		return _failure("PE bitmap resource %d has no language data" % resource_id)

	var data_rva := _read_u32(bytes, data_entry)
	var data_size := _read_u32(bytes, data_entry + 4)
	var data_offset := _rva_to_offset(bytes, data_rva, section_offset, section_count)
	if data_offset < 0 or not _has_range(bytes, data_offset, data_size):
		return _failure("PE bitmap resource %d data is truncated" % resource_id)
	var dib := bytes.slice(data_offset, data_offset + data_size)
	var wrapped := _wrap_dib(dib)
	if not wrapped.ok:
		return wrapped
	var image := Image.new()
	var load_error := image.load_bmp_from_buffer(wrapped.bytes)
	if load_error != OK:
		return _failure(
			"cannot decode PE bitmap resource %d: %s"
			% [resource_id, error_string(load_error)]
		)
	return {"ok": true, "image": image, "error": ""}


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


static func _wrap_dib(dib: PackedByteArray) -> Dictionary:
	if dib.size() < 40:
		return _failure("PE bitmap has an unsupported DIB header")
	var header_size := _read_u32(dib, 0)
	if header_size < 40 or header_size > dib.size():
		return _failure("PE bitmap DIB header is invalid")
	var bits_per_pixel := _read_u16(dib, 14)
	var compression := _read_u32(dib, 16)
	var color_count := _read_u32(dib, 32)
	if color_count == 0 and bits_per_pixel <= 8:
		color_count = 1 << bits_per_pixel
	var mask_size := 12 if compression == 3 and header_size == 40 else 0
	var pixel_offset := 14 + header_size + color_count * 4 + mask_size
	if pixel_offset > dib.size() + 14:
		return _failure("PE bitmap palette is truncated")
	var result := PackedByteArray()
	result.resize(14)
	_write_u16(result, 0, 0x4d42)
	_write_u32(result, 2, dib.size() + 14)
	_write_u32(result, 6, 0)
	_write_u32(result, 10, pixel_offset)
	result.append_array(dib)
	return {"ok": true, "bytes": result, "error": ""}


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


static func _write_u16(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = value & 0xff
	bytes[offset + 1] = (value >> 8) & 0xff


static func _write_u32(bytes: PackedByteArray, offset: int, value: int) -> void:
	for index in 4:
		bytes[offset + index] = (value >> (index * 8)) & 0xff


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
