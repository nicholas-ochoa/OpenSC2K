class_name ApplicationMapRender
extends RefCounted


const Minimap = preload("res://src/view/city_minimap.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const UndergroundView = preload("res://src/view/city_underground_view.gd")
const ViewFilter = preload("res://src/view/city_view_filter.gd")
const MapControl = preload("res://src/view/city_map_control.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func _refresh_map(force := true) -> void:
	if app.city_status_bar != null:
		app.city_status_bar.set_compass(app.city.compass_rotation() if app.city != null else -1)

	if app.city == null or app.palette == null:
		return

	app.map_view.trip_query_underground = app.overlay_mode == "underground"
	app.map_view.set_signs_visible(
		app.overlay_mode == "city" and bool(app.surface_visibility.signs)
	)

	if CityDataView.MODES.has(app.overlay_mode):
		_close_region_cache()
		app.pending_static_render = false
		app.map_view.set_dynamic_sprites([])
		app.map_view.show_transient_effects([])
		app.map_view.set_data_view(app.city, app.overlay_mode)

		return

	app.map_view.clear_data_view()

	if (app.city.map_size > 128 or CityRegionCache.gpu_supported(app.app_city_renderer)) and app.overlay_mode in ["city", "underground"]:
		_refresh_region_map(force)

		return

	_close_region_cache()
	var image: Image

	if app.overlay_mode == "city" or app.overlay_mode == "underground":
		if force:
			app.pending_static_render = false

		var view_size := app.static_render._city_view_size()
		var sprite_archive := app.static_render._sprite_archive_for_view(view_size)
		var current_signature := app.static_render._static_signature_for_mode(app.overlay_mode, view_size)
		var cached: Dictionary = app.static_view_cache.get(app.overlay_mode, {})

		if (
			not cached.is_empty()
			and cached.get("signature", []) == current_signature
			and int(cached.get("view_size", -1)) == view_size
		):
			app.static_city_image = cached.image
			app.moving_sprites._set_static_occlusion_commands(
				cached.get("occlusion_commands", []), view_size
			)
			app.static_visual_signature = current_signature
			app.static_render_mode = app.overlay_mode
			app.static_display_city = cached.display_city
			var cached_texture := CityMapTexture.create(app.static_city_image)
			app.map_view.set_city_view(
				app.static_display_city, cached_texture, cached_texture, true
			)
			app.menus._sync_map_style()

			if app.overlay_mode == "city":
				app.moving_sprites._refresh_moving_things(view_size)
			else:
				app.dynamic_sign_occluders.clear()
				app.dynamic_sign_occlusion_grid.clear()
				app.map_view.set_dynamic_sprites([])
				_refresh_sign_occlusion(view_size)

			return

		if (
			not force
			and app.static_city_image != null
			and app.static_render_mode == app.overlay_mode
			and current_signature == app.static_visual_signature
		):
			if app.overlay_mode == "city":
				app.moving_sprites._refresh_moving_things(view_size)
			else:
				app.dynamic_sign_occluders.clear()
				app.dynamic_sign_occlusion_grid.clear()
				app.map_view.set_dynamic_sprites([])
				_refresh_sign_occlusion(view_size)

			return

		if not force:
			app.static_render._request_static_render(current_signature, view_size, sprite_archive, app.overlay_mode)

			if app.overlay_mode == "city":
				app.moving_sprites._refresh_moving_things(view_size)
			else:
				app.dynamic_sign_occluders.clear()
				app.dynamic_sign_occlusion_grid.clear()
				app.map_view.set_dynamic_sprites([])
				_refresh_sign_occlusion(view_size)

			return

		app.static_render_epoch += 1
		var display_city := (
			app.city
			if app.overlay_mode == "underground"
			else ViewFilter.surface_copy(app.city, app.surface_visibility)
		)
		var indexed: Dictionary

		if app.overlay_mode == "underground":
			indexed = UndergroundView.create_image(
				display_city, app.palette_index_encoding, sprite_archive, view_size, true,
				app.show_underground_pipes, app.show_underground_subways, app.show_underground_water_mains
			)
		else:
			indexed = IsometricRenderer.create_image(
				display_city, app.palette_index_encoding, sprite_archive, view_size,
				int(IntegerMath.div_trunc(Time.get_ticks_msec(), 100)), false, true, true, false
			)

		if not indexed.ok:
			app.interface._show_error(indexed.error)

			return

		image = indexed.image

		if view_size != IsometricRenderer.VIEW_LARGE:
			image.resize(
				IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_LARGE, app.city.map_size).x,
				IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_LARGE, app.city.map_size).y,
				Image.INTERPOLATE_NEAREST,
			)

		app.static_city_image = image
		var occlusion_commands: Array[Dictionary] = []

		if app.overlay_mode == "city":
			occlusion_commands = IsometricRenderer.static_occlusion_commands(
				display_city, sprite_archive, view_size
			)

		app.moving_sprites._set_static_occlusion_commands(occlusion_commands, view_size)
		app.static_visual_signature = current_signature
		app.static_render_mode = app.overlay_mode
		app.static_display_city = display_city
		app.static_view_cache[app.overlay_mode] = {
			"image": image,
			"occlusion_commands": app.static_occlusion_commands,
			"signature": current_signature,
			"display_city": display_city,
			"view_size": view_size,
		}
	else:
		app.pending_static_render = false
		image = Minimap.create_image(app.city, app.palette, app.overlay_mode)
		image.resize(1024, 1024, Image.INTERPOLATE_NEAREST)
		app.static_city_image = null
		app.static_occlusion_commands.clear()
		app.static_occlusion_grid.clear()
		app.static_visual_signature = []
		app.dynamic_sign_occluders.clear()
		app.dynamic_sign_occlusion_grid.clear()
		app.map_view.set_dynamic_sprites([])

	var texture := CityMapTexture.create(image)
	app.map_view.set_city_view(
		app.static_display_city if app.overlay_mode in ["city", "underground"] else app.city,
		texture, texture if app.overlay_mode in ["city", "underground"] else null,
		app.overlay_mode in ["city", "underground"]
	)
	app.menus._sync_map_style()

	if app.overlay_mode == "city":
		app.moving_sprites._refresh_moving_things(app.static_render._city_view_size())
	else:
		_refresh_sign_occlusion(app.static_render._city_view_size())


