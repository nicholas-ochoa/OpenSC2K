class_name CityMapSigns
extends CityMapConstants

@warning_ignore_start("integer_division")

# the width of the light and dark edges, in native pixels
const BEVEL_WIDTH := 2.0

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


func sign_source_entries() -> Array[CityMapSigns.Entry]:
	if not map.signs_visible or map.city == null:
		return []

	_ensure_sign_entries()

	return sign_entries.duplicate()


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
	var font_size := _em_size(font, SIGN_FONT_HEIGHTS[view_index])
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
			label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(font_size)
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
	var font_size := _em_size(font, SIGN_FONT_HEIGHTS[view_index])

	for entry in sign_entries:
		if not Rect2(entry.bounds).intersects(map.camera.visible_source_rect()):
			continue

		# the panel and post are drawn in whole native pixels from a whole
		# screen pixel. The text is drawn at its screen size, so it stays sharp
		var origin := (offset + Vector2(entry.anchor) * scale).round()
		var screen_font_size := maxi(1, roundi(font_size * display_multiplier))

		if entry.screen_font_size != screen_font_size:
			entry.screen_font_size = screen_font_size
			entry.screen_text_width = font.get_string_size(
				entry.label, HORIZONTAL_ALIGNMENT_LEFT, -1, screen_font_size
			).x

		var layout := sign_layout(
			Vector2.ZERO, ceilf(entry.screen_text_width / display_multiplier), view_index
		)
		_draw_raised_sign_part(layout.panel, SIGN_PANEL_FILL, origin, display_multiplier)
		var text_position := (origin + (layout.panel.position + Vector2(4.0, 2.0)) * display_multiplier).round()
		text_position.y += font.get_ascent(screen_font_size)
		map.draw_string(
			font, text_position, entry.label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			screen_font_size, SIGN_TEXT_COLOR,
		)
		_draw_raised_sign_part(layout.post, SIGN_POST_FILL, origin, display_multiplier)


static func sign_view_index(zoom: float) -> int:
	if zoom <= 0.25:
		return Renderer.VIEW_SMALL

	if zoom <= 0.5:
		return Renderer.VIEW_MEDIUM

	return Renderer.VIEW_LARGE


static func sign_display_multiplier(zoom: float) -> float:
	return maxf(1.0, zoom)


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


# the executable asks for a character cell of `cell_height` pixels, ascent
# and descent together. A Godot font size is the em size, which is smaller
static func _em_size(font: Font, cell_height: float) -> float:
	const REFERENCE_SIZE := 100

	return cell_height * REFERENCE_SIZE / font.get_height(REFERENCE_SIZE)


func _get_sign_font() -> Font:
	if _sign_font == null:
		_sign_font = SystemFont.new()
		# the executable asks for "ariel", windows substitutes arial
		_sign_font.font_names = PackedStringArray(["Arial"])
		_sign_font.font_weight = 600

	return _sign_font


# FUN_004728a0 fills the rectangle and draws a two-pixel light edge along the
# top and left and a dark edge along the bottom and right. The light pen
# starts one pixel outside the fill. `part` is in native pixels from `origin`;
# the edges are drawn at screen resolution with mitered corners
func _draw_raised_sign_part(part: Rect2, fill: Color, origin: Vector2, multiplier: float) -> void:
	var start := (origin + (part.position - Vector2.ONE) * multiplier).round()
	var end := (origin + part.end * multiplier).round()
	var edge := maxf(1.0, roundf(BEVEL_WIDTH * multiplier))
	var inner_start := start + Vector2(edge, edge)
	var inner_end := end - Vector2(edge, edge)
	map.draw_rect(Rect2(start, end - start), fill)
	map.draw_colored_polygon(PackedVector2Array([
		start, Vector2(end.x, start.y), Vector2(inner_end.x, inner_start.y),
		inner_start, Vector2(inner_start.x, inner_end.y), Vector2(start.x, end.y),
	]), SIGN_EDGE_LIGHT)
	map.draw_colored_polygon(PackedVector2Array([
		end, Vector2(start.x, end.y), Vector2(inner_start.x, inner_end.y),
		inner_end, Vector2(inner_end.x, inner_start.y), Vector2(end.x, start.y),
	]), SIGN_EDGE_DARK)


class Entry extends RefCounted:
	var key: int
	var anchor: Vector2
	var label: String
	var text_width: float
	var bounds: Rect2i
	var draw_order: int
	# the text width at the font size of the last draw
	var screen_font_size := 0
	var screen_text_width := 0.0


class Layout extends RefCounted:
	var panel: Rect2
	var post: Rect2
