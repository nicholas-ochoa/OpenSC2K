extends SceneTree
## Check UI resource metadata and the toolbar command table.


func _initialize() -> void:
	_run()
	quit()


func _run() -> void:
	var directory := PeBitmapResource._load_resource_directory("res://../references/SIMCITY.EXE")
	assert(directory.ok, str(directory.error))
	var bytes: PackedByteArray = directory.bytes
	var hashing := HashingContext.new()
	assert(hashing.start(HashingContext.HASH_SHA256) == OK)
	assert(hashing.update(bytes) == OK)
	assert(hashing.finish().hex_encode() == "4f560f7a19586670a8ccb3e0ae69889679699ebf4de706a7a46b2098dd838e69")
	var offset := PeBitmapResource._rva_to_offset(bytes, 0xe62d8, directory.section_offset, directory.section_count)
	var expected := [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 28, 29, 30, 31, 33, 32, 34, 35, 36, 37, 38, 235, 39, 40, 41, 42, 43, 44, 45]
	for i in expected.size():
		assert(bytes.decode_u32(offset + i * 4) == expected[i])
	print("Confirmed 34 toolbar command IDs at 0x004e62d8: ", expected)
	for id in [2, 178, 247]:
		var result := PeBitmapResource.load_numeric("res://../references/SIMCITY.EXE", id)
		assert(result.ok, str(result.error))
		var size: Vector2i = {2: Vector2i(865, 23), 178: Vector2i(14, 154), 247: Vector2i(234, 20)}[id]
		var image: Image = result.image
		assert(image.get_size() == size)
		var background := image.get_pixel(0, 0)
		var count := 0
		for y in size.y:
			for x in size.x:
				count += int(image.get_pixel(x, y) != background)
		print("%d: %dx%d, background RGB %s, %d other pixels" % [id, size.x, size.y, background.to_html(false), count])
	print("PASS: supplied UI strip dimensions and toolbar command table")
