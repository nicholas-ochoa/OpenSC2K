class_name PeIconCursorResource
extends RefCounted
# indexed windows icon/cursor dibs. keep and and xor data separate

@warning_ignore_start("integer_division")


static func load_image(path: String, resource_id: int, cursor := false) -> Dictionary:
	var resource := load_resource(path, 1 if cursor else 3, resource_id)

	return decode_image(resource.bytes, cursor) if resource.ok else resource


static func load_group(path: String, resource_id: int, cursor := false) -> Dictionary:
	var resource := load_resource(path, 12 if cursor else 14, resource_id)

	return decode_group(resource.bytes, cursor) if resource.ok else resource


static func load_resource(path: String, type_id: int, resource_id: int) -> Dictionary:
	if resource_id < 0 or resource_id > 65535 or type_id not in [1, 3, 12, 14]:
		return _failure("Invalid icon/cursor resource ID or type")

	var directory := PeBitmapResource._load_resource_directory(path)

	if not directory.ok:
		return directory

	return resource_from_directory(directory, type_id, resource_id)


static func resource_from_directory(directory: Dictionary, type_id: int, resource_id: int) -> Dictionary:
	if resource_id < 0 or resource_id > 65535 or type_id not in [1, 3, 12, 14]:
		return _failure("Invalid icon/cursor resource ID or type")

	var bytes: PackedByteArray = directory.bytes
	var root: int = directory.root_offset
	var type_directory := PeBitmapResource._numeric_child_directory(bytes, root, root, type_id)

	if type_directory < 0:
		return _failure("Icon/cursor resource type is missing")

	var language := PeBitmapResource._numeric_child_directory(bytes, root, type_directory, resource_id)

	if language < 0:
		return _failure("Icon/cursor resource is missing")

	var entry := PeBitmapResource._first_child_data(bytes, root, language)

	if entry < 0 or not PeBitmapResource._has_range(bytes, entry, 16):
		return _failure("Icon/cursor language data is truncated")

	var offset := PeBitmapResource._rva_to_offset(bytes, bytes.decode_u32(entry), directory.section_offset, directory.section_count)
	var length := bytes.decode_u32(entry + 4)

	if offset < 0 or not PeBitmapResource._has_range(bytes, offset, length):
		return _failure("Icon/cursor resource data is truncated")

	return {"ok": true, "bytes": bytes.slice(offset, offset + length), "error": ""}


static func decode_group(bytes: PackedByteArray, cursor := false) -> Dictionary:
	if bytes.size() < 6 or bytes.decode_u16(0) != 0 or bytes.decode_u16(2) != (2 if cursor else 1):
		return _failure("Invalid icon/cursor group header")

	var count := bytes.decode_u16(4)

	if count == 0 or bytes.size() != 6 + count * 14:
		return _failure("Invalid icon/cursor group length")

	var entries: Array[Dictionary] = []
	var ids := {}

	for i in count:
		var at := 6 + i * 14
		var width: int = bytes.decode_u16(at) if cursor else (256 if bytes[at] == 0 else bytes[at])
		var height: int = bytes.decode_u16(at + 2) if cursor else (256 if bytes[at + 1] == 0 else bytes[at + 1])
		var id := bytes.decode_u16(at + 12)
		var length := bytes.decode_u32(at + 8)

		if width <= 0 or width > 256 or height <= 0 or height > 512 or id == 0 or ids.has(id) or length == 0:
			return _failure("Invalid icon/cursor group entry")

		ids[id] = true
		entries.append({"id": id, "width": width, "height": height, "planes": bytes.decode_u16(at + 4), "bits": bytes.decode_u16(at + 6), "length": length})

	return {"ok": true, "entries": entries, "error": ""}


