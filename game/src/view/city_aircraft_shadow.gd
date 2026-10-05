class_name CityAircraftShadow
extends RefCounted
## Black alpha silhouettes blend with the current ground, including moving water.

const OPACITY := 0.35


static func create(source: Image, occluder: Image, origin: Vector2i, limit: Vector2i) -> Image:
	var pixels := source.get_data()
	var width := source.get_width()
	var visible := false
	var foreground := occluder.get_data() if occluder != null else PackedByteArray()
	for y in source.get_height():
		for x in width:
			var offset := (y * width + x) * 4
			var alpha := int(round(pixels[offset + 3] * OPACITY))
			var point := origin + Vector2i(x, y)
			if point.x < 0 or point.y < 0 or point.x >= limit.x or point.y >= limit.y \
					or (not foreground.is_empty() and foreground[offset + 3] > 0):
				alpha = 0
			pixels[offset] = 0
			pixels[offset + 1] = 0
			pixels[offset + 2] = 0
			pixels[offset + 3] = alpha
			visible = visible or alpha > 0
	return Image.create_from_data(width, source.get_height(), false, Image.FORMAT_RGBA8, pixels) if visible else null
