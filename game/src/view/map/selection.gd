class_name CityMapSelection
extends CityMapConstants


@warning_ignore_start("integer_division")

var map: CityMapControl


func _init(control: CityMapControl) -> void:
	map = control


func set_edit_enabled(
	value: bool,
	mode := "rectangle",
	footprint_area := 1,
	shift_queries := false
) -> void:
	_hide_placement_error()
	map.edit_enabled = value
	map.selection_mode = mode
	map.point_footprint_area = clampi(footprint_area, 1, 7)
	map.shift_query_enabled = shift_queries
	clear_selection_price()
	map.mouse_default_cursor_shape = (
		Control.CURSOR_CROSS if map.edit_enabled else Control.CURSOR_ARROW
	)

	if not map.edit_enabled:
		map.selection_start = Vector2i(-1, -1)
		map.selection_end = Vector2i(-1, -1)
		map.selection_path.clear()
		map.hover_tile = Vector2i(-1, -1)

	map.queue_redraw()


func uses_paint_brush() -> bool:
	return map.landscape_brush or map.demolish_brush


func bulldozer_visible() -> bool:
	return (
		map.demolish_brush and map.edit_enabled and map.bulldozer_visual_provider.is_valid()
		and is_left_drag_active() and not map.brush_box_selection and map.hover_tile.x >= 0
	)


func is_left_drag_active() -> bool:
	return map.selection_start.x >= 0


func selection_tiles() -> Array[Vector2i]:
	return map.selection_path.duplicate()


func selection_was_dragged() -> bool:
	return map.selection_moved


func set_selection_price(value: int, affordable := true) -> void:
	var price := maxi(-1, value)

	if price == map.selection_price and affordable == map.selection_price_affordable:
		return

	map.selection_price = price
	map.selection_price_affordable = affordable
	map.queue_redraw()


func clear_selection_price() -> void:
	if map.selection_price < 0:
		return

	map.selection_price = -1
	map.selection_price_affordable = true
	map.queue_redraw()


func selection_price_text() -> String:
	if map.selection_price < 0:
		return ""

	return "$%s" % _format_price(map.selection_price)


func point_preview_tiles(point: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	if map.city == null or map.city.index_of(point.x, point.y) < 0:
		return result

	if map.landscape_brush:
		return brush_tiles(point)

	if map.point_footprint_area == 7:
		for x in range(-3, 4):
			for y in range(-3, 4):
				var tile := point + Vector2i(x + 3, y + 3)

				if x * x + y * y <= 10 and map.city.index_of(tile.x, tile.y) >= 0:
					result.append(tile)

		return result

	var site := BuildingTool.footprint(point, map.point_footprint_area)

	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			if map.city.index_of(x, y) >= 0:
				result.append(Vector2i(x, y))

	return result


func cancel_active_selection() -> bool:
	if map.selection_start.x < 0:
		return false

	_clear_selection()
	map.queue_redraw()
	map.selection_canceled.emit()
	map.selection_finished.emit()

	return true


func _selection_source_polygons() -> Array[PackedVector2Array]:
	var tiles: Array[Vector2i]

	if not map.show_selection_preview or not map.edit_enabled:
		return []

	if map.network_preview_active:
		if map.hover_tile.x >= 0:
			tiles.append(map.hover_tile)
	elif map.query_footprint_preview and map._shift_pressed:
		tiles = _query_footprint_tiles(map.hover_tile)
	elif map.brush_box_selection:
		tiles = map.selection_path.duplicate()
	elif map.selection_mode == "point":
		var preview_point := map.selection_end if map.selection_end.x >= 0 else map.hover_tile
		tiles = point_preview_tiles(preview_point)
	elif map.selection_start.x >= 0 and map.selection_end.x >= 0:
		tiles = map.selection_path
	elif map.edit_enabled and map.selection_mode == "path" and map.hover_tile.x >= 0:
		tiles = [map.hover_tile]

	if map.highway_preview and not map.network_preview_active:
		var expanded: Array[Vector2i] = []
		var seen := {}

		for tile in tiles:
			var anchor := HighwayGeometry.snap_anchor(tile)

			for x in range(anchor.x, anchor.x + 2):
				for y in range(anchor.y, anchor.y + 2):
					var point := Vector2i(x, y)

					if not seen.has(point) and map.city.index_of(x, y) >= 0:
						seen[point] = true
						expanded.append(point)

		tiles = expanded

	var polygons: Array[PackedVector2Array] = []

	for tile in tiles:
		var polygon := Renderer.tile_polygon(map.city, tile.x, tile.y) if map.terrain_diamond_preview else Renderer.terrain_surface_polygon(map.city, tile.x, tile.y)

		if polygon.size() == 4:
			polygons.append(polygon)

	return polygons


func _draw_selection_price() -> void:
	if map.city == null or map.selection_price < 0 or map.selection_start.x < 0:
		return

	if not map.data_view_mode.is_empty():
		return

	var polygon := Renderer.tile_polygon(map.city, map.selection_start.x, map.selection_start.y)

	if polygon.size() != 4:
		return

	var scale := map.camera._view_scale()
	var anchor := map.camera._draw_offset(scale) + (
		polygon[0] + polygon[1] + polygon[2] + polygon[3]
	) * 0.25 * scale + Vector2(10, -12)
	var font := map.get_theme_default_font()
	var text := selection_price_text()
	var color := Color("101010") if map.selection_price_affordable else Color("c00000")

	for outline in [
		Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0),
		Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1),
	]:
		map._price_layer.draw_string(
			font, anchor + outline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color.WHITE,
		)

	map._price_layer.draw_string(
		font, anchor, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color
	)


