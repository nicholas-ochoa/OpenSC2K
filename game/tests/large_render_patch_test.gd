extends SceneTree
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await check_texture_patch()
	var sprites := Sc2SpriteArchive.load_path("res://../references/DATA/SMALLMED.DAT")
	assert(sprites.is_valid())
	var palette := Sc2Palette.index_encoding()
	for edge in [128, 256, 384, 512]:
		var city := CityState.from_document(EmptyCityTemplate.create(edge))
		var before := CityIsometricRenderer.create_image(city, palette, sprites, CityIsometricRenderer.VIEW_SMALL, 0, false, true, false, false)
		assert(before.ok)
		var dirty := PackedInt32Array()
		for point in [Vector2i(edge - 10, edge - 10), Vector2i(edge / 2, edge - 20), Vector2i(4, 4)]:
			city.set_building_id(point.x, point.y, 0x1d)
			dirty.append(city.index_of(point.x, point.y))
			var full := CityIsometricRenderer.create_image(city, palette, sprites, CityIsometricRenderer.VIEW_SMALL, 0, false, true, false, false)
			var patch := CityIsometricRenderer.patch_static_image(before.image, city, palette, sprites, dirty, CityIsometricRenderer.VIEW_SMALL)
			assert(patch.ok)
			assert(patch.image.get_data() == full.image.get_data(), "Partial draw differs from full draw at %d" % edge)
			before = full
			dirty.clear()
		print("PASS: far, middle, and near edit rendering at %d" % edge)
	quit()

func check_texture_patch() -> void:
	var image := Image.create(8192, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var texture := CityMapTexture.create(image)
	var tiles: Array = texture.get_meta("map_tiles")
	var first: Texture2D = tiles[0].texture
	var second: Texture2D = tiles[1].texture
	image.set_pixel(5, 5, Color.BLUE)
	# Change the backing image outside the dirty area to detect uploads of clean tiles.
	image.set_pixel(5000, 5, Color.GREEN)
	var result := CityMapTexture.update_region(texture, image, Rect2i(5, 5, 1, 1))
	assert(result == texture and tiles[0].texture == first and tiles[1].texture == second)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		assert(first.get_image().get_pixel(5, 5) == Color.BLUE)
		assert(second.get_image().get_pixel(904, 5) == Color.RED)
	print("PASS: texture identity retained; pixel checks require native rendering")
