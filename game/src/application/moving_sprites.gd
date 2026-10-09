class_name ApplicationMovingSprites
extends RefCounted


@warning_ignore_start("integer_division")

const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const DynamicSpriteCanvas = preload("res://src/view/city_dynamic_sprite_canvas.gd")

var app: CityApplication
var caches: RenderCaches
var traffic_motion := CityTrafficMotion.new()
var moving_lights := CityMovingLights.new()
var tornado_renderer: CityTornadoRenderer
var beam_glow: CityDisasterBeamGlow
var hazard_animation: CityHazardAnimation


func _init(application: CityApplication) -> void:
	app = application
	caches = application.render_caches
	tornado_renderer = CityTornadoRenderer.new(application)
	beam_glow = CityDisasterBeamGlow.new(application)
	hazard_animation = CityHazardAnimation.new(application)


func process(delta: float) -> void:
	hazard_animation.process(delta)
	tornado_renderer.process(delta)
	beam_glow.process()
	if not _traffic_active():
		traffic_motion.reset()
		return
	var controller := app.simulation_state.speed_controller
	if controller == null or controller.speed == GameSpeedController.Speed.PAUSED \
			or controller.interaction_blocked or controller.terminal_blocked or app.frame._simulation_suspended():
		return
	if traffic_motion.advance(delta):
		refresh_moving_things()


func _traffic_active() -> bool:
	var options := app.preferences.visual_enhancements
	return app.document_state.city != null and app.map_view != null \
		and (app.view_state.show_vehicles or (options.disaster_enabled and options.disaster_motion)) \
		and app.view_state.overlay_mode == CityViewMode.Mode.CITY and not app.tool_state.landscape_editor


