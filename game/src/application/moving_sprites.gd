class_name ApplicationMovingSprites
extends RefCounted


@warning_ignore_start("integer_division")

const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const DynamicSpriteCanvas = preload("res://src/view/city_dynamic_sprite_canvas.gd")

# the rate that keeps the original 200 ms steps and the cpu occlusion path
const ORIGINAL_FRAME_RATE := 5
# blend only a short move. a longer change is a new, removed, or reused record
const BLEND_TILE_LIMIT := 2

var app: CityApplication
var caches: RenderCaches
# display interpolation state by xthg record. see `note_moving_tick`
var _blend_from: Dictionary[int, IsometricMovingVisuals.Position] = {}
var _blend_to: Dictionary[int, IsometricMovingVisuals.Anchor] = {}
var _blend_city_id := 0
var _blend_view_size := -1
var _blend_tick_msec := 0
var _blend_alpha := 1.0


func _init(application: CityApplication) -> void:
	app = application
	caches = application.render_caches


# true when moving objects use gpu occlusion and display interpolation
func _gpu_moving_active() -> bool:
	return (
		app.preferences.moving_frame_rate > ORIGINAL_FRAME_RATE
		and app.map_view != null
		and app.map_view.moving_occlusion_active()
	)


# start a blend after a moving-object tick. each record moves from its displayed
# position to its new saved position. the blend never changes simulation state
func note_moving_tick(now_msec := -1) -> void:
	if now_msec < 0:
		now_msec = Time.get_ticks_msec()

	if app.document_state.city == null or app.preferences.moving_frame_rate <= ORIGINAL_FRAME_RATE:
		reset_blend()

		return

	var view_size := app.static_render.city_view_size()
	var continuing := _blend_city_id == app.document_state.city.get_instance_id() and _blend_view_size == view_size
	var next: Dictionary[int, IsometricMovingVisuals.Anchor] = {}
	var from: Dictionary[int, IsometricMovingVisuals.Position] = {}

	for record in app.document_state.city.thing_count():
		var anchor := IsometricRenderer.moving_thing_anchor(app.document_state.city, record, view_size)

		if anchor == null:
			continue

		next[record] = anchor

		if continuing and _blend_to.has(record) and can_blend(_blend_to[record], anchor):
			from[record] = _displayed_anchor(record)

	_blend_to = next
	_blend_from = from
	_blend_city_id = app.document_state.city.get_instance_id()
	_blend_view_size = view_size
	_blend_tick_msec = now_msec
	_blend_alpha = 0.0
	_apply_blend()


# move the blend forward at the selected display rate
func advance_blend(now_msec := -1) -> void:
	if _blend_from.is_empty():
		return

	if now_msec < 0:
		now_msec = Time.get_ticks_msec()

	var alpha := blend_alpha(now_msec - _blend_tick_msec, app.preferences.moving_frame_rate)

	if is_equal_approx(alpha, _blend_alpha):
		return

	_blend_alpha = alpha
	_apply_blend()

	if alpha >= 1.0:
		_blend_from.clear()


func reset_blend() -> void:
	_blend_from.clear()
	_blend_to.clear()
	_blend_city_id = 0
	_blend_view_size = -1
	_blend_alpha = 1.0

	if app.map_view != null:
		app.map_view.set_moving_blend({}, {})


# return the blend fraction after `elapsed_msec`, stepped at `frame_rate`
static func blend_alpha(elapsed_msec: float, frame_rate: int) -> float:
	if frame_rate <= ORIGINAL_FRAME_RATE:
		return 1.0

	var interval := 1000.0 / frame_rate
	var shown := elapsed_msec if frame_rate >= 60 else floorf(elapsed_msec / interval) * interval

	return clampf(shown / GameSpeedController.BASE_TICK_MSEC, 0.0, 1.0)


# true when a record can move smoothly from `previous` to `current`
static func can_blend(previous: IsometricMovingVisuals.Anchor, current: IsometricMovingVisuals.Anchor) -> bool:
	var previous_type := int(previous.type)
	var current_type := int(current.type)
	var same_type := previous_type == current_type or (previous_type in [10, 11] and current_type in [10, 11])

	return (
		same_type
		and absi(int(previous.x) - int(current.x)) <= BLEND_TILE_LIMIT
		and absi(int(previous.y) - int(current.y)) <= BLEND_TILE_LIMIT
	)


