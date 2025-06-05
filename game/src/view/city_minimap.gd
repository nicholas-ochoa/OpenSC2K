class_name CityMinimap
extends RefCounted

const DIRT_COLORS := [129, 128, 127, 126, 125, 124, 123, 122, 121, 120, 119, 118, 117, 116]


static func create_image(city: CityState, palette: Sc2Palette, mode := "structures") -> Image:
	var image := Image.create(CityState.MAP_SIZE, CityState.MAP_SIZE, false, Image.FORMAT_RGBA8)
	for x in CityState.MAP_SIZE:
		for y in CityState.MAP_SIZE:
			var color := _base_color(city, palette, x, y)
			match mode:
				"zones":
					color = _zone_color(city, palette, x, y, color)
				"power":
					color = _power_color(city, palette, x, y, color)
				"water":
					color = _water_color(city, palette, x, y, color)
			image.set_pixel(x, y, color)
	return image


static func _base_color(city: CityState, palette: Sc2Palette, x: int, y: int) -> Color:
	var building := city.building_id(x, y)
	if building >= 0x06 and building <= 0x0c:
		return palette.color(67)
	if building >= 0x01 and building <= 0x05:
		return palette.color(53)
	if building != 0:
		return palette.color(0)
	if city.is_water(x, y) or city.terrain_id(x, y) >= 0x10:
		return palette.color(98)
	return palette.color(DIRT_COLORS[mini(city.land_altitude(x, y), DIRT_COLORS.size() - 1)])


static func _zone_color(
	city: CityState, palette: Sc2Palette, x: int, y: int, fallback: Color
) -> Color:
	match city.zone_id(x, y):
		1, 2:
			return palette.color(59)
		3, 4:
			return palette.color(92)
		5, 6:
			return palette.color(50)
		7:
			return Color8(130, 140, 90)
		8:
			return Color8(150, 150, 160)
		9:
			return Color8(70, 140, 180)
	return fallback


static func _power_color(
	city: CityState, _palette: Sc2Palette, x: int, y: int, fallback: Color
) -> Color:
	if city.is_powered(x, y):
		return Color8(255, 232, 76)
	if city.is_powerable(x, y):
		return Color8(180, 65, 47)
	return fallback.darkened(0.55)


static func _water_color(
	city: CityState, _palette: Sc2Palette, x: int, y: int, fallback: Color
) -> Color:
	if city.is_watered(x, y):
		return Color8(78, 198, 255)
	if city.is_piped(x, y):
		return Color8(50, 112, 180)
	return fallback.darkened(0.55)
