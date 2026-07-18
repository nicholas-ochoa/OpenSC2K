class_name CityMapTexture
extends RefCounted

const TILE_EDGE := 4096


static func create(image: Image) -> CityMapSource:
	if image.get_width() <= TILE_EDGE and image.get_height() <= TILE_EDGE:
		return CityMapSource.whole(ImageTexture.create_from_image(image))

	var result := CityMapSource.new(image.get_size())

	for y in range(0, image.get_height(), TILE_EDGE):
		for x in range(0, image.get_width(), TILE_EDGE):
			var bounds := Rect2i(x, y, mini(TILE_EDGE, image.get_width() - x), mini(TILE_EDGE, image.get_height() - y))
			var texture := ImageTexture.create_from_image(image.get_region(bounds))
			result.tiles.append(CityMapSource.TileEntry.new(Vector2(x, y), texture.get_size(), texture))

	return result


static func update_region(source: CityMapSource, image: Image, dirty: Rect2i) -> CityMapSource:
	if source == null or source.size != image.get_size():
		return create(image)

	if not source.tiles.is_empty():
		for tile in source.tiles:
			var bounds := Rect2i(Vector2i(tile.position), Vector2i(tile.texture.get_size()))

			if bounds.intersects(dirty):
				(tile.texture as ImageTexture).update(image.get_region(bounds))
		return source

	if source.texture is ImageTexture:
		(source.texture as ImageTexture).update(image)

		return source

	return create(image)