func _rebuild_selection_path() -> void:
	map.selection_path.clear()

	if map.selection_start.x < 0 or map.selection_end.x < 0:
		return

	if map.selection_mode == "point" and not map.brush_box_selection:
		map.selection_path.append(map.selection_end)

		return

	if (map.selection_mode == "rectangle" and not (map.shift_line_enabled and map._shift_pressed)) or map.brush_box_selection or (map.shift_rectangle_enabled and map._shift_pressed and not uses_paint_brush()):
		var minimum := Vector2i(
			mini(map.selection_start.x, map.selection_end.x),
			mini(map.selection_start.y, map.selection_end.y),
		)
		var maximum := Vector2i(
			maxi(map.selection_start.x, map.selection_end.x),
			maxi(map.selection_start.y, map.selection_end.y),
		)

		for x in range(minimum.x, maximum.x + 1):
			for y in range(minimum.y, maximum.y + 1):
				map.selection_path.append(Vector2i(x, y))

		return

	var current := map.selection_start
	map.selection_path.append(current)

	while current != map.selection_end:
		var difference := map.selection_end - current

		if absi(difference.y) < absi(difference.x):
			current.x += 1 if difference.x > 0 else -1
		else:
			current.y += 1 if difference.y > 0 else -1

		map.selection_path.append(current)


func _clear_selection() -> void:
	map.brush_box_selection = false
	map.selection_start = Vector2i(-1, -1)
	map.selection_end = Vector2i(-1, -1)
	map.selection_path.clear()
	map._last_brush_tile = Vector2i(-1, -1)
	map.selection_moved = false
	clear_selection_price()


static func _format_price(value: int) -> String:
	var digits := str(absi(value))
	var formatted := ""

	while digits.length() > 3:
		formatted = "," + digits.right(3) + formatted
		digits = digits.left(digits.length() - 3)

	return ("-" if value < 0 else "") + digits + formatted


func _clear_hover() -> void:
	_hide_placement_error()

	if map.hover_tile.x < 0:
		return

	map.hover_tile = Vector2i(-1, -1)
	map.queue_redraw()


