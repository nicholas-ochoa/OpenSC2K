class_name CityMapControl
extends Control

signal selection_completed(start: Vector2i, finish: Vector2i, path: Array[Vector2i])

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const MIN_ZOOM := 1.0
const MAX_ZOOM := 12.0
const ZOOM_STEP := 1.25

var city: CityState
var city_texture: Texture2D
var edit_enabled := false
var selection_mode := "rectangle"
var zoom_factor := 1.0
var source_center := Vector2.ZERO
var selection_start := Vector2i(-1, -1)
var selection_end := Vector2i(-1, -1)
var selection_path: Array[Vector2i] = []
var transient_effects: Array[Dictionary] = []
var _panning := false
var _effect_generation := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_on_resized)


func set_city_view(value: CityState, texture: Texture2D) -> void:
	var reset_center := city_texture == null or city_texture.get_size() != texture.get_size()
	city = value
	city_texture = texture
	if reset_center and city_texture != null:
		source_center = Vector2(city_texture.get_size()) * 0.5
	_clamp_source_center()
	queue_redraw()


func set_edit_enabled(value: bool, mode := "rectangle") -> void:
	edit_enabled = value
	selection_mode = mode
	mouse_default_cursor_shape = (
		Control.CURSOR_CROSS if edit_enabled else Control.CURSOR_ARROW
	)
	if not edit_enabled:
		selection_start = Vector2i(-1, -1)
		selection_end = Vector2i(-1, -1)
		selection_path.clear()
	queue_redraw()


func zoom_percent() -> int:
	return roundi(zoom_factor * 100.0)


func center_on_tile(point: Vector2i) -> bool:
	if city == null or city.index_of(point.x, point.y) < 0:
		return false
	var polygon := Renderer.tile_polygon(city, point.x, point.y)
	if polygon.size() != 4:
		return false
	source_center = (polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.25
	_clamp_source_center()
	queue_redraw()
	return true


func show_transient_effects(effects: Array[Dictionary], duration := 0.1) -> void:
	_effect_generation += 1
	transient_effects = effects.duplicate()
	queue_redraw()
	if transient_effects.is_empty() or not is_inside_tree():
		return
	var timer := get_tree().create_timer(maxf(0.0, float(duration)))
	timer.timeout.connect(_expire_transient_effects.bind(_effect_generation))


func _expire_transient_effects(generation: int) -> void:
	if generation != _effect_generation:
		return
	transient_effects.clear()
	queue_redraw()


func _draw() -> void:
	if city_texture == null:
		return
	var scale := _view_scale()
	var offset := _draw_offset(scale)
	draw_texture_rect(
		city_texture,
		Rect2(offset, Vector2(city_texture.get_size()) * scale),
		false
	)
	_draw_transient_effects(scale, offset)
	_draw_signs(scale, offset)
	if selection_start.x < 0 or selection_end.x < 0 or city == null:
		return
	var highlighted: Array[Vector2i] = []
	if selection_mode == "path":
		highlighted = selection_path
	elif selection_mode == "point":
		highlighted = [selection_end]
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


func _draw_signs(scale: float, offset: Vector2) -> void:
	if city == null or city_texture.get_width() <= CityState.MAP_SIZE:
		return
	var font := get_theme_default_font()
	for index in CityState.TILE_COUNT:
		var label_id := city.text_overlays[index]
		if label_id < 1 or label_id > 50:
			continue
		var text := city.label(label_id)
		if text.is_empty():
			continue
		var x := int(index / CityState.MAP_SIZE)
		var y := index % CityState.MAP_SIZE
		var polygon := Renderer.tile_polygon(city, x, y)
		var position := offset + (polygon[0] + polygon[2]) * 0.5 * scale
		draw_circle(position, 4.0, Color("fff06a"))
		if zoom_factor >= 2.0:
			draw_string(font, position + Vector2(7, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


func _gui_input(event: InputEvent) -> void:
	if city_texture == null:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at(event.position, ZOOM_STEP)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at(event.position, 1.0 / ZOOM_STEP)
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
		if tile.x >= 0:
			selection_start = tile
			selection_end = tile
			selection_path = [tile]
			queue_redraw()
	else:
		if selection_start.x >= 0:
			if tile.x >= 0:
				selection_end = tile
				_append_selection_tile(tile)
			selection_completed.emit(selection_start, selection_end, selection_path.duplicate())
			selection_start = Vector2i(-1, -1)
			selection_end = Vector2i(-1, -1)
			selection_path.clear()
			queue_redraw()
	accept_event()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _panning:
		source_center -= event.relative / _view_scale()
		_clamp_source_center()
		queue_redraw()
		accept_event()
		return
	if edit_enabled and selection_start.x >= 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var tile := _tile_at(event.position)
		if tile.x >= 0 and tile != selection_end:
			selection_end = tile
			_append_selection_tile(tile)
			queue_redraw()
		accept_event()


func _append_selection_tile(tile: Vector2i) -> void:
	if selection_path.is_empty() or selection_path[-1] != tile:
		selection_path.append(tile)


func _tile_at(local_point: Vector2) -> Vector2i:
	var scale := _view_scale()
	var source_point := (local_point - _draw_offset(scale)) / scale
	return Renderer.screen_to_tile(city, source_point)


func _zoom_at(local_point: Vector2, multiplier: float) -> void:
	var old_scale := _view_scale()
	var source_point := (local_point - _draw_offset(old_scale)) / old_scale
	zoom_factor = clampf(zoom_factor * multiplier, MIN_ZOOM, MAX_ZOOM)
	var new_scale := _view_scale()
	source_center = source_point + (size * 0.5 - local_point) / new_scale
	_clamp_source_center()
	queue_redraw()


func _view_scale() -> float:
	if city_texture == null:
		return 1.0
	var source_size := Vector2(city_texture.get_size())
	if source_size.x <= 0.0 or source_size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return 1.0
	return minf(size.x / source_size.x, size.y / source_size.y) * zoom_factor


func _draw_offset(scale: float) -> Vector2:
	return size * 0.5 - source_center * scale


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
	queue_redraw()
