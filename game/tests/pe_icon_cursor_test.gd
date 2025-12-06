extends SceneTree


func _initialize() -> void:
	# Four one-bit outcomes: black, white, transparent and inverse background.
	for cursor in [false, true]:
		for bits in [1, 4, 8]:
			var bytes := _fixture(bits, cursor)
			var decoded := PeIconCursorResource.decode_image(bytes, cursor)
			assert(decoded.ok and decoded.width == 4 and decoded.height == 2)
			assert(decoded.pixels == PackedInt32Array([0, 1, 0, 1, 1, 0, 1, 0]))
			assert(decoded.and_mask == PackedByteArray([0, 0, 1, 1, 1, 1, 0, 0]))
			assert(decoded.inverting_pixels == 2)
			assert(decoded.hotspot == (Vector2i(3, 1) if cursor else Vector2i.ZERO))
			var background := Image.create(4, 2, false, Image.FORMAT_RGBA8)
			background.fill(Color8(37, 83, 149))
			var composed := PeIconCursorResource.composite(decoded, background)
			assert(composed.get_pixel(0, 0) == Color.BLACK)
			assert(composed.get_pixel(1, 0) == Color.WHITE)
			assert(composed.get_pixel(2, 0) == Color8(37, 83, 149))
			assert(composed.get_pixel(3, 0) == Color8(218, 172, 106))
			assert(not PeIconCursorResource.transparent_image(decoded).ok)
			for length in bytes.size():
				assert(not PeIconCursorResource.decode_image(bytes.slice(0, length), cursor).ok)
			for change in ["header", "width", "height", "odd_height", "planes", "bits", "compression", "palette", "index"]:
				var bad := bytes.duplicate()
				var at := 4 if cursor else 0
				match change:
					"header": bad.encode_u32(at, 12)
					"width": bad.encode_u32(at + 4, 0xffffffff)
					"height": bad.encode_u32(at + 8, 0xfffffffc)
					"odd_height": bad.encode_u32(at + 8, 3)
					"planes": bad.encode_u16(at + 12, 2)
					"bits": bad.encode_u16(at + 14, 32)
					"compression": bad.encode_u32(at + 16, 1)
					"palette": bad.encode_u32(at + 32, 257)
					"index":
						bad.encode_u32(at + 32, 1)
						bad[at + 44] = 255
				assert(not PeIconCursorResource.decode_image(bad, cursor).ok, change)
			if cursor:
				var bad := bytes.duplicate()
				bad.encode_u16(0, 4)
				assert(not PeIconCursorResource.decode_image(bad, true).ok)
	_test_groups()
	print("PASS: indexed icon/cursor DIB rows, 1/4/8-bit masks, all four AND/XOR outcomes, hotspots, truncated data, invalid headers/palettes/indices and group records")
	quit()


func _fixture(bits: int, cursor: bool) -> PackedByteArray:
	var start := 4 if cursor else 0
	var count := 1 << bits
	var bytes := PackedByteArray()
	bytes.resize(start + 40 + count * 4 + 16)
	if cursor:
		bytes.encode_u16(0, 3)
		bytes.encode_u16(2, 1)
	bytes.encode_u32(start, 40)
	bytes.encode_u32(start + 4, 4)
	bytes.encode_u32(start + 8, 4)
	bytes.encode_u16(start + 12, 1)
	bytes.encode_u16(start + 14, bits)
	for channel in 3:
		bytes[start + 44 + channel] = 255
	var pixels := start + 40 + count * 4
	for row in 2:
		for x in 4:
			var value := (x + 1 - row) % 2
			bytes[pixels + row * 4 + int(x * bits / 8)] |= value << (8 - bits - (x * bits) % 8)
	bytes[pixels + 8] = 0xc0
	bytes[pixels + 12] = 0x30
	return bytes


func _test_groups() -> void:
	for cursor in [false, true]:
		var bytes := PackedByteArray()
		bytes.resize(20)
		bytes.encode_u16(2, 2 if cursor else 1)
		bytes.encode_u16(4, 1)
		if cursor:
			bytes.encode_u16(6, 32)
			bytes.encode_u16(8, 64)
		else:
			bytes[6] = 32
			bytes[7] = 32
		bytes.encode_u16(10, 1)
		bytes.encode_u16(12, 1 if cursor else 4)
		bytes.encode_u32(14, 308 if cursor else 744)
		bytes.encode_u16(18, 7)
		var decoded := PeIconCursorResource.decode_group(bytes, cursor)
		assert(decoded.ok and decoded.entries[0].id == 7 and decoded.entries[0].width == 32)
		assert(decoded.entries[0].height == (64 if cursor else 32))
		for length in 20:
			assert(not PeIconCursorResource.decode_group(bytes.slice(0, length), cursor).ok)
		for offset in [0, 2, 4, 18]:
			var bad := bytes.duplicate()
			bad.encode_u16(offset, 99 if offset == 0 else 0)
			assert(not PeIconCursorResource.decode_group(bad, cursor).ok)
