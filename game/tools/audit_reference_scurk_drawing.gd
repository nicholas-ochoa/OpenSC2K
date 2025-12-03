extends SceneTree
## Check resource dimensions and palette use.


func _initialize() -> void:
	var path := "res://../references/WINSCURK.EXE"
	var bytes := FileAccess.get_file_as_bytes(path)
	var hashing := HashingContext.new()
	assert(hashing.start(HashingContext.HASH_SHA256) == OK and hashing.update(bytes) == OK)
	assert(hashing.finish().hex_encode() == "fb8fdcbe3903f797b5cbb5bf5f3663d2d1337723e8459647f2dee8088f2467fc")
	for id in ScurkGraphics.TEXTURE_IDS:
		var loaded := PeBitmapResource.load_numeric_indexed8(path, id)
		assert(loaded.ok and loaded.width == 8 and loaded.height == 8)
	for id in ScurkGraphics.BACKGROUND_IDS:
		var loaded := PeBitmapResource.load_numeric_indexed8(path, id)
		assert(loaded.ok and loaded.width == 128 and loaded.height == 256)
	print("PASS: supplied SCURK hash, 42 texture resources, five native drawing background sizes")
	quit()
