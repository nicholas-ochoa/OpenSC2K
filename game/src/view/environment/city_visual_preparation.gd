class_name CityVisualPreparation
extends RefCounted
## City-owned presentation resources. The simulation and saved document are read-only.
@warning_ignore_start("integer_division")

const VARIANTS := 6
var app: CityApplication
var banks: Array[CityRegionCache] = []
var archives: Array[Sc2SpriteArchive] = []
var busy := false
var ready := false
var preparing_view := -1
var preparing_traffic := -1
var layout: Array = []
var stage := 0
var stages: Array[int] = []
var prepared_light_views: Dictionary[int, bool] = {}
var background_cursor := 0
var completed := 0
var total := 0
var failure := ""
var progress := 0.0
var lighting_started := false
var preparing_lights: Array[Vector2i] = []
var light_rescan: Dictionary[int, bool] = {}


func _init(application: CityApplication) -> void:
	app = application


func reset() -> void:
	busy = false
	ready = false
	preparing_view = -1
	preparing_traffic = -1
	if owns(app.render_caches.region_cache):
		app.render_caches.region_cache = null
	for cache in banks:
		cache.close()
	banks.clear()
	archives.clear()
	stages.clear()
	prepared_light_views.clear()
	light_rescan.clear()
	preparing_lights.clear()
	layout.clear()
	if app.city_dialogs != null and app.city_dialogs.visual_preparation_progress != null:
		app.city_dialogs.visual_preparation_progress.hide()
	for ground in app.visual_environment.night_lighting.ground_views.values():
		ground.resident = false
		ground.prepare_entire_city = false


func owns(cache: CityRegionCache) -> bool:
	return cache != null and cache in banks


func _layout() -> Array:
	var city := app.document_state.city
	return [city.document.get_instance_id(), city.map_size, city.compass_rotation(), city.visible_altitude_levels,
		app.asset_state.large_sprites, app.asset_state.small_medium_sprites,
		app.view_state.surface_visibility.duplicate(), app.preferences.city_renderer,
		app.preferences.zoom_graphics.duplicate(), app.preferences.overview_graphics, app.preferences.visual_enhancements.life_cars_enabled,
		app.asset_state.large_sprites.visual_nature_enabled, app.asset_state.large_sprites.visual_terrain_enabled,
		app.asset_state.small_medium_sprites.visual_nature_enabled, app.asset_state.small_medium_sprites.visual_terrain_enabled]


func required_variants() -> Array[int]:
	var result: Array[int] = []
	for zoom: float in CityMapConstants.ZOOM_LEVELS:
		var view := AppSettingsStore.graphics_size_at_zoom(app.preferences.zoom_graphics, roundi(zoom * 100), app.preferences.overview_graphics)
		var traffic := int(zoom >= 0.5 and app.preferences.visual_enhancements.life_cars_enabled and app.view_state.surface_visibility.networks)
		var index := mini(view, 2) * 2 + traffic
		if index not in result:
			result.append(index)
	result.sort()
	return result


func _index(view: int) -> int:
	var traffic := preparing_traffic if preparing_traffic >= 0 else int(app.static_render.original_archive_for_view(view).visual_city_life_traffic)
	return view * 2 + traffic


func archive_for_view(view: int) -> Sc2SpriteArchive:
	return archives[_index(view)] if archives.size() == VARIANTS and (ready or preparing_view >= 0) else null


func selected_cache(view: int) -> CityRegionCache:
	return banks[_index(view)]


