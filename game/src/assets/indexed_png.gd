class_name IndexedPng
extends RefCounted
# read editor-authored pngs without losing duplicate palette indices

@warning_ignore_start("integer_division")

const SIGNATURE := [137, 80, 78, 71, 13, 10, 26, 10]
const MAX_DIMENSION := 4096

# build once at script initialization. readers never modify this table
static var _crc_table: PackedInt64Array = _make_crc_table()


static func load_path(path: String, strict_palette := true) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("PNG file does not exist: %s" % path)

	return decode(FileAccess.get_file_as_bytes(path), strict_palette)


static func decode(bytes: PackedByteArray, strict_palette := true) -> Dictionary:
	if bytes.size() < 8 or bytes.slice(0, 8) != PackedByteArray(SIGNATURE):
		return _failure("Invalid PNG signature")

	var rewritten := bytes.slice(0, 8)
	var palette := Sc2Palette.new()
	var alpha := PackedByteArray()
	alpha.resize(256)
	alpha.fill(255)
	var position := 8
	var palette_count := 0
	var bit_depth := 8
	var width := 0
	var height := 0
	var has_data := false
	var ended_data := false
	var has_alpha := false
	var finished := false

	while position + 12 <= bytes.size():
		var length := _u32(bytes, position)

		if length > bytes.size() - position - 12:
			return _failure("PNG chunk extends past the file")

		var kind := bytes.slice(position + 4, position + 8).get_string_from_ascii()
		var payload := bytes.slice(position + 8, position + 8 + length)
		var checksum := _u32(bytes, position + 8 + length)

		if _crc(bytes.slice(position + 4, position + 8 + length)) != checksum:
			return _failure("Invalid PNG chunk checksum")

		if width == 0 and kind != "IHDR":
			return _failure("PNG must start with IHDR")

		if has_data and kind != "IDAT":
			ended_data = true

		match kind:
			"IHDR":
				if width != 0 or length != 13:
					return _failure("Invalid PNG header")

				width = _u32(payload, 0)
				height = _u32(payload, 4)

				if width < 1 or height < 1 or width > MAX_DIMENSION or height > MAX_DIMENSION:
					return _failure("PNG dimensions must be 1 through 4096")

				bit_depth = payload[8]

				if payload[9] != 3 or bit_depth not in [1, 2, 4, 8] or (strict_palette and bit_depth != 8):
					return _failure("PNG must use 8-bit indexed color" if strict_palette else "PNG must use 1-, 2-, 4-, or 8-bit indexed color")

				if payload[10] != 0 or payload[11] != 0 or payload[12] > 1:
					return _failure("Unsupported PNG encoding")
			"PLTE":
				if (not palette.colors.is_empty() or has_data or has_alpha or length == 0 or length % 3 != 0 or (length / 3) > (1 << bit_depth)
						or (strict_palette and length != 768)):
					return _failure("PNG must have one 256-color palette before pixel data" if strict_palette else "PNG must have one valid indexed palette before pixel data")

				palette_count = length / 3

				for index in palette_count:
					palette.colors.append(Color8(payload[index * 3], payload[index * 3 + 1], payload[index * 3 + 2]))
					# decode the palette index as gray so equal rgb colors don't merge
					# decode the index itself as gray, rather than map rgb back to a color
					payload[index * 3] = index
					payload[index * 3 + 1] = index
					payload[index * 3 + 2] = index

				while palette.colors.size() < 256:
					palette.colors.append(Color.BLACK)
			"tRNS":
				if has_alpha or has_data or not palette.is_valid() or length < 1 or length > palette_count:
					return _failure("Invalid PNG transparency table")

				has_alpha = true

				for index in length:
					if payload[index] != 0 and payload[index] != 255:
						# no partial alpha here, and even invisible pixels must keep their index
						return _failure("PNG transparency must be fully clear or opaque")

					alpha[index] = payload[index]

				# keep all decoded indices visible. apply transparency after decoding
				position += length + 12
				continue
			"IDAT":
				if not palette.is_valid() or ended_data:
					return _failure("Invalid PNG pixel-data order")

				has_data = true
			"IEND":
				if length != 0 or not has_data:
					return _failure("Invalid PNG end chunk")

				finished = true
			_:
				if (bytes[position + 4] & 32) == 0:
					return _failure("Unsupported critical PNG chunk: %s" % kind)

				# omit color profiles and other editor metadata from index decoding
				position += length + 12
				continue

		rewritten.append_array(_chunk(kind, payload))
		position += length + 12

		if finished:
			break

	if not finished or position != bytes.size():
		return _failure("PNG is incomplete or has trailing bytes")

	var image := Image.new()

	if image.load_png_from_buffer(rewritten) != OK:
		return _failure("Cannot decode PNG pixel data")

	image.convert(Image.FORMAT_RGBA8)
	var rgba := image.get_data()
	var pixels := PackedInt32Array()
	pixels.resize(width * height)

	for index in pixels.size():
		var value := int(rgba[index * 4])

		if value >= palette_count:
			return _failure("PNG pixel is outside its palette")

		pixels[index] = value if alpha[value] == 255 else -1

	return {"ok": true, "error": "", "width": width, "height": height,
		"pixels": pixels, "palette": palette}


