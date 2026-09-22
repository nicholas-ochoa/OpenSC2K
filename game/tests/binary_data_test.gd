extends SceneTree

var failures := 0


func _initialize() -> void:
	_test_words()
	_test_pe_bounds()
	_test_bitmap_readers()
	_test_indexed_resources()
	_test_scenario_picture()
	print("Binary data checks: %d failures" % failures)
	quit(1 if failures else 0)


func _test_words() -> void:
	var cases := [
		[0, [0, 0, 0, 0], 0],
		[0x12345678, [0x12, 0x34, 0x56, 0x78], 0x12345678],
		[0x7fffffff, [0x7f, 0xff, 0xff, 0xff], 0x7fffffff],
		[0x80000000, [0x80, 0, 0, 0], -2147483648],
		[0xffffffff, [0xff, 0xff, 0xff, 0xff], -1],
		[-2, [0xff, 0xff, 0xff, 0xfe], -2],
		[0x100000001, [0, 0, 0, 1], 1],
	]
	for entry: Array in cases:
		var data := PackedByteArray([0xa5, 0, 0, 0, 0, 0x5a])
		BinaryData.write_u32_be(data, 1, entry[0])
		check(data.slice(1, 5) == PackedByteArray(entry[1]), "big-endian bytes")
		check(data[0] == 0xa5 and data[5] == 0x5a, "surrounding bytes")
		check(BinaryData.read_u32_be(data, 1) == (int(entry[0]) & 0xffffffff), "unsigned value")
		check(BinaryData.read_i32_be(data, 1) == entry[2], "signed value")

	var short_data := PackedByteArray([0xa5, 0, 0, 0x5a])
	for value in 65536:
		BinaryData.write_u16_be(short_data, 1, value)
		check(short_data == PackedByteArray([0xa5, value >> 8, value & 255, 0x5a]), "big-endian 16-bit bytes")
		check(BinaryData.read_u16_be(short_data, 1) == value, "big-endian 16-bit read")
		short_data.encode_u16(1, value)
		check(short_data == PackedByteArray([0xa5, value & 255, value >> 8, 0x5a]), "little-endian 16-bit bytes")
		check(short_data.decode_u16(1) == value, "little-endian 16-bit read")
		check(short_data.decode_s16(1) == (value - 65536 if value >= 32768 else value), "signed little-endian 16-bit read")

	for value in [-9223372036854775807, -4294967297, -4294967296, -2147483649, -2147483648, -2, -1,
		0, 1, 0x7fff, 0x8000, 0xffff, 0x10000, 0x7fffffff, 0x80000000, 0xffffffff, 0x100000000, 0x100000001, 0x7fffffffffffffff]:
		_test_word32(value)
		BinaryData.write_u16_be(short_data, 1, value)
		check(short_data == PackedByteArray([0xa5, (value >> 8) & 255, value & 255, 0x5a]), "big-endian 16-bit wrap")
		short_data.encode_u16(1, value)
		check(short_data == PackedByteArray([0xa5, value & 255, (value >> 8) & 255, 0x5a]), "little-endian 16-bit wrap")

	for shift in [0, 8, 16, 24]:
		for byte in 256:
			_test_word32(byte << shift)


func _test_word32(value: int) -> void:
	var big := PackedByteArray([0xa5, 0, 0, 0, 0, 0x5a])
	var little := big.duplicate()
	BinaryData.write_u32_be(big, 1, value)
	little.encode_u32(1, value)
	for index in 4:
		var byte := (value >> (index * 8)) & 255
		check(big[4 - index] == byte and little[index + 1] == byte, "32-bit byte lanes")
	var unsigned := value & 0xffffffff
	var signed := unsigned - 0x100000000 if unsigned >= 0x80000000 else unsigned
	check(BinaryData.read_u32_be(big, 1) == unsigned and little.decode_u32(1) == unsigned, "32-bit unsigned read")
	check(BinaryData.read_i32_be(big, 1) == signed and little.decode_s32(1) == signed, "32-bit signed read")
	check(big[0] == 0xa5 and big[5] == 0x5a and little[0] == 0xa5 and little[5] == 0x5a, "32-bit sentinels")


func _test_pe_bounds() -> void:
	var bytes := PackedByteArray([0xa5, 0x12, 0x34, 0x56, 0x78, 0x5a])
	for size in range(bytes.size() + 1):
		var prefix := bytes.slice(0, size)
		for offset in range(-1, size + 2):
			var short_value := prefix.decode_u16(offset) if offset >= 0 and offset + 2 <= size else 0
			var word_value := prefix.decode_u32(offset) if offset >= 0 and offset + 4 <= size else 0
			check(PeBitmapResource._read_u16(prefix, offset) == short_value, "bounded PE 16-bit read")
			check(PeBitmapResource._read_u32(prefix, offset) == word_value, "bounded PE 32-bit read")


