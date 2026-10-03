class_name CityMapPresentation
extends CityMapConstants

# the placement preview shows the object at half opacity
const GHOST_COLOR := Color(1.0, 1.0, 1.0, 0.5)

var map: CityMapControl
var _effect_generation := 0
# effect sequences that play now. each one advances on its own timer
var _effect_sequences: Array[TransientEffectSequence] = []
var _shake_generation := 0
var shake_offset := Vector2.ZERO


func _init(control: CityMapControl) -> void:
	map = control


func _draw() -> void:
	if map.city_source == null:
		return

	var scale := map.camera._view_scale()
	var offset := map.camera._draw_offset(scale)

	if map.layers.price_layer != null:
		map.layers.price_layer.queue_redraw()

	if map.layers.overlay_layer != null:
		map.layers.overlay_layer.queue_redraw()

	if map.data_view_mesh != null:
		map.layers._draw_data_view(scale, offset)

		if map.trip_reach != null:
			map.trip_reach.draw_on(map, scale, offset, map.trip_query_underground)

		return

	if map.layers.base_layer == null and map.city_source.texture != null:
		map.draw_texture_rect(
			map.city_source.texture,
			Rect2(offset, Vector2(map.city_source.size) * scale),
			false
		)

	if map.layers.base_layer == null:
		_draw_dynamic_sprites(scale, offset)

	_draw_transient_effects(scale, offset)
	map.signs._draw_signs(scale, offset)

	for stamp in map.scurk_stamp_visuals:
		map.draw_texture_rect(stamp.texture, Rect2(offset + stamp.position * scale, stamp.texture.get_size() * scale), false)


# the selection preview, the bulldozer and trip routes draw on a child layer
# above the city and signs. other map redraws reuse the cached preview meshes
func _draw_overlay() -> void:
	if map.city_source == null or map.city == null or map.data_view_mesh != null:
		return

	var canvas := map.layers.overlay_layer
	var scale := map.camera._view_scale()
	var offset := map.camera._draw_offset(scale)
	var valid := (not map.placement_validator.is_valid()
		or bool(map.placement_validator.call(map.selection_end if map.selection_end.x >= 0 else map.hover_tile)))

	map.selection._draw_selection_preview(canvas, scale, offset, valid)

	if map.placement_ghost_provider.is_valid() and map.edit_enabled and map.hover_tile.x >= 0:
		var ghost: CityDynamicVisual = map.placement_ghost_provider.call(map.hover_tile)

		if ghost != null:
			canvas.draw_texture_rect(ghost.texture, Rect2(offset + ghost.position * scale, ghost.size * scale), false, GHOST_COLOR)

	if map.selection.bulldozer_visible() and map.bulldozer_visual_provider.is_valid():
		var visual: CityDynamicVisual = map.bulldozer_visual_provider.call(map.hover_tile, map.bulldozer_direction)
		if visual != null:
			canvas.draw_texture_rect(
				visual.texture, Rect2(offset + visual.position * scale, visual.size * scale),
				false, CityForegroundPalette.INDEXED_DRAW_COLOR
			)

	if map.trip_reach != null:
		map.trip_reach.draw_on(canvas, scale, offset, map.trip_query_underground)


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
	var old_sign_scans := map.signs.sign_cache_build_count
	var reuse_layout := (preserve_sign_cache and not sign_layout_token.is_empty()
			and sign_layout_token == map.signs.external_sign_layout_token
			and map.signs.sign_entries_city != null and is_equal_approx(map.signs.sign_entries_zoom, map.zoom_factor))

	if not preserve_sign_cache or map.city != value:
		map._preserve_sign_layout = preserve_sign_cache
		map.city = value
		map._preserve_sign_layout = false

	if reuse_layout:
		map.signs.sign_entries_city = value
	elif not sign_layout_token.is_empty() and sign_layout_token != map.signs.external_sign_layout_token:
		map.signs.sign_entries_city = null

	map.signs.external_sign_layout_token = sign_layout_token.duplicate()
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

	if (not preserve_sign_cache or reset_center or old_center != map.source_center or old_sign_scans != map.signs.sign_cache_build_count
			or map.hover_tile.x >= 0 or map.selection_start.x >= 0):
		map.queue_redraw()

	map.viewport_changed.emit()