func refresh_moving_things(view_size := -1) -> void:
	hazard_animation.begin()
	tornado_renderer.begin()
	app.disaster_effects.begin_commands()
	caches.trim_moving()
	caches.dynamic_active_keys.clear()
	if _traffic_active():
		traffic_motion.observe(app.document_state.city, app.preferences.visual_enhancements, app.view_state.show_vehicles)
	else:
		traffic_motion.reset()

	if (app.document_state.city == null
			or app.asset_state.palette == null
			or app.map_view == null
			or app.view_state.overlay_mode != CityViewMode.Mode.CITY):
		if app.map_view != null:
			app.map_view.set_dynamic_sprites([])

		app.disaster_effects.end_commands()
		tornado_renderer.finish()
		return

	if caches.region_cache != null and caches.region_cache.gpu_enabled and not caches.region_cache.covered():
		caches.foreground_complete = false
		app.map_view.set_dynamic_sprites([])

		app.disaster_effects.end_commands()
		tornado_renderer.finish()
		return

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
	var visible_bounds := app.map_view.visible_source_rect().grow(256 * divisor)
	var command_extent := Vector2(256, 256) * divisor

	for source_command in commands:
		if app.disaster_effects.observe_command(source_command):
			continue
		# Cull the exact interpolated bounds before allocating a draw command or
		# querying its lighting. The camera rectangle is shared by the whole pass.
		if caches.region_cache != null and not Rect2(
				Vector2(traffic_motion.command_position(source_command, divisor)) * divisor,
				command_extent).intersects(visible_bounds):
			continue
		var command := traffic_motion.draw_command(source_command, divisor, app.document_state.city.map_size)
		var display_position := Vector2(source_command.position * divisor) + traffic_motion.display_offset(source_command, divisor)
		var position := Vector2i(display_position.round())
		if not app.view_state.show_vehicles and command.record >= 0 and _is_vehicle(int(command.record)):
			continue

		var aircraft_shadow: bool = command.shadow and command.record >= 0 \
			and app.document_state.city.thing(command.record).type in [1, 2]
		var transparent_shadow: bool = aircraft_shadow and app.preferences.visual_enhancements.traffic_shadows_enabled
		var hazard := hazard_animation.observe(command, sprite_archive, view_size)
		if hazard != null:
			visuals.append(hazard)
			continue
		if command.record >= 0 and app.document_state.city.thing(command.record).type == 15 \
				and app.disaster_effects.active():
			var tornado_resource := dynamic_sprite_resource(sprite_archive, command.sprite_id, command.flip, divisor, factor)
			if tornado_resource != null:
				tornado_renderer.draw(command, source_command, tornado_resource, display_position, divisor)
				continue
		var cloud_style := 0
		if command.overlay == 0xfb and app.disaster_effects.active():
			cloud_style = app.disaster_effects.cloud_style(IsometricFloatingOcclusion.depth_tile(command.depth_order, app.document_state.city.map_size))
		var toxic_cloud := cloud_style == 1
		var warm_cloud := cloud_style == 2
		var light_allowed := VisualEnhancementOptions.detail_lights_visible(app.preferences.visual_enhancements, app.map_view.zoom_factor) \
			or not (command.record >= 0 and _is_vehicle(int(command.record)))
		var visual_cache_key := var_to_str([view_size, factor, sprite_archive.visual_revision, transparent_shadow, toxic_cloud, warm_cloud, light_allowed, position, command.value_signature()])
		# Include fully hidden shadows: a static change can make them visible.
		caches.dynamic_active_keys[visual_cache_key] = true

		if caches.dynamic_visual_cache.has(visual_cache_key):
			var cached: CityDynamicVisual = caches.dynamic_visual_cache[visual_cache_key]

			if cached != null and not cached.hidden:
				visuals.append(_at_position(cached, display_position))

			continue

		var resource := dynamic_sprite_resource(
			sprite_archive, command.sprite_id, command.flip, divisor, factor
		)

		if resource == null:
			continue

		var texture: Texture2D = resource.texture
		var index_texture: Texture2D = resource.index_texture
		var visual_image: Image = resource.image
		var occluder_mask: Image

		if bool(command.static_occlusion):
			occluder_mask = _dynamic_occluder_image(
				sprite_archive, divisor, position, resource.native_size,
				int(command.depth_order), bool(command.train), factor,
				resource if command.floating_altitude >= 0 else null, int(command.floating_altitude), command.train_support_orders, aircraft_shadow
			)

		var samples_static: bool = bool(command.shadow) and not transparent_shadow

		if command.shadow:
			var shadow_image := (CityAircraftShadow.create(resource.image, occluder_mask, position, app.map_render.static_image_size())
				if transparent_shadow else _dynamic_shadow_image(resource.image, position, occluder_mask, factor))

			if shadow_image == null:
				var hidden := CityDynamicVisual.new(null, Vector2(position), Vector2(resource.native_size))
				hidden.hidden = true
				hidden.samples_static = samples_static
				caches.dynamic_visual_cache[visual_cache_key] = hidden
				continue

			visual_image = shadow_image
			texture = ImageTexture.create_from_image(shadow_image)
			index_texture = null
		else:
			var foreground_indices: PackedInt32Array = command.same_tile_foreground_indices
			var index_image: Image = caches.static_city_image
			var index_covers_sprite := false

			# regions paint the city area under the sprite on demand
			if caches.region_cache != null and not foreground_indices.is_empty():
				index_image = caches.region_cache.image_region(Rect2i(position, resource.native_size), factor)
				index_covers_sprite = true
				samples_static = true

			var occluded := IsometricRenderer.occlude_dynamic_with_mask(
				resource.image, occluder_mask, position * factor, index_image, foreground_indices, index_covers_sprite
			)

			if int(occluded.occluded_pixels) > 0:
				visual_image = occluded.image
				texture = ImageTexture.create_from_image(occluded.image)
				index_texture = texture

		var visual := CityDynamicVisual.new()
		visual.vehicle_light = command.record >= 0 and _is_vehicle(int(command.record))
		visual.samples_static = samples_static
		visual.texture = texture
		visual.index_texture = index_texture
		visual.palette_lookup_all = true
		visual.texture_factor = factor
		visual.position = Vector2(position)
		visual.size = Vector2(resource.native_size)
		visual.image = visual_image
		if not command.shadow and light_allowed:
			var emission := resource.light_mask(moving_lights.mask(sprite_archive, command.sprite_id), command.flip)
			if visual_image == resource.image:
				visual.emission_texture = resource.light_texture()
			elif emission != null:
				# The cached mask already includes the original artwork alpha.
				# Apply the final silhouette to the authored source exactly once.
				visual.emission_texture = ImageTexture.create_from_image(CityBrightmaps.transform_mask(
					moving_lights.mask(sprite_archive, command.sprite_id), visual_image, command.flip))
		if sprite_archive.water_reflections and command.floating_altitude >= 0 and not command.shadow:
			visual.water_reflection = resource.reflection(position, int(command.floating_altitude), app.asset_state.palette, light_allowed)
		visual.special_overlay = command.overlay >= 0
		visual.fullbright = command.overlay == 0xff
		visual.toxic_cloud = toxic_cloud
		visual.warm_cloud = warm_cloud
		visual.beam_glow = not command.shadow and command.sprite_id in [385, 885, 1385]
		visual.batch_cache_key = visual_cache_key
		visual.depth_order = int(command.depth_order)
		visual.shadow = bool(command.shadow)
		visual.transparent_shadow = transparent_shadow
		visuals.append(_at_position(visual, display_position))

		if not visual_cache_key.is_empty():
			caches.dynamic_visual_cache[visual_cache_key] = visual

	app.disaster_effects.end_commands()
	hazard_animation.finish(visuals)
	tornado_renderer.finish()
	if caches.dynamic_special_batch_cache.size() > 128:
		caches.dynamic_special_batch_cache.clear()

	var batched_visuals := DynamicSpriteCanvas.batch_special_visuals(
		visuals, caches.dynamic_special_batch_cache
	)

	app.map_view.set_dynamic_sprites(batched_visuals)
	caches.foreground_view_rect = app.map_view.visible_source_rect()
	caches.foreground_complete = true


