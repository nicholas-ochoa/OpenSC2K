class_name IndexedBmp
extends RefCounted

const FILE_HEADER_SIZE := 14
const INFO_HEADER_SIZE := 40
const PALETTE_COLOR_COUNT := 256
const PALETTE_SIZE := PALETTE_COLOR_COUNT * 4
const PIXEL_OFFSET := FILE_HEADER_SIZE + INFO_HEADER_SIZE + PALETTE_SIZE
const MAX_DIMENSION := 0x7fff


static func load_path(path: String, target_palette: Sc2Palette) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("BMP file does not exist: %s" % path)
	var bytes := FileAccess.get_file_as_bytes(path)
	if FileAccess.get_open_error() != OK:
		return _failure("Cannot read BMP file: %s" % path)
	var decoded := decode(bytes)
	if not decoded.ok:
		return decoded
	var mapped := map_to_palette(decoded, target_palette)
	if not mapped.ok:
		return mapped
	return {
		"ok": true,
		"error": "",
		"width": decoded.width,
		"height": decoded.height,
		"pixels": mapped.pixels,
		"remapped_color_count": mapped.remapped_color_count,
	}


static func save_path(
	path: String,
	width: int,
	height: int,
	pixels: PackedInt32Array,
	palette: Sc2Palette
) -> Dictionary:
	var encoded := encode(width, height, pixels, palette)
	if not encoded.ok:
		return {"ok": false, "error": encoded.error}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"error": "Cannot open BMP output: %s" % error_string(FileAccess.get_open_error()),
		}
	file.store_buffer(encoded.bytes)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {
			"ok": false,
			"error": "Cannot write BMP output: %s" % error_string(write_error),
		}
	return {"ok": true, "error": "", "path": path}


static func encode_dib(
	width: int,
	height: int,
	pixels: PackedInt32Array,
	palette: Sc2Palette,
	transparent_index := 0
) -> Dictionary:
	var encoded := encode(width, height, pixels, palette, transparent_index)
	if not encoded.ok:
		return encoded
	return bmp_to_dib(encoded.bytes)


static func decode_dib(bytes: PackedByteArray) -> Dictionary:
	var wrapped := dib_to_bmp(bytes)
	if not wrapped.ok:
		return wrapped
	return decode(wrapped.bytes)


static func bmp_to_dib(bytes: PackedByteArray) -> Dictionary:
	var decoded := decode(bytes)
	if not decoded.ok:
		return decoded
	return {
		"ok": true,
		"error": "",
		"bytes": bytes.slice(FILE_HEADER_SIZE),
	}