func _displayed_anchor(record: int) -> IsometricMovingVisuals.Position:
	var target: IsometricMovingVisuals.Anchor = _blend_to[record]

	if not _blend_from.has(record):
		return target

	var start: IsometricMovingVisuals.Position = _blend_from[record]

	# Use the later draw order between tiles so neither tile's flat surface covers the sprite.
	var result := IsometricMovingVisuals.Position.new()
	result.anchor = start.anchor.lerp(target.anchor, _blend_alpha)
	result.order = maxi(int(start.order), int(target.order)) if _blend_alpha < 1.0 else int(target.order)

	return result


func _apply_blend() -> void:
	if app.map_view == null:
		return

	var offsets := {}
	var orders := {}
	# keep whole screen pixels so a sprite does not shimmer between texels
	var scale := maxf(app.map_view.screen_pixels_per_source_pixel(), 0.01)

	for record in _blend_from:
		var shown := _displayed_anchor(record)
		var offset: Vector2 = shown.anchor - _blend_to[record].anchor
		offsets[record] = (offset * scale).round() / scale
		orders[record] = int(shown.order)

	app.map_view.set_moving_blend(offsets, orders)


func refresh_moving_things(view_size := -1) -> void:
	if app.map_view != null:
		app.map_view.set_moving_occlusion_enabled(app.preferences.moving_frame_rate > ORIGINAL_FRAME_RATE)

	if app.document_state.city == null or app.asset_state.palette == null or app.map_view == null or app.view_state.overlay_mode != CityViewMode.Mode.CITY:
		caches.dynamic_sign_occluders.clear()
		caches.dynamic_sign_occlusion_grid.clear()

		if app.map_view != null:
			app.map_view.set_dynamic_sprites([])

		return

	if caches.region_cache != null and caches.region_cache.gpu_enabled and not caches.region_cache.covered():
		caches.foreground_complete = false
		app.map_view.set_dynamic_sprites([])
		app.map_view.set_sign_occlusion_visuals({})

		return

	if caches.dynamic_visual_cache.size() > 4096:
		caches.dynamic_visual_cache.clear()

	if view_size < 0:
		view_size = app.static_render.city_view_size()

	var sprite_archive := app.static_render.sprite_archive_for_view(view_size)
	var configuration := IsometricRenderer.view_configuration(view_size)
	var divisor := configuration.divisor
	var factor := 1
	var commands := caches.dynamic_command_cache.get_commands(
		app.document_state.city, sprite_archive, view_size, int(Time.get_ticks_msec() / 100)
	)
	var visuals: Array[CityDynamicVisual] = []
	var gpu_moving := _gpu_moving_active()

	for command in commands:
		if not app.view_state.show_vehicles and command.record >= 0 and _is_vehicle(int(command.record)):
			continue

		if (caches.region_cache != null and not Rect2(Vector2(command.position) * divisor,
				Vector2(Vector2i(256, 256)) * divisor).intersects(app.map_view.visible_source_rect().grow(256 * divisor))):
			continue

		# the shader applies occlusion and shadows, so the visual needs no image work
		if gpu_moving and command.overlay < 0:
			var gpu_visual := _gpu_moving_visual(sprite_archive, command, divisor, factor)

			if gpu_visual != null:
				visuals.append(gpu_visual)

			continue

		var visual_cache_key := var_to_str([view_size, factor, command.value_signature()])

		if caches.dynamic_visual_cache.has(visual_cache_key):
			var cached: CityDynamicVisual = caches.dynamic_visual_cache[visual_cache_key]

			if cached != null and not cached.hidden:
				visuals.append(cached)

			continue

		var resource := dynamic_sprite_resource(
			sprite_archive, command.sprite_id, command.flip, divisor, factor
		)

		if resource == null:
			continue

		var position := Vector2i(command.position) * divisor
		var texture: Texture2D = resource.texture
		var index_texture: Texture2D = resource.index_texture
		var visual_image: Image = resource.image
		var occluder_mask: Image

		if bool(command.static_occlusion):
			occluder_mask = _dynamic_occluder_image(
				sprite_archive, divisor, position, resource.native_size,
				int(command.depth_order), bool(command.train), factor
			)

		var samples_static := bool(command.shadow)

		if command.shadow:
			var shadow_image := _dynamic_shadow_image(resource.image, position, occluder_mask, factor)

			if shadow_image == null:
				var hidden := CityDynamicVisual.new(null, Vector2(position), Vector2(resource.native_size))
				hidden.hidden = true
				hidden.samples_static = true
				caches.dynamic_visual_cache[visual_cache_key] = hidden
				continue

			visual_image = shadow_image
			texture = ImageTexture.create_from_image(shadow_image)
			index_texture = null
		else:
			var foreground_indices: PackedInt32Array = command.same_tile_foreground_indices
			var index_reader := Callable()

			if caches.region_cache != null and not foreground_indices.is_empty():
				var sampled := caches.region_cache.image_region(Rect2i(position, resource.native_size), factor)
				samples_static = true
				index_reader = func(x: int, y: int) -> Color:
					return sampled.get_pixel(x - position.x * factor, y - position.y * factor)

			var occluded := IsometricRenderer.occlude_dynamic_with_mask(
				resource.image, occluder_mask, position * factor, caches.static_city_image,
				foreground_indices, index_reader
			)

			if int(occluded.occluded_pixels) > 0:
				visual_image = occluded.image
				texture = ImageTexture.create_from_image(occluded.image)
				index_texture = texture

		var visual := CityDynamicVisual.new()
		visual.samples_static = samples_static
		visual.texture = texture
		visual.index_texture = index_texture
		visual.palette_lookup_all = true
		visual.texture_factor = factor
		visual.position = Vector2(position)
		visual.size = Vector2(resource.native_size)
		visual.image = visual_image
		visual.special_overlay = command.overlay >= 0
		visual.batch_cache_key = visual_cache_key
		visual.depth_order = int(command.depth_order)
		visual.shadow = bool(command.shadow)
		visuals.append(visual)

		if not visual_cache_key.is_empty():
			caches.dynamic_visual_cache[visual_cache_key] = visual

	caches.dynamic_sign_occluders = visuals.duplicate()
	caches.dynamic_sign_occlusion_grid = CityDynamicVisual.build_grid(caches.dynamic_sign_occluders)

	if caches.dynamic_special_batch_cache.size() > 128:
		caches.dynamic_special_batch_cache.clear()

	var batched_visuals := DynamicSpriteCanvas.batch_special_visuals(
		visuals, caches.dynamic_special_batch_cache
	)

	app.map_view.set_dynamic_sprites(batched_visuals)
	app.map_render.refresh_sign_occlusion(view_size)
	caches.foreground_view_rect = app.map_view.visible_source_rect()
	caches.foreground_complete = true