func _at_position(visual: CityDynamicVisual, position: Vector2) -> CityDynamicVisual:
	if visual.position == position:
		return visual
	var result := visual.copy()
	result.position = position
	return result


func _is_vehicle(record: int) -> bool:
	var thing := app.document_state.city.thing(record)

	return thing != null and thing.type in CityViewFilter.VEHICLE_THING_TYPES


# drop vehicle sounds while the vehicles layer is hidden
func audible_sound_events(sound_events: Array[SoundEvent]) -> Array[SoundEvent]:
	if app.view_state.show_vehicles:
		return sound_events

	return sound_events.filter(func(event: SoundEvent) -> bool:
		return not (event.from_thing and event.thing_type in CityViewFilter.VEHICLE_THING_TYPES))


# the static silhouettes over an effect sprite at `position` that the painter
# draws after `depth_tile`. null when none cover it. `position` and `size` use
# the scaled view pixels
func effect_occluder_mask(position: Vector2i, size: Vector2i, depth_tile: Vector2i, view_size: int) -> Image:
	var city := app.document_state.city

	if city == null or city.index_of(depth_tile.x, depth_tile.y) < 0:
		return null

	var divisor := IsometricRenderer.view_configuration(view_size).divisor
	var order := (depth_tile.x + depth_tile.y) * city.map_size + depth_tile.y

	return _dynamic_occluder_image(app.static_render.sprite_archive_for_view(view_size), divisor, position, size, order)


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
	is_train := false, texture_factor := 1,
	floating: CitySpriteResource = null, floating_altitude := -1,
	train_support_orders := PackedInt32Array(), aircraft_shadow := false
) -> Image:
	if draw_order < 0 or (caches.static_occlusion_commands.is_empty() and caches.region_cache == null):
		return null

	var requested := Rect2i(position, size)
	if floating == null:
		# Neighboring interpolated positions share the same world silhouettes.
		# Ships retain position-dependent waterline clipping below.
		position = Vector2i(floori(position.x / 32.0), floori(position.y / 32.0)) * 32
		size += Vector2i(31, 31)
	var cache_key := "%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d" % [
		position.x, position.y, size.x, size.y, draw_order, int(is_train),
		app.static_render_state.epoch, texture_factor,
		floating.get_instance_id() if floating != null else 0, floating_altitude,
		divisor, sprite_archive.get_instance_id() if sprite_archive != null else 0,
	]
	cache_key += ":shadow" if aircraft_shadow else ""
	if not train_support_orders.is_empty():
		cache_key += ":" + str(train_support_orders)
	if caches.dynamic_occluder_cache.has(cache_key):
		return _occluder_region(caches.dynamic_occluder_cache[cache_key], requested, texture_factor)

	var bounds := Rect2i(position, size)

	if caches.static_occlusion_grid == null and caches.region_cache == null:
		caches.static_occlusion_grid = IsometricRenderer.build_occlusion_grid(
			caches.static_occlusion_commands, divisor
		)

	var mask: Image = null

	if floating != null:
		mask = _floating_occluder_image(sprite_archive, divisor, bounds, texture_factor, floating, floating_altitude)
		caches.dynamic_occluder_cache[cache_key] = RenderCaches.OccluderMask.new(bounds, mask)

		return mask

	# Bounding boxes include transparent pixels. Combine all later silhouettes
	# to find the foreground that actually covers the sprite.
	var train_height := _train_support_height(train_support_orders) if is_train else -1
	var shadow_height := -1
	if aircraft_shadow:
		var city := app.document_state.city
		var tile := IsometricFloatingOcclusion.depth_tile(draw_order, city.map_size)
		shadow_height = city.object_altitude(tile.x, tile.y)
	for command in static_occlusion_candidates(bounds):
		if shadow_height >= 0 and _shadow_receiver(command, shadow_height):
			continue
		if is_train and bool(command.train_ignore):
			continue
		if is_train and train_support_orders.has(command.depth_order) and _train_support_surface(command.sprite_id):
			continue
		if train_height >= 0 and _ground_below_train(command, train_height):
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

	var cached := RenderCaches.OccluderMask.new(bounds, mask)
	caches.dynamic_occluder_cache[cache_key] = cached

	return _occluder_region(cached, requested, texture_factor)


