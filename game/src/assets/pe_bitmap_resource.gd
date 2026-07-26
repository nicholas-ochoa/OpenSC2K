class_name PeBitmapResource
extends RefCounted

@warning_ignore_start("integer_division")

const PE_SIGNATURE := 0x00004550
const PE32_MAGIC := 0x010b
const RESOURCE_DIRECTORY_INDEX := 2
const RESOURCE_TYPE_BITMAP := 2


static func list_numeric_bitmap_ids(path: String) -> Dictionary:
	var directory := _load_resource_directory(path)

	if not directory.ok:
		return directory

	var bytes: PackedByteArray = directory.bytes
	var root_offset: int = directory.root_offset
	var type_directory := _numeric_child_directory(
		bytes, root_offset, root_offset, RESOURCE_TYPE_BITMAP
	)

	if type_directory < 0:
		return _failure("PE file does not contain bitmap resources")

	if not _has_range(bytes, type_directory, 16):
		return _failure("PE bitmap resource directory is truncated")

	var entry_count := (
		_read_u16(bytes, type_directory + 12)
		+ _read_u16(bytes, type_directory + 14)
	)
	var entry_offset := type_directory + 16

	if not _has_range(bytes, entry_offset, entry_count * 8):
		return _failure("PE bitmap resource entries are truncated")

	var ids := PackedInt32Array()

	for index in entry_count:
		var name := _read_u32(bytes, entry_offset + index * 8)
		var target := _read_u32(bytes, entry_offset + index * 8 + 4)

		if name & 0x80000000 or not target & 0x80000000:
			continue

		ids.append(name & 0xffff)

	ids.sort()

	return {"ok": true, "ids": ids, "error": ""}


static func load_numeric(path: String, resource_id: int) -> Dictionary:
	return _image_from_dib(load_numeric_dib(path, resource_id), resource_id)


static func load_named(path: String, resource_name: String) -> Dictionary:
	return _image_from_dib(load_named_dib(path, resource_name), resource_name)


static func _image_from_dib(loaded_dib: Dictionary, resource_id: Variant) -> Dictionary:
	if not loaded_dib.ok:
		return loaded_dib

	var dib: PackedByteArray = loaded_dib.bytes

	if loaded_dib.compression == 1:
		var decoded := _decode_indexed8_dib(loaded_dib, resource_id)

		if not decoded.ok:
			return decoded

		# Godot cannot read RLE-compressed BMPs. Expand the index rows and keep the DIB palette.
		var color_count: int = loaded_dib.color_count if loaded_dib.color_count > 0 else 256
		var pixel_offset := _read_u32(dib, 0) + color_count * 4
		var row_stride := (int(decoded.width) + 3) & ~3
		dib = dib.slice(0, pixel_offset)
		_write_u32(dib, 16, 0)
		_write_u32(dib, 20, row_stride * int(decoded.height))
		dib.resize(pixel_offset + row_stride * int(decoded.height))

		for y in int(decoded.height):
			for x in int(decoded.width):
				dib[pixel_offset + (int(decoded.height) - 1 - y) * row_stride + x] = decoded.pixels[y * int(decoded.width) + x]

	var wrapped := _wrap_dib(dib)

	if not wrapped.ok:
		return wrapped

	var image := Image.new()
	var load_error := image.load_bmp_from_buffer(wrapped.bytes)

	if load_error != OK:
		return _failure(
			"cannot decode PE bitmap resource %s: %s"
			% [resource_id, error_string(load_error)]
		)

	return {"ok": true, "image": image, "error": ""}


static func load_numeric_dib(path: String, resource_id: int) -> Dictionary:
	if resource_id < 0 or resource_id > 0xffff:
		return _failure("bitmap resource ID is outside the valid range")

	var directory := _load_resource_directory(path)

	if not directory.ok:
		return directory

	return _load_dib_from_directory(directory, resource_id)


static func load_named_dib(path: String, resource_name: String) -> Dictionary:
	if resource_name.is_empty():
		return _failure("bitmap resource name is empty")

	var directory := _load_resource_directory(path)

	if not directory.ok:
		return directory

	return _load_dib_from_directory(directory, resource_name)


static func _load_dib_from_directory(
	directory: Dictionary, resource_id: Variant
) -> Dictionary:
	var bytes: PackedByteArray = directory.bytes
	var root_offset: int = directory.root_offset
	var section_offset: int = directory.section_offset
	var section_count: int = directory.section_count
	var type_directory := _numeric_child_directory(
		bytes, root_offset, root_offset, RESOURCE_TYPE_BITMAP
	)

	if type_directory < 0:
		return _failure("PE file does not contain bitmap resources")

	var language_directory := _named_child_directory(bytes, root_offset, type_directory, resource_id) if resource_id is String else _numeric_child_directory(bytes, root_offset, type_directory, resource_id)

	if language_directory < 0:
		return _failure("PE bitmap resource %s is missing" % resource_id)

	var data_entry := _first_child_data(bytes, root_offset, language_directory)

	if data_entry < 0 or not _has_range(bytes, data_entry, 16):
		return _failure("PE bitmap resource %s has no language data" % resource_id)

	var data_rva := _read_u32(bytes, data_entry)
	var data_size := _read_u32(bytes, data_entry + 4)
	var data_offset := _rva_to_offset(bytes, data_rva, section_offset, section_count)

	if data_offset < 0 or not _has_range(bytes, data_offset, data_size):
		return _failure("PE bitmap resource %s data is truncated" % resource_id)

	var dib := bytes.slice(data_offset, data_offset + data_size)

	if dib.size() < 40:
		return _failure("PE bitmap resource %s has a short DIB header" % resource_id)

	return {
		"ok": true,
		"bytes": dib,
		"width": _read_u32(dib, 4),
		"height": _read_u32(dib, 8),
		"bits_per_pixel": _read_u16(dib, 14),
		"compression": _read_u32(dib, 16),
		"color_count": _read_u32(dib, 32),
		"error": "",
	}


