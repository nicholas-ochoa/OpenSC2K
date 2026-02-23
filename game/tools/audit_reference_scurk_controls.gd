extends SceneTree
## Check icon dimensions and bit depth.


func _initialize() -> void:
	var path := "res://../references/SIMCITY2000/WINSCURK.EXE"
	var hashing := HashingContext.new()
	assert(hashing.start(HashingContext.HASH_SHA256) == OK)
	assert(hashing.update(FileAccess.get_file_as_bytes(path)) == OK)
	assert(hashing.finish().hex_encode() == "fb8fdcbe3903f797b5cbb5bf5f3663d2d1337723e8459647f2dee8088f2467fc")

	for id in ScurkGraphics.CONTROL_IDS:
		var source := PeBitmapResource.load_numeric_dib(path, id)
		assert(source.ok and source.width == 20 and source.height == 20 and source.compression == 0)
		assert(source.bits_per_pixel == (8 if id in [21006, 21007] else 4))
		var original: Image = PeBitmapResource.load_numeric(path, id).image
		original.convert(Image.FORMAT_RGBA8)

	print("PASS: supplied SCURK hash, all 27 native control sizes and bit depths")
	quit()