static func _train_support_surface(sprite_id: int) -> bool:
	var id := posmod(sprite_id, 500)
	# Only ground and ground-level rail artwork. Crossing decks, bridge towers,
	# tunnel entrances, buildings and all unrelated tiles keep their masks.
	return (id >= 256 and id <= 268) \
		or (id >= BuildingTileIds.RAIL_FIRST and id <= BuildingTileIds.RAIL_LAST) \
		or id in [BuildingTileIds.ROAD_RAIL_CROSSING_1, BuildingTileIds.ROAD_RAIL_CROSSING_2]


func _train_support_height(orders: PackedInt32Array) -> int:
	var city := app.document_state.city
	if orders.is_empty() or city == null:
		return -1
	var height := 32
	for order in orders:
		var tile := IsometricFloatingOcclusion.depth_tile(order, city.map_size)
		height = mini(height, city.land_altitude(tile.x, tile.y))
	return height


func _ground_below_train(command: CityStaticCommand, height: int) -> bool:
	var id := posmod(command.sprite_id, 500)
	if not _train_support_surface(command.sprite_id):
		return false
	var city := app.document_state.city
	var tile := IsometricFloatingOcclusion.depth_tile(command.depth_order, city.map_size)
	# Flat terrain at rail level cannot cover the train, even when its bitmap
	# extends into an adjacent tile. Higher ground and cliff faces still can.
	var flat := id == 256 or (id < 256 and city.terrain_id(tile.x, tile.y) == TerrainTileIds.FLAT)
	var top := city.land_altitude(tile.x, tile.y) + (0 if flat else 1)
	return top <= height


func _shadow_receiver(command: CityStaticCommand, height: int) -> bool:
	var id := posmod(command.sprite_id, 500)
	# Ground and surface transport receive the shadow across tile boundaries.
	# Never remove trees, structures, raised decks or cliff faces from the mask.
	var ground := id >= 256 and id <= 268
	var water := IsometricFloatingOcclusion.is_water_surface(command.sprite_id)
	var zone := id >= 291 and id <= 299
	var road := id >= BuildingTileIds.ROAD_STRAIGHT_1 and id <= BuildingTileIds.RAIL_LAST
	var crossing := id in [BuildingTileIds.ROAD_RAIL_CROSSING_1, BuildingTileIds.ROAD_RAIL_CROSSING_2]
	if not (ground or water or zone or road or crossing):
		return false
	var city := app.document_state.city
	var tile := IsometricFloatingOcclusion.depth_tile(command.depth_order, city.map_size)
	var flat := id == 256 or city.terrain_id(tile.x, tile.y) == TerrainTileIds.FLAT
	var top := city.object_altitude(tile.x, tile.y) if water else city.land_altitude(tile.x, tile.y) + (0 if flat else 1)
	return top <= height