static func dib_to_bmp(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < INFO_HEADER_SIZE:
		return _failure("DIB data is shorter than its information header.")
	var header_size := _read_u32(bytes, 0)
	if header_size < INFO_HEADER_SIZE or header_size > bytes.size():
		return _failure("DIB information header is invalid.")
	if _read_u16(bytes, 12) != 1:
		return _failure("DIB plane count is not one.")
	if _read_u16(bytes, 14) != 8:
		return _failure("SCURK clipboard input requires an 8-bit indexed DIB.")
	if _read_u32(bytes, 16) != 0:
		return _failure("SCURK clipboard input requires an uncompressed DIB.")
	var color_count := _read_u32(bytes, 32)
	if color_count == 0:
		color_count = PALETTE_COLOR_COUNT
	if color_count != PALETTE_COLOR_COUNT:
		return _failure("SCURK clipboard input requires exactly 256 palette colors.")
	var dib_pixel_offset := header_size + color_count * 4
	if dib_pixel_offset > bytes.size():
		return _failure("DIB palette extends past the clipboard data.")
	var file_size := FILE_HEADER_SIZE + bytes.size()
	var wrapped := PackedByteArray()
	wrapped.resize(FILE_HEADER_SIZE)
	wrapped.fill(0)
	wrapped[0] = 0x42
	wrapped[1] = 0x4d
	_write_u32(wrapped, 2, file_size)
	_write_u32(wrapped, 10, FILE_HEADER_SIZE + dib_pixel_offset)
	wrapped.append_array(bytes)
	var decoded := decode(wrapped)
	if not decoded.ok:
		return decoded
	return {"ok": true, "error": "", "bytes": wrapped}


static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < PIXEL_OFFSET:
		return _failure("BMP file is shorter than an 8-bit indexed header.")
	if bytes[0] != 0x42 or bytes[1] != 0x4d:
		return _failure("File does not have a Windows BMP signature.")
	var declared_size := _read_u32(bytes, 2)
	if declared_size != 0 and declared_size > bytes.size():
		return _failure("BMP file is shorter than its declared size.")
	var pixel_offset := _read_u32(bytes, 10)
	var header_size := _read_u32(bytes, FILE_HEADER_SIZE)
	if header_size < INFO_HEADER_SIZE:
		return _failure("BMP does not use a supported information header.")
	if FILE_HEADER_SIZE + header_size > bytes.size():
		return _failure("BMP information header extends past the file.")
	var width := _read_i32(bytes, 18)
	var signed_height := _read_i32(bytes, 22)
	if (
		width <= 0
		or width > MAX_DIMENSION
		or signed_height == 0
		or absi(signed_height) > MAX_DIMENSION
	):
		return _failure("BMP dimensions are invalid or too large.")
	if _read_u16(bytes, 26) != 1:
		return _failure("BMP plane count is not one.")
	if _read_u16(bytes, 28) != 8:
		return _failure("SCURK import requires an 8-bit indexed BMP.")
	if _read_u32(bytes, 30) != 0:
		return _failure("SCURK import requires an uncompressed BMP.")
	var color_count := _read_u32(bytes, 46)
	if color_count == 0:
		color_count = PALETTE_COLOR_COUNT
	if color_count != PALETTE_COLOR_COUNT:
		return _failure("SCURK import requires exactly 256 palette colors.")
	var palette_offset := FILE_HEADER_SIZE + header_size
	if palette_offset + PALETTE_SIZE > bytes.size():
		return _failure("BMP palette extends past the file.")
	if pixel_offset < palette_offset + PALETTE_SIZE or pixel_offset > bytes.size():
		return _failure("BMP pixel offset is invalid.")
	var height := absi(signed_height)
	var row_stride := _row_stride(width)
	if pixel_offset + row_stride * height > bytes.size():
		return _failure("BMP pixel data extends past the file.")

	var colors: Array[Color] = []
	for index in PALETTE_COLOR_COUNT:
		var offset := palette_offset + index * 4
		colors.append(Color8(bytes[offset + 2], bytes[offset + 1], bytes[offset], 255))
	var pixels := PackedInt32Array()
	pixels.resize(width * height)
	var top_down := signed_height < 0
	for y in height:
		var source_y := y if top_down else height - 1 - y
		var row_offset := pixel_offset + source_y * row_stride
		for x in width:
			pixels[y * width + x] = bytes[row_offset + x]
	return {
		"ok": true,
		"error": "",
		"width": width,
		"height": height,
		"pixels": pixels,
		"colors": colors,
		"top_down": top_down,
	}


static func map_to_palette(
	decoded: Dictionary, target_palette: Sc2Palette, transparent_index := 0
) -> Dictionary:
	if not decoded.get("ok", false):
		return _failure(decoded.get("error", "BMP data is invalid."))
	if target_palette == null or not target_palette.is_valid():
		return _failure("The SimCity 2000 palette is not available.")
	var source_colors: Array = decoded.get("colors", [])
	var source_pixels: PackedInt32Array = decoded.get("pixels", PackedInt32Array())
	if source_colors.size() != PALETTE_COLOR_COUNT:
		return _failure("BMP palette does not contain 256 colors.")
	var index_map := PackedInt32Array()
	index_map.resize(PALETTE_COLOR_COUNT)
	var remapped_color_count := 0
	for source_index in PALETTE_COLOR_COUNT:
		if source_index == transparent_index:
			index_map[source_index] = -1
			continue
		var source_color: Color = source_colors[source_index]
		if _same_rgb(source_color, target_palette.color(source_index)):
			index_map[source_index] = source_index
			continue
		index_map[source_index] = _nearest_palette_index(source_color, target_palette)
		remapped_color_count += 1
	var mapped := PackedInt32Array()
	mapped.resize(source_pixels.size())
	for index in source_pixels.size():
		mapped[index] = index_map[source_pixels[index]]
	return {
		"ok": true,
		"error": "",
		"pixels": mapped,
		"remapped_color_count": remapped_color_count,
	}


static func encode(
	width: int,
	height: int,
	pixels: PackedInt32Array,
	palette: Sc2Palette,
	transparent_index := 0
) -> Dictionary:
	if width <= 0 or width > MAX_DIMENSION or height <= 0 or height > MAX_DIMENSION:
		return _failure("BMP dimensions are invalid or too large.")
	if pixels.size() != width * height:
		return _failure("BMP pixel count does not match its dimensions.")
	if palette == null or not palette.is_valid():
		return _failure("The SimCity 2000 palette is not available.")
	if transparent_index < 0 or transparent_index >= PALETTE_COLOR_COUNT:
		return _failure("BMP transparent palette index is invalid.")
	for pixel in pixels:
		if pixel < -1 or pixel >= PALETTE_COLOR_COUNT:
			return _failure("BMP has a palette index outside the 8-bit range.")

	var row_stride := _row_stride(width)
	var pixel_data_size := row_stride * height
	var file_size := PIXEL_OFFSET + pixel_data_size
	var bytes := PackedByteArray()
	bytes.resize(file_size)
	bytes.fill(0)
	bytes[0] = 0x42
	bytes[1] = 0x4d
	_write_u32(bytes, 2, file_size)
	_write_u32(bytes, 10, PIXEL_OFFSET)
	_write_u32(bytes, 14, INFO_HEADER_SIZE)
	_write_u32(bytes, 18, width)
	_write_u32(bytes, 22, height)
	_write_u16(bytes, 26, 1)
	_write_u16(bytes, 28, 8)
	_write_u32(bytes, 34, pixel_data_size)
	_write_u32(bytes, 46, PALETTE_COLOR_COUNT)
	_write_u32(bytes, 50, PALETTE_COLOR_COUNT)
	for index in PALETTE_COLOR_COUNT:
		var color := palette.color(index)
		var palette_entry := FILE_HEADER_SIZE + INFO_HEADER_SIZE + index * 4
		bytes[palette_entry] = clampi(roundi(color.b * 255.0), 0, 255)
		bytes[palette_entry + 1] = clampi(roundi(color.g * 255.0), 0, 255)
		bytes[palette_entry + 2] = clampi(roundi(color.r * 255.0), 0, 255)
	for y in height:
		var target_y := height - 1 - y
		var row_offset := PIXEL_OFFSET + target_y * row_stride
		for x in width:
			var pixel := pixels[y * width + x]
			bytes[row_offset + x] = transparent_index if pixel < 0 else pixel
	return {"ok": true, "error": "", "bytes": bytes}


static func _nearest_palette_index(source: Color, target_palette: Sc2Palette) -> int:
	var source_r := clampi(roundi(source.r * 255.0), 0, 255)
	var source_g := clampi(roundi(source.g * 255.0), 0, 255)
	var source_b := clampi(roundi(source.b * 255.0), 0, 255)
	var best_index := 1
	var best_distance := 0x7fffffff
	for target_index in range(1, PALETTE_COLOR_COUNT):
		var target := target_palette.color(target_index)
		var delta_r := source_r - clampi(roundi(target.r * 255.0), 0, 255)
		var delta_g := source_g - clampi(roundi(target.g * 255.0), 0, 255)
		var delta_b := source_b - clampi(roundi(target.b * 255.0), 0, 255)
		var distance := delta_r * delta_r + delta_g * delta_g + delta_b * delta_b
		if distance < best_distance:
			best_index = target_index
			best_distance = distance
			if distance == 0:
				break
	return best_index


static func _same_rgb(first: Color, second: Color) -> bool:
	return (
		clampi(roundi(first.r * 255.0), 0, 255)
			== clampi(roundi(second.r * 255.0), 0, 255)
		and clampi(roundi(first.g * 255.0), 0, 255)
			== clampi(roundi(second.g * 255.0), 0, 255)
		and clampi(roundi(first.b * 255.0), 0, 255)
			== clampi(roundi(second.b * 255.0), 0, 255)
	)


static func _row_stride(width: int) -> int:
	return (width + 3) & ~3


static func _read_u16(bytes: PackedByteArray, offset: int) -> int:
	return bytes[offset] | (bytes[offset + 1] << 8)


static func _read_u32(bytes: PackedByteArray, offset: int) -> int:
	return (
		bytes[offset]
		| (bytes[offset + 1] << 8)
		| (bytes[offset + 2] << 16)
		| (bytes[offset + 3] << 24)
	)


static func _read_i32(bytes: PackedByteArray, offset: int) -> int:
	var value := _read_u32(bytes, offset)
	return value - 0x100000000 if value >= 0x80000000 else value


static func _write_u16(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = value & 0xff
	bytes[offset + 1] = (value >> 8) & 0xff


static func _write_u32(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = value & 0xff
	bytes[offset + 1] = (value >> 8) & 0xff
	bytes[offset + 2] = (value >> 16) & 0xff
	bytes[offset + 3] = (value >> 24) & 0xff


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