static func load_numeric_indexed8(path: String, resource_id: int) -> Dictionary:
	var loaded := load_numeric_dib(path, resource_id)

	return _decode_indexed8_dib(loaded, resource_id)


static func load_numeric_indexed8_many(
	path: String, resource_ids: Array
) -> Dictionary:
	var directory := _load_resource_directory(path)

	if not directory.ok:
		return directory

	var entries: Array[Dictionary] = []

	for resource_id_value in resource_ids:
		var resource_id := int(resource_id_value)

		if resource_id < 0 or resource_id > 0xffff:
			return _failure("bitmap resource ID is outside the valid range")

		var loaded := _load_dib_from_directory(directory, resource_id)
		var decoded := _decode_indexed8_dib(loaded, resource_id)

		if not decoded.ok:
			return decoded

		entries.append(decoded)

	return {"ok": true, "entries": entries, "error": ""}


static func _decode_indexed8_dib(loaded: Dictionary, resource_id: Variant) -> Dictionary:
	if not loaded.ok:
		return loaded

	if loaded.bits_per_pixel != 8 or loaded.compression not in [0, 1]:
		return _failure(
			"PE bitmap resource %s is not an uncompressed or RLE8 indexed image" % resource_id
		)

	var dib: PackedByteArray = loaded.bytes
	var header_size := _read_u32(dib, 0)
	var width: int = loaded.width
	var stored_height: int = loaded.height
	var top_down := bool(stored_height & 0x80000000)
	var height := (
		int((~stored_height + 1) & 0xffffffff) if top_down else stored_height
	)

	if width <= 0 or height <= 0 or width > 4096 or height > 4096:
		return _failure("PE bitmap resource %s has invalid dimensions" % resource_id)

	var color_count: int = loaded.color_count if loaded.color_count > 0 else 256
	var pixel_offset := header_size + color_count * 4

	if header_size < 40 or color_count < 1 or color_count > 256 or not _has_range(dib, 0, pixel_offset) or _read_u16(dib, 12) != 1:
		return _failure("PE bitmap resource %s has an invalid header or palette" % resource_id)

	if loaded.compression == 1:
		if top_down:
			return _failure("RLE8 bitmap height must be positive")

		var data_size := _read_u32(dib, 20)

		if data_size <= 0 or not _has_range(dib, pixel_offset, data_size):
			return _failure("RLE8 bitmap data size is invalid")

		var decoded := WindowsBitmapRle8.decode(dib.slice(pixel_offset, pixel_offset + data_size), width, height)

		if decoded.ok:
			for index in decoded.pixels:
				if index >= color_count:
					return _failure("RLE8 pixel index exceeds its palette")

			decoded.width = width
			decoded.height = height

		return decoded

	var row_stride := int((width + 3) / 4) * 4

	if not _has_range(dib, pixel_offset, row_stride * height):
		return _failure("PE bitmap resource %s pixel data is truncated" % resource_id)

	var pixels := PackedInt32Array()
	pixels.resize(width * height)

	for y in height:
		var source_y := y if top_down else height - 1 - y

		for x in width:
			pixels[y * width + x] = dib[pixel_offset + source_y * row_stride + x]

	return {
		"ok": true,
		"width": width,
		"height": height,
		"pixels": pixels,
		"error": "",
	}


static func _load_resource_directory(path: String) -> Dictionary:
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

	return {
		"ok": true,
		"bytes": bytes,
		"root_offset": root_offset,
		"section_offset": section_offset,
		"section_count": section_count,
		"error": "",
	}


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


static func _named_child_directory(
	bytes: PackedByteArray, root_offset: int, directory_offset: int, wanted_name: String
) -> int:
	if not _has_range(bytes, directory_offset, 16):
		return -1

	var entry_count := _read_u16(bytes, directory_offset + 12) + _read_u16(bytes, directory_offset + 14)
	var entry_offset := directory_offset + 16

	if not _has_range(bytes, entry_offset, entry_count * 8):
		return -1

	var wanted := wanted_name.to_utf16_buffer()

	for index in entry_count:
		var name := _read_u32(bytes, entry_offset + index * 8)

		if not name & 0x80000000:
			continue

		var name_offset := root_offset + int(name & 0x7fffffff)

		if not _has_range(bytes, name_offset, 2):
			return -1

		var byte_count := _read_u16(bytes, name_offset) * 2

		if not _has_range(bytes, name_offset + 2, byte_count):
			return -1

		if bytes.slice(name_offset + 2, name_offset + 2 + byte_count) != wanted:
			continue

		var target := _read_u32(bytes, entry_offset + index * 8 + 4)

		if not target & 0x80000000:
			return -1

		var result := root_offset + int(target & 0x7fffffff)

		return result if _has_range(bytes, result, 16) else -1

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
