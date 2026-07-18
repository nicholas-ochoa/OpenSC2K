class_name CityMapSigns
extends CityMapConstants


var map: CityMapControl


func _init(control: CityMapControl) -> void:
	map = control


func set_animated_palette(texture: Texture2D) -> void:
	map.animated_palette_texture = texture
	map.layers._sync_base_material()


func set_signs_visible(value: bool) -> void:
	if map.signs_visible == value:
		return

	map.signs_visible = value
	map.queue_redraw()


func set_sign_occlusion_visuals(value: Dictionary) -> void:
	if map.sign_occlusion_visuals == value:
		return

	map.sign_occlusion_visuals = value.duplicate(true)
	map.queue_redraw()


func sign_source_entries() -> Array[Dictionary]:
	if not map.signs_visible or map.city == null:
		return []

	_ensure_sign_entries()
	var entries: Array[Dictionary] = []

	for entry in map._sign_entries:
		entries.append({
			"key": int(entry.key),
			"bounds": entry.bounds,
			"draw_order": int(entry.draw_order),
		})

	return entries


func _ensure_sign_entries() -> void:
	var map_edge: int = map.city.map_size if map.city != null else 128

	if map._sign_entries_city == map.city and is_equal_approx(map._sign_entries_zoom, map.zoom_factor):
		return

	if map.city == null:
		map._sign_entries.clear()
		map._sign_entries_city = null

		return

	var sign_indices := OverlayData.sign_indices(map.city.text_overlays)
	sign_indices.sort()
	var sign_values := PackedInt32Array()

	for index in sign_indices:
		sign_values.append(index)
		sign_values.append(OverlayData.read(map.city.text_overlays, index))

	var labels := map.city.document.find_chunk("XLAB")
	var signature := [map_edge, map.city.visible_altitude_levels, map.city.compass_rotation(), hash(map.city.altitude_words), hash(sign_values), hash(labels.decoded_payload) if labels != null else 0]

	if map._sign_layout_signature == signature and is_equal_approx(map._sign_entries_zoom, map.zoom_factor):
		map._sign_entries_city = map.city

		return

	map._sign_layout_signature = signature
	map._sign_entries.clear()
	map._sign_entries_city = map.city
	map._sign_entries_zoom = map.zoom_factor
	map._sign_cache_build_count += 1
	var view_index := sign_view_index(map.zoom_factor)
	var divisor := int(Renderer.view_configuration(view_index).divisor)
	var font := _get_sign_font()
	var font_size: int = SIGN_FONT_HEIGHTS[view_index]
	var positions: Array[Vector2i] = []

	for index in sign_indices:
		var x := int(IntegerMath.div_trunc(index, map_edge))
		var y := index % map_edge
		positions.append(Vector2i((x + y) * map_edge + y, index))

	positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x)

	for entry in positions:
		var x := int(IntegerMath.div_trunc(entry.y, map_edge))
		var y := entry.y % map_edge

		if not map.city.tile_is_visible(x, y):
			continue

		var label_id := map.city.text_overlay_id(x, y)

		if not OverlayData.is_sign(label_id):
			continue

		var label_text := map.city.label(label_id)

		if label_text.is_empty():
			continue

		var polygon := Renderer.tile_polygon(map.city, x, y)

		if polygon.size() != 4:
			continue

		var native_width := roundf(font.get_string_size(
			label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		).x)
		var layout := sign_layout(
			polygon[0] + Vector2(0, -8), native_width * divisor,
			view_index, divisor,
		)
		var bounds: Rect2 = layout.panel.merge(layout.post)
		map._sign_entries.append({
			"key": map.city.index_of(x, y),
			"anchor": polygon[0] + Vector2(0, -8),
			"label": label_text,
			"text_width": native_width,
			"bounds": Rect2i(
				Vector2i(floori(bounds.position.x), floori(bounds.position.y)),
				Vector2i(ceili(bounds.size.x), ceili(bounds.size.y)),
			),
			"draw_order": (x + y) * map_edge + y,
		})


func _invalidate_sign_entries() -> void:
	map._external_sign_layout_token.clear()
	map._sign_layout_signature.clear()
	map._sign_entries.clear()
	map._sign_entries_city = null
	map._sign_entries_zoom = -1.0


