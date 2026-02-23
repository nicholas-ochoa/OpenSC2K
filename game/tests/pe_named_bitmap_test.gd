extends SceneTree


func _initialize() -> void:
	var bytes := PackedByteArray()
	bytes.resize(384)
	bytes.encode_u16(108, 1)
	bytes.encode_u16(110, 1)
	bytes.encode_u32(112, 0x80000080)
	bytes.encode_u32(116, 0x800000c0)
	bytes.encode_u32(120, 7)
	bytes.encode_u32(124, 0x800000d0)

	for name in ["ADVICEU", "城🏙"]:
		var encoded: PackedByteArray = name.to_utf16_buffer()
		bytes.encode_u16(192, encoded.size() / 2)

		for i in encoded.size():
			bytes[194 + i] = encoded[i]

		bytes[194 + encoded.size()] = 0xff # Names are length-prefixed, not terminated.
		assert(PeBitmapResource._named_child_directory(bytes, 64, 96, name) == 256)
		assert(PeBitmapResource._named_child_directory(bytes, 64, 96, "missing") == -1)
		assert(PeBitmapResource._named_child_directory(bytes, 64, 96, "7") == -1)
		assert(PeBitmapResource._numeric_child_directory(bytes, 64, 96, 7) == 272)

		for length in 272:
			assert(PeBitmapResource._named_child_directory(bytes.slice(0, length), 64, 96, name) == -1)

	for change in ["entry_count", "name_offset", "name_length", "leaf_target", "target_offset"]:
		var bad := bytes.duplicate()

		match change:
			"entry_count":
				bad.encode_u16(108, 0xffff)
			"name_offset":
				bad.encode_u32(112, 0xffffffff)
			"name_length":
				bad.encode_u16(192, 0xffff)
			"leaf_target":
				bad.encode_u32(116, 192)
			"target_offset":
				bad.encode_u32(116, 0xffffffff)

		assert(PeBitmapResource._named_child_directory(bad, 64, 96, "城🏙") == -1, change)

	# Independent ImageMagick decoding of read-only in-memory DIBs produced these hashes.
	var expected := {
		"ADVICED": "ac6c2f888d87a64906e1089abd66a601c993a94d0b3511af2ba0b031fb777a08",
		"ADVICEF": "3d373c65db53f1d154e15e1381a3c8ddc68ad4e4c2d693dcc3aa57c3e74c3dc3",
		"ADVICEU": "64b55d17554b37c20b4b6416ffe7bfd3db68cc18e41b6b8c368487b2a0626935",
		"BOOKD": "eeb7f7e5425347b23600018e8573260dee8e7b4deef67697e175ed35795ebc69",
		"BOOKF": "0896ed190613d493ca4a25c69e5cc5aa0a7f9eff492f6d48515e66c89975f9a9",
		"BOOKU": "42c78b8969fe0dbb70e0488054e692e7b347eed62857568b68f54f3e0ae0ab5e",
		"CHECKD": "c3e27aa31f76a946797d98f4ffaaba074c59a345b98a346bd09c728fb1d22aab",
		"CHECKF": "3acdab1fc5085d34a84206bb8bfd4d644978dbee30d1295d6e60f1de9261b079",
		"CHECKU": "3acdab1fc5085d34a84206bb8bfd4d644978dbee30d1295d6e60f1de9261b079",
		"CTL3D_3DCHECK": "5e3730e59388f44f556e310cd39031839504d031f389df35c9fe49670c249ba4",
		"MAPBUTTONIMAGED": "468f3862a968a391edbe168a6bfa5c7310ba2aec92ce33603f77a1e51ba528fd",
		"MAPBUTTONIMAGEU": "b308628b259b919ccbe27bd7b1166779f060569902d88ea2e0803d65a2b82a56",
		"PAPERCLOSED": "cb872c55f2783e812fd39922c224cafe3c6344f25bfef19faf5f839157259630",
		"PAPERCLOSEU": "8c180ef106f593993430dfb47cbb2bcb888cafd6c1d52b796e7080bd3d1e8f14",
	}
	var path := "res://../references/SIMCITY2000/SIMCITY.EXE"

	for name in expected:
		var result := PeBitmapResource.load_named(path, name)
		assert(result.ok, str(result.error))
		var image: Image = result.image
		image.convert(Image.FORMAT_RGBA8)
		var hash := HashingContext.new()
		assert(hash.start(HashingContext.HASH_SHA256) == OK and hash.update(image.get_data()) == OK)
		assert(hash.finish().hex_encode() == expected[name], "named bitmap decoder agreement: " + name)

	for name in ["", "adviceu", "MISSING", "2"]:
		assert(not PeBitmapResource.load_named(path, name).ok)

	assert(PeBitmapResource.load_numeric(path, 2).ok)
	print("PASS: exact UTF-16 resource names, root-relative offsets, numeric separation, all truncated prefixes, malformed directories and all 14 supplied named bitmaps against independent RGBA hashes")
	quit()
