class_name CitySignForeground
extends RefCounted


static func static_pixels(sampled: Image, masks: Array[Dictionary], bounds: Rect2i) -> Image:
	var mask := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	for entry in masks:
		var image: Image = entry.image
		if image.get_format() != Image.FORMAT_RGBA8:
			image = image.duplicate()
			image.convert(Image.FORMAT_RGBA8)
		var overlap := bounds.intersection(Rect2i(entry.position, image.get_size()))
		if overlap.has_area():
			mask.blend_rect(image, Rect2i(overlap.position - Vector2i(entry.position), overlap.size), overlap.position - bounds.position)
	var source := sampled.duplicate()
	# The RGB conversion makes masked pixels opaque, as in the original index-copy loop.
	source.convert(Image.FORMAT_RGB8)
	source.convert(Image.FORMAT_RGBA8)
	var output := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	output.blit_rect_mask(source, mask, Rect2i(Vector2i.ZERO, bounds.size), Vector2i.ZERO)
	return output

static func add_moving(output: Image, moving: Image, position: Vector2i, bounds: Rect2i) -> void:
	var overlap := bounds.intersection(Rect2i(position, moving.get_size()))
	if not overlap.has_area():
		return
	var source := moving
	if source.get_format() != Image.FORMAT_RGBA8:
		source = source.duplicate()
		source.convert(Image.FORMAT_RGBA8)
	output.blit_rect_mask(source, source, Rect2i(overlap.position - position, overlap.size), overlap.position - bounds.position)

static func used_indices(image: Image) -> Dictionary:
	var result := {}
	var bytes := image.get_data()
	for offset in range(0, bytes.size(), 4):
		if bytes[offset + 3] != 0:
			result[int(bytes[offset])] = true
	return result
