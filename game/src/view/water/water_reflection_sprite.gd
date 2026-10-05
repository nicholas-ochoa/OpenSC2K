class_name WaterReflectionSprite
extends RefCounted
## An unoccluded floating sprite reflected about its actual waterline columns.
@warning_ignore_start("integer_division")

var position := Vector2i.ZERO
var level := 0
var image: Image
var emission: Image


static func create(source: Image, lights: Image, origin: Vector2i, water_level: int, palette: Sc2Palette = null) -> WaterReflectionSprite:
	if source == null or water_level < 0:
		return null
	var result := WaterReflectionSprite.new()
	result.position = origin
	result.level = water_level
	result.image = Image.create(source.get_width(), source.get_height() * 2, false, Image.FORMAT_RGBA8)
	result.emission = Image.create(source.get_width(), source.get_height() * 2, false, Image.FORMAT_RGBA8)
	var columns := hull_columns(source, palette)
	for x in source.get_width():
		var contact := columns[x].y
		if contact < 0:
			continue
		for y in range(columns[x].x, contact):
			var pixel := source.get_pixel(x, y)
			if pixel.a == 0:
				continue
			var reflected_y := 2 * contact - y - 1
			pixel.a *= maxf(0.0, 1.0 - float(reflected_y - contact) / 255.0)
			result.image.set_pixel(x, reflected_y, pixel)
			if lights != null:
				result.emission.set_pixel(x, reflected_y, lights.get_pixel(x, y))
	return result


## Sprite wakes already lie on the water plane. They are neither a reflecting
## object nor an anchor for the hull. Use the connected body, not scattered foam.
## This mask affects reflections only; floating occlusion and original art stay intact.
static func hull_columns(source: Image, palette: Sc2Palette) -> Array[Vector2i]:
	var columns: Array[Vector2i] = []
	columns.resize(source.get_width())
	if palette == null or not palette.is_valid() or palette.is_index_encoding:
		var silhouette := IsometricFloatingOcclusion.waterline(source)
		for x in silhouette.size():
			columns[x] = Vector2i(0, silhouette[x])
		return columns
	var width := source.get_width()
	var height := source.get_height()
	var water := PackedByteArray()
	water.resize(256)
	for index in 256:
		var color := palette.color(index)
		# Include the cyan and pale blue foam ramp, not just the dark water blues.
		water[index] = int(color.b > color.r * 1.2 and color.b >= color.g * 0.95 and color.b > 0.15)
	var body := PackedByteArray()
	body.resize(width * height)
	for y in height:
		for x in width:
			var pixel := source.get_pixel(x, y)
			body[y * width + x] = int(pixel.a > 0.0 and water[roundi(pixel.r * 255.0)] == 0)
	var largest := PackedInt32Array()
	for seed in body.size():
		if body[seed] == 0:
			continue
		var component := PackedInt32Array([seed])
		body[seed] = 0
		var cursor := 0
		while cursor < component.size():
			var at := component[cursor]
			cursor += 1
			# Diagonal pixels belong to the same isometric hull as well.
			for delta: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
				Vector2i.LEFT, Vector2i.RIGHT, Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
				var next := Vector2i(at % width, at / width) + delta
				if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
					continue
				var offset := next.y * width + next.x
				if body[offset] != 0:
					body[offset] = 0
					component.append(offset)
		if component.size() > largest.size():
			largest = component
	columns.fill(Vector2i(height, -1))
	for at in largest:
		var column := columns[at % width]
		columns[at % width] = Vector2i(mini(column.x, at / width), maxi(column.y, at / width + 1))
	return columns
