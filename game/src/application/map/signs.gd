class_name ApplicationMapSigns
extends RefCounted
# Sign occlusion, palette signatures, and palette images.


static func refresh_sign_occlusion(render: ApplicationMapRender, view_size: int) -> void:
	if (
		render.app.overlay_mode != CityViewMode.Mode.CITY
		or not bool(render.app.surface_visibility.signs)
		or render.app.document_state.city == null
		or render.app.map_view == null
		or (render.caches.static_city_image == null and render.caches.region_cache == null)
		or (render.caches.static_occlusion_commands.is_empty() and render.caches.region_cache == null)
	):
		if render.app.map_view != null:
			render.app.map_view.set_sign_occlusion_visuals({})

		return

	var entries := render.app.map_view.sign_source_entries()

	if entries.is_empty():
		render.app.map_view.set_sign_occlusion_visuals({})

		return

	var sprite_archive := render.app.static_render.sprite_archive_for_view(view_size)
	var configuration := ApplicationMapRender.IsometricRenderer.view_configuration(view_size)
	var divisor := int(configuration.divisor)
	var factor := 1

	if render.caches.static_occlusion_grid.is_empty() and render.caches.region_cache == null:
		render.caches.static_occlusion_grid = ApplicationMapRender.IsometricRenderer.build_occlusion_grid(
			render.caches.static_occlusion_commands, divisor
		)

	var color_indices := render.app.palette.animation_index_map(render.app.palette_clock.cycle_ticks)
	var gpu_palette := render.caches.region_cache != null and render.caches.region_cache.gpu_enabled
	var image_bounds := Rect2i(Vector2i.ZERO, render.static_image_size())
	var visuals := {}

	for entry in entries:
		var source_bounds: Rect2i = entry.bounds

		if render.caches.region_cache != null and not Rect2(source_bounds).intersects(render.app.map_view.visible_source_rect().grow(128)):
			continue

		var bounds := source_bounds.intersection(image_bounds)

		if bounds.get_area() <= 0:
			continue

		var moving_candidates: Array[Dictionary] = []

		for moving_index in ApplicationMapRender.IsometricRenderer.occlusion_candidate_indices(render.caches.dynamic_sign_occlusion_grid, bounds):
			moving_candidates.append(render.caches.dynamic_sign_occluders[moving_index])

		var signature := [view_size, bounds, int(entry.draw_order), moving_candidates]
		var key := int(entry.key)

		if render.caches.sign_foreground_cache.has(key) and render.caches.sign_foreground_cache[key].signature == signature:
			var cached: Dictionary = render.caches.sign_foreground_cache[key]

			if cached.indices != null:
				var palette_signature := 0 if gpu_palette else render.sign_palette_signature(cached.used_indices, color_indices)

				if not gpu_palette and int(cached.palette_signature) != palette_signature:
					cached.visual.texture = ImageTexture.create_from_image(render.sign_palette_image(cached.indices, color_indices))
					cached.palette_signature = palette_signature

				visuals[key] = cached.visual

			continue

		var foreground: Image = render.caches.region_cache.sign_foreground(key, bounds, int(entry.draw_order), factor) if gpu_palette else null

		if foreground == null:
			var masks: Array[Dictionary] = []

			for command in render.app.moving_sprites.static_occlusion_candidates(bounds):
				if int(command.depth_order) <= int(entry.draw_order):
					continue

				var position := Vector2i(command.position) * divisor

				if not bounds.intersects(Rect2i(position, Vector2i(command.size) * divisor)):
					continue

				var resource := render.app.moving_sprites.dynamic_sprite_resource(sprite_archive, int(command.sprite_id), bool(command.flip), divisor, factor)

				if not resource.is_empty():
					masks.append({"image": resource.image, "position": position * factor})

			var sampled: Image = render.caches.region_cache.image_region(bounds, factor) if render.caches.region_cache != null else render.caches.static_city_image.get_region(bounds)
			foreground = CitySignForeground.static_pixels(sampled, masks, Rect2i(bounds.position * factor, bounds.size * factor))

		for visual in CityMapSigns.later_sign_occluder_visuals(moving_candidates, bounds, int(entry.draw_order)):
			var moving_image: Image = visual.get("image") as Image

			if moving_image != null:
				CitySignForeground.add_moving(foreground, moving_image, Vector2i(visual.position) * factor, Rect2i(bounds.position * factor, bounds.size * factor))

		var used_indices := {} if gpu_palette else CitySignForeground.used_indices(foreground)
		var empty_foreground := foreground.is_invisible() if gpu_palette else used_indices.is_empty()

		if empty_foreground:
			render.caches.sign_foreground_cache[key] = {"signature": signature, "indices": null}
			continue

		var texture: Texture2D
		var previous: Dictionary = render.app.map_view.sign_occlusion_visuals.get(key, {})

		if gpu_palette and bool(previous.get("indexed", false)) and previous.has("indices") and previous.indices.get_size() == foreground.get_size() and previous.indices.get_data() == foreground.get_data():
			foreground = previous.indices
			texture = previous.texture
		else:
			texture = ImageTexture.create_from_image(foreground if gpu_palette else render.sign_palette_image(foreground, color_indices))

		visuals[int(entry.key)] = {
			"indexed": gpu_palette,
			"indices": foreground if gpu_palette else null,
			"texture": texture,
			"position": Vector2(bounds.position),
			"size": Vector2(bounds.size),
		}
		render.caches.sign_foreground_cache[key] = {"signature": signature, "indices": foreground, "palette_signature": 0 if gpu_palette else render.sign_palette_signature(used_indices, color_indices), "used_indices": used_indices, "visual": visuals[key]}

	render.app.map_view.set_sign_occlusion_visuals(visuals)


static func sign_palette_signature(render: ApplicationMapRender, used: Dictionary, mapping: PackedInt32Array) -> int:
	var colors := PackedInt32Array()

	for index in used:
		colors.append(mapping[index])

	return hash(colors)


static func sign_palette_image(render: ApplicationMapRender, indexed: Image, mapping: PackedInt32Array) -> Image:
	var bytes := indexed.get_data()

	for offset in range(0, bytes.size(), 4):
		if bytes[offset + 3] == 0:
			continue

		var color := render.app.palette.color(mapping[bytes[offset]])
		bytes[offset] = color.r8
		bytes[offset + 1] = color.g8
		bytes[offset + 2] = color.b8

	return Image.create_from_data(indexed.get_width(), indexed.get_height(), false, Image.FORMAT_RGBA8, bytes)
