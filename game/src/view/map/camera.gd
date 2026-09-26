class_name CityMapCamera
extends CityMapConstants


class ScrollState extends RefCounted:
	var content := Vector2.ZERO
	var page := Vector2.ZERO
	var value := Vector2.ZERO


var map: CityMapControl


func _init(control: CityMapControl) -> void:
	map = control


func zoom_percent() -> int:
	return roundi(map.zoom_factor * 100.0)


func zoom_in(local_point := Vector2.INF) -> bool:
	return _change_zoom(1, local_point)


func zoom_out(local_point := Vector2.INF) -> bool:
	return _change_zoom(-1, local_point)


func wheel_zoom(
	direction: int, local_point := Vector2.INF, current_time_msec := -1
) -> bool:
	if direction == 0:
		return false

	if current_time_msec < 0:
		current_time_msec = Time.get_ticks_msec()

	# one wheel gesture can send events for longer than the interval, for
	# example with smooth or momentum scrolling. each ignored event extends the
	# interval, up to a limit after the last zoom, so a continuous scroll still
	# steps through levels
	if current_time_msec < map._next_wheel_zoom_msec:
		map._next_wheel_zoom_msec = mini(
			current_time_msec + WHEEL_ZOOM_DEBOUNCE_MSEC,
			map._last_wheel_zoom_msec + WHEEL_ZOOM_MAX_DEBOUNCE_MSEC
		)

		return false

	var changed := _change_zoom(1 if direction > 0 else -1, local_point)

	if changed:
		map._last_wheel_zoom_msec = current_time_msec
		map._next_wheel_zoom_msec = current_time_msec + WHEEL_ZOOM_DEBOUNCE_MSEC

	return changed


func can_zoom_in() -> bool:
	return _zoom_index() < ZOOM_LEVELS.size() - 1


func can_zoom_out() -> bool:
	return _zoom_index() > 0


func pan_screen(displacement: Vector2) -> void:
	if displacement.is_zero_approx():
		return

	map.source_center += displacement / _view_scale()
	_clamp_source_center()
	map.selection._hide_placement_error()
	var pointer := map.get_local_mouse_position()
	map.hover_tile = _tile_at(pointer) if Rect2(Vector2.ZERO, map.size).has_point(pointer) else Vector2i(-1, -1)
	map.layers._sync_base_layer()
	map.queue_redraw()
	map.viewport_changed.emit()


func is_panning() -> bool:
	return map._panning


func center_on_tile(point: Vector2i) -> bool:
	return center_on_tiles(point, point)


# centers the view midway between two tiles, such as a building's opposite corners