static func encode(
	width: int, height: int, pixels: PackedInt32Array, palette: Sc2Palette
) -> Dictionary:
	if width < 1 or height < 1 or width > MAX_DIMENSION or height > MAX_DIMENSION:
		return _failure("PNG dimensions must be 1 through 4096")

	if pixels.size() != width * height or palette == null or not palette.is_valid():
		return _failure("Invalid PNG pixels or palette")

	var used := PackedByteArray()
	used.resize(256)
	used.fill(0)
	var has_transparency := false

	for pixel in pixels:
		if pixel < -1 or pixel > 255:
			return _failure("PNG palette index must be -1 through 255")

		if pixel == -1:
			has_transparency = true
		else:
			used[pixel] = 1

	var transparent_index := used.find(0) if has_transparency else -1

	if has_transparency and transparent_index < 0:
		return _failure("Indexed PNG needs an unused palette index for transparency")

	var header := PackedByteArray()
	_append_u32(header, width)
	_append_u32(header, height)
	header.append_array(PackedByteArray([8, 3, 0, 0, 0]))
	var colors := PackedByteArray()

	for color in palette.colors:
		colors.append_array(PackedByteArray([color.r8, color.g8, color.b8]))

	var raw := PackedByteArray()
	raw.resize(height * (width + 1))

	for y in height:
		raw[y * (width + 1)] = 0 # png filter none

		for x in width:
			var pixel := pixels[y * width + x]
			raw[y * (width + 1) + x + 1] = transparent_index if pixel == -1 else pixel

	var output := PackedByteArray(SIGNATURE)
	output.append_array(_chunk("IHDR", header))
	output.append_array(_chunk("PLTE", colors))

	if has_transparency:
		var alpha := PackedByteArray()
		alpha.resize(transparent_index + 1)
		alpha.fill(255)
		alpha[transparent_index] = 0
		output.append_array(_chunk("tRNS", alpha))

	output.append_array(_chunk("IDAT", raw.compress(FileAccess.COMPRESSION_DEFLATE)))
	output.append_array(_chunk("IEND", PackedByteArray()))

	return {"ok": true, "error": "", "bytes": output}


static func _chunk(kind: String, payload: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	_append_u32(result, payload.size())
	var body := kind.to_ascii_buffer()
	body.append_array(payload)
	result.append_array(body)
	_append_u32(result, _crc(body))

	return result


static func _make_crc_table() -> PackedInt64Array:
	var table := PackedInt64Array()
	table.resize(256)
	for byte in 256:
		var value := byte
		for _bit in 8:
			value = (value >> 1) ^ (0xedb88320 if value & 1 else 0)
		table[byte] = value
	return table


static func _crc(bytes: PackedByteArray) -> int:
	var value := 0xffffffff
	for byte in bytes:
		value = (value >> 8) ^ _crc_table[(value ^ byte) & 255]
	return value ^ 0xffffffff


static func _u32(bytes: PackedByteArray, offset: int) -> int:
	return (int(bytes[offset]) << 24) | (int(bytes[offset + 1]) << 16) | (int(bytes[offset + 2]) << 8) | int(bytes[offset + 3])


static func _append_u32(bytes: PackedByteArray, value: int) -> void:
	for shift in [24, 16, 8, 0]:
		bytes.append((value >> shift) & 255)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