func begin() -> void:
	# Initialize presentation clocks while the previous render source is still
	# attached. A detached regional source must never enter the whole-image path.
	app.visual_environment.process(0.0)
	var replace_active := owns(app.render_caches.region_cache)
	reset()
	app.city_life.sprites.prepare_frames()
	layout = _layout()
	failure = ""
	stage = 0
	completed = 0
	progress = 0.0
	lighting_started = false
	stages = required_variants()
	total = stages.size()
	for index in VARIANTS:
		var view := index / 2
		var original := app.static_render.original_archive_for_view(view)
		var archive := Sc2SpriteArchive.new()
		# Share immutable decoded art; only the decorative traffic switch differs.
		archive.entries = original.entries
		archive.entries_by_id = original.entries_by_id
		archive.visual_emission = original.visual_emission
		archive.visual_seasons = original.visual_seasons
		archive.visual_nature = original.visual_nature
		archive.visual_nature_masks = original.visual_nature_masks
		archive.visual_nature_enabled = original.visual_nature_enabled
		archive.visual_terrain_enabled = original.visual_terrain_enabled
		archive.visual_revision = original.visual_revision
		archive.water_reflections = original.water_reflections
		archive.water_indices = original.water_indices
		archive.redraw_small_highway_ground = original.redraw_small_highway_ground
		archive.visual_city_life_traffic = index % 2 == 1
		archives.append(archive)
		var cache := CityRegionCache.new()
		cache.gpu_enabled = CityRegionCache.gpu_supported(app.preferences.city_renderer)
		cache.resident = true
		cache.background_preparation = true
		banks.append(cache)
		_configure(index)
		if index in stages:
			cache.update_viewport(Rect2(Vector2.ZERO, Vector2(cache.native_size * cache.divisor)))
	busy = true
	if replace_active:
		app.map_render.refresh_map(false)
	_progress(0.0, "Preparing city graphics…")


func _progress(fraction: float, detail: String) -> void:
	progress = maxf(progress, fraction)
	app.city_dialogs.visual_preparation_progress.show_progress("Preparing Visual Enhancements", detail, progress)


func process() -> bool:
	if app.document_state.city == null or app.asset_state.large_sprites == null or app.asset_state.small_medium_sprites == null:
		if not banks.is_empty():
			reset()
		return false
	if app.tool_state.landscape_editor or app.main_menu.visible:
		if busy:
			reset()
		return false
	if layout != _layout():
		begin()
		return false
	if not busy:
		if ready:
			_background()
		return false
	# Camera work uses the normal renderer. Do not compete with uncovered areas.
	var active := app.render_caches.region_cache
	if active != null and not active.covered():
		return false
	var previous_view := preparing_view
	var previous_traffic := preparing_traffic
	var index := stages[stage]
	preparing_view = index / 2
	preparing_traffic = index % 2
	app.render_caches.region_cache = banks[index]
	_prepare_step()
	preparing_view = previous_view
	preparing_traffic = previous_traffic
	app.render_caches.region_cache = active
	if not failure.is_empty():
		var message := failure
		var failed_layout := layout
		reset()
		layout = failed_layout
		app.interface.show_error("Visual preparation failed: " + message)
	elif ready:
		app.map_render.refresh_map(false)
		app.city_dialogs.visual_preparation_progress.hide()
	return false


func _prepare_step() -> void:
	var cache := banks[stages[stage]]
	_configure(stages[stage])
	cache.tick()
	# An edit can arrive while a bank is loading. Publish its changed silhouettes
	# to retained light masks, just as the ordinary visible renderer does.
	if cache.generation > 1 and not cache.lighting_changes.is_empty():
		app.visual_environment.night_lighting.invalidate_regions(cache.lighting_changes)
	if not cache.last_error.is_empty():
		failure = cache.last_error
		return
	var fraction := 0.8 * float(cache.entries.size()) / maxi(cache.wanted.size(), 1)
	var detail := "%s graphics (%s): %d / %d areas" % [["Small", "Medium", "Large"][preparing_view],
		"individual cars" if preparing_traffic == 1 else "classic traffic", cache.entries.size(), cache.wanted.size()]
	# Ongoing simulation repaints must not starve initial preparation. Every
	# area must exist; newer generations continue through the normal updater.
	if cache.covered():
		if not prepared_light_views.has(preparing_view) and VisualEnhancementOptions.detail_lights_visible(app.preferences.visual_enhancements, app.map_view.zoom_factor):
			var lighting := app.visual_environment.night_lighting
			lighting._select_ground(preparing_view)
			var ground := lighting.ground
			ground.resident = true
			if not lighting_started:
				# Discover offscreen receivers once. Keep the ordinary viewport for
				# drawing; resident pending jobs survive the visible-area collection.
				ground.sync(app, 0.0, 0.0, true, 1000)
				ground.bounds = ground._city_bounds(app.document_state.city)
				ground._collect(app.document_state.city)
				preparing_lights.assign(ground.visible_tiles)
				ground.bounds = Rect2i()
				lighting_started = true
			ground.sync(app, 0.0, 0.0, true, 1000)
			var built_lights := 0
			for tile in preparing_lights:
				built_lights += int(ground.cache.has(tile))
			fraction = 0.8 + 0.2 * float(built_lights) / maxi(preparing_lights.size(), 1)
			detail = "%s lighting: %d streets remaining" % [["Small", "Medium", "Large"][preparing_view], preparing_lights.size() - built_lights]
			# Dirty existing lights may keep arriving while the city is running.
			# Their refresh must not restart or hold up initial cache completion.
			if built_lights < preparing_lights.size():
				_progress((stage + fraction) / total, detail)
				return
		prepared_light_views[preparing_view] = true
		cache.update_viewport(app.map_view.visible_source_rect())
		cache._close_gpu_workers()
		cache._gpu_has_work = false
		cache.background_preparation = true
		stage += 1
		completed = stage
		lighting_started = false
		preparing_lights.clear()
		fraction = 0.0
		if stage == total:
			ready = true
			busy = false
	_progress((completed + fraction) / total, detail)


