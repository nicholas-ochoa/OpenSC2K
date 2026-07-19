class_name ApplicationMovingSprites
extends RefCounted


const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const DynamicSpriteCanvas = preload("res://src/view/city_dynamic_sprite_canvas.gd")

# the rate that keeps the original 200 ms steps and the cpu occlusion path
const ORIGINAL_FRAME_RATE := 5
# blend only a short move. a longer change is a new, removed, or reused record
const BLEND_TILE_LIMIT := 2

var app: CityApplication
# display interpolation state by xthg record. see `_note_moving_tick`
var _blend_from: Dictionary = {}
var _blend_to: Dictionary = {}
var _blend_city_id := 0
var _blend_view_size := -1
var _blend_tick_msec := 0
var _blend_alpha := 1.0


func _init(application: CityApplication) -> void:
	app = application


# true when moving objects use gpu occlusion and display interpolation
func _gpu_moving_active() -> bool:
	return (
		app.app_moving_frame_rate > ORIGINAL_FRAME_RATE
		and app.map_view != null
		and app.map_view.moving_occlusion_active()
	)


# start a blend after a moving-object tick. each record moves from its displayed
# position to its new saved position. the blend never changes simulation state
func _note_moving_tick(now_msec := -1) -> void:
	if now_msec < 0:
		now_msec = Time.get_ticks_msec()

	if app.city == null or app.app_moving_frame_rate <= ORIGINAL_FRAME_RATE:
		_reset_blend()

		return

	var view_size := app.static_render._city_view_size()
	var continuing := _blend_city_id == app.city.get_instance_id() and _blend_view_size == view_size
	var next := {}
	var from := {}

	for record in app.city.thing_count():
		var anchor := IsometricRenderer.moving_thing_anchor(app.city, record, view_size)

		if anchor.is_empty():
			continue

		next[record] = anchor

		if continuing and _blend_to.has(record) and can_blend(_blend_to[record], anchor):
			from[record] = _displayed_anchor(record)

	_blend_to = next
	_blend_from = from
	_blend_city_id = app.city.get_instance_id()
	_blend_view_size = view_size
	_blend_tick_msec = now_msec
	_blend_alpha = 0.0
	_apply_blend()


# move the blend forward at the selected display rate
func _advance_blend(now_msec := -1) -> void:
	if _blend_from.is_empty():
		return

	if now_msec < 0:
		now_msec = Time.get_ticks_msec()

	var alpha := blend_alpha(now_msec - _blend_tick_msec, app.app_moving_frame_rate)

	if is_equal_approx(alpha, _blend_alpha):
		return

	_blend_alpha = alpha
	_apply_blend()

	if alpha >= 1.0:
		_blend_from.clear()


func _reset_blend() -> void:
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
static func can_blend(previous: Dictionary, current: Dictionary) -> bool:
	var previous_type := int(previous.type)
	var current_type := int(current.type)
	var same_type := previous_type == current_type or (previous_type in [10, 11] and current_type in [10, 11])

	return (
		same_type
		and absi(int(previous.x) - int(current.x)) <= BLEND_TILE_LIMIT
		and absi(int(previous.y) - int(current.y)) <= BLEND_TILE_LIMIT
	)


func _displayed_anchor(record: int) -> Dictionary:
	var target: Dictionary = _blend_to[record]

	if not _blend_from.has(record):
		return target

	var start: Dictionary = _blend_from[record]

	# Use the later draw order between tiles so neither tile's flat surface covers the sprite.
	return {
		"anchor": start.anchor.lerp(target.anchor, _blend_alpha),
		"order": maxi(int(start.order), int(target.order)) if _blend_alpha < 1.0 else int(target.order),
	}


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