func _is_vehicle(record: int) -> bool:
	var thing := app.document_state.city.thing(record)

	return thing != null and thing.type in CityViewFilter.VEHICLE_THING_TYPES


# drop vehicle sounds while the vehicles layer is hidden
func audible_sound_events(sound_events: Array[SoundEvent]) -> Array[SoundEvent]:
	if app.view_state.show_vehicles:
		return sound_events

	return sound_events.filter(func(event: SoundEvent) -> bool:
		return not (event.from_thing and event.thing_type in CityViewFilter.VEHICLE_THING_TYPES))


func _gpu_moving_visual(sprite_archive: Sc2SpriteArchive, command: CityDynamicCommand, divisor: int, factor: int) -> CityDynamicVisual:
	var resource := dynamic_sprite_resource(
		sprite_archive, command.sprite_id, command.flip, divisor, factor
	)

	if resource == null:
		return null

	var mode := CityMapMovingOcclusion.MODE_SPRITE

	if bool(command.shadow):
		mode = CityMapMovingOcclusion.MODE_SHADOW
	elif bool(command.train):
		mode = CityMapMovingOcclusion.MODE_TRAIN

	var result := CityDynamicVisual.new()

	result.texture = resource.texture
	result.texture_factor = factor
	result.position = Vector2(Vector2i(command.position) * divisor)
	result.size = Vector2(resource.native_size)
	# signs treat this image as an opaque moving sprite. a shadow has none
	result.image = null if bool(command.shadow) else resource.image
	result.depth_order = int(command.depth_order) if bool(command.static_occlusion) else -1
	result.shadow = bool(command.shadow)
	result.record = int(command.record)
	result.gpu_mode = mode

	return result


func static_occlusion_candidates(bounds: Rect2i) -> Array[CityStaticCommand]:
	if caches.region_cache != null:
		return caches.region_cache.occlusion_candidates(bounds)

	var result: Array[CityStaticCommand] = []

	for index in IsometricRenderer.occlusion_candidate_indices(caches.static_occlusion_grid, bounds):
		result.append(caches.static_occlusion_commands[index])

	return result


