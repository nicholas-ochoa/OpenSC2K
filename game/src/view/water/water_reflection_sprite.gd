class_name WaterReflectionSprite
extends RefCounted
## An unoccluded floating sprite reflected about its actual waterline columns.

var position := Vector2i.ZERO
var level := 0
var image: Image
var emission: Image


static func create(source: Image, lights: Image, origin: Vector2i, water_level: int) -> WaterReflectionSprite:
	if source == null or water_level < 0:
		return null
	var result := WaterReflectionSprite.new()
	result.position = origin
	result.level = water_level
	result.image = Image.create(source.get_width(), source.get_height() * 2, false, Image.FORMAT_RGBA8)
	result.emission = Image.create(source.get_width(), source.get_height() * 2, false, Image.FORMAT_RGBA8)
	var columns := IsometricFloatingOcclusion.waterline(source)
	for x in source.get_width():
		if columns[x] < 0:
			continue
		for y in columns[x]:
			var pixel := source.get_pixel(x, y)
			if pixel.a == 0:
				continue
			var reflected_y := 2 * columns[x] - y - 1
			pixel.a *= maxf(0.0, 1.0 - float(reflected_y - columns[x]) / 255.0)
			result.image.set_pixel(x, reflected_y, pixel)
			if lights != null:
				result.emission.set_pixel(x, reflected_y, lights.get_pixel(x, y))
	return result
