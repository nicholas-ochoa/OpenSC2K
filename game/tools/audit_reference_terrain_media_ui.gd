extends SceneTree
## Check source tables, image dimensions, and duplicate loose bitmaps.


func _initialize() -> void:
	var path := "res://../references/SIMCITY2000/SIMCITY.EXE"
	var directory := PeBitmapResource._load_resource_directory(path)
	assert(directory.ok)
	var bytes: PackedByteArray = directory.bytes
	var hashing := HashingContext.new()
	assert(hashing.start(HashingContext.HASH_SHA256) == OK)
	assert(hashing.update(bytes) == OK)
	assert(hashing.finish().hex_encode() == "4f560f7a19586670a8ccb3e0ae69889679699ebf4de706a7a46b2098dd838e69")
	var commands := [64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 80, 81, 82, 83, 84, 85, 86, 87]
	var offset := PeBitmapResource._rva_to_offset(bytes, 0xe6360, directory.section_offset, directory.section_count)
	for i in 23:
		assert(bytes.decode_u32(offset + i * 4) == commands[i])
	for table in [0xeaa90, 0xeaaa8, 0xeaac0]:
		offset = PeBitmapResource._rva_to_offset(bytes, table, directory.section_offset, directory.section_count)
		for i in 5:
			var expected := 262 + i * 2 if table == 0xeaa90 else 261 + i * 2
			if table == 0xeaac0:
				expected = [5, 1, 2, 3, 4][i]
			assert(bytes.decode_u32(offset + i * 4) == expected)
	var original := CityUiGraphics.load_original("res://../references/SIMCITY2000")
	assert(original.terrain.size() == 3 and original.media.size() == 20)
	for id in CityUiGraphics.TERRAIN_SIZES:
		assert(original.terrain[id].get_size() == CityUiGraphics.TERRAIN_SIZES[id])
	for id in CityUiGraphics.MEDIA_IDS:
		assert(original.media[id].get_size() == CityUiGraphics.media_size(id))
	for i in 5:
		for pressed in [false, true]:
			var native: Image = original.media_image(i, pressed).duplicate()
			var loose: Image = original.media["WILL%d%s.BMP" % [i, "D" if pressed else "U"]].duplicate()
			native.convert(Image.FORMAT_RGBA8)
			loose.convert(Image.FORMAT_RGBA8)
			assert(native.get_data() == loose.get_data(), "PE/loose media duplicates")
	var native: Image = original.terrain[207].get_region(Rect2i(0, 0, 341, 19))
	var loose: Image = original.terrain["TERRAIN.BMP"].duplicate()
	native.convert(Image.FORMAT_RGBA8)
	loose.convert(Image.FORMAT_RGBA8)
	var same := native.get_data() == loose.get_data()
	print("Terrain PE/loose first 341 columns have identical RGBA: ", same)
	for i in 19:
		var role: String = CityUiGraphics.TERRAIN_ROLES[i]
		var icon := original.terrain_icon(role)
		assert(icon.get_size() == CityUiGraphics.terrain_region(i).size)
		if i < 16:
			assert(_rgba(icon) == _rgba(original.terrain_icon(role, true)), "PE/loose terrain role: " + role)
	print("PASS: supplied executable hash, 23 terrain command IDs, five normal/pressed button pairs, action IDs, all native sizes, ten PE/loose media duplicates; no source pixels exported")
	quit()


func _rgba(image: Image) -> PackedByteArray:
	var copy := image.duplicate()
	copy.convert(Image.FORMAT_RGBA8)
	return copy.get_data()
