extends SceneTree
## Check source dimensions, palette tables, and file paths.

const PATHS := {0x4e6120: "titlescr.bmp", 0x4e6130: "presents.bmp", 0x4e61c0: "\\about.bmp", 0x4e7294: "\\pal_mstr.bmp", 0x4eaa14: "\\2000win.bmp", 0x4eac8c: "CTL3D32.DLL"}


func _initialize() -> void:
	var directory := PeBitmapResource._load_resource_directory("res://../references/SIMCITY2000/SIMCITY.EXE")
	assert(directory.ok)
	var bytes: PackedByteArray = directory.bytes
	assert(_sha256(bytes) == "4f560f7a19586670a8ccb3e0ae69889679699ebf4de706a7a46b2098dd838e69")

	for address in PATHS:
		var expected: String = PATHS[address]
		var offset := PeBitmapResource._rva_to_offset(bytes, address - 0x400000, directory.section_offset, directory.section_count)
		assert(bytes.slice(offset, offset + expected.length()).get_string_from_ascii() == expected)

	assert(FileAccess.file_exists("res://../references/SIMCITY2000/BITMAPS/PRESNTS.BMP"))
	assert(not FileAccess.file_exists("res://../references/SIMCITY2000/BITMAPS/PRESENTS.BMP"))
	var original := CityUiGraphics.load_original("res://../references/SIMCITY2000")

	for id in CityUiGraphics.PRESENTATION_SIZES:
		var bmp := FileAccess.get_file_as_bytes("res://../references/SIMCITY2000/BITMAPS/" + id)
		var size: Vector2i = CityUiGraphics.PRESENTATION_SIZES[id]
		assert(bmp.decode_u16(28) == 8)
		assert(bmp.decode_u32(18) == size.x and bmp.decode_u32(22) == size.y)
		assert(original.presentation[id].get_size() == size)
		var image: Image = original.presentation[id].duplicate()
		image.convert(Image.FORMAT_RGBA8)

	var hashes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../data/formats/city-presentation-palette-hashes.json"))

	for id in hashes:
		var bmp := FileAccess.get_file_as_bytes("res://../references/SIMCITY2000/BITMAPS/" + str(id))
		var offset := 14 + bmp.decode_u32(14)
		assert(_sha256(bmp.slice(offset, offset + 1024)) == hashes[id])
		assert(original.presentation_palettes[id].colors == Sc2Palette.load_bmp("res://../references/SIMCITY2000/BITMAPS/" + str(id)).colors)

	print("PASS: supplied executable paths and hash, presents/PRESNTS filename difference, eight native bitmap dimensions, three exact ordered palettes; no source raster exported")
	quit()


func _sha256(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	assert(hashing.start(HashingContext.HASH_SHA256) == OK and hashing.update(bytes) == OK)

	return hashing.finish().hex_encode()
