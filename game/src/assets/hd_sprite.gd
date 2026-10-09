class_name HdSprite
extends RefCounted
## The full-color art of one indexed city sprite. It changes only the look of
## the sprite. The indexed pixels still give the geometry, masks, and saves.

# RGBA pixels at any density. They cover the width of the sprite and `height`
# logical rows that end at the bottom of the sprite.
var image: Image
var height := 0
# Optional: equal frames from top to bottom, each the size of `image`.
var animation: Image
var frames := 1
var fps := 8


# `source` at `size`. The filter averages premultiplied colors, so transparent
# pixels add no dark edge. The result has straight alpha.
static func scaled(source: Image, size: Vector2i) -> Image:
	var result: Image = source.duplicate()

	if result.get_size() == size:
		return result

	result.convert(Image.FORMAT_RGBA8)
	result.premultiply_alpha()
	result.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)

	for y in result.get_height():
		for x in result.get_width():
			var color := result.get_pixel(x, y)

			if color.a > 0.0:
				result.set_pixel(x, y, Color(color.r / color.a, color.g / color.a, color.b / color.a, color.a))
			else:
				result.set_pixel(x, y, Color.TRANSPARENT)

	return result