func _configure(index: int, dirty := Rect2i()) -> void:
	var cache := banks[index]
	var view := index / 2
	var signature := app.static_render.static_signature_for_mode(CityViewMode.Mode.CITY, view)
	signature.append(archives[index].get_instance_id())
	var changed: Array[Rect2i] = []
	var listed := false
	if not cache.signature.is_empty() and cache.signature != signature:
		listed = ApplicationStaticRender.changed_source_rects(app.document_state.city, cache.source_payloads, archives[index], view, changed)
	var previous_generation := cache.generation
	cache.configure(app.document_state.city, app.asset_state.palette_index_encoding, archives[index], signature, view,
		CityViewMode.Mode.CITY, app.view_state.surface_visibility, app.view_state.show_underground_pipes,
		app.view_state.show_underground_subways, dirty, app.view_state.show_underground_water_mains, changed, listed,
		app.view_state.show_underground_tunnels)
	if (ready or busy) and cache.generation != previous_generation:
		light_rescan[view] = true


func refresh(dirty := Rect2i()) -> void:
	var divisor := CityIsometricRenderer.view_configuration(app.static_render.city_view_size()).divisor
	for index in banks.size():
		if index not in stages and banks[index].entries.is_empty() and banks[index] != app.render_caches.region_cache:
			continue
		var converted := Rect2i(dirty.position * divisor / banks[index].divisor, dirty.size * divisor / banks[index].divisor)
		_configure(index, converted)


func _background() -> void:
	# Visible work has its normal frame budget. One hidden bank catches up per
	# frame, updating only regions whose source tiles changed.
	background_cursor = (background_cursor + 1) % VARIANTS
	var cache := banks[background_cursor]
	if cache == app.render_caches.region_cache:
		# The active lighting layer checks its geometry in the ordinary frame.
		light_rescan.erase(background_cursor / 2)
		return
	if background_cursor not in stages and cache.entries.is_empty():
		return
	# Hidden views keep the same small queues and upload allowance as loading.
	cache.background_preparation = true
	cache.tick()
	if not cache.lighting_changes.is_empty():
		app.visual_environment.night_lighting.invalidate_regions(cache.lighting_changes)
	var view := background_cursor / 2
	if not VisualEnhancementOptions.detail_lights_visible(app.preferences.visual_enhancements, app.map_view.zoom_factor):
		return
	var lighting := app.visual_environment.night_lighting
	if not lighting.ground_views.has(view):
		return
	var ground := lighting.ground_views[view]
	if not light_rescan.has(view) and ground.pending.is_empty():
		return
	var previous_cache := app.render_caches.region_cache
	app.render_caches.region_cache = cache
	preparing_view = view
	preparing_traffic = background_cursor % 2
	# Geometry tracking finds local additions/removals, including offscreen
	# streets. Traffic repaint generations must not enumerate the whole city.
	light_rescan.erase(view)
	ground.sync(app, 0.0, 0.0, true)
	preparing_view = -1
	preparing_traffic = -1
	app.render_caches.region_cache = previous_cache