func _close_region_cache() -> void:
	app.static_render._clear_dynamic_composition_cache()
	app.foreground_complete = false

	if app.region_cache != null:
		app.region_cache.close()

	app.region_cache = null


func _refresh_region_map(force: bool, dirty := Rect2i()) -> void:
	if app.region_cache == null:
		app.region_cache = CityRegionCache.new()
		app.region_cache.gpu_enabled = CityRegionCache.gpu_supported(app.app_city_renderer)

	app.static_city_image = null
	app.static_view_cache.clear()
	app.static_occlusion_commands.clear()
	app.static_occlusion_grid.clear()
	app.pending_static_render = false
	var view_size := app.static_render._city_view_size()
	var sprites := app.static_render._sprite_archive_for_view(view_size)
	var signature := app.static_render._static_signature_for_mode(app.overlay_mode, view_size)
	signature.append(sprites.get_instance_id())

	if force:
		app.region_cache.signature = []

	app.region_cache.configure(app.city, app.palette_index_encoding, sprites, signature, view_size,
		app.overlay_mode, app.surface_visibility, app.show_underground_pipes, app.show_underground_subways, dirty, app.show_underground_water_mains)

	if app.overlay_mode == "city":
		var labels := app.city.document.find_chunk("XLAB")
		# reuse the altitude and sign/dispatch hashes already computed for this snapshot
		app.region_cache.sign_layout_token = [app.city.map_size, signature[1], signature[2], signature[3], signature[9], hash(labels.decoded_payload) if labels != null else 0]
	else:
		app.region_cache.sign_layout_token = []

	app.static_visual_signature = signature
	app.static_render_mode = app.overlay_mode
	app.static_display_city = app.region_cache.display_city
	var texture := app.region_cache.texture()
	app.map_view.set_city_view(app.static_display_city, texture, texture, true, true, app.region_cache.sign_layout_token)
	app.menus._sync_map_style()
	app.region_cache.set_sign_requests(app.map_view.sign_source_entries())
	app.region_cache.update_viewport(app.map_view.visible_source_rect())

	if app.overlay_mode == "city":
		app.moving_sprites._refresh_moving_things(view_size)
	else:
		app.map_view.set_dynamic_sprites([])
		app.map_view.set_sign_occlusion_visuals({})