func _refresh_moving_things(view_size := -1) -> void:
	if app.map_view != null:
		app.map_view.set_moving_occlusion_enabled(app.app_moving_frame_rate > ORIGINAL_FRAME_RATE)

	if app.city == null or app.palette == null or app.map_view == null or app.overlay_mode != "city":
		app.dynamic_sign_occluders.clear()
		app.dynamic_sign_occlusion_grid.clear()

		if app.map_view != null:
			app.map_view.set_dynamic_sprites([])

		return

	if app.region_cache != null and app.region_cache.gpu_enabled and not app.region_cache.covered():
		app.foreground_complete = false
		app.map_view.set_dynamic_sprites([])
		app.map_view.set_sign_occlusion_visuals({})

		return

	if app.dynamic_visual_cache.size() > 4096:
		app.dynamic_visual_cache.clear()

	if view_size < 0:
		view_size = app.static_render._city_view_size()

	var sprite_archive := app.static_render._sprite_archive_for_view(view_size)
	var configuration := IsometricRenderer.view_configuration(view_size)
	var divisor := int(configuration.divisor)
	var factor := 1
	var commands := app.dynamic_command_cache.get_commands(
		app.city, sprite_archive, view_size, int(IntegerMath.div_trunc(Time.get_ticks_msec(), 100))
	)
	var visuals: Array[Dictionary] = []
	var gpu_moving := _gpu_moving_active()

	for command in commands:
		if not app.show_vehicles and command.has("record") and _is_vehicle(int(command.record)):
			continue

		if app.region_cache != null and not Rect2(Vector2(command.position) * divisor, Vector2(command.get("size", Vector2i(256, 256))) * divisor).intersects(app.map_view.visible_source_rect().grow(256 * divisor)):
			continue

		# the shader applies occlusion and shadows, so the visual needs no image work
		if gpu_moving and not command.has("overlay"):
			var gpu_visual := _gpu_moving_visual(sprite_archive, command, divisor, factor)

			if not gpu_visual.is_empty():
				visuals.append(gpu_visual)

			continue

		var visual_cache_key := var_to_str([view_size, factor, command])

		if app.dynamic_visual_cache.has(visual_cache_key):
			var cached: Dictionary = app.dynamic_visual_cache[visual_cache_key]

			if not cached.is_empty() and not bool(cached.get("hidden", false)):
				visuals.append(cached)

			continue

		var resource := _dynamic_sprite_resource(
			sprite_archive, command.sprite_id, command.flip, divisor, factor
		)

		if resource.is_empty():
			continue

		var position := Vector2i(command.position) * divisor
		var texture: Texture2D = resource.texture
		var index_texture: Texture2D = resource.index_texture
		var visual_image: Image = resource.image
		var occluder_mask: Image

		if bool(command.get("static_occlusion", true)):
			occluder_mask = _dynamic_occluder_image(
				sprite_archive, divisor, position, resource.native_size,
				int(command.get("depth_order", -1)), bool(command.get("train", false)), factor
			)

		if command.shadow:
			var shadow_image := _dynamic_shadow_image(resource.image, position, occluder_mask, factor)

			if shadow_image == null:
				app.dynamic_visual_cache[visual_cache_key] = {"hidden": true, "position": Vector2(position), "size": Vector2(resource.native_size)}
				continue

			visual_image = shadow_image
			texture = ImageTexture.create_from_image(shadow_image)
			index_texture = null
		else:
			var foreground_indices: PackedInt32Array = command.get("same_tile_foreground_indices", PackedInt32Array())
			var index_reader := Callable()

			if app.region_cache != null and not foreground_indices.is_empty():
				var sampled := app.region_cache.image_region(Rect2i(position, resource.native_size), factor)
				index_reader = func(x: int, y: int) -> Color:
					return sampled.get_pixel(x - position.x * factor, y - position.y * factor)

			var occluded := IsometricRenderer.occlude_dynamic_with_mask(
				resource.image, occluder_mask, position * factor, app.static_city_image,
				foreground_indices, index_reader
			)

			if int(occluded.occluded_pixels) > 0:
				visual_image = occluded.image
				texture = ImageTexture.create_from_image(occluded.image)
				index_texture = texture

		var visual := {
			"texture": texture,
			"index_texture": index_texture,
			"palette_lookup_all": true,
			"texture_factor": factor,
			"position": Vector2(position),
			"size": Vector2(resource.native_size),
			"image": visual_image,
			"special_overlay": command.has("overlay"),
			"batch_cache_key": visual_cache_key,
			"depth_order": int(command.get("depth_order", -1)),
			"shadow": bool(command.get("shadow", false)),
		}
		visuals.append(visual)

		if not visual_cache_key.is_empty():
			app.dynamic_visual_cache[visual_cache_key] = visual

	app.dynamic_sign_occluders = visuals.duplicate()
	app.dynamic_sign_occlusion_grid = IsometricRenderer.build_occlusion_grid(
		app.dynamic_sign_occluders, 1
	)

	if app.dynamic_special_batch_cache.size() > 128:
		app.dynamic_special_batch_cache.clear()

	var batched_visuals := DynamicSpriteCanvas.batch_special_visuals(
		visuals, app.dynamic_special_batch_cache
	)
	app.map_view.set_dynamic_sprites(batched_visuals)
	app.map_render._refresh_sign_occlusion(view_size)
	app.foreground_view_rect = app.map_view.visible_source_rect()
	app.foreground_complete = true


