class_name CityMapSigns
extends CityMapConstants

@warning_ignore_start("integer_division")

var map: CityMapControl
var _sign_font: SystemFont
var sign_entries: Array[CityMapSigns.Entry] = []
var sign_entries_city: CityState
var sign_entries_zoom := -1.0
var _sign_layout_signature: Array = []
var external_sign_layout_token: Array = []
var sign_cache_build_count := 0


func _init(control: CityMapControl) -> void:
	map = control


func set_animated_palette(texture: Texture2D) -> void:
	map.animated_palette_texture = texture
	map.layers._sync_base_material()


func set_dark_underground_palette(texture: Texture2D) -> void:
	map.dark_underground_palette_texture = texture
	map.layers._sync_base_material()


func set_signs_visible(value: bool) -> void:
	if map.signs_visible == value:
		return

	map.signs_visible = value
	map.queue_redraw()


func set_sign_occlusion_visuals(value: Dictionary[int, CitySignVisual]) -> void:
	var unchanged := map.sign_occlusion_visuals.size() == value.size()

	if unchanged:
		for key in value:
			if not value[key].matches(map.sign_occlusion_visuals.get(key)):
				unchanged = false
				break

	if unchanged:
		return

	var retained: Dictionary[int, CitySignVisual] = {}

	for key in value:
		retained[key] = value[key].copy()

	map.sign_occlusion_visuals = retained
	map.queue_redraw()


func sign_source_entries() -> Array[CitySignRequest]:
	if not map.signs_visible or map.city == null:
		return []

	_ensure_sign_entries()
	var entries: Array[CitySignRequest] = []

	for entry in sign_entries:
		entries.append(CitySignRequest.new(entry.key, entry.bounds, entry.draw_order))

	return entries


func _ensure_sign_entries() -> void:
	var map_edge: int = map.city.map_size if map.city != null else 128

	if sign_entries_city == map.city and is_equal_approx(sign_entries_zoom, map.zoom_factor):
		return

	if map.city == null:
		sign_entries.clear()
		sign_entries_city = null

		return

	var sign_texts := map.city.sign_texts()

	# the original paints a sign at each connection marker; no record holds it
	sign_texts.merge(CityNeighbors.connection_sign_texts(map.city))
	var sign_indices := PackedInt32Array(sign_texts.keys())
	sign_indices.sort()
	var sign_values := []

	# a layout reads only the sign tiles, so their values replace a map hash
	for index in sign_indices:
		sign_values.append(index)
		sign_values.append(sign_texts[index])

		if index < map.city.altitude_words.size():
			sign_values.append(map.city.altitude_words[index])
			sign_values.append(map.city.terrain[index])
			sign_values.append(map.city.tile_flags[index])

	var signature := [
		map_edge,
		map.city.visible_altitude_levels,
		map.city.compass_rotation(),
		hash(sign_values),
	]

	if _sign_layout_signature == signature and is_equal_approx(sign_entries_zoom, map.zoom_factor):
		sign_entries_city = map.city

		return

	_sign_layout_signature = signature
	sign_entries.clear()
	sign_entries_city = map.city
	sign_entries_zoom = map.zoom_factor
	sign_cache_build_count += 1
	var view_index := sign_view_index(map.zoom_factor)
	var configuration := Renderer.view_configuration(view_index)
	var divisor := configuration.divisor
	# each tile routine passes the bottom of the ground sprite, and the sign
	# painter FUN_0044d9a0 moves up half a tile: the center of the tile
	var anchor_drop := Vector2(0, (configuration.tile_height - configuration.half_height) * divisor)
	var font := _get_sign_font()
	var font_size: int = SIGN_FONT_HEIGHTS[view_index]
	var positions: Array[Vector2i] = []

	for index in sign_indices:
		var x := index / map_edge
		var y := index % map_edge
		positions.append(Vector2i((x + y) * map_edge + y, index))

	positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x)

	for entry in positions:
		var x := entry.y / map_edge
		var y := entry.y % map_edge

		if not map.city.tile_is_visible(x, y):
			continue

		var label_text: String = sign_texts.get(entry.y, "")

		if label_text.is_empty():
			continue

		var polygon := Renderer.tile_polygon(map.city, x, y)

		if polygon.size() != 4:
			continue

		var native_width := roundf(font.get_string_size(
			label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		).x)
		var anchor := polygon[0] + anchor_drop
		var layout := sign_layout(
			anchor, native_width * divisor,
			view_index, divisor,
		)
		# the light pen reaches one native pixel above and left of the panel
		var bounds: Rect2 = layout.panel.merge(layout.post).grow_individual(divisor, divisor, 0, 0)
		var sign_entry := Entry.new()
		sign_entry.key = map.city.index_of(x, y)
		sign_entry.anchor = anchor
		sign_entry.label = label_text
		sign_entry.text_width = native_width
		sign_entry.bounds = Rect2i(
			Vector2i(floori(bounds.position.x), floori(bounds.position.y)),
			Vector2i(ceili(bounds.size.x), ceili(bounds.size.y)),
		)
		sign_entry.draw_order = (x + y) * map_edge + y
		sign_entries.append(sign_entry)


