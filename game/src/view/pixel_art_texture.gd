class_name PixelArtTexture
extends Texture2D
# Draws a pixel-art texture with a whole number of screen pixels for each
# artwork pixel at the scale that ScreenPixels holds. The reported size is in
# whole interface pixels for layout. Each drawing uses the exact whole-pixel
# size, centered in the requested rectangle. A control that draws this texture
# needs nearest filtering. With a whole number of screen pixels for each
# artwork pixel, nearest sampling gives each artwork pixel the same width at
# any start position.

var source: Texture2D
# interface pixels for each artwork pixel when drawn at its own size
var base := 1.0


# wraps texture, or returns null or an already wrapped texture unchanged
static func wrap(texture: Texture2D, value_base := 1.0) -> Texture2D:
	if texture == null or texture is PixelArtTexture:
		return texture

	var result := PixelArtTexture.new()
	result.source = texture
	result.base = value_base
	ScreenPixels.watch(result)

	return result


# the source of a wrapped texture, or texture itself
static func unwrap(texture: Texture2D) -> Texture2D:
	return (texture as PixelArtTexture).source if texture is PixelArtTexture else texture


func _get_width() -> int:
	return ceili(ScreenPixels.art_length(source.get_width(), base) - 0.001)


func _get_height() -> int:
	return ceili(ScreenPixels.art_length(source.get_height(), base) - 0.001)


func _has_alpha() -> bool:
	return source.has_alpha()


func _is_pixel_opaque(x: int, y: int) -> bool:
	var image := source.get_image()
	var point := Vector2i(Vector2(x, y) * Vector2(source.get_size()) / Vector2(get_size()))

	return image == null or not Rect2i(Vector2i.ZERO, image.get_size()).has_point(point) or image.get_pixelv(point).a > 0.5


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	_draw_rect(to_canvas_item, Rect2(pos, get_size()), false, modulate, transpose)


func _draw_rect(to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
	if tile:
		source.draw_rect(to_canvas_item, rect, true, modulate, transpose)

		return

	var texels := Vector2(source.get_size())

	if transpose:
		texels = Vector2(texels.y, texels.x)

	source.draw_rect(to_canvas_item, whole_rect(rect, texels), false, modulate, transpose)


func _draw_rect_region(
	to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool
) -> void:
	# the region is in this texture's reported size
	var ratio := Vector2(source.get_size()) / Vector2(get_size())
	var region := Rect2(src_rect.position * ratio, src_rect.size * ratio)

	# a part of the texture covers the rectangle, as in a covered texture
	# rectangle. show fewer artwork pixels at whole screen pixels instead
	if region.size.x < source.get_width() - 0.01 or region.size.y < source.get_height() - 0.01:
		source.draw_rect_region(to_canvas_item, rect, covered_region(rect, region, transpose), modulate, transpose, clip_uv)

		return

	var texels := region.size

	if transpose:
		texels = Vector2(texels.y, texels.x)

	source.draw_rect_region(to_canvas_item, whole_rect(rect, texels), region, modulate, transpose, clip_uv)


# the source region, centered on region, that fills rect with a whole number
# of screen pixels for each artwork pixel. a request below one screen pixel for
# each artwork pixel is unchanged
func covered_region(rect: Rect2, region: Rect2, transpose: bool) -> Rect2:
	var pixels_per_unit := ScreenPixels.scale
	var drawn := rect.size.abs()

	if transpose:
		drawn = Vector2(drawn.y, drawn.x)

	if pixels_per_unit <= 0.0 or region.size.x <= 0.0 or region.size.y <= 0.0:
		return region

	var requested := drawn / region.size

	if requested.x * pixels_per_unit < 1.0 or requested.y * pixels_per_unit < 1.0:
		return region

	var pixels := (requested * pixels_per_unit - Vector2.ONE * 0.001).ceil()

	if is_equal_approx(requested.x, requested.y):
		pixels = Vector2.ONE * maxf(pixels.x, pixels.y)

	var shown := drawn * pixels_per_unit / pixels

	return Rect2(region.get_center() - shown * 0.5, shown)


# the rectangle centered in rect that gives each of texels artwork pixels a
# whole number of screen pixels. a request for this texture's own size uses its
# own scale. any other request uses the largest scale that fits, and a request
# below one screen pixel for each artwork pixel is unchanged
func whole_rect(rect: Rect2, texels: Vector2) -> Rect2:
	var pixels_per_unit := ScreenPixels.scale

	if pixels_per_unit <= 0.0 or texels.x <= 0.0 or texels.y <= 0.0:
		return rect

	var drawn := rect.size.abs()
	var requested := drawn / texels
	var pixels := Vector2.ONE * ScreenPixels.art_pixels(base)

	if not drawn.is_equal_approx(Vector2(get_size())) or texels != Vector2(source.get_size()):
		if requested.x * pixels_per_unit < 1.0 or requested.y * pixels_per_unit < 1.0:
			return rect

		pixels = (requested * pixels_per_unit + Vector2.ONE * 0.001).floor()

		# keep square artwork pixels for a square request
		if is_equal_approx(requested.x, requested.y):
			pixels = Vector2.ONE * minf(pixels.x, pixels.y)

	var size := texels * pixels / pixels_per_unit

	return Rect2(rect.position + (rect.size - size * rect.size.sign()) * 0.5, size * rect.size.sign())