func _is_vehicle(record: int) -> bool:
	return int(app.city.thing(record).get("type", 0)) in CityViewFilter.VEHICLE_THING_TYPES


# drop vehicle sounds while the vehicles layer is hidden
func _audible_sound_events(sound_events: Array) -> Array:
	if app.show_vehicles:
		return sound_events

	return sound_events.filter(func(event: Variant) -> bool:
		return not (event is Dictionary and int(event.get("thing_type", 0)) in CityViewFilter.VEHICLE_THING_TYPES))


func _gpu_moving_visual(sprite_archive: Sc2SpriteArchive, command: Dictionary, divisor: int, factor: int) -> Dictionary:
	var resource := _dynamic_sprite_resource(
		sprite_archive, command.sprite_id, command.flip, divisor, factor
	)

	if resource.is_empty():
		return {}

	var mode := CityMapMovingOcclusion.MODE_SPRITE

	if bool(command.get("shadow", false)):
		mode = CityMapMovingOcclusion.MODE_SHADOW
	elif bool(command.get("train", false)):
		mode = CityMapMovingOcclusion.MODE_TRAIN

	return {
		"texture": resource.texture,
		"texture_factor": factor,
		"position": Vector2(Vector2i(command.position) * divisor),
		"size": Vector2(resource.native_size),
		# signs treat this image as an opaque moving sprite. a shadow has none
		"image": null if bool(command.get("shadow", false)) else resource.image,
		"depth_order": int(command.get("depth_order", -1)) if bool(command.get("static_occlusion", true)) else -1,
		"shadow": bool(command.get("shadow", false)),
		"record": int(command.get("record", -1)),
		"gpu_mode": mode,
	}


func _static_occlusion_candidates(bounds: Rect2i) -> Array[Dictionary]:
	if app.region_cache != null:
		return app.region_cache.occlusion_candidates(bounds)

	var result: Array[Dictionary] = []

	for index in IsometricRenderer.occlusion_candidate_indices(app.static_occlusion_grid, bounds):
		result.append(app.static_occlusion_commands[index])

	return result


