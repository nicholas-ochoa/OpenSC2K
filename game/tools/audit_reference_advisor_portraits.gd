extends SceneTree
## Read-only supplied executable portrait table, metadata and artwork audit.


func _initialize() -> void:
	var path := "res://../references/SIMCITY2000/SIMCITY.EXE"
	var bytes := FileAccess.get_file_as_bytes(path)
	var hashing := HashingContext.new()
	assert(hashing.start(HashingContext.HASH_SHA256) == OK)
	assert(hashing.update(bytes) == OK)
	assert(hashing.finish().hex_encode() == "4f560f7a19586670a8ccb3e0ae69889679699ebf4de706a7a46b2098dd838e69")
	# Supplied-build DWORD portrait table at VA 0x004e6c40, file offset 0xd9e40.
	for i in 8:
		assert(bytes.decode_u32(0xd9e40 + i * 4) == CityUiGraphics.PORTRAIT_IDS[i])
	# The 33 advice strings are IDs 294 through 326, indexed separately.
	for i in 33:
		assert(bytes.decode_u32(0xd9db8 + i * 4) == 294 + i)
	var original := CityUiGraphics.load_original("res://../references/SIMCITY2000")
	assert(original.portraits.keys() == CityUiGraphics.PORTRAIT_IDS)
	for id in CityUiGraphics.PORTRAIT_IDS:
		var dib := PeBitmapResource.load_numeric_dib(path, id)
		assert(dib.ok and Vector2i(dib.width, dib.height) == Vector2i(64, 82))
		assert(dib.bits_per_pixel == 8 and dib.compression == 0)
		var image: Image = original.portraits[id]
		image.convert(Image.FORMAT_RGBA8)
	print("PASS: supplied executable hash, portrait/advice resource tables, eight 64 by 82 uncompressed indexed portraits, original loading; no original raster exported")
	quit()