func _draw_signs(scale: float, offset: Vector2) -> void:
	var map_edge: int = map.city.map_size if map.city != null else 128

	if not map.signs_visible or map.city == null or map.city_source.size.x <= map_edge:
		return

	_ensure_sign_entries()
	var view_index := sign_view_index(map.zoom_factor)
	var display_multiplier := sign_display_multiplier(map.zoom_factor)
	var font := _get_sign_font()
	var font_size: int = SIGN_FONT_HEIGHTS[view_index]

	for entry in map._sign_entries:
		if not Rect2(entry.bounds).intersects(map.camera.visible_source_rect()):
			continue

		# every native painter moves from the tile's top point by the
		# equivalent of 16 pixels right and 8 pixels up in large space
		var anchor := offset + Vector2(entry.anchor) * scale
		var drawing_anchor := anchor

		if display_multiplier > 1.0:
			drawing_anchor = Vector2.ZERO
			map.draw_set_transform(
				anchor, 0.0, Vector2(display_multiplier, display_multiplier)
			)

		var layout := sign_layout(
			drawing_anchor, float(entry.text_width), view_index
		)
		_draw_raised_sign_part(layout.panel, SIGN_PANEL_FILL, 1.0)
		var text_position := Vector2(
			layout.panel.position.x + 4.0,
			layout.panel.position.y + 2.0 + font.get_ascent(font_size),
		)
		map.draw_string(
			font, text_position, String(entry.label), HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, SIGN_TEXT_COLOR,
		)
		_draw_raised_sign_part(layout.post, SIGN_POST_FILL, 1.0)

		if display_multiplier > 1.0:
			map.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		_draw_sign_occlusion(int(entry.key), scale, offset)


func _draw_sign_occlusion(key: int, scale: float, offset: Vector2) -> void:
	var visual: Dictionary = map.sign_occlusion_visuals.get(key, {})

	if visual.is_empty():
		return

	var texture: Texture2D = visual.get("texture") as Texture2D

	if texture == null:
		return

	var source_position: Vector2 = visual.get("position", Vector2.ZERO)
	var source_size: Vector2 = visual.get("size", Vector2(texture.get_size()))
	map.draw_texture_rect(
		texture,
		Rect2(offset + source_position * scale, source_size * scale),
		false,
		CityForegroundPalette.INDEXED_DRAW_COLOR if bool(visual.get("indexed", false)) else Color.WHITE,
	)


static func sign_view_index(zoom: float) -> int:
	if zoom <= 0.25:
		return Renderer.VIEW_SMALL

	if zoom <= 0.5:
		return Renderer.VIEW_MEDIUM

	return Renderer.VIEW_LARGE


static func sign_display_multiplier(zoom: float) -> float:
	return maxf(1.0, zoom)


static func later_sign_occluder_visuals(
	visuals: Array[Dictionary], bounds: Rect2i, draw_order: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for visual in visuals:
		if bool(visual.get("shadow", false)) or int(visual.get("depth_order", -1)) <= draw_order:
			continue

		var visual_bounds := Rect2i(
			Vector2i(visual.get("position", Vector2.ZERO)),
			Vector2i(visual.get("size", Vector2.ZERO)),
		)

		if bounds.intersects(visual_bounds):
			result.append(visual)

	return result


static func sign_layout(
	anchor: Vector2, text_width: float, view_index: int, display_multiplier := 1.0
) -> Dictionary:
	if view_index < Renderer.VIEW_SMALL or view_index > Renderer.VIEW_LARGE:
		return {}

	var multiplier: float = maxf(1.0, display_multiplier)
	var width: float = roundf(text_width)
	var font_height: float = float(SIGN_FONT_HEIGHTS[view_index]) * multiplier
	var panel_bottom: float = (
		anchor.y - (15.0 * view_index + 20.0) * multiplier
	)
	var panel_top: float = panel_bottom - font_height - 5.0 * multiplier
	var panel_left: float = anchor.x - floorf(width * 0.5) - 8.0 * multiplier
	var panel_right: float = panel_left + width + 16.0 * multiplier

	return {
		"panel": Rect2(
			Vector2(panel_left, panel_top),
			Vector2(panel_right - panel_left, panel_bottom - panel_top),
		),
		"post": Rect2(
			Vector2(anchor.x - 2.0 * multiplier, panel_bottom),
			Vector2(4.0 * multiplier, anchor.y - panel_bottom),
		),
	}


func _get_sign_font() -> Font:
	if map._sign_font == null:
		map._sign_font = SystemFont.new()
		# the executable asks for "ariel", windows substitutes arial
		map._sign_font.font_names = PackedStringArray(["Arial"])
		map._sign_font.font_weight = 600

	return map._sign_font


func _draw_raised_sign_part(rect: Rect2, fill: Color, multiplier: float) -> void:
	var edge := maxf(1.0, multiplier)
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	map.draw_rect(rect, fill)
	map.draw_polyline(
		PackedVector2Array([
			Vector2(right - 2.0 * edge, top + edge),
			Vector2(left + edge, top + edge),
			Vector2(left + edge, bottom - 2.0 * edge),
		]),
		SIGN_EDGE_LIGHT, 2.0 * edge, false,
	)
	map.draw_polyline(
		PackedVector2Array([
			Vector2(left + edge, bottom - 2.0 * edge),
			Vector2(right - 2.0 * edge, bottom - 2.0 * edge),
			Vector2(right - 2.0 * edge, top + edge),
		]),
		SIGN_EDGE_DARK, 2.0 * edge, false,
	)
	map.draw_line(
		Vector2(left, bottom - edge),
		Vector2(left + edge, bottom - 2.0 * edge),
		SIGN_EDGE_MIDDLE, edge, false,
	)
