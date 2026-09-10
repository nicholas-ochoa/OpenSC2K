class_name Sc2ImportContainer
extends RefCounted
## Bounded readers for original asset containers. Never execute source programs.

@warning_ignore_start("integer_division")

var resources: Array[Sc2ImportResource] = []
var error := ""


static func has_range(data: PackedByteArray, offset: int, length: int) -> bool:
	return offset >= 0 and length >= 0 and offset <= data.size() and length <= data.size() - offset


static func be16(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])


static func be32(data: PackedByteArray, offset: int) -> int:
	return (be16(data, offset) << 16) | be16(data, offset + 2)


static func named_archive(data: PackedByteArray, origin: String) -> Sc2ImportContainer:
	var result := Sc2ImportContainer.new()

	if data.size() < 16:
		return result._fail("The asset directory is truncated.")

	var first := int(data.decode_u32(12))

	if first < 16 or first % 16 != 0 or first > data.size() or first / 16 > 65536:
		return result._fail("The asset directory has an invalid data offset.")

	for index in first / 16:
		var entry := index * 16
		var raw_name := data.slice(entry, entry + 12)
		var zero := raw_name.find(0)

		if zero >= 0:
			raw_name = raw_name.slice(0, zero)

		var name := raw_name.get_string_from_ascii().strip_edges()
		var start := int(data.decode_u32(entry + 12))
		var end := data.size()

		if entry + 16 < first:
			end = int(data.decode_u32(entry + 28))

		if name.is_empty() or start < first or end < start or not has_range(data, start, end - start):
			return result._fail("Invalid asset directory entry %d." % index)

		result.resources.append(Sc2ImportResource.make(name, data.slice(start, end), origin))

	return result


static func macintosh(data: PackedByteArray, origin: String) -> Sc2ImportContainer:
	var result := Sc2ImportContainer.new()
	var fork := data

	# AppleDouble and AppleSingle both identify the resource fork with entry 2.
	if has_range(data, 0, 26) and be32(data, 0) in [0x00051607, 0x00051600]:
		var count := be16(data, 24)

		if not has_range(data, 26, count * 12):
			return result._fail("The AppleDouble entry table is truncated.")

		fork = PackedByteArray()

		for index in count:
			var entry := 26 + index * 12

			if be32(data, entry) != 2:
				continue

			var offset := be32(data, entry + 4)
			var length := be32(data, entry + 8)

			if not has_range(data, offset, length):
				return result._fail("The Macintosh resource fork is truncated.")

			fork = data.slice(offset, offset + length)
			break

	# MacBinary stores a padded data fork before its resource fork.
	elif has_range(data, 0, 128) and data[0] == 0 and data[1] >= 1 and data[1] <= 63 and data[74] == 0 and data[82] == 0:
		var offset := 128 + ((be32(data, 83) + 127) / 128) * 128
		var length := be32(data, 87)

		if length > 0 and has_range(data, offset, length):
			fork = data.slice(offset, offset + length)

	if not has_range(fork, 0, 16):
		return result._fail("No readable Macintosh resource fork was found.")

	var data_start := be32(fork, 0)
	var map_start := be32(fork, 4)
	var data_length := be32(fork, 8)
	var map_length := be32(fork, 12)

	if not has_range(fork, data_start, data_length) or map_length < 28 or not has_range(fork, map_start, map_length):
		return result._fail("Invalid Macintosh resource map.")

	var map_end := map_start + map_length
	var type_start := map_start + be16(fork, map_start + 24)

	if type_start < map_start or type_start + 2 > map_end:
		return result._fail("Invalid Macintosh type table.")

	var types := be16(fork, type_start) + 1

	if types > 4096 or type_start + 2 + types * 8 > map_end:
		return result._fail("The Macintosh type table is truncated.")

	for index in types:
		var entry := type_start + 2 + index * 8
		var type := fork.slice(entry, entry + 4).get_string_from_ascii()
		var count := be16(fork, entry + 4) + 1
		var refs := type_start + be16(fork, entry + 6)

		if refs < type_start or refs + count * 12 > map_end:
			return result._fail("The Macintosh reference list is truncated.")

		for resource_index in count:
			var ref := refs + resource_index * 12
			var id := be16(fork, ref)

			if id >= 32768:
				id -= 65536

			var relative := be32(fork, ref + 4) & 0xffffff

			if relative + 4 > data_length:
				return result._fail("Invalid Macintosh resource offset.")

			var start := data_start + relative
			var length := be32(fork, start)

			if relative + 4 + length > data_length:
				return result._fail("The Macintosh resource data is truncated.")

			result.resources.append(Sc2ImportResource.make("%s/%d" % [type, id], fork.slice(start + 4, start + 4 + length), origin, type, id))

	return result


