class_name CityMapControl
extends Control

signal selection_completed(
	start: Vector2i, finish: Vector2i, path: Array[Vector2i], dragged: bool
)
signal selection_changed(
	start: Vector2i, finish: Vector2i, path: Array[Vector2i], dragged: bool
)
signal selection_canceled()
signal query_requested(point: Vector2i)
signal zoom_changed(percent: int)
signal viewport_changed()

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const BuildingTool = preload("res://src/tools/building_command.gd")
const DynamicSpriteCanvas = preload("res://src/view/city_dynamic_sprite_canvas.gd")
const ZOOM_LEVELS := [0.25, 0.5, 1.0, 2.0]
const DEFAULT_ZOOM_INDEX := 2
const SIGN_FONT_HEIGHTS := [12, 14, 16]
const SIGN_PANEL_FILL := Color("9f9f9f")
const SIGN_POST_FILL := Color("bbbbbb")
const SIGN_EDGE_LIGHT := Color("e3e3e3")
const SIGN_EDGE_MIDDLE := Color("838383")
const SIGN_EDGE_DARK := Color("575757")
const SIGN_TEXT_COLOR := Color("000030")
const PALETTE_CYCLE_SHADER := """
shader_type canvas_item;

uniform sampler2D palette_indices : filter_nearest, repeat_disable;
uniform sampler2D animated_palette : source_color, filter_nearest, repeat_disable;
uniform bool palette_cycle_enabled = false;
uniform bool palette_lookup_all = false;

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);
	float encoded_index = (
		palette_lookup_all ? base_color.r : texture(palette_indices, UV).r
	);
	int palette_index = int(round(encoded_index * 255.0));
	bool animated_index =
		(palette_index >= 171 && palette_index <= 198) ||
		(palette_index >= 200 && palette_index <= 219) ||
		(palette_index >= 224 && palette_index <= 239);
	if (palette_cycle_enabled && (palette_lookup_all || animated_index)) {
		vec2 palette_uv = vec2((float(palette_index) + 0.5) / 256.0, 0.5);
		vec4 cycle_color = texture(animated_palette, palette_uv);
		COLOR = vec4(cycle_color.rgb, base_color.a);
	} else {
		COLOR = base_color;
	}
}
"""

var city: CityState
var city_texture: Texture2D
var palette_index_texture: Texture2D
var animated_palette_texture: Texture2D
var base_palette_lookup_all := false
var signs_visible := true
var edit_enabled := false
var selection_mode := "rectangle"
var point_footprint_area := 1
var shift_query_enabled := false
var zoom_factor: float = ZOOM_LEVELS[DEFAULT_ZOOM_INDEX]
var source_center := Vector2.ZERO
var selection_start := Vector2i(-1, -1)
var selection_end := Vector2i(-1, -1)
var selection_path: Array[Vector2i] = []
var selection_moved := false
var selection_price := -1
var selection_price_affordable := true
var hover_tile := Vector2i(-1, -1)
var transient_effects: Array[Dictionary] = []
var dynamic_sprites: Array[Dictionary] = []
var sign_occlusion_visuals: Dictionary = {}
var _panning := false
var _effect_generation := 0
var _shake_generation := 0
var _shake_offset := Vector2.ZERO
var _base_layer: TextureRect
var _base_material: ShaderMaterial
var _dynamic_canvas: CityDynamicSpriteCanvas
var _dynamic_material: ShaderMaterial
var _palette_shader: Shader
var _sign_font: SystemFont


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_base_layer()
	resized.connect(_on_resized)
	mouse_exited.connect(_clear_hover)


func set_city_view(
	value: CityState,
	texture: Texture2D,
	index_texture: Texture2D = null,
	palette_lookup_all := false
) -> void:
	var reset_center := city_texture == null or city_texture.get_size() != texture.get_size()
	city = value
	city_texture = texture
	palette_index_texture = index_texture
	base_palette_lookup_all = palette_lookup_all
	if reset_center and city_texture != null:
		source_center = Vector2(city_texture.get_size()) * 0.5
	_clamp_source_center()
	_sync_base_layer()
	queue_redraw()
	viewport_changed.emit()


