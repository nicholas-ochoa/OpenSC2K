class_name CityDynamicSpriteCanvas
extends Node2D

const MAX_SPECIAL_VISUALS_PER_BATCH := 256
const MAX_SPECIAL_BATCH_AREA := 1500000

var visuals: Array[CityDynamicVisual] = []
var view_scale := 1.0
var view_offset := Vector2.ZERO
var visual_revision := 0
var detail_lights_visible := true


func _draw() -> void:
	for visual in visuals:
		var texture: Texture2D = visual.texture as Texture2D

		if texture == null:
			continue

		var source_position: Vector2 = visual.position
		var source_size: Vector2 = visual.size
		if visual.hazard_animation != null:
			var animation := visual.hazard_animation
			# Reserved blue values select the eight-frame indexed atlas in the palette shader.
			draw_texture_rect(texture, Rect2(source_position, source_size), false,
				Color(animation.phase / 8.0, animation.opacity, 0.25 if visual.toxic_cloud else (0.125 if visual.warm_cloud else (0.5 if visual.fullbright else 0.75))))
			continue

		draw_texture_rect(
			texture,
			Rect2(source_position, source_size),
			false,
			Color(1, 0, 1) if visual.transparent_shadow else (Color(1, 0, 0) if visual.toxic_cloud else (Color(1, 0.5, 0) if visual.warm_cloud else (Color(1, 1, 0) if visual.fullbright else Color.WHITE))),
		)

		if visual.emission_texture != null and (detail_lights_visible or not visual.vehicle_light):
			# Palette-address masks use LA8; authored color masks remain RGBA8.
			var indexed := visual.emission_texture is ImageTexture and (visual.emission_texture as ImageTexture).get_format() == Image.FORMAT_LA8
			draw_texture_rect(visual.emission_texture, Rect2(source_position, source_size), false,
				Color(0, 1, 0) if indexed else Color(0, 1, 1))


func set_visuals(
	value: Array[CityDynamicVisual], scale_value: float, offset_value: Vector2
) -> void:
	visuals = value.duplicate()
	visual_revision += 1
	set_view_transform(scale_value, offset_value)
	visible = not visuals.is_empty()
	queue_redraw()


func set_detail_lights_visible(value: bool) -> void:
	if detail_lights_visible != value:
		detail_lights_visible = value
		queue_redraw()


func set_view_transform(scale_value: float, offset_value: Vector2) -> void:
	view_scale = scale_value
	view_offset = offset_value
	position = view_offset
	scale = Vector2(view_scale, view_scale)


func visual_count() -> int:
	return visuals.size()


static func batch_special_visuals(
	value: Array[CityDynamicVisual], batch_cache: Dictionary[String, CityDynamicVisual] = {}
) -> Array[CityDynamicVisual]:
	var result: Array[CityDynamicVisual] = []
	var pending: Array[CityDynamicVisual] = []
	var pending_bounds := Rect2i()

	for visual in value:
		if not visual.special_overlay or visual.emission_texture != null:
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
				or merged.get_area() * int(visual.texture_factor) * int(visual.texture_factor) > MAX_SPECIAL_BATCH_AREA
				or int(visual.texture_factor) != int(pending[0].texture_factor)
				or visual.fullbright != pending[0].fullbright
				or visual.toxic_cloud != pending[0].toxic_cloud
				or visual.warm_cloud != pending[0].warm_cloud
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
	result: Array[CityDynamicVisual], pending: Array[CityDynamicVisual], batch_cache: Dictionary[String, CityDynamicVisual]
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

	var factor := int(pending[0].texture_factor)
	var image := Image.create(
		bounds.size.x * factor, bounds.size.y * factor, false, Image.FORMAT_RGBA8
	)
	image.fill(Color.TRANSPARENT)

	for visual in pending:
		var source: Image = visual.image as Image

		if source == null:
			continue

		var sprite_position := Vector2i(visual.position)
		image.blend_rect(
			source,
			Rect2i(Vector2i.ZERO, source.get_size()),
			(sprite_position - bounds.position) * factor,
		)

	var texture := ImageTexture.create_from_image(image)
	var batch := CityDynamicVisual.new()
	batch.texture = texture
	batch.index_texture = texture
	batch.palette_lookup_all = true
	batch.position = Vector2(bounds.position)
	batch.size = Vector2(bounds.size)
	batch.image = image
	batch.special_batch = true
	batch.fullbright = pending[0].fullbright
	batch.toxic_cloud = pending[0].toxic_cloud
	batch.warm_cloud = pending[0].warm_cloud
	result.append(batch)

	if not cache_key.is_empty():
		batch_cache[cache_key] = batch


static func _special_batch_cache_key(pending: Array[CityDynamicVisual]) -> String:
	var parts := PackedStringArray()
	parts.resize(pending.size())

	for index in pending.size():
		var key := String(pending[index].batch_cache_key)

		if key.is_empty():
			return ""

		parts[index] = key

	return "|".join(parts)


static func _visual_bounds(visual: CityDynamicVisual) -> Rect2i:
	return Rect2i(
		Vector2i(visual.position),
		Vector2i(visual.size),
	)
