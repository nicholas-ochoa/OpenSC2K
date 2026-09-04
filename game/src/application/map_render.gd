class_name ApplicationMapRender
extends RefCounted


@warning_ignore_start("integer_division")

const Minimap = preload("res://src/view/city_minimap.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const UndergroundView = preload("res://src/view/city_underground_view.gd")
const ViewFilter = preload("res://src/view/city_view_filter.gd")

var app: CityApplication
var caches: RenderCaches


func _init(application: CityApplication) -> void:
	app = application
	caches = application.render_caches


func refresh_map(force := true) -> void:
	if app.city_status_bar != null:
		app.city_status_bar.set_compass(app.document_state.city.compass_rotation() if app.document_state.city != null else -1)

	if app.document_state.city == null or app.asset_state.palette == null:
		return

	app.map_view.trip_query_underground = app.view_state.overlay_mode == CityViewMode.Mode.UNDERGROUND
	app.map_view.set_signs_visible(
		app.view_state.overlay_mode == CityViewMode.Mode.CITY and bool(app.view_state.surface_visibility.signs)
	)

	if CityViewMode.is_data(app.view_state.overlay_mode):
		close_region_cache()
		app.static_render_state.pending = false
		app.map_view.set_dynamic_sprites([])
		app.map_view.show_transient_effects([])
		app.map_view.set_data_view(app.document_state.city, app.view_state.overlay_mode)

		return

	app.map_view.clear_data_view()

	if ((app.document_state.city.map_size > 128 or CityRegionCache.gpu_supported(app.preferences.city_renderer))
			and CityViewMode.is_map(app.view_state.overlay_mode)):
		refresh_region_map(force)

		return

	close_region_cache()

	if not CityViewMode.is_map(app.view_state.overlay_mode):
		_show_overview_map()

		return

	if force:
		app.static_render_state.pending = false

	var view_size := app.static_render.city_view_size()
	var sprite_archive := app.static_render.sprite_archive_for_view(view_size)
	var current_signature := app.static_render.static_signature_for_mode(app.view_state.overlay_mode, view_size)

	if _show_cached_static_view(current_signature, view_size):
		return

	if not force:
		_refresh_deferred(current_signature, view_size, sprite_archive)

		return

	_render_static_view(current_signature, view_size, sprite_archive)


# shows a cached static view that matches the signature and view size. returns false on a cache miss
func _show_cached_static_view(current_signature: Array, view_size: int) -> bool:
	var cached: RenderCaches.StaticView = caches.static_view_cache.get(app.view_state.overlay_mode)

	if (
		cached == null
		or cached.signature != current_signature
		or cached.view_size != view_size
	):
		return false

	caches.static_city_image = cached.image
	app.moving_sprites.set_static_occlusion_commands(
		cached.occlusion_commands, view_size
	)
	caches.static_visual_signature = current_signature
	caches.static_render_mode = app.view_state.overlay_mode
	caches.static_display_city = cached.display_city
	var cached_source := CityMapTexture.create(caches.static_city_image)
	app.map_view.set_city_view(
		caches.static_display_city, cached_source, null, true
	)
	app.menus.sync_map_style()
	_refresh_dynamic_layer(view_size)

	return true


# keeps the current static image and requests a background render when it is stale
func _refresh_deferred(current_signature: Array, view_size: int, sprite_archive: Sc2SpriteArchive) -> void:
	if (
		caches.static_city_image == null
		or caches.static_render_mode != app.view_state.overlay_mode
		or current_signature != caches.static_visual_signature
	):
		app.static_render.request_static_render(current_signature, view_size, sprite_archive, app.view_state.overlay_mode)

	_refresh_dynamic_layer(view_size)


# renders the city or underground static view on the main thread and caches it
func _render_static_view(current_signature: Array, view_size: int, sprite_archive: Sc2SpriteArchive) -> void:
	app.static_render_state.epoch += 1
	var display_city := (
		app.document_state.city
		if app.view_state.overlay_mode == CityViewMode.Mode.UNDERGROUND
		else ViewFilter.surface_copy(app.document_state.city, app.view_state.surface_visibility)
	)
	var indexed: AssetImageResult

	if app.view_state.overlay_mode == CityViewMode.Mode.UNDERGROUND:
		indexed = UndergroundView.create_image(
			display_city, app.asset_state.palette_index_encoding, sprite_archive, view_size, true,
			app.view_state.show_underground_pipes, app.view_state.show_underground_subways, app.view_state.show_underground_water_mains
		)
	else:
		indexed = IsometricRenderer.create_image(
			display_city, app.asset_state.palette_index_encoding, sprite_archive, view_size,
			int(Time.get_ticks_msec() / 100), false, true, true, false
		)

	if not indexed.ok:
		app.interface.show_error(indexed.error)

		return

	var image: Image = indexed.image

	if view_size != IsometricRenderer.VIEW_LARGE:
		image.resize(
			IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_LARGE, app.document_state.city.map_size).x,
			IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_LARGE, app.document_state.city.map_size).y,
			Image.INTERPOLATE_NEAREST,
		)

	caches.static_city_image = image
	var occlusion_commands: Array[Dictionary] = []

	if app.view_state.overlay_mode == CityViewMode.Mode.CITY:
		occlusion_commands = IsometricRenderer.static_occlusion_commands(
			display_city, sprite_archive, view_size
		)

	app.moving_sprites.set_static_occlusion_commands(occlusion_commands, view_size)
	caches.static_visual_signature = current_signature
	caches.static_render_mode = app.view_state.overlay_mode
	caches.static_display_city = display_city
	caches.static_view_cache[app.view_state.overlay_mode] = RenderCaches.StaticView.new(
		image, caches.static_occlusion_commands, current_signature,
		display_city, view_size
	)
	var source := CityMapTexture.create(image)
	app.map_view.set_city_view(caches.static_display_city, source, null, true)
	app.menus.sync_map_style()
	_refresh_dynamic_layer(app.static_render.city_view_size(), false)


