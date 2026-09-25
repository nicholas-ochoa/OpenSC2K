class_name IndexedGif
extends RefCounted
# gif89a export and indexed gif import. the cycle export has full frames with
# local palettes and a repeating scurk cycle

const CYCLE_START := 31 # past the one-time slow-table initialization
const CYCLE_TICKS := 120 # lcm of the 40-tick fast and 60-tick slow cycles
const MAX_DIMENSION := 4096
const MAX_CODES := 4096
# first rows and row steps of the four interlace passes
const INTERLACE_PASSES := [[0, 8], [4, 8], [2, 4], [1, 2]]


class Frame extends RefCounted:
	var start := 0
	var mapping := PackedInt32Array()
	var signature := PackedInt32Array()


static func encode_cycle(width: int, height: int, pixels: PackedInt32Array, palette: Sc2Palette) -> AssetBytesResult:
	if width < 1 or height < 1 or width > 128 or height > 256 or pixels.size() != width * height or palette == null or not palette.is_valid():
		return AssetBytesResult.failure("Invalid SCURK GIF dimensions, pixels, or palette.")

	var used := PackedByteArray()
	used.resize(256)
	used.fill(0)
	var transparent := false

	for pixel in pixels:
		if pixel < -1 or pixel > 255:
			return AssetBytesResult.failure("GIF pixel is outside the indexed palette.")

		if pixel < 0:
			transparent = true
		else:
			used[pixel] = 1

	var clear_index := used.find(0) if transparent else 0

	if clear_index < 0:
		return AssetBytesResult.failure("GIF transparency requires an unused palette index.")

	var raster := PackedByteArray()

	for pixel in pixels:
		raster.append(clear_index if pixel < 0 else pixel)

	var compressed := _literal_lzw(raster)
	var frames: Array[Frame] = []

	for tick in CYCLE_TICKS:
		var mapping := palette.scurk_animation_index_map(CYCLE_START + tick)
		var signature := PackedInt32Array()

		for index in 256:
			if used[index]:
				signature.append(mapping[index])

		if frames.is_empty() or frames.back().signature != signature:
			var frame := Frame.new()
			frame.start = tick
			frame.mapping = mapping
			frame.signature = signature
			frames.append(frame)

	var output := "GIF89a".to_ascii_buffer()
	_u16(output, width)
	_u16(output, height)
	output.append_array(PackedByteArray([0xf7, clear_index, 0]))
	_palette(output, palette, palette.scurk_animation_index_map(CYCLE_START))
	output.append_array(PackedByteArray([0x21, 0xff, 11]))
	output.append_array("NETSCAPE2.0".to_ascii_buffer())
	output.append_array(PackedByteArray([3, 1, 0, 0, 0])) # repeat forever

	for index in frames.size():
		var frame := frames[index]
		var end: int = frames[index + 1].start if index + 1 < frames.size() else CYCLE_TICKS
		var delay := roundi(end * 5.5) - roundi(int(frame.start) * 5.5)
		output.append_array(PackedByteArray([0x21, 0xf9, 4, 9 if transparent else 8]))
		_u16(output, delay)
		output.append_array(PackedByteArray([clear_index, 0, 0x2c]))
		_u16(output, 0)
		_u16(output, 0)
		_u16(output, width)
		_u16(output, height)
		output.append(0x87)
		_palette(output, palette, frame.mapping)
		output.append(8) # initial lzw code size

		for offset in range(0, compressed.size(), 255):
			var block := compressed.slice(offset, mini(offset + 255, compressed.size()))
			output.append(block.size())
			output.append_array(block)

		output.append(0)

	output.append(0x3b)

	var outcome := AssetBytesResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.bytes = output
	outcome.frame_count = frames.size()
	outcome.duration_cs = 660

	return outcome


# one frame with the palette in its original index order
static func encode(width: int, height: int, pixels: PackedInt32Array, palette: Sc2Palette) -> AssetBytesResult:
	if width < 1 or height < 1 or width > MAX_DIMENSION or height > MAX_DIMENSION or pixels.size() != width * height or palette == null or not palette.is_valid():
		return AssetBytesResult.failure("Invalid GIF dimensions, pixels, or palette.")

	var used := PackedByteArray()
	used.resize(256)
	used.fill(0)
	var transparent := false

	for pixel in pixels:
		if pixel < -1 or pixel > 255:
			return AssetBytesResult.failure("GIF pixel is outside the indexed palette.")

		if pixel < 0:
			transparent = true
		else:
			used[pixel] = 1

	var clear_index := used.find(0) if transparent else 0

	if clear_index < 0:
		return AssetBytesResult.failure("GIF transparency requires an unused palette index.")

	var raster := PackedByteArray()

	for pixel in pixels:
		raster.append(clear_index if pixel < 0 else pixel)

	var identity := PackedInt32Array()

	for index in 256:
		identity.append(index)

	var output := "GIF89a".to_ascii_buffer()
	_u16(output, width)
	_u16(output, height)
	output.append_array(PackedByteArray([0xf7, clear_index, 0]))
	_palette(output, palette, identity)

	if transparent:
		output.append_array(PackedByteArray([0x21, 0xf9, 4, 1, 0, 0, clear_index, 0]))

	output.append(0x2c)
	_u16(output, 0)
	_u16(output, 0)
	_u16(output, width)
	_u16(output, height)
	output.append(0)
	output.append(8) # initial lzw code size
	var compressed := _literal_lzw(raster)

	for offset in range(0, compressed.size(), 255):
		var block := compressed.slice(offset, mini(offset + 255, compressed.size()))
		output.append(block.size())
		output.append_array(block)

	output.append(0)
	output.append(0x3b)
	var outcome := AssetBytesResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.bytes = output
	outcome.frame_count = 1

	return outcome