func _dynamic_occluder_image(
	sprite_archive: Sc2SpriteArchive,
	divisor: int,
	position: Vector2i,
	size: Vector2i,
	draw_order: int,
	is_train := false, texture_factor := 1
) -> Image:
	if draw_order < 0 or (caches.static_occlusion_commands.is_empty() and caches.region_cache == null):
		return null

	var cache_key := "%d:%d:%d:%d:%d:%d:%d:%d" % [
		position.x, position.y, size.x, size.y, draw_order, int(is_train),
		app.static_render_state.epoch, texture_factor,
	]
	if caches.dynamic_occluder_cache.has(cache_key):
		return caches.dynamic_occluder_cache[cache_key].image

	var bounds := Rect2i(position, size)

	if caches.static_occlusion_grid.is_empty() and caches.region_cache == null:
		caches.static_occlusion_grid = IsometricRenderer.build_occlusion_grid(
			caches.static_occlusion_commands, divisor
		)

	var mask: Image

	# Bounding boxes include transparent pixels. Combine all later silhouettes
	# to find the foreground that actually covers the sprite.
	for command in static_occlusion_candidates(bounds):
		if is_train and bool(command.train_ignore):
			continue

		var later_static := int(command.depth_order) > draw_order
		var train_foreground := (
			is_train and (command.train_foreground_reference_sprite_id != 0 or command.train_deck_thickness != 0)
			and (not (bool(command.train_foreground_requires_depth) or command.train_deck_thickness != 0)
				or int(command.depth_order) >= draw_order)
		)
		var use_later_static := (
			later_static and not train_foreground
		)

		if not use_later_static and not train_foreground:
			continue

		var occluder_position := Vector2i(command.position) * divisor
		var occluder_size := Vector2i(command.size) * divisor
		var overlap := bounds.intersection(
			Rect2i(occluder_position, occluder_size)
		)

		if overlap.get_area() <= 0:
			continue

		var resource := dynamic_sprite_resource(
			sprite_archive, int(command.sprite_id), bool(command.flip), divisor, texture_factor
		)

		if resource == null:
			continue

		var occluder_image: Image = resource.image

		if train_foreground:
			occluder_image = _dynamic_train_foreground_image(
				sprite_archive, command, divisor, resource.image, texture_factor
			)

		if mask == null:
			mask = Image.create(size.x * texture_factor, size.y * texture_factor, false, Image.FORMAT_RGBA8)
			mask.fill(Color.TRANSPARENT)

		mask.blend_rect(
			occluder_image,
			Rect2i((overlap.position - occluder_position) * texture_factor, overlap.size * texture_factor),
			(overlap.position - position) * texture_factor,
		)

	caches.dynamic_occluder_cache[cache_key] = RenderCaches.OccluderMask.new(bounds, mask)

	return mask


func set_static_occlusion_commands(commands: Array[CityStaticCommand], view_size: int) -> void:
	caches.static_occlusion_commands.assign(commands)
	caches.dynamic_occluder_cache.clear()
	caches.dynamic_visual_cache.clear()
	caches.sign_foreground_cache.clear()
	caches.dynamic_special_batch_cache.clear()
	var divisor := IsometricRenderer.view_configuration(view_size).divisor
	caches.static_occlusion_grid = IsometricRenderer.build_occlusion_grid(
		caches.static_occlusion_commands, divisor
	)


func _dynamic_train_foreground_image(
	sprite_archive: Sc2SpriteArchive,
	command: CityStaticCommand,
	divisor: int,
	surface: Image, texture_factor := 1
) -> Image:
	if command.train_deck_thickness != 0:
		var deck_key := "deck:%d:%d:%d:%d" % [int(command.sprite_id), int(command.flip), divisor, texture_factor]

		if caches.dynamic_foreground_cache.has(deck_key):
			return caches.dynamic_foreground_cache[deck_key]

		var deck_surface := surface

		# a highway/power crossing uses the wire-free highway as its mask
		if command.train_deck_reference_sprite_id != 0:
			var background := dynamic_sprite_resource(sprite_archive, int(command.train_deck_reference_sprite_id), bool(command.flip), divisor, texture_factor)

			if background != null:
				deck_surface = Image.create(surface.get_width(), surface.get_height(), false, Image.FORMAT_RGBA8)
				deck_surface.blit_rect(background.image, Rect2i(Vector2i.ZERO, background.image.get_size()),
						Vector2i(0, surface.get_height() - background.image.get_height()))

		var deck := IsometricRenderer.highway_train_deck_mask(deck_surface, int(command.train_deck_thickness) * divisor * texture_factor)
		caches.dynamic_foreground_cache[deck_key] = deck

		return deck

	var reference_sprite_id := int(command.train_foreground_reference_sprite_id)

	if reference_sprite_id < 0:
		return surface

	var key := "%d:%d:%d:%d:%d" % [
		int(command.sprite_id), int(command.flip), divisor, reference_sprite_id, texture_factor,
	]

	if caches.dynamic_foreground_cache.has(key):
		return caches.dynamic_foreground_cache[key]

	var reference := dynamic_sprite_resource(
		sprite_archive, reference_sprite_id, bool(command.flip), divisor, texture_factor
	)

	if reference == null:
		return surface

	var foreground := IsometricRenderer.foreground_difference_mask(
		surface, reference.image
	)
	caches.dynamic_foreground_cache[key] = foreground

	return foreground