func _dynamic_occluder_image(
	sprite_archive: Sc2SpriteArchive,
	divisor: int,
	position: Vector2i,
	size: Vector2i,
	draw_order: int,
	is_train := false, texture_factor := 1
) -> Image:
	if draw_order < 0 or (app.static_occlusion_commands.is_empty() and app.region_cache == null):
		return null

	var cache_key := "%d:%d:%d:%d:%d:%d:%d:%d" % [
		position.x, position.y, size.x, size.y, draw_order, int(is_train),
		app.static_render_epoch, texture_factor,
	]

	if app.dynamic_occluder_cache.has(cache_key):
		return app.dynamic_occluder_cache[cache_key] as Image

	var bounds := Rect2i(position, size)

	if app.static_occlusion_grid.is_empty() and app.region_cache == null:
		app.static_occlusion_grid = IsometricRenderer.build_occlusion_grid(
			app.static_occlusion_commands, divisor
		)

	var mask: Image

	# Bounding boxes include transparent pixels. Combine all later silhouettes
	# to find the foreground that actually covers the sprite.
	for command in _static_occlusion_candidates(bounds):
		if is_train and bool(command.get("train_ignore", false)):
			continue

		var later_static := int(command.depth_order) > draw_order
		var train_foreground := (
			is_train and (command.has("train_foreground_reference_sprite_id") or command.has("train_deck_thickness"))
			and (not (bool(command.get("train_foreground_requires_depth", false)) or command.has("train_deck_thickness"))
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

		var resource := _dynamic_sprite_resource(
			sprite_archive, int(command.sprite_id), bool(command.flip), divisor, texture_factor
		)

		if resource.is_empty():
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

	app.dynamic_occluder_cache[cache_key] = mask

	return mask


func _set_static_occlusion_commands(commands: Array, view_size: int) -> void:
	app.static_occlusion_commands.assign(commands)
	app.dynamic_occluder_cache.clear()
	app.dynamic_visual_cache.clear()
	app.sign_foreground_cache.clear()
	app.dynamic_special_batch_cache.clear()
	var divisor := int(IsometricRenderer.view_configuration(view_size).divisor)
	app.static_occlusion_grid = IsometricRenderer.build_occlusion_grid(
		app.static_occlusion_commands, divisor
	)


func _dynamic_train_foreground_image(
	sprite_archive: Sc2SpriteArchive,
	command: Dictionary,
	divisor: int,
	surface: Image, texture_factor := 1
) -> Image:
	if command.has("train_deck_thickness"):
		var deck_key := "deck:%d:%d:%d:%d" % [int(command.sprite_id), int(command.flip), divisor, texture_factor]

		if app.dynamic_foreground_cache.has(deck_key):
			return app.dynamic_foreground_cache[deck_key]

		var deck_surface := surface

		# a highway/power crossing uses the wire-free highway as its mask
		if command.has("train_deck_reference_sprite_id"):
			var background := _dynamic_sprite_resource(sprite_archive, int(command.train_deck_reference_sprite_id), bool(command.flip), divisor, texture_factor)

			if not background.is_empty():
				deck_surface = Image.create(surface.get_width(), surface.get_height(), false, Image.FORMAT_RGBA8)
				deck_surface.blit_rect(background.image, Rect2i(Vector2i.ZERO, background.image.get_size()), Vector2i(0, surface.get_height() - background.image.get_height()))

		var deck := IsometricRenderer.highway_train_deck_mask(deck_surface, int(command.train_deck_thickness) * divisor * texture_factor)
		app.dynamic_foreground_cache[deck_key] = deck

		return deck

	var reference_sprite_id := int(command.train_foreground_reference_sprite_id)

	if reference_sprite_id < 0:
		return surface

	var key := "%d:%d:%d:%d:%d" % [
		int(command.sprite_id), int(command.flip), divisor, reference_sprite_id, texture_factor,
	]

	if app.dynamic_foreground_cache.has(key):
		return app.dynamic_foreground_cache[key]

	var reference := _dynamic_sprite_resource(
		sprite_archive, reference_sprite_id, bool(command.flip), divisor, texture_factor
	)

	if reference.is_empty():
		return surface

	var foreground := IsometricRenderer.foreground_difference_mask(
		surface, reference.image
	)
	app.dynamic_foreground_cache[key] = foreground

	return foreground


func _demolish_brush_visual(tile: Vector2i, direction: int) -> Dictionary:
	var view_size := app.static_render._city_view_size()
	var archive := app.static_render._sprite_archive_for_view(view_size)
	if app.city == null or archive == null or app.palette == null:
		return {}

	var sprite := IsometricRenderer.moving_thing_sprite({"type": 4, "direction": direction}, view_size)
	var entry := archive.find_sprite(int(sprite.sprite_id))
	if entry == null:
		return {}

	var configuration := IsometricRenderer.view_configuration(view_size)
	var divisor := int(configuration.divisor)
	var resource := _dynamic_sprite_resource(archive, int(sprite.sprite_id), bool(sprite.flip), divisor)
	if resource.is_empty():
		return {}

	var visual := {
		"sprite_id": sprite.sprite_id, "flip": sprite.flip, "type": 4,
		"x": tile.x, "y": tile.y, "z": 0, "px": 0, "py": 0,
		"monster": false, "tornado": false, "train": false,
	}
	var commands := IsometricRenderer.moving_thing_draw_commands_for_visual(app.city, archive, visual, configuration)
	if commands.is_empty():
		return {}
	return {
		"texture": resource.texture,
		"position": Vector2(commands[0].position * divisor),
		"size": Vector2(entry.width, entry.height) * divisor,
	}


func _dynamic_sprite_resource(
	sprite_archive: Sc2SpriteArchive, sprite_id: int, flip: bool, divisor: int, texture_factor := 1
) -> Dictionary:
	var key := "%d:%d:%d:%d:%d" % [sprite_id, int(flip), divisor, texture_factor, sprite_archive.get_instance_id()]

	if app.dynamic_sprite_cache.has(key):
		return app.dynamic_sprite_cache[key]

	var entry := sprite_archive.find_sprite(sprite_id)

	if entry == null:
		return {}

	var native_size := Vector2i(entry.width, entry.height) * divisor
	var indexed := entry.create_image(app.palette_index_encoding)

	if not indexed.ok:
		return {}

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
	var resource := {
		"image": image,
		"native_size": native_size,
		"texture": texture,
		"index_texture": texture,
	}
	app.dynamic_sprite_cache[key] = resource

	return resource


func _dynamic_shadow_image(
	mask: Image, position: Vector2i, occluder_mask: Image = null, texture_factor := 1
) -> Image:
	if app.static_city_image == null and app.region_cache == null:
		return null

	var shadow := Image.create(
		mask.get_width(), mask.get_height(), false, Image.FORMAT_RGBA8
	)
	shadow.fill(Color.TRANSPARENT)
	var changed_pixels := 0
	@warning_ignore("integer_division")
	var sampled: Image = app.region_cache.image_region(Rect2i(position, mask.get_size() / texture_factor), texture_factor) if app.region_cache != null else null

	for source_y in mask.get_height():
		var output_y := position.y + int(IntegerMath.div_trunc(source_y, texture_factor))

		if output_y < 0 or output_y >= app.map_render._static_image_size().y:
			continue

		for source_x in mask.get_width():
			if mask.get_pixel(source_x, source_y).a == 0.0:
				continue

			if (
				occluder_mask != null
				and occluder_mask.get_pixel(source_x, source_y).a > 0.0
			):
				continue

			var output_x := position.x + int(IntegerMath.div_trunc(source_x, texture_factor))

			if output_x < 0 or output_x >= app.map_render._static_image_size().x:
				continue

			var current: Color = sampled.get_pixel(source_x, source_y) if sampled != null else app.static_city_image.get_pixel(output_x, output_y)
			var palette_index := roundi(current.r * 255.0)
			var changed_index := IsometricRenderer.shadow_palette_index(palette_index)

			if changed_index != palette_index:
				shadow.set_pixel(
					source_x, source_y,
					Color8(changed_index, changed_index, changed_index, 255)
				)
				changed_pixels += 1

	return shadow if changed_pixels > 0 else null