func _poll_region_cache() -> void:
	if app.region_cache == null or app.city == null:
		return

	app.region_cache.update_viewport(app.map_view.visible_source_rect())

	if not app.region_cache.tick():
		return

	if not app.region_cache.last_error.is_empty():
		app.interface._show_error(app.region_cache.last_error)

		return

	app.static_display_city = app.region_cache.display_city
	app.dynamic_occluder_cache.clear()
	var foreground_changed := _invalidate_region_foregrounds(app.region_cache.foreground_changes)
	var texture := app.region_cache.texture()
	app.map_view.set_city_view(app.static_display_city, texture, texture, true, true, app.region_cache.sign_layout_token)
	app.menus._sync_map_style()

	if app.overlay_mode == "city":
		if foreground_changed or not app.foreground_complete or app.foreground_view_rect != app.map_view.visible_source_rect():
			app.moving_sprites._refresh_moving_things(app.region_cache.view_size)
	else:
		app.map_view.set_dynamic_sprites([])


func _invalidate_region_foregrounds(changes: Array[Rect2i]) -> bool:
	var invalidated := false

	for key in app.dynamic_visual_cache.keys():
		var visual: Dictionary = app.dynamic_visual_cache[key]

		if visual.is_empty():
			app.dynamic_visual_cache.erase(key)
			continue

		var bounds := Rect2i(Vector2i(visual.position), Vector2i(visual.size))

		for changed in changes:
			if bounds.intersects(changed):
				app.dynamic_visual_cache.erase(key)
				invalidated = true
				break

	for key in app.sign_foreground_cache.keys():
		var bounds: Rect2i = app.sign_foreground_cache[key].signature[1]

		for changed in changes:
			if bounds.intersects(changed):
				app.sign_foreground_cache.erase(key)
				invalidated = true
				break

	return invalidated


func _static_image_size() -> Vector2i:
	return app.region_cache.native_size * app.region_cache.divisor if app.region_cache != null else (app.static_city_image.get_size() if app.static_city_image != null else Vector2i.ZERO)


func _static_pixel(x: int, y: int) -> Color:
	return app.region_cache.pixel(Vector2i(x, y)) if app.region_cache != null else app.static_city_image.get_pixel(x, y)