func set_animated_palette(texture: Texture2D) -> void:
	animated_palette_texture = texture
	_sync_base_material()


func set_signs_visible(value: bool) -> void:
	if signs_visible == value:
		return
	signs_visible = value
	queue_redraw()


func set_sign_occlusion_visuals(value: Dictionary) -> void:
	sign_occlusion_visuals = value.duplicate()
	queue_redraw()


func sign_source_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not signs_visible or city == null:
		return entries
	var view_index := sign_view_index(zoom_factor)
	var divisor := int(Renderer.view_configuration(view_index).divisor)
	var font := _get_sign_font()
	var font_size: int = SIGN_FONT_HEIGHTS[view_index]
	for diagonal in CityState.MAP_SIZE * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y
			if x >= CityState.MAP_SIZE or y >= CityState.MAP_SIZE:
				continue
			var label_id := city.text_overlay_id(x, y)
			if label_id < 1 or label_id > 50:
				continue
			var label_text := city.label(label_id)
			if label_text.is_empty():
				continue
			var polygon := Renderer.tile_polygon(city, x, y)
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
			entries.append({
				"key": city.index_of(x, y),
				"bounds": Rect2i(
					Vector2i(floori(bounds.position.x), floori(bounds.position.y)),
					Vector2i(ceili(bounds.size.x), ceili(bounds.size.y)),
				),
				"draw_order": (x + y) * CityState.MAP_SIZE + y,
			})
	return entries


func set_edit_enabled(
	value: bool,
	mode := "rectangle",
	footprint_area := 1,
	shift_queries := false
) -> void:
	edit_enabled = value
	selection_mode = mode
	point_footprint_area = clampi(footprint_area, 1, 4)
	shift_query_enabled = shift_queries
	clear_selection_price()
	mouse_default_cursor_shape = (
		Control.CURSOR_CROSS if edit_enabled else Control.CURSOR_ARROW
	)
	if not edit_enabled:
		selection_start = Vector2i(-1, -1)
		selection_end = Vector2i(-1, -1)
		selection_path.clear()
		hover_tile = Vector2i(-1, -1)
	queue_redraw()


func zoom_percent() -> int:
	return roundi(zoom_factor * 100.0)


func zoom_in(local_point := Vector2.INF) -> bool:
	return _change_zoom(1, local_point)


func zoom_out(local_point := Vector2.INF) -> bool:
	return _change_zoom(-1, local_point)


func can_zoom_in() -> bool:
	return _zoom_index() < ZOOM_LEVELS.size() - 1


func can_zoom_out() -> bool:
	return _zoom_index() > 0


func is_left_drag_active() -> bool:
	return selection_start.x >= 0


func selection_tiles() -> Array[Vector2i]:
	return selection_path.duplicate()


func selection_was_dragged() -> bool:
	return selection_moved


func set_selection_price(value: int, affordable := true) -> void:
	selection_price = maxi(-1, value)
	selection_price_affordable = affordable
	queue_redraw()


func clear_selection_price() -> void:
	if selection_price < 0:
		return
	selection_price = -1
	selection_price_affordable = true
	queue_redraw()


func selection_price_text() -> String:
	if selection_price < 0:
		return ""
	return "$%s" % _format_price(selection_price)


