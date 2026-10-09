extends SceneTree


func _initialize() -> void:
	var sprites := CityLifeSprites.new()
	var source := Image.new()
	assert(source.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/city_life/vehicles_b.png")) == OK)
	assert(source.get_size() == Vector2i(64, 540))
	var sizes := [Vector2i(9, 6), Vector2i(12, 8), Vector2i(14, 9)]
	for kind in 3:
		for variant in 18:
			for direction in 4:
				var sprite := sprites.sprite(false, variant, direction, 0, kind)
				var frame := source.get_region(Rect2i(Vector2i(direction * 16, (kind * 18 + variant) * 10), sizes[kind]))
				assert(sprite.get_size() == sizes[kind])
				assert(sprite.get_data() == frame.get_data(), "Imported Set B frames must preserve every approved RGBA pixel")
				assert(sprite == sprites.sprite(false, variant, direction, 1, kind), "Vehicle frames are shared across gait phases")
				assert(not sprite.is_invisible())
	# Walking animation must stay independent of the vehicle atlas.
	var person := sprites.sprite(true, 2, 0, 0)
	assert(person.get_size() == Vector2i(3, 6))
	assert(person.get_data() != sprites.sprite(true, 2, 0, 1).get_data())
	print("PASS: all 216 Set B frames preserve approved native RGBA pixels, directions, dimensions and caching")
	quit()