func demolish_brush_visual(tile: Vector2i, direction: int) -> CityDynamicVisual:
	var view_size := app.static_render.city_view_size()
	var archive := app.static_render.sprite_archive_for_view(view_size)
	if app.document_state.city == null or archive == null or app.asset_state.palette == null:
		return null

	var sprite := IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({"type": 4, "direction": direction}), view_size)
	var entry := archive.find_sprite(int(sprite.sprite_id))
	if entry == null:
		return null

	var configuration := IsometricRenderer.view_configuration(view_size)
	var divisor := configuration.divisor
	var resource := dynamic_sprite_resource(archive, int(sprite.sprite_id), bool(sprite.flip), divisor)
	if resource == null:
		return null

	var visual := IsometricMovingVisuals.Visual.new()
	visual.sprite_id = sprite.sprite_id
	visual.flip = sprite.flip
	visual.type = 4
	visual.x = tile.x
	visual.y = tile.y
	var commands := IsometricRenderer.moving_thing_draw_commands_for_visual(app.document_state.city, archive, visual, configuration)
	if commands.is_empty():
		return null
	var result := CityDynamicVisual.new()
	result.texture = resource.texture
	result.position = Vector2(commands[0].position * divisor)
	result.size = Vector2(entry.width, entry.height) * divisor

	return result


func dynamic_sprite_resource(
	sprite_archive: Sc2SpriteArchive, sprite_id: int, flip: bool, divisor: int, texture_factor := 1
) -> CitySpriteResource:
	var key := "%d:%d:%d:%d:%d" % [sprite_id, int(flip), divisor, texture_factor, sprite_archive.get_instance_id()]

	if caches.dynamic_sprite_cache.has(key):
		return caches.dynamic_sprite_cache[key]

	var entry := sprite_archive.find_sprite(sprite_id)

	if entry == null:
		return null

	var native_size := Vector2i(entry.width, entry.height) * divisor
	var indexed := entry.create_image(app.asset_state.palette_index_encoding)

	if not indexed.ok:
		return null

	var image: Image = indexed.image

	if flip or divisor > 1 or image.get_size() != native_size * texture_factor:
		image = image.duplicate()

	if flip:
		image.flip_x()

	if image.get_size() != native_size * texture_factor:
		image.resize(
			native_size.x * texture_factor,
			native_size.y * texture_factor,
			Image.INTERPOLATE_NEAREST
		)

	var texture := ImageTexture.create_from_image(image)
	var resource := CitySpriteResource.new()
	resource.image = image
	resource.native_size = native_size
	resource.texture = texture
	resource.index_texture = texture
	caches.dynamic_sprite_cache[key] = resource

	return resource


func _dynamic_shadow_image(
	mask: Image, position: Vector2i, occluder_mask: Image = null, texture_factor := 1
) -> Image:
	if caches.static_city_image == null and caches.region_cache == null:
		return null

	var shadow := Image.create(
		mask.get_width(), mask.get_height(), false, Image.FORMAT_RGBA8
	)
	shadow.fill(Color.TRANSPARENT)
	var changed_pixels := 0
	@warning_ignore("integer_division")
	var sampled: Image = (caches.region_cache.image_region(Rect2i(position, mask.get_size() / texture_factor), texture_factor)
			if caches.region_cache != null else null)

	for source_y in mask.get_height():
		var output_y := position.y + int(source_y / texture_factor)

		if output_y < 0 or output_y >= app.map_render.static_image_size().y:
			continue

		for source_x in mask.get_width():
			if mask.get_pixel(source_x, source_y).a == 0.0:
				continue

			if (
				occluder_mask != null
				and occluder_mask.get_pixel(source_x, source_y).a > 0.0
			):
				continue

			var output_x := position.x + int(source_x / texture_factor)

			if output_x < 0 or output_x >= app.map_render.static_image_size().x:
				continue

			var current: Color = sampled.get_pixel(source_x, source_y) if sampled != null else caches.static_city_image.get_pixel(output_x, output_y)
			var palette_index := roundi(current.r * 255.0)
			var changed_index := IsometricRenderer.shadow_palette_index(palette_index)

			if changed_index != palette_index:
				shadow.set_pixel(
					source_x, source_y,
					Color8(changed_index, changed_index, changed_index, 255)
				)
				changed_pixels += 1

	return shadow if changed_pixels > 0 else null