func point_preview_tiles(point: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if city == null or city.index_of(point.x, point.y) < 0:
		return result
	var site := BuildingTool.footprint(point, point_footprint_area)
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			if city.index_of(x, y) >= 0:
				result.append(Vector2i(x, y))
	return result


func cancel_active_selection() -> bool:
	if selection_start.x < 0:
		return false
	_clear_selection()
	queue_redraw()
	selection_canceled.emit()
	return true


func center_on_tile(point: Vector2i) -> bool:
	if city == null or city.index_of(point.x, point.y) < 0:
		return false
	var polygon := Renderer.tile_polygon(city, point.x, point.y)
	if polygon.size() != 4:
		return false
	source_center = (polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.25
	_clamp_source_center()
	_sync_base_layer()
	queue_redraw()
	viewport_changed.emit()
	return true


func center_tile() -> Vector2i:
	if city == null:
		return Vector2i(-1, -1)
	return Renderer.screen_to_tile(city, source_center + Vector2(0, -0.5))


func scroll_state() -> Dictionary:
	if city_texture == null:
		return {}
	var content := Vector2(city_texture.get_size())
	var visible := size / _view_scale()
	var page := Vector2(
		minf(content.x, visible.x),
		minf(content.y, visible.y),
	)
	var value := source_center - page * 0.5
	for axis in 2:
		if page[axis] >= content[axis]:
			value[axis] = 0.0
		else:
			value[axis] = clampf(value[axis], 0.0, content[axis] - page[axis])
	return {"content": content, "page": page, "value": value}


func set_scroll_value(axis: int, value: float) -> bool:
	if axis < 0 or axis > 1:
		return false
	var state := scroll_state()
	if state.is_empty():
		return false
	var offset: Vector2 = state.value
	offset[axis] = value
	var page: Vector2 = state.page
	source_center = offset + page * 0.5
	_clamp_source_center()
	_sync_base_layer()
	queue_redraw()
	viewport_changed.emit()
	return true


func show_transient_effects(effects: Array[Dictionary], duration := 0.1) -> void:
	_effect_generation += 1
	transient_effects.clear()
	queue_redraw()
	if effects.is_empty() or not is_inside_tree():
		return
	var sequence: Array[Dictionary] = []
	sequence.append_array(effects)
	var last_frame := 0
	for effect in sequence:
		last_frame = maxi(last_frame, int(effect.get("frame", 0)))
	_show_transient_effect_frame(
		sequence, 0, last_frame, maxf(0.0, float(duration)), _effect_generation
	)


func shake_view(frames := 24, frame_duration := 0.005, distance := 4.0) -> void:
	_shake_generation += 1
	_shake_offset = Vector2.ZERO
	if frames <= 0 or not is_inside_tree():
		_sync_base_layer()
		queue_redraw()
		return
	_show_shake_frame(
		0,
		frames,
		maxf(0.0, float(frame_duration)),
		maxf(0.0, float(distance)),
		_shake_generation
	)


func set_dynamic_sprites(sprites: Array[Dictionary]) -> void:
	dynamic_sprites = sprites.duplicate()
	_sync_dynamic_canvas()
	queue_redraw()


func dynamic_render_node_count() -> int:
	return int(_dynamic_canvas != null)


func _expire_transient_effects(generation: int) -> void:
	if generation != _effect_generation:
		return
	transient_effects.clear()
	queue_redraw()


func _show_transient_effect_frame(
	effects: Array[Dictionary],
	frame: int,
	last_frame: int,
	duration: float,
	generation: int
) -> void:
	if generation != _effect_generation:
		return
	transient_effects.clear()
	for effect in effects:
		if int(effect.get("frame", 0)) == frame:
			transient_effects.append(effect)
	queue_redraw()
	var timer := get_tree().create_timer(duration)
	if frame >= last_frame:
		timer.timeout.connect(_expire_transient_effects.bind(generation))
	else:
		timer.timeout.connect(_show_transient_effect_frame.bind(
			effects, frame + 1, last_frame, duration, generation
		))


func _show_shake_frame(
	frame: int, frames: int, duration: float, distance: float, generation: int
) -> void:
	if generation != _shake_generation:
		return
	if frame >= frames:
		_shake_offset = Vector2.ZERO
		_sync_base_layer()
		queue_redraw()
		return
	_shake_offset = Vector2(-distance * maxf(1.0, zoom_factor), 0.0) if frame & 1 == 0 else Vector2.ZERO
	_sync_base_layer()
	queue_redraw()
	get_tree().create_timer(duration).timeout.connect(
		_show_shake_frame.bind(frame + 1, frames, duration, distance, generation)
	)


func _draw() -> void:
	if city_texture == null:
		return
	var scale := _view_scale()
	var offset := _draw_offset(scale)
	if _base_layer == null:
		draw_texture_rect(
			city_texture,
			Rect2(offset, Vector2(city_texture.get_size()) * scale),
			false
		)
	if _base_layer == null:
		_draw_dynamic_sprites(scale, offset)
	_draw_transient_effects(scale, offset)
	_draw_signs(scale, offset)
	if city == null:
		return
	var highlighted: Array[Vector2i] = []
	if selection_mode == "point":
		var preview_point := selection_end if selection_end.x >= 0 else hover_tile
		highlighted = point_preview_tiles(preview_point)
	elif selection_start.x < 0 or selection_end.x < 0:
		return
	elif selection_mode == "path":
		highlighted = selection_path
	else:
		var minimum := Vector2i(
			mini(selection_start.x, selection_end.x), mini(selection_start.y, selection_end.y)
		)
		var maximum := Vector2i(
			maxi(selection_start.x, selection_end.x), maxi(selection_start.y, selection_end.y)
		)
		for x in range(minimum.x, maximum.x + 1):
			for y in range(minimum.y, maximum.y + 1):
				highlighted.append(Vector2i(x, y))
	for tile in highlighted:
		var source_polygon := Renderer.tile_polygon(city, tile.x, tile.y)
		var local_polygon := PackedVector2Array()
		for point in source_polygon:
			local_polygon.append(offset + point * scale)
		draw_colored_polygon(local_polygon, Color(0.3, 0.95, 0.45, 0.28))
		local_polygon.append(local_polygon[0])
		draw_polyline(local_polygon, Color(0.55, 1.0, 0.65, 0.9), 1.0)
	_draw_selection_price(scale, offset)


func _draw_selection_price(scale: float, offset: Vector2) -> void:
	if selection_price < 0 or selection_start.x < 0:
		return
	var polygon := Renderer.tile_polygon(city, selection_start.x, selection_start.y)
	if polygon.size() != 4:
		return
	var anchor := offset + (
		polygon[0] + polygon[1] + polygon[2] + polygon[3]
	) * 0.25 * scale + Vector2(10, -12)
	var font := get_theme_default_font()
	var text := selection_price_text()
	var color := Color("101010") if selection_price_affordable else Color("c00000")
	for outline in [
		Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0),
		Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1),
	]:
		draw_string(
			font, anchor + outline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color.WHITE,
		)
	draw_string(font, anchor, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


func _draw_transient_effects(scale: float, offset: Vector2) -> void:
	for effect in transient_effects:
		var texture: Texture2D = effect.get("texture") as Texture2D
		if texture == null:
			continue
		var source_position: Vector2 = effect.get("position", Vector2.ZERO)
		draw_texture_rect(
			texture,
			Rect2(offset + source_position * scale, Vector2(texture.get_size()) * scale),
			false
		)


func _draw_dynamic_sprites(scale: float, offset: Vector2) -> void:
	for visual in dynamic_sprites:
		var texture: Texture2D = visual.get("texture") as Texture2D
		if texture == null:
			continue
		var source_position: Vector2 = visual.get("position", Vector2.ZERO)
		var source_size: Vector2 = visual.get("size", Vector2(texture.get_size()))
		draw_texture_rect(
			texture,
			Rect2(offset + source_position * scale, source_size * scale),
			false
		)


func _draw_signs(scale: float, offset: Vector2) -> void:
	if not signs_visible or city == null or city_texture.get_width() <= CityState.MAP_SIZE:
		return
	var view_index := sign_view_index(zoom_factor)
	var display_multiplier := sign_display_multiplier(zoom_factor)
	var font := _get_sign_font()
	var font_size: int = SIGN_FONT_HEIGHTS[view_index]
	for diagonal in CityState.MAP_SIZE * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y
			if x >= CityState.MAP_SIZE or y >= CityState.MAP_SIZE:
				continue
			var label_id := city.text_overlay_id(x, y)
			if label_id < 1 or label_id > 50:
				continue
			var label_text := city.label(label_id)
			if label_text.is_empty():
				continue
			var polygon := Renderer.tile_polygon(city, x, y)
			if polygon.size() != 4:
				continue
			# every native painter moves from the tile's top point by the
			# equivalent of 16 pixels right and 8 pixels up in large space
			var anchor := offset + (polygon[0] + Vector2(0, -8)) * scale
			var text_width := font.get_string_size(
				label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
			).x
			var drawing_anchor := anchor
			if display_multiplier > 1.0:
				drawing_anchor = Vector2.ZERO
				draw_set_transform(
					anchor, 0.0, Vector2(display_multiplier, display_multiplier)
				)
			var layout := sign_layout(drawing_anchor, text_width, view_index)
			_draw_raised_sign_part(layout.panel, SIGN_PANEL_FILL, 1.0)
			var text_position := Vector2(
				layout.panel.position.x + 4.0,
				layout.panel.position.y + 2.0 + font.get_ascent(font_size),
			)
			draw_string(
				font, text_position, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				font_size, SIGN_TEXT_COLOR,
			)
			_draw_raised_sign_part(layout.post, SIGN_POST_FILL, 1.0)
			if display_multiplier > 1.0:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_draw_sign_occlusion(
				city.index_of(x, y), scale, offset
			)


func _draw_sign_occlusion(key: int, scale: float, offset: Vector2) -> void:
	var visual: Dictionary = sign_occlusion_visuals.get(key, {})
	if visual.is_empty():
		return
	var texture: Texture2D = visual.get("texture") as Texture2D
	if texture == null:
		return
	var source_position: Vector2 = visual.get("position", Vector2.ZERO)
	var source_size: Vector2 = visual.get("size", Vector2(texture.get_size()))
	draw_texture_rect(
		texture,
		Rect2(offset + source_position * scale, source_size * scale),
		false,
	)


static func sign_view_index(zoom: float) -> int:
	if zoom <= 0.25:
		return Renderer.VIEW_SMALL
	if zoom <= 0.5:
		return Renderer.VIEW_MEDIUM
	return Renderer.VIEW_LARGE


static func sign_display_multiplier(zoom: float) -> float:
	return 2.0 if zoom > 1.0 else 1.0


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
	if _sign_font == null:
		_sign_font = SystemFont.new()
		# the executable asks for "ariel", windows substitutes arial
		_sign_font.font_names = PackedStringArray(["Arial"])
		_sign_font.font_weight = 600
	return _sign_font


func _draw_raised_sign_part(rect: Rect2, fill: Color, multiplier: float) -> void:
	var edge := maxf(1.0, multiplier)
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	draw_rect(rect, fill)
	draw_polyline(
		PackedVector2Array([
			Vector2(right - 2.0 * edge, top + edge),
			Vector2(left + edge, top + edge),
			Vector2(left + edge, bottom - 2.0 * edge),
		]),
		SIGN_EDGE_LIGHT, 2.0 * edge, false,
	)
	draw_polyline(
		PackedVector2Array([
			Vector2(left + edge, bottom - 2.0 * edge),
			Vector2(right - 2.0 * edge, bottom - 2.0 * edge),
			Vector2(right - 2.0 * edge, top + edge),
		]),
		SIGN_EDGE_DARK, 2.0 * edge, false,
	)
	draw_line(
		Vector2(left, bottom - edge),
		Vector2(left + edge, bottom - 2.0 * edge),
		SIGN_EDGE_MIDDLE, edge, false,
	)


func _gui_input(event: InputEvent) -> void:
	if city_texture == null:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		zoom_in(event.position)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		zoom_out(event.position)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and cancel_active_selection():
		_panning = false
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
		_panning = event.pressed
		accept_event()
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not edit_enabled:
		return
	var tile := _tile_at(event.position)
	if event.pressed:
		if shift_query_enabled and event.shift_pressed:
			if tile.x >= 0:
				hover_tile = tile
				query_requested.emit(tile)
			accept_event()
			return
		if tile.x >= 0:
			hover_tile = tile
			selection_start = tile
			selection_end = tile
			selection_moved = false
			_rebuild_selection_path()
			selection_changed.emit(
				selection_start, selection_end, selection_path.duplicate(), false
			)
			queue_redraw()
	else:
		if selection_start.x >= 0:
			if tile.x >= 0 and tile != selection_end:
				selection_end = tile
				selection_moved = true
				_rebuild_selection_path()
			selection_completed.emit(
				selection_start,
				selection_end,
				selection_path.duplicate(),
				selection_moved,
			)
			_clear_selection()
			queue_redraw()
	accept_event()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _panning:
		source_center -= event.relative / _view_scale()
		_clamp_source_center()
		_sync_base_layer()
		queue_redraw()
		viewport_changed.emit()
		accept_event()
		return
	var tile := _tile_at(event.position)
	if tile != hover_tile:
		hover_tile = tile
		queue_redraw()
	if edit_enabled and selection_start.x >= 0:
		if tile.x >= 0 and tile != selection_end:
			selection_end = tile
			selection_moved = true
			_rebuild_selection_path()
			selection_changed.emit(
				selection_start,
				selection_end,
				selection_path.duplicate(),
				true,
			)
			queue_redraw()
		accept_event()


func _rebuild_selection_path() -> void:
	selection_path.clear()
	if selection_start.x < 0 or selection_end.x < 0:
		return
	if selection_mode == "point":
		selection_path.append(selection_end)
		return
	if selection_mode == "rectangle":
		var minimum := Vector2i(
			mini(selection_start.x, selection_end.x),
			mini(selection_start.y, selection_end.y),
		)
		var maximum := Vector2i(
			maxi(selection_start.x, selection_end.x),
			maxi(selection_start.y, selection_end.y),
		)
		for x in range(minimum.x, maximum.x + 1):
			for y in range(minimum.y, maximum.y + 1):
				selection_path.append(Vector2i(x, y))
		return
	var current := selection_start
	selection_path.append(current)
	while current != selection_end:
		var difference := selection_end - current
		if absi(difference.y) < absi(difference.x):
			current.x += 1 if difference.x > 0 else -1
		else:
			current.y += 1 if difference.y > 0 else -1
		selection_path.append(current)


func _clear_selection() -> void:
	selection_start = Vector2i(-1, -1)
	selection_end = Vector2i(-1, -1)
	selection_path.clear()
	selection_moved = false
	clear_selection_price()


static func _format_price(value: int) -> String:
	var digits := str(absi(value))
	var formatted := ""
	while digits.length() > 3:
		formatted = "," + digits.right(3) + formatted
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + formatted


func _clear_hover() -> void:
	if hover_tile.x < 0:
		return
	hover_tile = Vector2i(-1, -1)
	queue_redraw()


func _tile_at(local_point: Vector2) -> Vector2i:
	var scale := _view_scale()
	var source_point := (local_point - _draw_offset(scale)) / scale
	return Renderer.screen_to_tile(city, source_point)


func _change_zoom(direction: int, local_point: Vector2) -> bool:
	var old_index := _zoom_index()
	var new_index := clampi(old_index + direction, 0, ZOOM_LEVELS.size() - 1)
	if new_index == old_index:
		return false
	var anchor := local_point
	if not anchor.is_finite():
		anchor = size * 0.5
	var old_scale := _view_scale()
	var source_point := source_center
	if old_scale > 0.0:
		source_point = (anchor - _draw_offset(old_scale)) / old_scale
	zoom_factor = ZOOM_LEVELS[new_index]
	var new_scale := _view_scale()
	source_center = source_point + (size * 0.5 - anchor) / new_scale
	_clamp_source_center()
	_sync_base_layer()
	zoom_changed.emit(zoom_percent())
	queue_redraw()
	viewport_changed.emit()
	return true


func _zoom_index() -> int:
	var closest := 0
	var distance := absf(zoom_factor - ZOOM_LEVELS[0])
	for index in range(1, ZOOM_LEVELS.size()):
		var candidate := absf(zoom_factor - ZOOM_LEVELS[index])
		if candidate < distance:
			closest = index
			distance = candidate
	return closest


func _view_scale() -> float:
	return zoom_factor


func _draw_offset(scale: float) -> Vector2:
	return (size * 0.5 - source_center * scale).round() + _shake_offset


func _clamp_source_center() -> void:
	if city_texture == null:
		return
	var source_size := Vector2(city_texture.get_size())
	var half_visible := size / (_view_scale() * 2.0)
	for axis in 2:
		if half_visible[axis] >= source_size[axis] * 0.5:
			source_center[axis] = source_size[axis] * 0.5
		else:
			source_center[axis] = clampf(
				source_center[axis], half_visible[axis], source_size[axis] - half_visible[axis]
			)


func _on_resized() -> void:
	_clamp_source_center()
	_sync_base_layer()
	queue_redraw()
	viewport_changed.emit()


func _ensure_base_layer() -> void:
	if _base_layer != null:
		return
	_base_layer = TextureRect.new()
	_base_layer.name = "CityBaseLayer"
	_base_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_base_layer.stretch_mode = TextureRect.STRETCH_SCALE
	_base_layer.show_behind_parent = true
	_palette_shader = Shader.new()
	_palette_shader.code = PALETTE_CYCLE_SHADER
	_base_material = _new_palette_material()
	_base_layer.material = _base_material
	add_child(_base_layer)
	_dynamic_canvas = DynamicSpriteCanvas.new()
	_dynamic_canvas.name = "DynamicSpriteCanvas"
	_dynamic_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dynamic_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_dynamic_canvas.show_behind_parent = true
	_dynamic_material = _new_palette_material()
	_dynamic_canvas.material = _dynamic_material
	add_child(_dynamic_canvas)
	_dynamic_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sync_base_layer()


func _sync_base_layer() -> void:
	if _base_layer == null:
		return
	if city_texture == null:
		_base_layer.hide()
		return
	var scale := _view_scale()
	_base_layer.texture = city_texture
	_base_layer.position = _draw_offset(scale)
	_base_layer.size = Vector2(city_texture.get_size()) * scale
	_base_layer.show()
	_sync_base_material()
	_sync_dynamic_canvas()


func _sync_base_material() -> void:
	if _base_material == null:
		return
	_base_material.set_shader_parameter("palette_indices", palette_index_texture)
	_base_material.set_shader_parameter("animated_palette", animated_palette_texture)
	_base_material.set_shader_parameter(
		"palette_cycle_enabled",
		palette_index_texture != null and animated_palette_texture != null,
	)
	_base_material.set_shader_parameter("palette_lookup_all", base_palette_lookup_all)
	if _dynamic_material != null:
		_dynamic_material.set_shader_parameter(
			"animated_palette", animated_palette_texture
		)
		_dynamic_material.set_shader_parameter(
			"palette_cycle_enabled", animated_palette_texture != null
		)
		_dynamic_material.set_shader_parameter("palette_lookup_all", true)


func _sync_dynamic_canvas() -> void:
	if _dynamic_canvas == null:
		return
	if city_texture == null:
		_dynamic_canvas.hide()
		return
	var scale := _view_scale()
	var offset := _draw_offset(scale)
	_dynamic_canvas.set_visuals(dynamic_sprites, scale, offset)


func _new_palette_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _palette_shader
	return material
