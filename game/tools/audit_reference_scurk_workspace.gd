extends SceneTree
## Check resource metadata and masks.


func _initialize() -> void:
	var path := "res://../references/SIMCITY2000/WINSCURK.EXE"
	var hashing := HashingContext.new()
	assert(hashing.start(HashingContext.HASH_SHA256) == OK)
	assert(hashing.update(FileAccess.get_file_as_bytes(path)) == OK)
	assert(hashing.finish().hex_encode() == "fb8fdcbe3903f797b5cbb5bf5f3663d2d1337723e8459647f2dee8088f2467fc")
	for id in ScurkGraphics.WORKSPACE_SIZES:
		var source := PeBitmapResource.load_numeric_dib(path, id)
		assert(source.ok and Vector2i(source.width, source.height) == ScurkGraphics.WORKSPACE_SIZES[id])
		if id in [21008, 21009]:
			var mask := PeBitmapResource.load_numeric_indexed8(path, id)
			assert(mask.ok and mask.width == 8 and mask.height == 8)
			assert(mask.pixels.count(255) == (12 if id == 21008 else 21))
	print("PASS: supplied SCURK hash, 36 native dimensions, two functional round masks; no original images exported")
	quit()