func _query_footprint_tiles(point: Vector2i) -> Array[Vector2i]:
	var map_edge: int = map.city.map_size if map.city != null else 128
	var result: Array[Vector2i] = []
	var source := map.query_city if map.query_city != null else map.city

	if source == null or source.index_of(point.x, point.y) < 0:
		return result

	var tile_id := source.building_id(point.x, point.y)
	var area := DemolishTool._building_area(tile_id)
	var site := Rect2i(point, Vector2i.ONE)

	if area > 1:
		var found := DemolishTool._find_building_site(
			source.buildings, source.zones, point, tile_id, area, source.compass_rotation(), map_edge
		)

		if found.has_area():
			site = found

	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			result.append(Vector2i(x, y))

	return result


func _get_tooltip(at_position: Vector2) -> String:
	if map.service_query != null and not map.camera.is_panning():
		return map.service_query.tile_tooltip(map.camera._tile_at(at_position))
	if map.trip_reach != null and not map.camera.is_panning():
		return map.trip_reach.tile_tooltip(map.camera._tile_at(at_position))

	if not map.edit_enabled or not map.show_selection_preview or map.camera.is_panning() or map.selection_start.x >= 0 or not map.placement_error_provider.is_valid():
		return ""

	var tile := map.camera._tile_at(at_position)

	if tile.x < 0:
		return ""

	var reason := String(map.placement_error_provider.call(tile))

	return "Cannot build here: " + reason if not reason.is_empty() else ""


func _show_placement_error(at_position: Vector2) -> void:
	_hide_placement_error()
	var message := _get_tooltip(at_position)

	if message.is_empty():
		return

	if map.placement_error_popup == null:
		map.placement_error_popup = PanelContainer.new()
		map.placement_error_popup.name = "PlacementErrorTooltip"
		map.placement_error_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map.placement_error_popup.theme = AppUiTheme.current()
		map.placement_error_popup.theme_type_variation = "TooltipPanel"
		map.placement_error_popup.z_index = 100
		map.placement_error_label = Label.new()
		map.placement_error_label.theme_type_variation = "TooltipLabel"
		map.placement_error_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		map.placement_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		map.placement_error_label.custom_minimum_size.x = 300
		map.placement_error_popup.add_child(map.placement_error_label)
		map.add_child(map.placement_error_popup)

	map.placement_error_label.text = message
	map.placement_error_popup.reset_size()
	map.placement_error_popup.position = (at_position + Vector2(16, 20)).clamp(
		Vector2.ZERO, (map.size - map.placement_error_popup.size).max(Vector2.ZERO)
	)
	map.placement_error_popup.show()


func _hide_placement_error() -> void:
	if is_instance_valid(map.placement_error_popup):
		map.placement_error_popup.hide()


func _emit_brush_dab(tile: Vector2i, dragged: bool) -> void:
	var points: Array[Vector2i] = [tile]
	if uses_paint_brush():
		points.clear()
		var previous := map._last_brush_tile if map._last_brush_tile.x >= 0 else tile
		var movement := tile - previous
		if movement != Vector2i.ZERO:
			if absi(movement.x) > absi(movement.y):
				map.bulldozer_direction = 1 if movement.x > 0 else 3
			else:
				map.bulldozer_direction = 2 if movement.y > 0 else 0
		var distance := maxi(absi(movement.x), absi(movement.y))
		var seen := {}
		for step in range(distance + 1):
			var center := Vector2i(Vector2(previous).lerp(Vector2(tile), float(step) / maxf(1.0, distance)).round())
			for point in (brush_tiles(center) if map.landscape_brush else [center]):
				if not seen.has(point):
					seen[point] = true
					points.append(point)
		map._last_brush_tile = tile
	map.selection_completed.emit(tile, tile, points, dragged)


func brush_tiles(center: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	if map.city == null or center.x < 0:
		return points
	var width := clampi(map.brush_size, 1, 15)
	var offset := (width - 1) / 2
	var middle := float(width - 1) * 0.5
	for x in width:
		for y in width:
			if map.brush_round and Vector2(x - middle, y - middle).length_squared() > pow(float(width) * 0.5, 2.0):
				continue
			var point := center + Vector2i(x - offset, y - offset)
			if map.city.index_of(point.x, point.y) >= 0:
				points.append(point)
	return points
