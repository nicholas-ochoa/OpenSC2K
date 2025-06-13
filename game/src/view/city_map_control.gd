class_name CityMapControl
extends Control

signal selection_completed(start: Vector2i, finish: Vector2i)

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const MIN_ZOOM := 1.0
const MAX_ZOOM := 12.0
const ZOOM_STEP := 1.25

var city: CityState
var city_texture: Texture2D
var edit_enabled := false
var zoom_factor := 1.0
var source_center := Vector2.ZERO
var selection_start := Vector2i(-1, -1)
var selection_end := Vector2i(-1, -1)
var _panning := false


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


func set_edit_enabled(value: bool) -> void:
	edit_enabled = value
	mouse_default_cursor_shape = (
		Control.CURSOR_CROSS if edit_enabled else Control.CURSOR_ARROW
	)
	if not edit_enabled:
		selection_start = Vector2i(-1, -1)
		selection_end = Vector2i(-1, -1)
	queue_redraw()


func zoom_percent() -> int:
	return roundi(zoom_factor * 100.0)


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
	if selection_start.x < 0 or selection_end.x < 0 or city == null:
		return
	var minimum := Vector2i(
		mini(selection_start.x, selection_end.x), mini(selection_start.y, selection_end.y)
	)
	var maximum := Vector2i(
		maxi(selection_start.x, selection_end.x), maxi(selection_start.y, selection_end.y)
	)
	for x in range(minimum.x, maximum.x + 1):
		for y in range(minimum.y, maximum.y + 1):
			var source_polygon := Renderer.tile_polygon(city, x, y)
			var local_polygon := PackedVector2Array()
			for point in source_polygon:
				local_polygon.append(offset + point * scale)
			draw_colored_polygon(local_polygon, Color(0.3, 0.95, 0.45, 0.28))
			local_polygon.append(local_polygon[0])
			draw_polyline(local_polygon, Color(0.55, 1.0, 0.65, 0.9), 1.0)


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
			queue_redraw()
	else:
		if selection_start.x >= 0:
			if tile.x >= 0:
				selection_end = tile
			selection_completed.emit(selection_start, selection_end)
			selection_start = Vector2i(-1, -1)
			selection_end = Vector2i(-1, -1)
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
			queue_redraw()
		accept_event()


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
