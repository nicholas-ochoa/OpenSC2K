class_name CityMapTexture
extends RefCounted

const TILE_EDGE := 4096


static func create(image: Image) -> Texture2D:
	if image.get_width() <= TILE_EDGE and image.get_height() <= TILE_EDGE:
		return ImageTexture.create_from_image(image)

	var result := PlaceholderTexture2D.new()
	result.size = image.get_size()
	var tiles: Array[Dictionary] = []

	for y in range(0, image.get_height(), TILE_EDGE):
		for x in range(0, image.get_width(), TILE_EDGE):
			var bounds := Rect2i(x, y, mini(TILE_EDGE, image.get_width() - x), mini(TILE_EDGE, image.get_height() - y))
			tiles.append({"position": Vector2(x, y), "texture": ImageTexture.create_from_image(image.get_region(bounds))})

	result.set_meta("map_tiles", tiles)

	return result


static func update_region(texture: Texture2D, image: Image, dirty: Rect2i) -> Texture2D:
	if texture == null or texture.get_size() != Vector2(image.get_size()):
		return create(image)

	if texture.has_meta("map_tiles"):
		for tile: Dictionary in texture.get_meta("map_tiles"):
			var bounds := Rect2i(Vector2i(tile.position), Vector2i(tile.texture.get_size()))

			if bounds.intersects(dirty):
				(tile.texture as ImageTexture).update(image.get_region(bounds))
		return texture

	if texture is ImageTexture:
		(texture as ImageTexture).update(image)

		return texture

	return create(image)
