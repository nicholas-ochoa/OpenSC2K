class_name IndexedGif
extends RefCounted
# gif89a full-frame export with local palettes and a repeating scurk cycle

const CYCLE_START := 31 # past the one-time slow-table initialization
const CYCLE_TICKS := 120 # lcm of the 40-tick fast and 60-tick slow cycles

static func encode_cycle(width: int, height: int, pixels: PackedInt32Array, palette: Sc2Palette) -> Dictionary:
	if width < 1 or height < 1 or width > 128 or height > 256 or pixels.size() != width * height or palette == null or not palette.is_valid():
		return {"ok": false, "error": "Invalid SCURK GIF dimensions, pixels, or palette."}
	var used := PackedByteArray()
	used.resize(256)
	used.fill(0)
	var transparent := false
	for pixel in pixels:
		if pixel < -1 or pixel > 255:
			return {"ok": false, "error": "GIF pixel is outside the indexed palette."}
		if pixel < 0:
			transparent = true
		else:
			used[pixel] = 1
	var clear_index := used.find(0) if transparent else 0
	if clear_index < 0:
		return {"ok": false, "error": "GIF transparency requires an unused palette index."}
	var raster := PackedByteArray()
	for pixel in pixels:
		raster.append(clear_index if pixel < 0 else pixel)
	var compressed := _literal_lzw(raster)
	var frames: Array[Dictionary] = []
	for tick in CYCLE_TICKS:
		var mapping := palette.scurk_animation_index_map(CYCLE_START + tick)
		var signature := PackedInt32Array()
		for index in 256:
			if used[index]:
				signature.append(mapping[index])
		if frames.is_empty() or frames.back().signature != signature:
			frames.append({"start": tick, "mapping": mapping, "signature": signature})
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
	return {"ok": true, "error": "", "bytes": output, "frame_count": frames.size(), "duration_cs": 660}

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
