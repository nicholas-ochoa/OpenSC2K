class_name TerrainToolIcons
extends RefCounted


static func stretch() -> ImageTexture:
	# one flat tile sits one level above the surrounding ground
	var image := Image.create(48, 36, false, Image.FORMAT_RGBA8)
	var outer := PackedVector2Array([Vector2(24, 7), Vector2(47, 19), Vector2(24, 31), Vector2(1, 19)])
	var top := PackedVector2Array([Vector2(24, 3), Vector2(32, 7), Vector2(24, 11), Vector2(16, 7)])
	var shades := [Color("8c9e47"), Color("687c32"), Color("87983f"), Color("a6b252")]

	for side in 4:
		var next := (side + 1) % 4
		_fill(image, PackedVector2Array([outer[side], outer[next], top[next], top[side]]), shades[side])

	_fill(image, top, Color("c2c875"))

	return ImageTexture.create_from_image(image)


static func _fill(image: Image, points: PackedVector2Array, color: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			if Geometry2D.is_point_in_polygon(Vector2(x, y) + Vector2(0.5, 0.5), points):
				image.set_pixel(x, y, color)


static func terrain_action(graphics: CityUiGraphics, role: String) -> ImageTexture:
	var image: Image = null if graphics == null else graphics.terrain_icon(role)

	if image != null:
		image.convert(Image.FORMAT_RGBA8)
		var background := image.get_pixel(0, 0)

		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).is_equal_approx(background):
					image.set_pixel(x, y, Color.TRANSPARENT)

		image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	else:
		image = stretch().get_image()
		var ink := Color("fff4b0")

		if role == "level":
			image.fill_rect(Rect2i(9, 6, 30, 3), ink)
		elif role in ["raise", "lower"]:
			image.fill_rect(Rect2i(22, 5, 4, 15), ink)
			var arrow := PackedVector2Array([Vector2(17, 9), Vector2(24, 1), Vector2(31, 9)])

			if role == "lower":
				arrow = PackedVector2Array([Vector2(17, 16), Vector2(24, 24), Vector2(31, 16)])

			_fill(image, arrow, ink)

	return ImageTexture.create_from_image(image)