static func load_path(path: String) -> IndexedImageResult:
	if not FileAccess.file_exists(path):
		return IndexedImageResult.failure("GIF file does not exist: %s" % path)

	return decode(FileAccess.get_file_as_bytes(path))


# the first image of the file on its logical screen. pixels outside that image
# and pixels with the transparent index are -1. the palette has 256 entries
static func decode(bytes: PackedByteArray) -> IndexedImageResult:
	if bytes.size() < 13 or bytes.slice(0, 6).get_string_from_ascii() not in ["GIF87a", "GIF89a"]:
		return IndexedImageResult.failure("File does not have a GIF signature.")

	var screen_width := bytes.decode_u16(6)
	var screen_height := bytes.decode_u16(8)

	if screen_width < 1 or screen_height < 1 or screen_width > MAX_DIMENSION or screen_height > MAX_DIMENSION:
		return IndexedImageResult.failure("GIF dimensions must be 1 through 4096")

	var position := 13
	var global_colors: Array[Color] = []

	if bytes[10] & 0x80:
		global_colors = _read_colors(bytes, position, 2 << (bytes[10] & 7))

		if global_colors.is_empty():
			return IndexedImageResult.failure("GIF color table extends past the file.")

		position += global_colors.size() * 3

	var transparent_index := -1

	while position < bytes.size():
		var kind := bytes[position]
		position += 1

		if kind == 0x3b:
			break

		if kind == 0x21:
			if position >= bytes.size():
				break

			var label := bytes[position]
			position += 1

			if label == 0xf9 and position + 5 < bytes.size() and bytes[position] == 4:
				transparent_index = bytes[position + 4] if bytes[position + 1] & 1 else -1

			position = _skip_blocks(bytes, position)

			if position < 0:
				return IndexedImageResult.failure("GIF extension extends past the file.")

			continue

		if kind != 0x2c:
			return IndexedImageResult.failure("GIF contains an unknown block.")

		return _decode_image(bytes, position, screen_width, screen_height, global_colors, transparent_index)

	return IndexedImageResult.failure("GIF contains no image.")


static func _decode_image(
	bytes: PackedByteArray, start: int, screen_width: int, screen_height: int, global_colors: Array[Color], transparent_index: int
) -> IndexedImageResult:
	if start + 9 > bytes.size():
		return IndexedImageResult.failure("GIF image header extends past the file.")

	var left := bytes.decode_u16(start)
	var top := bytes.decode_u16(start + 2)
	var width := bytes.decode_u16(start + 4)
	var height := bytes.decode_u16(start + 6)
	var flags := bytes[start + 8]
	var position := start + 9

	if width < 1 or height < 1 or left + width > screen_width or top + height > screen_height:
		return IndexedImageResult.failure("GIF image is outside its logical screen.")

	var colors := global_colors

	if flags & 0x80:
		colors = _read_colors(bytes, position, 2 << (flags & 7))

		if colors.is_empty():
			return IndexedImageResult.failure("GIF color table extends past the file.")

		position += colors.size() * 3

	if colors.is_empty():
		return IndexedImageResult.failure("GIF has no color table.")

	if position >= bytes.size() or bytes[position] < 2 or bytes[position] > 8:
		return IndexedImageResult.failure("GIF LZW code size is invalid.")

	var code_size := bytes[position]
	var data := PackedByteArray()
	position += 1

	while true:
		if position >= bytes.size():
			return IndexedImageResult.failure("GIF image data extends past the file.")

		var length := bytes[position]

		if position + 1 + length > bytes.size():
			return IndexedImageResult.failure("GIF image data extends past the file.")

		if length == 0:
			break

		data.append_array(bytes.slice(position + 1, position + 1 + length))
		position += 1 + length

	var indices := _lzw_decode(data, code_size, width * height)

	if indices.size() < width * height:
		return IndexedImageResult.failure("GIF image data is invalid or incomplete.")

	var rows := PackedInt32Array()

	if flags & 0x40:
		for interlace_pass in INTERLACE_PASSES:
			for row in range(interlace_pass[0], height, interlace_pass[1]):
				rows.append(row)
	else:
		for row in height:
			rows.append(row)

	var result := IndexedImageResult.new()
	result.pixels.resize(screen_width * screen_height)
	result.pixels.fill(-1)

	for source_row in height:
		var y: int = top + rows[source_row]

		for x in width:
			var index := indices[source_row * width + x]

			if index >= colors.size():
				return IndexedImageResult.failure("GIF pixel is outside its color table.")

			result.pixels[y * screen_width + left + x] = -1 if index == transparent_index else index

	result.palette = Sc2Palette.new()

	for index in 256:
		result.palette.colors.append(colors[index] if index < colors.size() else Color.BLACK)

	result.colors = result.palette.colors
	result.width = screen_width
	result.height = screen_height
	result.ok = true

	return result


