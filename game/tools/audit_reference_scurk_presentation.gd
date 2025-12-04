extends SceneTree
## Check resource dimensions and bit depth.


func _initialize() -> void:
	var path := "res://../references/WINSCURK.EXE"
	var hashing := HashingContext.new()
	assert(hashing.start(HashingContext.HASH_SHA256) == OK)
	assert(hashing.update(FileAccess.get_file_as_bytes(path)) == OK)
	assert(hashing.finish().hex_encode() == "fb8fdcbe3903f797b5cbb5bf5f3663d2d1337723e8459647f2dee8088f2467fc")
	for id in ScurkGraphics.PRESENTATION_SIZES:
		var source := PeBitmapResource.load_numeric_dib(path, id)
		assert(source.ok and Vector2i(source.width, source.height) == ScurkGraphics.PRESENTATION_SIZES[id])
		assert(source.bits_per_pixel == 8 and source.compression == 0)
		var original: Image = PeBitmapResource.load_numeric(path, id).image
		original.convert(Image.FORMAT_RGBA8)
	print("PASS: supplied SCURK hash, two 128 by 256 mascot frames, 640 by 480 title, native bit depths; no source images exported")
	quit()