static func _occluder_region(mask: RenderCaches.OccluderMask, bounds: Rect2i, factor: int) -> Image:
	if mask.image == null or mask.bounds == bounds:
		return mask.image
	return mask.image.get_region(Rect2i((bounds.position - mask.bounds.position) * factor, bounds.size * factor))


# The static silhouettes over a ship or sailboat, by IsometricFloatingOcclusion.
# Positions scaled by `divisor` use the large view geometry
func _floating_occluder_image(
	sprite_archive: Sc2SpriteArchive,
	divisor: int,
	bounds: Rect2i,
	texture_factor: int,
	floating: CitySpriteResource,
	floating_altitude: int
) -> Image:
	var map_edge: int = app.document_state.city.map_size
	var large := IsometricRenderer.view_configuration(IsometricRenderer.VIEW_LARGE)
	var waterline := floating.waterline()
	var columns_by_tile: Dictionary[Vector2i, PackedByteArray] = {}
	var mask: Image = null

	for command in static_occlusion_candidates(bounds):
		if IsometricFloatingOcclusion.is_water_surface(int(command.sprite_id)):
			continue

		var occluder_position := Vector2i(command.position) * divisor
		var overlap := bounds.intersection(Rect2i(occluder_position, Vector2i(command.size) * divisor))

		if overlap.get_area() <= 0:
			continue

		var tile := IsometricFloatingOcclusion.depth_tile(int(command.depth_order), map_edge)

		if not columns_by_tile.has(tile):
			columns_by_tile[tile] = IsometricFloatingOcclusion.hidden_columns(
				waterline, Vector2(bounds.position), 1.0 / texture_factor, large, floating_altitude, map_edge, tile
			)

		var resource := dynamic_sprite_resource(
			sprite_archive, int(command.sprite_id), bool(command.flip), divisor, texture_factor
		)

		if resource == null:
			continue

		if mask == null:
			mask = Image.create(bounds.size.x * texture_factor, bounds.size.y * texture_factor, false, Image.FORMAT_RGBA8)
			mask.fill(Color.TRANSPARENT)

		IsometricFloatingOcclusion.blend_hidden_columns(
			mask,
			resource.image,
			Rect2i((overlap.position - occluder_position) * texture_factor, overlap.size * texture_factor),
			(overlap.position - bounds.position) * texture_factor,
			columns_by_tile[tile]
		)

	return mask


func set_static_occlusion_commands(commands: Array[CityStaticCommand], view_size: int) -> void:
	if app.visual_environment != null:
		app.visual_environment.night_lighting.invalidate_all()
	caches.static_occlusion_commands.assign(commands)
	caches.dynamic_occluder_cache.clear()
	caches.dynamic_visual_cache.clear()
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
			var background := dynamic_sprite_resource(
				sprite_archive,
				int(command.train_deck_reference_sprite_id),
				bool(command.flip),
				divisor,
				texture_factor,
			)

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

	var reference_sprite := dynamic_sprite_resource(
		sprite_archive, reference_sprite_id, bool(command.flip), divisor, texture_factor
	)

	if reference_sprite == null:
		return surface

	var foreground := IsometricRenderer.foreground_difference_mask(
		surface, reference_sprite.image
	)
	caches.dynamic_foreground_cache[key] = foreground

	return foreground


func demolish_brush_visual(tile: Vector2i, direction: int) -> CityDynamicVisual:
	var view_size := app.static_render.city_view_size()
	var archive := app.static_render.sprite_archive_for_view(view_size)
	if app.document_state.city == null or archive == null or app.asset_state.palette == null:
		return null

	var sprite := IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({ "type": 4, "direction": direction }), view_size)
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

	var image := CityTrainArtwork.clean(entry, indexed.image)

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

	# regions paint the city area under the sprite; the static view has the whole map
	@warning_ignore("integer_division")
	var sampled: Image = (caches.region_cache.image_region(Rect2i(position, mask.get_size() / texture_factor), texture_factor)
			if caches.region_cache != null else null)

	return NativeSpriteCompositor.moving_shadow(mask, occluder_mask, sampled if sampled != null else caches.static_city_image,
		sampled == null, position, app.map_render.static_image_size(), texture_factor)