func _invalidate_sign_entries() -> void:
	external_sign_layout_token.clear()
	_sign_layout_signature.clear()
	sign_entries.clear()
	sign_entries_city = null
	sign_entries_zoom = -1.0


func _draw_signs(scale: float, offset: Vector2) -> void:
	var map_edge: int = map.city.map_size if map.city != null else 128

	if not map.signs_visible or map.city == null or map.city_source.size.x <= map_edge:
		return

	_ensure_sign_entries()
	var view_index := sign_view_index(map.zoom_factor)
	var display_multiplier := sign_display_multiplier(map.zoom_factor) * map.map_pixel_ratio
	var font := _get_sign_font()
	var font_size: int = SIGN_FONT_HEIGHTS[view_index]

	for entry in sign_entries:
		if not Rect2(entry.bounds).intersects(map.camera.visible_source_rect()):
			continue

		# the sign is drawn in whole native pixels from a whole screen pixel
		var origin := (offset + Vector2(entry.anchor) * scale).round()
		var layout := sign_layout(Vector2.ZERO, float(entry.text_width), view_index)
		_draw_raised_sign_part(layout.panel, SIGN_PANEL_FILL, origin, display_multiplier)
		var text_position := Vector2(
			layout.panel.position.x + 4.0,
			layout.panel.position.y + 2.0 + font.get_ascent(font_size),
		)
		map.draw_set_transform(origin, 0.0, Vector2(display_multiplier, display_multiplier))
		# the glyphs keep their native size; the nearest filter enlarges them
		map.draw_string(
			font, text_position, String(entry.label), HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, SIGN_TEXT_COLOR, TextServer.JUSTIFICATION_NONE,
			TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL, 1.0,
		)
		map.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_raised_sign_part(layout.post, SIGN_POST_FILL, origin, display_multiplier)
		_draw_sign_occlusion(int(entry.key), scale, offset)


func _draw_sign_occlusion(key: int, scale: float, offset: Vector2) -> void:
	var visual: CitySignVisual = map.sign_occlusion_visuals.get(key)

	if visual == null:
		return

	var texture := visual.texture

	if texture == null:
		return

	var source_position := visual.position
	var source_size := visual.size
	map.draw_texture_rect(
		texture,
		Rect2(offset + source_position * scale, source_size * scale),
		false,
		CityForegroundPalette.INDEXED_DRAW_COLOR if visual.indexed else Color.WHITE,
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
	visuals: Array[CityDynamicVisual], bounds: Rect2i, draw_order: int
) -> Array[CityDynamicVisual]:
	var result: Array[CityDynamicVisual] = []

	for visual in visuals:
		if visual.shadow or visual.depth_order <= draw_order:
			continue

		var visual_bounds := Rect2i(
			Vector2i(visual.position),
			Vector2i(visual.size),
		)

		if bounds.intersects(visual_bounds):
			result.append(visual)

	return result


