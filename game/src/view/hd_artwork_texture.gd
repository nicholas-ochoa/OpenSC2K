class_name HdArtworkTexture
extends Texture2D
## Full-color art at a logical size. Its source can have more pixels than the
## logical size; it draws with filtering and mipmaps, even in a control that
## draws pixel art with nearest filtering.

var source: CanvasTexture
var logical_size := Vector2i.ZERO


# `image` drawn at `size`. The image has mipmaps after the call.
static func create(image: Image, size: Vector2i) -> HdArtworkTexture:
	image.generate_mipmaps()
	var result := HdArtworkTexture.new()
	result.source = CanvasTexture.new()
	result.source.diffuse_texture = ImageTexture.create_from_image(image)
	result.source.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	result.logical_size = size

	return result


func _get_width() -> int:
	return logical_size.x


func _get_height() -> int:
	return logical_size.y


func _has_alpha() -> bool:
	return true


func _draw(to_canvas_item: RID, position: Vector2, modulate: Color, transpose: bool) -> void:
	source.draw_rect(to_canvas_item, Rect2(position, Vector2(logical_size)), false, modulate, transpose)


func _draw_rect(to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
	source.draw_rect(to_canvas_item, rect, tile, modulate, transpose)


func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool,
		clip_uv: bool) -> void:
	var ratio := source.get_size() / Vector2(logical_size)
	source.draw_rect_region(to_canvas_item, rect, Rect2(src_rect.position * ratio, src_rect.size * ratio), modulate,
		transpose, clip_uv)
