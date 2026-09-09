@static_unload
class_name CityViewConfigurations
extends IsometricConstants


static var _small := CityViewConfiguration.new(VIEW_SMALL, 4,
	Vector2i(8, 5), Vector2i(4, 2), 3, Vector2i(8, 128), 0)
static var _medium := CityViewConfiguration.new(VIEW_MEDIUM, 2,
	Vector2i(16, 9), Vector2i(8, 4), 6, Vector2i(16, 256), 500)
static var _large := CityViewConfiguration.new(VIEW_LARGE, 1,
	Vector2i(TILE_WIDTH, TILE_HEIGHT), Vector2i(HALF_WIDTH, HALF_HEIGHT),
	ALTITUDE_STEP, Vector2i(SIDE_MARGIN, TOP_MARGIN), 1000)


static func for_size(view_size: int) -> CityViewConfiguration:
	match view_size:
		VIEW_SMALL:
			return _small
		VIEW_MEDIUM:
			return _medium
		VIEW_LARGE:
			return _large

	return null