func _refresh_sign_occlusion(view_size: int) -> void:
	if (
		app.overlay_mode != "city"
		or not bool(app.surface_visibility.signs)
		or app.city == null
		or app.map_view == null
		or (app.static_city_image == null and app.region_cache == null)
		or (app.static_occlusion_commands.is_empty() and app.region_cache == null)
	):
		if app.map_view != null:
			app.map_view.set_sign_occlusion_visuals({})

		return

	var entries := app.map_view.sign_source_entries()

	if entries.is_empty():
		app.map_view.set_sign_occlusion_visuals({})

		return

	var sprite_archive := app.static_render._sprite_archive_for_view(view_size)
	var configuration := IsometricRenderer.view_configuration(view_size)
	var divisor := int(configuration.divisor)
	var factor := 1

	if app.static_occlusion_grid.is_empty() and app.region_cache == null:
		app.static_occlusion_grid = IsometricRenderer.build_occlusion_grid(
			app.static_occlusion_commands, divisor
		)

	var color_indices := app.palette.animation_index_map(app.palette_cycle_ticks)
	var gpu_palette := app.region_cache != null and app.region_cache.gpu_enabled
	var image_bounds := Rect2i(Vector2i.ZERO, _static_image_size())
	var visuals := {}

	for entry in entries:
		var source_bounds: Rect2i = entry.bounds

		if app.region_cache != null and not Rect2(source_bounds).intersects(app.map_view.visible_source_rect().grow(128)):
			continue

		var bounds := source_bounds.intersection(image_bounds)

		if bounds.get_area() <= 0:
			continue

		var moving_candidates: Array[Dictionary] = []

		for moving_index in IsometricRenderer.occlusion_candidate_indices(app.dynamic_sign_occlusion_grid, bounds):
			moving_candidates.append(app.dynamic_sign_occluders[moving_index])

		var signature := [view_size, bounds, int(entry.draw_order), moving_candidates]
		var key := int(entry.key)

		if app.sign_foreground_cache.has(key) and app.sign_foreground_cache[key].signature == signature:
			var cached: Dictionary = app.sign_foreground_cache[key]

			if cached.indices != null:
				var palette_signature := 0 if gpu_palette else _sign_palette_signature(cached.used_indices, color_indices)

				if not gpu_palette and int(cached.palette_signature) != palette_signature:
					cached.visual.texture = ImageTexture.create_from_image(_sign_palette_image(cached.indices, color_indices))
					cached.palette_signature = palette_signature

				visuals[key] = cached.visual

			continue

		var foreground: Image = app.region_cache.sign_foreground(key, bounds, int(entry.draw_order), factor) if gpu_palette else null

		if foreground == null:
			var masks: Array[Dictionary] = []

			for command in app.moving_sprites._static_occlusion_candidates(bounds):
				if int(command.depth_order) <= int(entry.draw_order):
					continue

				var position := Vector2i(command.position) * divisor

				if not bounds.intersects(Rect2i(position, Vector2i(command.size) * divisor)):
					continue

				var resource := app.moving_sprites._dynamic_sprite_resource(sprite_archive, int(command.sprite_id), bool(command.flip), divisor, factor)

				if not resource.is_empty():
					masks.append({"image": resource.image, "position": position * factor})

			var sampled: Image = app.region_cache.image_region(bounds, factor) if app.region_cache != null else app.static_city_image.get_region(bounds)
			foreground = CitySignForeground.static_pixels(sampled, masks, Rect2i(bounds.position * factor, bounds.size * factor))

		for visual in MapControl.later_sign_occluder_visuals(moving_candidates, bounds, int(entry.draw_order)):
			var moving_image: Image = visual.get("image") as Image

			if moving_image != null:
				CitySignForeground.add_moving(foreground, moving_image, Vector2i(visual.position) * factor, Rect2i(bounds.position * factor, bounds.size * factor))

		var used_indices := {} if gpu_palette else CitySignForeground.used_indices(foreground)
		var empty_foreground := foreground.is_invisible() if gpu_palette else used_indices.is_empty()

		if empty_foreground:
			app.sign_foreground_cache[key] = {"signature": signature, "indices": null}
			continue

		var texture: Texture2D
		var previous: Dictionary = app.map_view.sign_occlusion_visuals.get(key, {})

		if gpu_palette and bool(previous.get("indexed", false)) and previous.has("indices") and previous.indices.get_size() == foreground.get_size() and previous.indices.get_data() == foreground.get_data():
			foreground = previous.indices
			texture = previous.texture
		else:
			texture = ImageTexture.create_from_image(foreground if gpu_palette else _sign_palette_image(foreground, color_indices))

		visuals[int(entry.key)] = {
			"indexed": gpu_palette,
			"indices": foreground if gpu_palette else null,
			"texture": texture,
			"position": Vector2(bounds.position),
			"size": Vector2(bounds.size),
		}
		app.sign_foreground_cache[key] = {"signature": signature, "indices": foreground, "palette_signature": 0 if gpu_palette else _sign_palette_signature(used_indices, color_indices), "used_indices": used_indices, "visual": visuals[key]}

	app.map_view.set_sign_occlusion_visuals(visuals)


func _sign_palette_signature(used: Dictionary, mapping: PackedInt32Array) -> int:
	var colors := PackedInt32Array()

	for index in used:
		colors.append(mapping[index])

	return hash(colors)


func _sign_palette_image(indexed: Image, mapping: PackedInt32Array) -> Image:
	var bytes := indexed.get_data()

	for offset in range(0, bytes.size(), 4):
		if bytes[offset + 3] == 0:
			continue

		var color := app.palette.color(mapping[bytes[offset]])
		bytes[offset] = color.r8
		bytes[offset + 1] = color.g8
		bytes[offset + 2] = color.b8

	return Image.create_from_data(indexed.get_width(), indexed.get_height(), false, Image.FORMAT_RGBA8, bytes)