static func windows(data: PackedByteArray, origin: String) -> Sc2ImportContainer:
	var result := Sc2ImportContainer.new()

	if not has_range(data, 0, 64) or data.slice(0, 2).get_string_from_ascii() != "MZ":
		return result._fail("No Windows executable header was found.")

	var header := int(data.decode_u32(60))

	if not has_range(data, header, 64):
		return result._fail("The Windows executable header is truncated.")

	if data.slice(header, header + 2).get_string_from_ascii() == "NE":
		return result._read_ne(data, header, origin)

	if data.decode_u32(header) != 0x4550 or data.decode_u16(header + 24) != 0x10b:
		return result._fail("No supported Windows resource table was found.")

	var section_count := int(data.decode_u16(header + 6))
	var optional_size := int(data.decode_u16(header + 20))
	var sections := header + 24 + optional_size

	if optional_size < 120 or not has_range(data, header + 24, optional_size) or not has_range(data, sections, section_count * 40):
		return result._fail("The PE section table is truncated.")

	var rva := int(data.decode_u32(header + 24 + 112))
	var root := _pe_offset(data, sections, section_count, rva)

	if rva == 0 or root < 0:
		return result._fail("The executable contains no resource directory.")

	result._pe_directory(data, root, root, sections, section_count, origin, [], 0)

	return result


func _read_ne(data: PackedByteArray, header: int, origin: String) -> Sc2ImportContainer:
	var table := header + int(data.decode_u16(header + 36))
	var end := header + int(data.decode_u16(header + 38))

	if not has_range(data, table, 2) or end < table + 2 or end > data.size():
		return _fail("The NE resource table is truncated.")

	var shift := int(data.decode_u16(table))

	if shift > 20:
		return _fail("Invalid NE resource alignment.")

	var cursor := table + 2

	while cursor + 2 <= end:
		var type_id := int(data.decode_u16(cursor))

		if type_id == 0:
			return self

		if cursor + 8 > end:
			return _fail("The NE type record is truncated.")

		var count := int(data.decode_u16(cursor + 2))
		var type := _ne_name(data, table, end, type_id)
		cursor += 8

		if cursor + count * 12 > end:
			return _fail("The NE resource list is truncated.")

		for index in count:
			var ref := cursor + index * 12
			var start := int(data.decode_u16(ref)) << shift
			var size := int(data.decode_u16(ref + 2)) << shift
			var id := int(data.decode_u16(ref + 6))
			var name := _ne_name(data, table, end, id)

			if not has_range(data, start, size):
				return _fail("The NE resource data is truncated.")

			resources.append(Sc2ImportResource.make(name, data.slice(start, start + size), origin, type, id & 0x7fff if id & 0x8000 else -1))

		cursor += count * 12

	return _fail("The NE resource table has no terminator.")


static func _ne_name(data: PackedByteArray, table: int, end: int, value: int) -> String:
	if value & 0x8000:
		return str(value & 0x7fff)

	var start := table + value

	if start < table or start >= end or start + 1 + data[start] > end:
		return ""

	return data.slice(start + 1, start + 1 + data[start]).get_string_from_ascii()


static func _pe_offset(data: PackedByteArray, sections: int, count: int, rva: int) -> int:
	for index in count:
		var entry := sections + index * 40
		var address := int(data.decode_u32(entry + 12))
		var length := int(data.decode_u32(entry + 16))
		var start := int(data.decode_u32(entry + 20))

		if rva >= address and rva - address < length and has_range(data, start, length):
			return start + rva - address

	return -1


func _pe_directory(data: PackedByteArray, root: int, directory: int, sections: int, section_count: int, origin: String, names: Array[String], depth: int) -> void:
	if not error.is_empty():
		return

	if depth > 2 or not has_range(data, directory, 16):
		_fail("Invalid PE resource directory.")
		return

	var count := int(data.decode_u16(directory + 12)) + int(data.decode_u16(directory + 14))

	if not has_range(data, directory + 16, count * 8):
		_fail("The PE resource table is truncated.")
		return

	for index in count:
		var entry := directory + 16 + index * 8
		var identifier := int(data.decode_u32(entry))
		var target := int(data.decode_u32(entry + 4))
		var name := str(identifier)

		if identifier & 0x80000000:
			var text_start := root + (identifier & 0x7fffffff)

			if not has_range(data, text_start, 2) or not has_range(data, text_start + 2, int(data.decode_u16(text_start)) * 2):
				_fail("The PE resource name is truncated.")
				return

			name = data.slice(text_start + 2, text_start + 2 + int(data.decode_u16(text_start)) * 2).get_string_from_utf16()

		var path: Array[String] = names.duplicate()
		path.append(name)

		if target & 0x80000000:
			_pe_directory(data, root, root + (target & 0x7fffffff), sections, section_count, origin, path, depth + 1)
			continue

		var record := root + target

		if path.size() != 3 or not has_range(data, record, 16):
			_fail("Invalid PE resource data record.")
			return

		var start := _pe_offset(data, sections, section_count, int(data.decode_u32(record)))
		var size := int(data.decode_u32(record + 4))

		if not has_range(data, start, size):
			_fail("The PE resource data is truncated.")
			return

		resources.append(Sc2ImportResource.make(path[1], data.slice(start, start + size), origin, path[0], int(path[1]) if path[1].is_valid_int() else -1))


func _fail(message: String) -> Sc2ImportContainer:
	error = message
	resources.clear()

	return self
