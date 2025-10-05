class_name CityDynamicSpriteCanvas
extends Control

const MAX_SPECIAL_VISUALS_PER_BATCH := 256
const MAX_SPECIAL_BATCH_AREA := 1500000

var visuals: Array[Dictionary] = []
var view_scale := 1.0
var view_offset := Vector2.ZERO


func set_visuals(
	value: Array[Dictionary], scale_value: float, offset_value: Vector2
) -> void:
	visuals = value.duplicate()
	view_scale = scale_value
	view_offset = offset_value
	visible = not visuals.is_empty()
	queue_redraw()


func visual_count() -> int:
	return visuals.size()


static func batch_special_visuals(
	value: Array[Dictionary], batch_cache: Dictionary = {}
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pending: Array[Dictionary] = []
	var pending_bounds := Rect2i()
	for visual in value:
		if not visual.get("special_overlay", false):
			_append_special_batch(result, pending, batch_cache)
			pending.clear()
			pending_bounds = Rect2i()
			result.append(visual)
			continue
		var bounds := _visual_bounds(visual)
		var merged := bounds if pending.is_empty() else pending_bounds.merge(bounds)
		if (
			not pending.is_empty()
			and (
				pending.size() >= MAX_SPECIAL_VISUALS_PER_BATCH
				or merged.get_area() > MAX_SPECIAL_BATCH_AREA
			)
		):
			_append_special_batch(result, pending, batch_cache)
			pending.clear()
			pending_bounds = bounds
		else:
			pending_bounds = merged
		pending.append(visual)
	_append_special_batch(result, pending, batch_cache)
	return result


static func _append_special_batch(
	result: Array[Dictionary], pending: Array[Dictionary], batch_cache: Dictionary
) -> void:
	if pending.is_empty():
		return
	if pending.size() == 1:
		result.append(pending[0])
		return
	var cache_key := _special_batch_cache_key(pending)
	if not cache_key.is_empty() and batch_cache.has(cache_key):
		result.append(batch_cache[cache_key])
		return
	var bounds := _visual_bounds(pending[0])
	for index in range(1, pending.size()):
		bounds = bounds.merge(_visual_bounds(pending[index]))
	var image := Image.create(
		bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8
	)
	image.fill(Color.TRANSPARENT)
	for visual in pending:
		var source: Image = visual.get("image") as Image
		if source == null:
			continue
		var position := Vector2i(visual.get("position", Vector2.ZERO))
		image.blend_rect(
			source,
			Rect2i(Vector2i.ZERO, source.get_size()),
			position - bounds.position,
		)
	var texture := ImageTexture.create_from_image(image)
	var batch := {
		"texture": texture,
		"index_texture": texture,
		"palette_lookup_all": true,
		"position": Vector2(bounds.position),
		"size": Vector2(bounds.size),
		"image": image,
		"special_batch": true,
	}
	result.append(batch)
	if not cache_key.is_empty():
		batch_cache[cache_key] = batch


static func _special_batch_cache_key(pending: Array[Dictionary]) -> String:
	var parts := PackedStringArray()
	parts.resize(pending.size())
	for index in pending.size():
		var key := String(pending[index].get("batch_cache_key", ""))
		if key.is_empty():
			return ""
		parts[index] = key
	return "|".join(parts)


static func _visual_bounds(visual: Dictionary) -> Rect2i:
	return Rect2i(
		Vector2i(visual.get("position", Vector2.ZERO)),
		Vector2i(visual.get("size", Vector2.ZERO)),
	)


func _draw() -> void:
	for visual in visuals:
		var texture: Texture2D = visual.get("texture") as Texture2D
		if texture == null:
			continue
		var source_position: Vector2 = visual.get("position", Vector2.ZERO)
		var source_size: Vector2 = visual.get("size", Vector2(texture.get_size()))
		draw_texture_rect(
			texture,
			Rect2(
				view_offset + source_position * view_scale,
				source_size * view_scale,
			),
			false,
		)
