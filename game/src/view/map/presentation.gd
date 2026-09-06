class_name CityMapPresentation
extends CityMapConstants


var map: CityMapControl


func _init(control: CityMapControl) -> void:
	map = control


func set_city_view(
	value: CityState,
	source: CityMapSource,
	index_texture: Texture2D = null,
	palette_lookup_all := false,
	preserve_sign_cache := false,
	sign_layout_token: Array = []
) -> void:
	var reset_center := map.city_source == null or map.city_source.size != source.size
	var old_center := map.source_center
	var old_sign_scans := map._sign_cache_build_count
	var reuse_layout := (preserve_sign_cache and not sign_layout_token.is_empty() and sign_layout_token == map._external_sign_layout_token
			and map._sign_entries_city != null and is_equal_approx(map._sign_entries_zoom, map.zoom_factor))

	if not preserve_sign_cache or map.city != value:
		map._preserve_sign_layout = preserve_sign_cache
		map.city = value
		map._preserve_sign_layout = false

	if reuse_layout:
		map._sign_entries_city = value
	elif not sign_layout_token.is_empty() and sign_layout_token != map._external_sign_layout_token:
		map._sign_entries_city = null

	map._external_sign_layout_token = sign_layout_token.duplicate()
	map.city_source = source
	map.palette_index_texture = index_texture
	map.base_palette_lookup_all = palette_lookup_all

	if not preserve_sign_cache:
		map.signs._invalidate_sign_entries()

	if reset_center and map.city_source != null:
		map.source_center = Vector2(map.city_source.size) * 0.5

	if map.pending_loaded_center.x >= 0:
		map.camera.center_on_tile(map.pending_loaded_center)
		map.pending_loaded_center = Vector2i(-1, -1)

	map.camera._clamp_source_center()
	map.layers._sync_base_layer()

	if preserve_sign_cache:
		map.signs._ensure_sign_entries()

	if (not preserve_sign_cache or reset_center or old_center != map.source_center or old_sign_scans != map._sign_cache_build_count
			or map.hover_tile.x >= 0 or map.selection_start.x >= 0):
		map.queue_redraw()

	map.viewport_changed.emit()


func show_transient_effects(effects: Array[Dictionary], duration := 0.1) -> void:
	map._effect_generation += 1
	map.transient_effects.clear()
	map.queue_redraw()

	if effects.is_empty() or not map.is_inside_tree():
		return

	var sequence: Array[Dictionary] = []
	sequence.append_array(effects)
	var last_frame := 0

	for effect in sequence:
		last_frame = maxi(last_frame, int(effect.get("frame", 0)))

	_show_transient_effect_frame(
		sequence, 0, last_frame, maxf(0.0, float(duration)), map._effect_generation
	)


func shake_view(frames := 24, frame_duration := 0.005, distance := 4.0) -> void:
	map._shake_generation += 1
	map._shake_offset = Vector2.ZERO

	if frames <= 0 or not map.is_inside_tree():
		map.layers._sync_base_layer()
		map.queue_redraw()

		return

	_show_shake_frame(
		0,
		frames,
		maxf(0.0, float(frame_duration)),
		maxf(0.0, float(distance)),
		map._shake_generation
	)


func set_dynamic_sprites(sprites: Array[CityDynamicVisual]) -> void:
	var unchanged := map.dynamic_sprites.size() == sprites.size()

	if unchanged:
		for index in sprites.size():
			if not sprites[index].matches(map.dynamic_sprites[index]):
				unchanged = false
				break

	if unchanged:
		return

	var retained: Array[CityDynamicVisual] = []

	for visual in sprites:
		retained.append(visual.copy())

	map.dynamic_sprites = retained

	if map._dynamic_canvas != null:
		map._dynamic_canvas.set_visuals(
			map.dynamic_sprites, map.camera._view_scale(), map.camera._draw_offset(map.camera._view_scale())
		)
	else:
		map.queue_redraw()


func dynamic_render_node_count() -> int:
	return int(map._dynamic_canvas != null)


func debug_metrics() -> Dictionary:
	return {
		"zoom": "%d%%" % map.camera.zoom_percent(),
		"center_tile": str(map.camera.center_tile()),
		"panning": map._panning,
		"selection_drag": map.selection.is_left_drag_active(),
		"sign_entries": map._sign_entries.size(),
		"sign_scans": map._sign_cache_build_count,
		"dynamic_visuals": (
			map._dynamic_canvas.visual_count() if map._dynamic_canvas != null else 0
		),
		"dynamic_revisions": (
			map._dynamic_canvas.visual_revision if map._dynamic_canvas != null else 0
		),
		"transient_effects": map.transient_effects.size(),
	}


func _expire_transient_effects(generation: int) -> void:
	if generation != map._effect_generation:
		return

	map.transient_effects.clear()
	map.queue_redraw()


func _show_transient_effect_frame(
	effects: Array[Dictionary],
	frame: int,
	last_frame: int,
	duration: float,
	generation: int
) -> void:
	if generation != map._effect_generation:
		return

	map.transient_effects.clear()

	for effect in effects:
		if int(effect.get("frame", 0)) == frame:
			map.transient_effects.append(effect)

	map.queue_redraw()
	# keep timer callbacks bound to the control and its lifetime
	var timer := map.get_tree().create_timer(duration)

	if frame >= last_frame:
		timer.timeout.connect(map._expire_transient_effects.bind(generation))
	else:
		timer.timeout.connect(map._show_transient_effect_frame.bind(
			effects, frame + 1, last_frame, duration, generation
		))


