extends SceneTree


func _initialize() -> void:
	var stream := PackedByteArray([
		3, 171, 0, 3, 172, 173, 174, 0, 2, 171, 0, 0,
		0, 2, 2, 0, 2, 7, 0, 2, 2, 0, 2, 8, 0, 0,
		0, 8, 0, 1, 2, 3, 4, 5, 6, 7, 0, 1,
	])
	var decoded := WindowsBitmapRle8.decode(stream, 8, 3)
	assert(decoded.ok and decoded.consumed == stream.size())
	assert(decoded.pixels == PackedInt32Array([
		0, 1, 2, 3, 4, 5, 6, 7,
		0, 0, 7, 7, 0, 0, 8, 8,
		171, 171, 171, 172, 173, 174, 171, 171,
	]))
	var delta := WindowsBitmapRle8.decode(PackedByteArray([2, 4, 0, 2, 3, 1, 1, 9, 0, 1]), 8, 3)
	assert(delta.ok and delta.pixels.count(4) == 2 and delta.pixels[8 + 5] == 9)
	assert(WindowsBitmapRle8.decode(PackedByteArray([8, 5, 0, 0, 0, 1]), 8, 1).ok)
	assert(WindowsBitmapRle8.decode(PackedByteArray([0, 3, 4, 5, 6, 255, 0, 1]), 8, 1).pixels.slice(0, 3) == PackedInt32Array([4, 5, 6]))

	for bad in [
		[], [1], [8, 5], [9, 5, 0, 1], [0, 3, 1, 2, 3],
		[0, 2, 1], [0, 2, 9, 0, 0, 1], [0, 2, 0, 1, 0, 1],
		[0, 0, 0, 0, 0, 1], [0, 0, 1, 3, 0, 1],
		[0, 9, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 0, 1],
	]:
		assert(not WindowsBitmapRle8.decode(PackedByteArray(bad), 8, 1).ok, str(bad))

	for size in [Vector2i(0, 1), Vector2i(1, -1), Vector2i(4097, 1), Vector2i(1, 4097)]:
		assert(not WindowsBitmapRle8.decode(PackedByteArray([0, 1]), size.x, size.y).ok)

	var path := "res://../references/SIMCITY2000/WINSCURK.EXE"
	# Independent ImageMagick BMP decoding produced these RGBA hashes.
	var expected := {
		1202: "3fab3792f632fd2a747bc75136cb5ad5dc8cd8a7ac741f8a5977b36a21b44f6d",
		1208: "c5510ffda5519e8fcb7112082a988c6b5c25cdb1a6133a0e75ade1534d38775e",
		1209: "31e8a835a37857e59fd1d8a0126f01768015edabd7ede7cdb701ebdf1a0d8b55",
		22005: "7809189625ebaca58f28431311574cb53a307f37ae6a44fdfd99a4720d089cb1",
	}

	for id in expected:
		var source := PeBitmapResource.load_numeric_dib(path, id)
		assert(source.ok and source.compression == 1 and source.bits_per_pixel == 8)
		var indexed := PeBitmapResource.load_numeric_indexed8(path, id)
		assert(indexed.ok and indexed.pixels.size() == source.width * source.height)
		var rendered := PeBitmapResource.load_numeric(path, id)
		assert(rendered.ok, str(rendered.error))
		var image: Image = rendered.image
		image.convert(Image.FORMAT_RGBA8)
		var hash := HashingContext.new()
		assert(hash.start(HashingContext.HASH_SHA256) == OK and hash.update(image.get_data()) == OK)
		assert(hash.finish().hex_encode() == expected[id], "independent decoder agreement for %d" % id)

	for change in ["top_down", "palette", "truncated", "size", "planes"]:
		var bad := PeBitmapResource.load_numeric_dib(path, 1202)

		match change:
			"top_down":
				bad.height = 0xffffffff - 24
			"palette":
				bad.color_count = 257
			"truncated":
				bad.bytes.resize(1040)
			"size":
				bad.bytes.encode_u32(20, 0xffffffff)
			"planes":
				bad.bytes.encode_u16(12, 2)

		assert(not PeBitmapResource._decode_indexed8_dib(bad, 1202).ok, change)

	print("PASS: Windows RLE8 runs, absolute padding, deltas, bottom-up order, exact indices, malformed inputs and all four supplied compressed resources against independent RGBA hashes")
	quit()