static func sign_layout(
	anchor: Vector2, text_width: float, view_index: int, display_multiplier := 1.0
) -> Layout:
	if view_index < Renderer.VIEW_SMALL or view_index > Renderer.VIEW_LARGE:
		return null

	var multiplier: float = maxf(1.0, display_multiplier)
	var width: float = roundf(text_width)
	var font_height: float = float(SIGN_FONT_HEIGHTS[view_index]) * multiplier
	var panel_bottom: float = (
		anchor.y - (15.0 * view_index + 20.0) * multiplier
	)
	var panel_top: float = panel_bottom - font_height - 5.0 * multiplier
	var panel_left: float = anchor.x - floorf(width * 0.5) - 8.0 * multiplier
	var panel_right: float = panel_left + width + 16.0 * multiplier

	var layout := Layout.new()
	layout.panel = Rect2(
		Vector2(panel_left, panel_top),
		Vector2(panel_right - panel_left, panel_bottom - panel_top),
	)
	layout.post = Rect2(
		Vector2(anchor.x - 2.0 * multiplier, panel_bottom),
		Vector2(4.0 * multiplier, anchor.y - panel_bottom),
	)

	return layout


func _get_sign_font() -> Font:
	if _sign_font == null:
		_sign_font = SystemFont.new()
		# the executable asks for "ariel", windows substitutes arial
		_sign_font.font_names = PackedStringArray(["Arial"])
		_sign_font.font_weight = 600
		# windows 95 draws sign text without smoothing
		_sign_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_sign_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED

	return _sign_font


# FUN_004728a0 fills the rectangle, then draws two-pixel pens: light along the
# top and left, dark along the bottom and right, and a middle pixel at the
# lower-left corner. A two-pixel GDI pen at coordinate c covers c - 1 and c,
# so the light edge starts outside the fill and one fill row and column stay
# outside the dark edge. `part` is in native pixels from `origin`
func _draw_raised_sign_part(part: Rect2, fill: Color, origin: Vector2, multiplier: float) -> void:
	var left := part.position.x
	var top := part.position.y
	var right := part.end.x
	var bottom := part.end.y
	_draw_native_rect(left, top, right, bottom, fill, origin, multiplier)

	_draw_native_rect(left, top - 1.0, right - 2.0, top, SIGN_EDGE_LIGHT, origin, multiplier)
	_draw_native_rect(left - 1.0, top, right - 1.0, top + 1.0, SIGN_EDGE_LIGHT, origin, multiplier)
	_draw_native_rect(left - 1.0, top, left + 1.0, bottom - 1.0, SIGN_EDGE_LIGHT, origin, multiplier)

	_draw_native_rect(right - 3.0, top + 1.0, right - 1.0, bottom - 1.0, SIGN_EDGE_DARK, origin, multiplier)
	_draw_native_rect(left + 2.0, bottom - 3.0, right - 1.0, bottom - 2.0, SIGN_EDGE_DARK, origin, multiplier)
	_draw_native_rect(left + 1.0, bottom - 2.0, right - 1.0, bottom - 1.0, SIGN_EDGE_DARK, origin, multiplier)

	_draw_native_rect(left, bottom - 1.0, left + 1.0, bottom, SIGN_EDGE_MIDDLE, origin, multiplier)


# each native edge lands on a whole screen pixel, so no edge blurs
func _draw_native_rect(
	left: float, top: float, right: float, bottom: float, color: Color, origin: Vector2, multiplier: float
) -> void:
	var start := (origin + Vector2(left, top) * multiplier).round()
	var end := (origin + Vector2(right, bottom) * multiplier).round()
	map.draw_rect(Rect2(start, end - start), color)


class Entry extends RefCounted:
	var key: int
	var anchor: Vector2
	var label: String
	var text_width: float
	var bounds: Rect2i
	var draw_order: int


class Layout extends RefCounted:
	var panel: Rect2
	var post: Rect2