func _show_shake_frame(
	frame: int, frames: int, duration: float, distance: float, generation: int
) -> void:
	if generation != map._shake_generation:
		return

	if frame >= frames:
		map._shake_offset = Vector2.ZERO
		map.layers._sync_base_layer()
		map.queue_redraw()

		return

	map._shake_offset = Vector2(-distance * maxf(1.0, map.zoom_factor), 0.0) if frame & 1 == 0 else Vector2.ZERO
	map.layers._sync_base_layer()
	map.queue_redraw()
	map.get_tree().create_timer(duration).timeout.connect(
		map._show_shake_frame.bind(frame + 1, frames, duration, distance, generation)
	)


func _draw() -> void:
	if map.city_source == null:
		return

	var scale := map.camera._view_scale()
	var offset := map.camera._draw_offset(scale)

	if map._price_layer != null:
		map._price_layer.queue_redraw()

	if map.data_view_mesh != null:
		map.layers._draw_data_view(scale, offset)

		if map.service_query != null:
			map.service_query.draw_on(map, scale, offset)
		if map.trip_reach != null:
			map.trip_reach.draw_on(map, scale, offset, map.trip_query_underground)

		return

	if map._base_layer == null and map.city_source.texture != null:
		map.draw_texture_rect(
			map.city_source.texture,
			Rect2(offset, Vector2(map.city_source.size) * scale),
			false
		)

	if map._base_layer == null:
		_draw_dynamic_sprites(scale, offset)

	_draw_transient_effects(scale, offset)
	map.signs._draw_signs(scale, offset)

	for stamp in map.scurk_stamp_visuals:
		map.draw_texture_rect(stamp.texture, Rect2(offset + stamp.position * scale, stamp.texture.get_size() * scale), false)

	if map.city == null:
		return

	var valid := not map.placement_validator.is_valid() or bool(map.placement_validator.call(map.selection_end if map.selection_end.x >= 0 else map.hover_tile))

	for source_polygon in map.selection._selection_source_polygons():
		var local_polygon := PackedVector2Array()

		for point in source_polygon:
			local_polygon.append(offset + point * scale)

		map.draw_colored_polygon(local_polygon, Color(0.3, 0.95, 0.45, 0.28) if valid else Color(1.0, 0.15, 0.12, 0.35))
		local_polygon.append(local_polygon[0])
		map.draw_polyline(local_polygon, Color(0.55, 1.0, 0.65, 0.9) if valid else Color(1.0, 0.25, 0.2, 0.95), 1.0)

	if map.selection.bulldozer_visible() and map.bulldozer_visual_provider.is_valid():
		var visual: CityDynamicVisual = map.bulldozer_visual_provider.call(map.hover_tile, map.bulldozer_direction)
		if visual != null:
			map.draw_texture_rect(
				visual.texture, Rect2(offset + visual.position * scale, visual.size * scale),
				false, CityForegroundPalette.INDEXED_DRAW_COLOR
			)

	if map.service_query != null:
		map.service_query.draw_on(map, scale, offset)
	if map.trip_reach != null:
		map.trip_reach.draw_on(map, scale, offset, map.trip_query_underground)


func _draw_transient_effects(scale: float, offset: Vector2) -> void:
	for effect in map.transient_effects:
		var texture: Texture2D = effect.get("texture") as Texture2D

		if texture == null:
			continue

		var source_position: Vector2 = effect.get("position", Vector2.ZERO)
		map.draw_texture_rect(
			texture,
			Rect2(offset + source_position * scale, Vector2(texture.get_size()) * scale),
			false
		)


func _draw_dynamic_sprites(scale: float, offset: Vector2) -> void:
	for visual in map.dynamic_sprites:
		var texture: Texture2D = visual.texture

		if texture == null:
			continue

		var source_position: Vector2 = visual.position
		var source_size: Vector2 = visual.size
		map.draw_texture_rect(
			texture,
			Rect2(offset + source_position * scale, source_size * scale),
			false
		)


func show_trip_reach(source: CityState, point: Vector2i) -> Dictionary:
	var result := TripReachAnalysis.inspect(source, point)
	if result.ok:
		map.trip_reach = TripReachOverlay.new()
		map.trip_reach.rebuild(source, result)
		map.queue_redraw()
	return result


func clear_trip_reach() -> void:
	if map.trip_reach != null:
		map.trip_reach = null
		map.queue_redraw()


func show_service_query(source: CityState, point: Vector2i, all_stations := false) -> ServiceQueryAnalysis.Result:
	clear_service_query()
	var result := ServiceQueryAnalysis.inspect(source, point, all_stations)
	if result.ok:
		map.service_query = ServiceQueryOverlay.new()
		map.service_query.rebuild(source, result)
	map.queue_redraw()
	return result


func clear_service_query() -> void:
	if map.service_query != null:
		map.service_query = null
		map.queue_redraw()