func _test_bitmap_readers() -> void:
	var encoded := IndexedBmp.encode(2, 2, PackedInt32Array([1, 2, 3, 4]), Sc2Palette.index_encoding())
	check(encoded.ok, "generated BMP encodes")
	if not encoded.ok:
		return

	var bytes := encoded.bytes
	check(bytes.slice(0, 30) == "424d3e040000000000003604000028000000020000000200000001000800".hex_decode(), "BMP header bytes")
	check(bytes.slice(IndexedBmp.PIXEL_OFFSET) == PackedByteArray([3, 4, 0, 0, 1, 2, 0, 0]), "BMP bottom-up rows and padding")
	check(IndexedBmp.decode(bytes).pixels == PackedInt32Array([1, 2, 3, 4]), "generated BMP decodes")
	var top_down := bytes.duplicate()
	top_down.encode_u32(22, -2)
	check(IndexedBmp.decode(top_down).pixels == PackedInt32Array([3, 4, 1, 2]), "signed BMP height")

	var undeclared := bytes.duplicate()
	undeclared.encode_u32(2, 0)
	for size in bytes.size():
		check(not IndexedBmp.decode(undeclared.slice(0, size)).ok, "BMP rejects every truncated prefix")
	var dib := bytes.slice(IndexedBmp.FILE_HEADER_SIZE)
	check(IndexedBmp.decode_dib(dib).pixels == PackedInt32Array([1, 2, 3, 4]), "generated DIB decodes")
	for size in dib.size():
		check(not IndexedBmp.decode_dib(dib.slice(0, size)).ok, "DIB rejects every truncated prefix")

	var palette_path := "user://binary-palette.bmp"
	_store(palette_path, bytes)
	check(Sc2Palette.load_bmp(palette_path).colors == Sc2Palette.index_encoding().colors, "generated palette decodes")
	for bad in [bytes.slice(0, 53), bytes.slice(0, IndexedBmp.PIXEL_OFFSET - 1)]:
		_store(palette_path, bad)
		check(not Sc2Palette.load_bmp(palette_path).is_valid(), "palette rejects truncated header or colors")
	for field in [[14, 0xffffffff], [28, 24], [46, 257]]:
		var bad := bytes.duplicate()
		bad.encode_u32(field[0], field[1])
		_store(palette_path, bad)
		check(not Sc2Palette.load_bmp(palette_path).is_valid(), "palette rejects invalid header fields")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(palette_path))


func _test_indexed_resources() -> void:
	var data_path := "user://binary-resource.dat"
	var index_path := "user://binary-resource.idx"
	var index := "01000000000000000200000002000000".hex_decode()
	_store(data_path, "ABCD".to_ascii_buffer())
	_store(index_path, index)
	var text := TextUsaResource.load_ids(data_path, index_path, PackedInt32Array([1, 2]))
	check(text.ok and text.strings == {1: "AB", 2: "CD"}, "little-endian text index")
	for bad in [index.slice(0, 7), "01000000ffffffff".hex_decode(), "01000000020000000200000001000000".hex_decode()]:
		_store(index_path, bad)
		check(not TextUsaResource.load_ids(data_path, index_path, PackedInt32Array([1])).ok, "text rejects partial, invalid or unordered offsets")

	var data := PackedByteArray()
	data.resize(11004)
	data[1003] = 2 # Phrase zero starts at the second string; phrase one starts at zero.
	data[11000] = 65
	data[11002] = 66
	index = "e803000000000000e9030000f4010000ea030000e8030000eb030000f82a0000".hex_decode()
	_store(data_path, data)
	_store(index_path, index)
	var grammar := DataUsaResource.load_path(data_path, index_path)
	check(grammar.is_valid() and grammar.phrase_bytes(0) == PackedByteArray([66]) and grammar.phrase_bytes(1) == PackedByteArray([65]), "mixed-endian data tables")
	for bad in [index.slice(0, 31), "e8030000ffffffff".hex_decode(), "e803000002000000e903000001000000".hex_decode()]:
		_store(index_path, bad)
		check(not DataUsaResource.load_path(data_path, index_path).is_valid(), "data rejects partial, invalid or unordered offsets")
	_store(index_path, index)
	data[1000] = 0x80
	_store(data_path, data)
	check(not DataUsaResource.load_path(data_path, index_path).is_valid(), "data rejects high-bit phrase offset")
	for path in [data_path, index_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_scenario_picture() -> void:
	var scenario := ScenarioState.new()
	scenario.document = Sc2File.new()
	var chunk := Sc2Chunk.new()
	chunk.chunk_id = "PICT"
	chunk.decoded_payload = "80000000020001001122".hex_decode()
	scenario.document.chunks.append(chunk)
	var picture := scenario.picture_indices()
	check(picture.ok and picture.width == 2 and picture.height == 1 and picture.pixels == PackedByteArray([0x11, 0x22]), "PICT little-endian dimensions")
	for bad in [PackedByteArray(), "80000000020001".hex_decode(), "8000000000000100".hex_decode(), "800000000200010011".hex_decode()]:
		chunk.decoded_payload = bad
		check(not scenario.picture_indices().ok, "PICT rejects invalid header, empty dimensions or incomplete rows")


func _store(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(bytes)
	file.close()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)