# shows a whole-city overview map for the non-isometric views
func _show_overview_map() -> void:
	app.static_render_state.pending = false
	var image := Minimap.create_image(app.document_state.city, app.asset_state.palette, CityViewMode.key(app.view_state.overlay_mode))
	image.resize(1024, 1024, Image.INTERPOLATE_NEAREST)
	caches.static_city_image = null
	caches.static_occlusion_commands.clear()
	caches.static_occlusion_grid.clear()
	caches.static_visual_signature = []
	_clear_dynamic_sprites()
	var source := CityMapTexture.create(image)
	app.map_view.set_city_view(app.document_state.city, source, null, false)
	app.menus.sync_map_style()
	_refresh_dynamic_layer(app.static_render.city_view_size(), false)


# refreshes moving sprites in the city view, or sign occlusion in other views
# outside the city view, clear_moving first removes moving sprites and their sign occluders
func _refresh_dynamic_layer(view_size: int, clear_moving := true) -> void:
	if app.view_state.overlay_mode == CityViewMode.Mode.CITY:
		app.moving_sprites.refresh_moving_things(view_size)
	else:
		if clear_moving:
			_clear_dynamic_sprites()

		refresh_sign_occlusion(view_size)


func _clear_dynamic_sprites() -> void:
	caches.dynamic_sign_occluders.clear()
	caches.dynamic_sign_occlusion_grid.clear()
	app.map_view.set_dynamic_sprites([])


func close_region_cache() -> void:
	app.static_render.clear_dynamic_composition_cache()
	caches.foreground_complete = false

	if caches.region_cache != null:
		caches.region_cache.close()

	caches.region_cache = null


