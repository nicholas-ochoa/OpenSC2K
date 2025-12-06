extends SceneTree
## Print source metadata.


func _initialize() -> void:
	var resource := PeBitmapResource._load_resource_directory("res://../references/SIMCITY.EXE")
	assert(resource.ok)
	var bytes: PackedByteArray = resource.bytes
	assert(_sha256(bytes) == "4f560f7a19586670a8ccb3e0ae69889679699ebf4de706a7a46b2098dd838e69")
	var offset := PeBitmapResource._rva_to_offset(bytes, 0xea428, resource.section_offset, resource.section_count)
	var table := bytes.slice(offset, offset + 136)
	assert(_sha256(table) == "6e61f6cfbeffc061ac1d82df6a82a51bc9fbbbd8370514837281ac7a947066d3")
	for i in 68:
		assert(table.decode_u16(i * 2) == NewspaperPicture.STORY_PICTURES[i])
	# The next DWORD is a paper-name string ID, not another picture entry.
	assert(bytes.decode_u32(offset + 136) == 360)
	var original := CityUiGraphics.load_original("res://../references")
	assert(original.notices.size() == 12)
	for id in CityUiGraphics.NOTICE_IDS:
		var bmp := FileAccess.get_file_as_bytes("res://../references/BITMAPS/%d.BMP" % id)
		assert(bmp.slice(0, 2).get_string_from_ascii() == "BM")
		assert(bmp.decode_u16(28) == 8)
		assert(bmp.decode_u32(18) == (154 if id == 411 else 155) and bmp.decode_u32(22) == 100)
		var image: Image = original.notices[id].duplicate()
		image.convert(Image.FORMAT_RGBA8)
	print("PASS: supplied executable hash, 68-word picture mapping and adjacent-data boundary, twelve original native indexed bitmaps; no original pixels exported")
	quit()


func _sha256(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	assert(hashing.start(HashingContext.HASH_SHA256) == OK and hashing.update(bytes) == OK)
	return hashing.finish().hex_encode()
