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