func refresh_region_map(force: bool, dirty := Rect2i()) -> void:
	if caches.region_cache == null:
		caches.region_cache = CityRegionCache.new()
		caches.region_cache.gpu_enabled = CityRegionCache.gpu_supported(app.preferences.city_renderer)

	caches.static_city_image = null
	caches.static_view_cache.clear()
	caches.static_occlusion_commands.clear()
	caches.static_occlusion_grid.clear()
	app.static_render_state.pending = false
	var view_size := app.static_render.city_view_size()
	var sprites := app.static_render.sprite_archive_for_view(view_size)
	var signature := app.static_render.static_signature_for_mode(app.view_state.overlay_mode, view_size)
	signature.append(sprites.get_instance_id())

	if force:
		caches.region_cache.signature = []

	caches.region_cache.configure(app.document_state.city, app.asset_state.palette_index_encoding, sprites, signature, view_size,
		app.view_state.overlay_mode, app.view_state.surface_visibility, app.view_state.show_underground_pipes,
		app.view_state.show_underground_subways, dirty, app.view_state.show_underground_water_mains)

	if app.view_state.overlay_mode == CityViewMode.Mode.CITY:
		var labels := app.document_state.city.document.find_chunk("XLAB")
		# reuse the altitude revision and the sign/dispatch signature already
		# computed for this snapshot
		caches.region_cache.sign_layout_token = [app.document_state.city.map_size, signature[1], signature[2], signature[3], signature[9], hash(labels.decoded_payload) if labels != null else 0]
	else:
		caches.region_cache.sign_layout_token = []

	caches.static_visual_signature = signature
	caches.static_render_mode = app.view_state.overlay_mode
	caches.static_display_city = caches.region_cache.display_city
	var source := caches.region_cache.texture()
	app.map_view.set_city_view(caches.static_display_city, source, null, true, true, caches.region_cache.sign_layout_token)
	app.menus.sync_map_style()
	caches.region_cache.set_sign_requests(app.map_view.sign_source_entries())
	caches.region_cache.update_viewport(app.map_view.visible_source_rect())

	if app.view_state.overlay_mode == CityViewMode.Mode.CITY:
		app.moving_sprites.refresh_moving_things(view_size)
	else:
		app.map_view.set_dynamic_sprites([])
		app.map_view.set_sign_occlusion_visuals({})


func poll_region_cache() -> void:
	if caches.region_cache == null or app.document_state.city == null:
		return

	caches.region_cache.update_viewport(app.map_view.visible_source_rect())

	if not caches.region_cache.tick():
		return

	if not caches.region_cache.last_error.is_empty():
		app.interface.show_error(caches.region_cache.last_error)

		return

	caches.static_display_city = caches.region_cache.display_city
	caches.dynamic_occluder_cache.clear()
	var foreground_changed := _invalidate_region_foregrounds(caches.region_cache.foreground_changes)
	var source := caches.region_cache.texture()
	app.map_view.set_city_view(caches.static_display_city, source, null, true, true, caches.region_cache.sign_layout_token)
	app.menus.sync_map_style()

	if app.view_state.overlay_mode == CityViewMode.Mode.CITY:
		if foreground_changed or not caches.foreground_complete or caches.foreground_view_rect != app.map_view.visible_source_rect():
			app.moving_sprites.refresh_moving_things(caches.region_cache.view_size)
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


func static_image_size() -> Vector2i:
	return (caches.region_cache.native_size * caches.region_cache.divisor if caches.region_cache != null
			else (caches.static_city_image.get_size() if caches.static_city_image != null else Vector2i.ZERO))


func _static_pixel(x: int, y: int) -> Color:
	return caches.region_cache.pixel(Vector2i(x, y)) if caches.region_cache != null else caches.static_city_image.get_pixel(x, y)


func refresh_sign_occlusion(view_size: int) -> void:
	ApplicationMapSigns.refresh_sign_occlusion(self, view_size)


func sign_palette_signature(used: Dictionary[int, bool], mapping: PackedInt32Array) -> int:
	return ApplicationMapSigns.sign_palette_signature(self, used, mapping)


func sign_palette_image(indexed: Image, mapping: PackedInt32Array) -> Image:
	return ApplicationMapSigns.sign_palette_image(self, indexed, mapping)