func center_on_tiles(first: Vector2i, last: Vector2i) -> bool:
	if map.city == null or map.city.index_of(first.x, first.y) < 0 or map.city.index_of(last.x, last.y) < 0:
		return false

	var center := Vector2.ZERO

	for point in [first, last]:
		var polygon := Renderer.tile_polygon(map.city, point.x, point.y)

		if polygon.size() != 4:
			return false

		center += (polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.125

	map.source_center = center
	_clamp_source_center()
	map.layers._sync_base_layer()
	map.queue_redraw()
	map.viewport_changed.emit()

	return true


func center_tile() -> Vector2i:
	if map.city == null:
		return Vector2i(-1, -1)

	return Renderer.screen_to_tile(map.city, map.source_center + Vector2(0, -0.5))


func visible_source_rect() -> Rect2:
	var scale := _view_scale()

	return Rect2(-_draw_offset(scale) / scale, map.size / scale)


func visible_tile_outline() -> PackedVector2Array:
	var map_edge: int = map.city.map_size if map.city != null else 128
	var result := PackedVector2Array()

	if map.city == null or map.city_source == null:
		return result

	var half_visible := _camera_rect().size / (_view_scale() * 2.0)
	var source_points := PackedVector2Array([
		map.source_center + Vector2(-half_visible.x, -half_visible.y),
		map.source_center + Vector2(half_visible.x, -half_visible.y),
		map.source_center + Vector2(half_visible.x, half_visible.y),
		map.source_center + Vector2(-half_visible.x, half_visible.y),
	])
	var origin_x := Renderer.SIDE_MARGIN + map_edge * Renderer.HALF_WIDTH

	for point in source_points:
		var difference := (
			(point.x - origin_x - Renderer.HALF_WIDTH) / float(Renderer.HALF_WIDTH)
		)
		var sum := (
			(point.y - Renderer.TOP_MARGIN - Renderer.HALF_HEIGHT)
			/ float(Renderer.HALF_HEIGHT)
		)
		result.append(Vector2((sum + difference) * 0.5, (sum - difference) * 0.5))

	return result


func scroll_state() -> ScrollState:
	if map.city_source == null:
		return null

	var bounds := _camera_source_bounds()
	var content := bounds.size
	var visible := _camera_rect().size / _view_scale()
	var page := Vector2(
		minf(content.x, visible.x),
		minf(content.y, visible.y),
	)
	var value := map.source_center - bounds.position - page * 0.5

	for axis in 2:
		if page[axis] >= content[axis]:
			value[axis] = 0.0
		else:
			value[axis] = clampf(value[axis], 0.0, content[axis] - page[axis])

	var result := ScrollState.new()
	result.content = content
	result.page = page
	result.value = value

	return result


func set_scroll_value(axis: int, value: float) -> bool:
	if axis < 0 or axis > 1:
		return false

	var state := scroll_state()

	if state == null:
		return false

	var offset: Vector2 = state.value
	offset[axis] = value
	var page: Vector2 = state.page
	map.source_center = _camera_source_bounds().position + offset + page * 0.5
	_clamp_source_center()
	map.layers._sync_base_layer()
	map.queue_redraw()
	map.viewport_changed.emit()

	return true


func _tile_at(local_point: Vector2) -> Vector2i:
	var scale := _view_scale()
	var source_point := (local_point - _draw_offset(scale)) / scale

	return Renderer.screen_to_tile(map.city, source_point, map.data_view_mode == CityViewMode.Mode.HEIGHT)


func _change_zoom(direction: int, local_point: Vector2) -> bool:
	var old_index := _zoom_index()
	var new_index := clampi(old_index + direction, 0, ZOOM_LEVELS.size() - 1)

	if new_index == old_index:
		return false

	var anchor := local_point

	if not anchor.is_finite():
		anchor = _camera_rect().get_center()

	var old_scale := _view_scale()
	var source_point := map.source_center

	if old_scale > 0.0:
		source_point = (anchor - _draw_offset(old_scale)) / old_scale

	map.zoom_factor = ZOOM_LEVELS[new_index]
	map.signs._invalidate_sign_entries()
	var new_scale := _view_scale()
	map.source_center = source_point + (_camera_rect().get_center() - anchor) / new_scale
	_clamp_source_center()
	map.layers._sync_base_layer()
	map.zoom_changed.emit(zoom_percent())

	if not map.data_view_mode == CityViewMode.Mode.NONE and map.hover_tile.x >= 0:
		map.hover_tile = _tile_at(map.get_local_mouse_position())

	map.queue_redraw()
	map.viewport_changed.emit()

	return true


func _zoom_index() -> int:
	var closest := 0
	var distance := absf(map.zoom_factor - ZOOM_LEVELS[0])

	for index in range(1, ZOOM_LEVELS.size()):
		var candidate := absf(map.zoom_factor - ZOOM_LEVELS[index])

		if candidate < distance:
			closest = index
			distance = candidate

	return closest


func _view_scale() -> float:
	return map.zoom_factor * map.map_pixel_ratio


func _camera_rect() -> Rect2:
	return map.camera_view_rect if map.camera_view_rect.has_area() else Rect2(Vector2.ZERO, map.size)


func _draw_offset(scale: float) -> Vector2:
	var offset := _camera_rect().get_center() - map.source_center * scale

	if map.screen_pixel_scale == Vector2.ZERO:
		return offset.round() + map._shake_offset

	# put source pixel edges on screen pixel edges
	var to_screen := Transform2D.IDENTITY.scaled(map.screen_pixel_scale) * map.get_global_transform_with_canvas()

	return to_screen.affine_inverse() * (to_screen * offset).round() + map._shake_offset


func _camera_source_bounds() -> Rect2:
	# match the existing top margin without enlarging render textures or atlases
	var side_padding := float(Renderer.TOP_MARGIN - Renderer.SIDE_MARGIN)
	return Rect2(
		Vector2(-side_padding, 0),
		Vector2(map.city_source.size) + Vector2(side_padding * 2.0, 0)
	)


func _clamp_source_center() -> void:
	if map.city_source == null:
		return

	var bounds := _camera_source_bounds()
	var half_visible := _camera_rect().size / (_view_scale() * 2.0)

	for axis in 2:
		if half_visible[axis] >= bounds.size[axis] * 0.5:
			map.source_center[axis] = bounds.get_center()[axis]
		else:
			map.source_center[axis] = clampf(
				map.source_center[axis], bounds.position[axis] + half_visible[axis],
				bounds.end[axis] - half_visible[axis]
			)


# screen_pixels is the screen pixels for each interface pixel on each axis, and
# map_pixels is the whole screen pixels for each source pixel at 100% zoom.
# Godot rounds the interface layout to whole pixels, so the two screen axes can
# have slightly different scales. the map corrects the smaller axis so that a
# source pixel has the same whole number of screen pixels on each axis
func set_pixel_scales(screen_pixels: Vector2, map_pixels: int) -> void:
	var aligned := screen_pixels.x > 0.0 and screen_pixels.y > 0.0
	var reference := maxf(screen_pixels.x, screen_pixels.y)
	var ratio := float(maxi(1, map_pixels)) / reference if aligned else 1.0

	if map.screen_pixel_scale.is_equal_approx(screen_pixels) and is_equal_approx(map.map_pixel_ratio, ratio):
		return

	map.screen_pixel_scale = screen_pixels if aligned else Vector2.ZERO
	map.map_pixel_ratio = ratio
	map.scale = Vector2.ONE * reference / screen_pixels if aligned else Vector2.ONE
	map.signs._invalidate_sign_entries()
	_on_resized()


func _on_resized() -> void:
	_clamp_source_center()
	map.layers._sync_base_layer()
	map.queue_redraw()
	map.viewport_changed.emit()