static func _read_colors(bytes: PackedByteArray, start: int, count: int) -> Array[Color]:
	var colors: Array[Color] = []

	if start + count * 3 > bytes.size():
		return colors

	for index in count:
		var offset := start + index * 3
		colors.append(Color8(bytes[offset], bytes[offset + 1], bytes[offset + 2]))

	return colors


# returns the position after the terminating zero-length block, or -1
static func _skip_blocks(bytes: PackedByteArray, start: int) -> int:
	var position := start

	while position < bytes.size():
		var length := bytes[position]
		position += 1 + length

		if length == 0:
			return position

	return -1


# variable-length lzw codes of up to 12 bits. returns fewer indices on an error
static func _lzw_decode(data: PackedByteArray, minimum_code_size: int, count: int) -> PackedByteArray:
	var clear_code := 1 << minimum_code_size
	var end_code := clear_code + 1
	var prefixes := PackedInt32Array()
	var suffixes := PackedByteArray()
	var firsts := PackedByteArray()
	prefixes.resize(MAX_CODES)
	suffixes.resize(MAX_CODES)
	firsts.resize(MAX_CODES)

	for code in clear_code:
		prefixes[code] = -1
		suffixes[code] = code
		firsts[code] = code

	var output := PackedByteArray()
	var stack := PackedByteArray()
	stack.resize(MAX_CODES)
	var code_size := minimum_code_size + 1
	var next_code := end_code + 1
	var previous := -1
	var buffer := 0
	var bits := 0
	var position := 0

	while output.size() < count:
		while bits < code_size:
			if position >= data.size():
				return output

			buffer |= data[position] << bits
			position += 1
			bits += 8

		var code := buffer & ((1 << code_size) - 1)
		buffer >>= code_size
		bits -= code_size

		if code == clear_code:
			code_size = minimum_code_size + 1
			next_code = end_code + 1
			previous = -1
			continue

		if code == end_code:
			return output

		if previous < 0:
			if code >= clear_code:
				return output

			output.append(code)
			previous = code
			continue

		var entry := code

		if code == next_code:
			entry = previous
		elif code > next_code or (code >= clear_code and code <= end_code):
			return output

		var depth := 0
		var walk := entry

		while walk >= 0:
			stack[depth] = suffixes[walk]
			depth += 1
			walk = prefixes[walk]

		for index in range(depth - 1, -1, -1):
			output.append(stack[index])

		if code == next_code:
			output.append(firsts[previous])

		if next_code < MAX_CODES:
			prefixes[next_code] = previous
			suffixes[next_code] = firsts[entry]
			firsts[next_code] = firsts[previous]
			next_code += 1

			if next_code == 1 << code_size and code_size < 12:
				code_size += 1

		previous = code

	return output


static func _palette(output: PackedByteArray, palette: Sc2Palette, mapping: PackedInt32Array) -> void:
	for index in mapping:
		var color := palette.color(index)
		output.append_array(PackedByteArray([color.r8, color.g8, color.b8]))


static func _u16(output: PackedByteArray, value: int) -> void:
	output.append_array(PackedByteArray([value & 255, (value >> 8) & 255]))


# clear every 254 pixels to keep the gif codes at nine bits
static func _literal_lzw(pixels: PackedByteArray) -> PackedByteArray:
	# legal early clear codes keep the encoder at nine bits. no external encoder
	var codes := PackedInt32Array()

	for start in range(0, pixels.size(), 254):
		codes.append(256)

		for index in range(start, mini(start + 254, pixels.size())):
			codes.append(pixels[index])

	codes.append(257)
	var output := PackedByteArray()
	var buffer := 0
	var bits := 0

	for code in codes:
		buffer |= code << bits
		bits += 9

		while bits >= 8:
			output.append(buffer & 255)
			buffer >>= 8
			bits -= 8

	if bits > 0:
		output.append(buffer & 255)

	return output
