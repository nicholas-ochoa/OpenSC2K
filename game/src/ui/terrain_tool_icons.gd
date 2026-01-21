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