# play `effects` with the sequences that already play. an empty list stops them all
func show_transient_effects(effects: Array[CityTransientEffectVisual], duration := 0.1) -> void:
	if effects.is_empty():
		_effect_generation += 1
		_effect_sequences.clear()
		map.queue_redraw()

		return

	if not map.is_inside_tree():
		return

	var sequence := TransientEffectSequence.new(effects)
	_effect_sequences.append(sequence)
	_show_transient_effect_frame(sequence, 0, maxf(0.0, float(duration)), _effect_generation)


func transient_effect_count() -> int:
	var count := 0

	for sequence in _effect_sequences:
		count += sequence.current().size()

	return count


func shake_view(frames := 24, frame_duration := 0.005, distance := 4.0) -> void:
	_shake_generation += 1
	shake_offset = Vector2.ZERO

	if frames <= 0 or not map.is_inside_tree():
		map.layers._sync_base_layer()
		map.queue_redraw()

		return

	_show_shake_frame(
		0,
		frames,
		maxf(0.0, float(frame_duration)),
		maxf(0.0, float(distance)),
		_shake_generation
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

	if map.layers.dynamic_canvas != null:
		map.layers.dynamic_canvas.set_visuals(
			map.dynamic_sprites, map.camera._view_scale(), map.camera._draw_offset(map.camera._view_scale())
		)
	else:
		map.queue_redraw()


func dynamic_render_node_count() -> int:
	return int(map.layers.dynamic_canvas != null)


func debug_metrics() -> Dictionary:
	return {
		"zoom": "%d%%" % map.camera.zoom_percent(),
		"center_tile": str(map.camera.center_tile()),
		"panning": map.interaction.panning,
		"selection_drag": map.selection.is_left_drag_active(),
		"sign_entries": map.signs.sign_entries.size(),
		"sign_scans": map.signs.sign_cache_build_count,
		"dynamic_visuals": (
			map.layers.dynamic_canvas.visual_count() if map.layers.dynamic_canvas != null else 0
		),
		"dynamic_revisions": (
			map.layers.dynamic_canvas.visual_revision if map.layers.dynamic_canvas != null else 0
		),
		"transient_effects": transient_effect_count(),
	}


func _expire_transient_effects(sequence: TransientEffectSequence, generation: int) -> void:
	if generation != _effect_generation:
		return

	_effect_sequences.erase(sequence)
	map.queue_redraw()


func _show_transient_effect_frame(
	sequence: TransientEffectSequence,
	frame: int,
	duration: float,
	generation: int
) -> void:
	if generation != _effect_generation:
		return

	sequence.frame = frame
	map.queue_redraw()
	# keep timer callbacks bound to the control and its lifetime
	var timer := map.get_tree().create_timer(duration)

	if frame >= sequence.frames.size() - 1:
		timer.timeout.connect(map._expire_transient_effects.bind(sequence, generation))
	else:
		timer.timeout.connect(map._show_transient_effect_frame.bind(sequence, frame + 1, duration, generation))


func _show_shake_frame(
	frame: int, frames: int, duration: float, distance: float, generation: int
) -> void:
	if generation != _shake_generation:
		return

	if frame >= frames:
		shake_offset = Vector2.ZERO
		map.layers._sync_base_layer()
		map.queue_redraw()

		return

	shake_offset = Vector2(-distance * maxf(1.0, map.zoom_factor) * map.map_pixel_ratio, 0.0) if frame & 1 == 0 else Vector2.ZERO
	map.layers._sync_base_layer()
	map.queue_redraw()
	map.get_tree().create_timer(duration).timeout.connect(
		map._show_shake_frame.bind(frame + 1, frames, duration, distance, generation)
	)


func _draw_transient_effects(scale: float, offset: Vector2) -> void:
	var effects: Array[CityTransientEffectVisual] = []

	for sequence in _effect_sequences:
		for effect: CityTransientEffectVisual in sequence.current():
			effect.order = effects.size()
			effects.append(effect)

	# effects of separate requests overlap. draw them in painter order
	if _effect_sequences.size() > 1:
		effects.sort_custom(CityTransientEffectVisual.draws_before)

	for effect in effects:
		var texture: Texture2D = effect.texture

		if texture == null:
			continue

		var source_position: Vector2 = effect.position
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


func show_trip_reach(source: CityState, point: Vector2i) -> TransportTripReachResult:
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


# the visuals of one effect request, grouped by frame
class TransientEffectSequence extends RefCounted:
	var frames: Array[Array] = []
	var frame := 0

	func _init(effects: Array[CityTransientEffectVisual]) -> void:
		for effect in effects:
			while frames.size() <= effect.frame:
				frames.append([])

			frames[effect.frame].append(effect)

	func current() -> Array:
		return frames[frame] if frame < frames.size() else []
