extends SceneTree


func _initialize() -> void:
	var bounds := Rect2i(100, 200, 53, 31)

	for format in [Image.FORMAT_RGBA8, Image.FORMAT_LA8]:
		var sampled := _image(bounds.size, format, 1)
		var masks: Array[Dictionary] = [
			{"image": _image(Vector2i(33, 29), format, 3), "position": Vector2i(88, 190)},
			{"image": _image(Vector2i(42, 27), format, 7), "position": Vector2i(120, 211)},
		]
		var expected := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
		expected.fill(Color.TRANSPARENT)

		for entry in masks:
			var overlap := bounds.intersection(Rect2i(entry.position, entry.image.get_size()))

			for y in range(overlap.position.y, overlap.end.y):
				for x in range(overlap.position.x, overlap.end.x):
					if entry.image.get_pixel(x - entry.position.x, y - entry.position.y).a != 0:
						var index := sampled.get_pixel(x - bounds.position.x, y - bounds.position.y).r8
						expected.set_pixel(x - bounds.position.x, y - bounds.position.y, Color8(index, index, index, 255))

		var actual := CitySignForeground.static_pixels(sampled, masks, bounds)
		assert(actual.get_data() == expected.get_data(), "Static mask pixels differ from the reference loop")
		var moving := _image(Vector2i(30, 25), format, 11)
		var position := Vector2i(115, 220)

		for y in range(220, bounds.end.y):
			for x in range(115, 145):
				var pixel := moving.get_pixel(x - position.x, y - position.y)

				if pixel.a != 0:
					expected.set_pixel(x - bounds.position.x, y - bounds.position.y, Color8(pixel.r8, pixel.r8, pixel.r8, 255))

		CitySignForeground.add_moving(actual, moving, position, bounds)
		assert(actual.get_data() == expected.get_data(), "Moving mask pixels differ from the reference loop")
		var used := CitySignForeground.used_indices(actual)

		for y in bounds.size.y:
			for x in bounds.size.x:
				var pixel := actual.get_pixel(x, y)

				if pixel.a != 0:
					assert(used.has(pixel.r8))

	print("PASS: native sign composition matches clipped static and moving pixel loops in RGBA8 and LA8")
	quit()


func _image(size: Vector2i, format: Image.Format, seed: int) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)

	for y in size.y:
		for x in size.x:
			var index := (x * 19 + y * 37 + seed) & 255
			image.set_pixel(x, y, Color8(index, index, index, 0 if (x + y + seed) % 3 == 0 else 255))

	image.convert(format)

	return image