static func decode_image(bytes: PackedByteArray, cursor := false) -> Dictionary:
	var start := 4 if cursor else 0

	if bytes.size() < start + 40:
		return _failure("Icon/cursor DIB header is truncated")

	var hotspot := Vector2i(bytes.decode_u16(0), bytes.decode_u16(2)) if cursor else Vector2i.ZERO
	var header := bytes.decode_u32(start)
	var width := bytes.decode_s32(start + 4)
	var stored_height := bytes.decode_s32(start + 8)
	var bits := bytes.decode_u16(start + 14)

	if header != 40 or width < 1 or width > 256 or stored_height < 2 or stored_height > 512 or stored_height % 2 != 0:
		return _failure("Unsupported icon/cursor DIB dimensions or header")

	# dib height counts the pixels and the mask, halve it for the visible cursor
	var height := int(stored_height / 2)

	if hotspot.x >= width or hotspot.y >= height:
		return _failure("Cursor hotspot is outside its image")

	if bytes.decode_u16(start + 12) != 1 or bits not in [1, 4, 8] or bytes.decode_u32(start + 16) != 0:
		return _failure("Icon/cursor DIB must be uncompressed indexed data")

	var count := bytes.decode_u32(start + 32)

	if count == 0:
		count = 1 << bits

	if count < 1 or count > (1 << bits):
		return _failure("Invalid icon/cursor palette length")

	var pixels_start := start + header + count * 4
	var xor_stride := int((width * bits + 31) / 32) * 4
	var and_stride := int((width + 31) / 32) * 4
	var mask_start := pixels_start + xor_stride * height
	var end := mask_start + and_stride * height

	if bytes.size() < end:
		return _failure("Icon/cursor palette or mask data is truncated")

	var palette := PackedColorArray()

	for i in count:
		var at := start + header + i * 4
		palette.append(Color8(bytes[at + 2], bytes[at + 1], bytes[at]))

	var pixels := PackedInt32Array()
	var and_mask := PackedByteArray()
	var inverted := 0

	for y in height:
		var row := height - 1 - y

		for x in width:
			var bit_offset := x * bits
			var index := (bytes[pixels_start + row * xor_stride + int(bit_offset / 8)] >> (8 - bits - bit_offset % 8)) & ((1 << bits) - 1)

			if index >= count:
				return _failure("Icon/cursor index is outside its palette")

			var mask := (bytes[mask_start + row * and_stride + int(x / 8)] >> (7 - x % 8)) & 1
			pixels.append(index)
			and_mask.append(mask)

			if mask == 1 and palette[index] != Color.BLACK:
				inverted += 1

	return {"ok": true, "width": width, "height": height, "bits": bits, "hotspot": hotspot, "palette": palette, "pixels": pixels,
			"and_mask": and_mask, "inverting_pixels": inverted, "trailing_bytes": bytes.size() - end, "error": ""}


static func composite(decoded: Dictionary, background: Image) -> Image:
	assert(decoded.ok and background.get_size() == Vector2i(decoded.width, decoded.height))
	var image := Image.create(decoded.width, decoded.height, false, Image.FORMAT_RGBA8)

	for y in int(decoded.height):
		for x in int(decoded.width):
			var i := y * int(decoded.width) + x
			var xor_color: Color = decoded.palette[decoded.pixels[i]]
			var backdrop := background.get_pixel(x, y) if decoded.and_mask[i] else Color.BLACK
			image.set_pixel(x, y, Color8(backdrop.r8 ^ xor_color.r8, backdrop.g8 ^ xor_color.g8, backdrop.b8 ^ xor_color.b8))

	return image


static func transparent_image(decoded: Dictionary) -> Dictionary:
	if not decoded.ok:
		return decoded

	if decoded.inverting_pixels > 0:
		return _failure("This cursor requires background XOR compositing")

	var image := Image.create(decoded.width, decoded.height, false, Image.FORMAT_RGBA8)

	for y in int(decoded.height):
		for x in int(decoded.width):
			var i := y * int(decoded.width) + x
			image.set_pixel(x, y, Color(0, 0, 0, 0) if decoded.and_mask[i] else decoded.palette[decoded.pixels[i]])

	return {"ok": true, "image": image, "error": ""}


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
