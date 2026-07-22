class_name ApplicationMapRender
extends RefCounted


const Minimap = preload("res://src/view/city_minimap.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const UndergroundView = preload("res://src/view/city_underground_view.gd")
const ViewFilter = preload("res://src/view/city_view_filter.gd")
const MapControl = preload("res://src/view/city_map_control.gd")

var app: CityApplication
var caches: RenderCaches


func _init(application: CityApplication) -> void:
	app = application
	caches = application.render_caches


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
		app.static_render_state.pending = false
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
			app.static_render_state.pending = false

		var view_size := app.static_render._city_view_size()
		var sprite_archive := app.static_render._sprite_archive_for_view(view_size)
		var current_signature := app.static_render._static_signature_for_mode(app.overlay_mode, view_size)
		var cached: Dictionary = caches.static_view_cache.get(app.overlay_mode, {})

		if (
			not cached.is_empty()
			and cached.get("signature", []) == current_signature
			and int(cached.get("view_size", -1)) == view_size
		):
			caches.static_city_image = cached.image
			app.moving_sprites._set_static_occlusion_commands(
				cached.get("occlusion_commands", []), view_size
			)
			caches.static_visual_signature = current_signature
			caches.static_render_mode = app.overlay_mode
			caches.static_display_city = cached.display_city
			var cached_source := CityMapTexture.create(caches.static_city_image)
			app.map_view.set_city_view(
				caches.static_display_city, cached_source, null, true
			)
			app.menus._sync_map_style()

			if app.overlay_mode == "city":
				app.moving_sprites._refresh_moving_things(view_size)
			else:
				caches.dynamic_sign_occluders.clear()
				caches.dynamic_sign_occlusion_grid.clear()
				app.map_view.set_dynamic_sprites([])
				_refresh_sign_occlusion(view_size)

			return

		if (
			not force
			and caches.static_city_image != null
			and caches.static_render_mode == app.overlay_mode
			and current_signature == caches.static_visual_signature
		):
			if app.overlay_mode == "city":
				app.moving_sprites._refresh_moving_things(view_size)
			else:
				caches.dynamic_sign_occluders.clear()
				caches.dynamic_sign_occlusion_grid.clear()
				app.map_view.set_dynamic_sprites([])
				_refresh_sign_occlusion(view_size)

			return

		if not force:
			app.static_render._request_static_render(current_signature, view_size, sprite_archive, app.overlay_mode)

			if app.overlay_mode == "city":
				app.moving_sprites._refresh_moving_things(view_size)
			else:
				caches.dynamic_sign_occluders.clear()
				caches.dynamic_sign_occlusion_grid.clear()
				app.map_view.set_dynamic_sprites([])
				_refresh_sign_occlusion(view_size)

			return

		app.static_render_state.epoch += 1
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

		caches.static_city_image = image
		var occlusion_commands: Array[Dictionary] = []

		if app.overlay_mode == "city":
			occlusion_commands = IsometricRenderer.static_occlusion_commands(
				display_city, sprite_archive, view_size
			)

		app.moving_sprites._set_static_occlusion_commands(occlusion_commands, view_size)
		caches.static_visual_signature = current_signature
		caches.static_render_mode = app.overlay_mode
		caches.static_display_city = display_city
		caches.static_view_cache[app.overlay_mode] = {
			"image": image,
			"occlusion_commands": caches.static_occlusion_commands,
			"signature": current_signature,
			"display_city": display_city,
			"view_size": view_size,
		}
	else:
		app.static_render_state.pending = false
		image = Minimap.create_image(app.city, app.palette, app.overlay_mode)
		image.resize(1024, 1024, Image.INTERPOLATE_NEAREST)
		caches.static_city_image = null
		caches.static_occlusion_commands.clear()
		caches.static_occlusion_grid.clear()
		caches.static_visual_signature = []
		caches.dynamic_sign_occluders.clear()
		caches.dynamic_sign_occlusion_grid.clear()
		app.map_view.set_dynamic_sprites([])

	var source := CityMapTexture.create(image)
	app.map_view.set_city_view(
		caches.static_display_city if app.overlay_mode in ["city", "underground"] else app.city,
		source, null,
		app.overlay_mode in ["city", "underground"]
	)
	app.menus._sync_map_style()

	if app.overlay_mode == "city":
		app.moving_sprites._refresh_moving_things(app.static_render._city_view_size())
	else:
		_refresh_sign_occlusion(app.static_render._city_view_size())


func _close_region_cache() -> void:
	app.static_render._clear_dynamic_composition_cache()
	caches.foreground_complete = false

	if caches.region_cache != null:
		caches.region_cache.close()

	caches.region_cache = null


func _refresh_region_map(force: bool, dirty := Rect2i()) -> void:
	if caches.region_cache == null:
		caches.region_cache = CityRegionCache.new()
		caches.region_cache.gpu_enabled = CityRegionCache.gpu_supported(app.app_city_renderer)

	caches.static_city_image = null
	caches.static_view_cache.clear()
	caches.static_occlusion_commands.clear()
	caches.static_occlusion_grid.clear()
	app.static_render_state.pending = false
	var view_size := app.static_render._city_view_size()
	var sprites := app.static_render._sprite_archive_for_view(view_size)
	var signature := app.static_render._static_signature_for_mode(app.overlay_mode, view_size)
	signature.append(sprites.get_instance_id())

	if force:
		caches.region_cache.signature = []

	caches.region_cache.configure(app.city, app.palette_index_encoding, sprites, signature, view_size,
		app.overlay_mode, app.surface_visibility, app.show_underground_pipes, app.show_underground_subways, dirty, app.show_underground_water_mains)

	if app.overlay_mode == "city":
		var labels := app.city.document.find_chunk("XLAB")
		# reuse the altitude revision and the sign/dispatch signature already
		# computed for this snapshot
		caches.region_cache.sign_layout_token = [app.city.map_size, signature[1], signature[2], signature[3], signature[9], hash(labels.decoded_payload) if labels != null else 0]
	else:
		caches.region_cache.sign_layout_token = []

	caches.static_visual_signature = signature
	caches.static_render_mode = app.overlay_mode
	caches.static_display_city = caches.region_cache.display_city
	var source := caches.region_cache.texture()
	app.map_view.set_city_view(caches.static_display_city, source, null, true, true, caches.region_cache.sign_layout_token)
	app.menus._sync_map_style()
	caches.region_cache.set_sign_requests(app.map_view.sign_source_entries())
	caches.region_cache.update_viewport(app.map_view.visible_source_rect())

	if app.overlay_mode == "city":
		app.moving_sprites._refresh_moving_things(view_size)
	else:
		app.map_view.set_dynamic_sprites([])
		app.map_view.set_sign_occlusion_visuals({})


func _poll_region_cache() -> void:
	if caches.region_cache == null or app.city == null:
		return

	caches.region_cache.update_viewport(app.map_view.visible_source_rect())

	if not caches.region_cache.tick():
		return

	if not caches.region_cache.last_error.is_empty():
		app.interface._show_error(caches.region_cache.last_error)

		return

	caches.static_display_city = caches.region_cache.display_city
	caches.dynamic_occluder_cache.clear()
	var foreground_changed := _invalidate_region_foregrounds(caches.region_cache.foreground_changes)
	var source := caches.region_cache.texture()
	app.map_view.set_city_view(caches.static_display_city, source, null, true, true, caches.region_cache.sign_layout_token)
	app.menus._sync_map_style()

	if app.overlay_mode == "city":
		if foreground_changed or not caches.foreground_complete or caches.foreground_view_rect != app.map_view.visible_source_rect():
			app.moving_sprites._refresh_moving_things(caches.region_cache.view_size)
	else:
		app.map_view.set_dynamic_sprites([])


func _invalidate_region_foregrounds(changes: Array[Rect2i]) -> bool:
	var invalidated := false

	for key in caches.dynamic_visual_cache.keys():
		var visual: Dictionary = caches.dynamic_visual_cache[key]

		if visual.is_empty():
			caches.dynamic_visual_cache.erase(key)
			continue

		var bounds := Rect2i(Vector2i(visual.position), Vector2i(visual.size))

		for changed in changes:
			if bounds.intersects(changed):
				caches.dynamic_visual_cache.erase(key)
				invalidated = true
				break

	for key in caches.sign_foreground_cache.keys():
		var bounds: Rect2i = caches.sign_foreground_cache[key].signature[1]

		for changed in changes:
			if bounds.intersects(changed):
				caches.sign_foreground_cache.erase(key)
				invalidated = true
				break

	return invalidated


func _static_image_size() -> Vector2i:
	return caches.region_cache.native_size * caches.region_cache.divisor if caches.region_cache != null else (caches.static_city_image.get_size() if caches.static_city_image != null else Vector2i.ZERO)


func _static_pixel(x: int, y: int) -> Color:
	return caches.region_cache.pixel(Vector2i(x, y)) if caches.region_cache != null else caches.static_city_image.get_pixel(x, y)


func _refresh_sign_occlusion(view_size: int) -> void:
	ApplicationMapSigns._refresh_sign_occlusion(self, view_size)


func _sign_palette_signature(used: Dictionary, mapping: PackedInt32Array) -> int:
	return ApplicationMapSigns._sign_palette_signature(self, used, mapping)


func _sign_palette_image(indexed: Image, mapping: PackedInt32Array) -> Image:
	return ApplicationMapSigns._sign_palette_image(self, indexed, mapping)
