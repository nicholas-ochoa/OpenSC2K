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
var background_cursor := 0
var completed := 0
var total := 0
var failure := ""
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
	light_rescan.clear()
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
		app.view_state.surface_visibility.duplicate(), app.preferences.city_renderer]


func _index(view: int) -> int:
	var traffic := preparing_traffic if preparing_traffic >= 0 else int(app.static_render.original_archive_for_view(view).visual_city_life_traffic)
	return view * 2 + traffic


func archive_for_view(view: int) -> Sc2SpriteArchive:
	return archives[_index(view)] if archives.size() == VARIANTS else null


func selected_cache(view: int) -> CityRegionCache:
	return banks[_index(view)]


func begin() -> void:
	# Initialize presentation clocks while the previous render source is still
	# attached. A detached regional source must never enter the whole-image path.
	app.visual_environment.process(0.0)
	reset()
	app.map_render.close_region_cache()
	app.visual_environment.night_lighting.reset()
	app.city_life.sprites.prepare_frames()
	layout = _layout()
	failure = ""
	stage = 0
	completed = 0
	total = VARIANTS
	for index in VARIANTS:
		var view := index / 2
		var original := app.static_render.original_archive_for_view(view)
		var archive := Sc2SpriteArchive.new()
		# Share immutable decoded art; only the decorative traffic switch differs.
		archive.entries = original.entries
		archive.entries_by_id = original.entries_by_id
		archive.visual_emission = original.visual_emission
		archive.visual_seasons = original.visual_seasons
		archive.visual_revision = original.visual_revision
		archive.water_reflections = original.water_reflections
		archive.water_indices = original.water_indices
		archive.redraw_small_highway_ground = original.redraw_small_highway_ground
		archive.visual_city_life_traffic = index % 2 == 1
		archives.append(archive)
		var cache := CityRegionCache.new()
		cache.gpu_enabled = CityRegionCache.gpu_supported(app.preferences.city_renderer)
		cache.resident = true
		banks.append(cache)
		_configure(index)
		cache.update_viewport(Rect2(Vector2.ZERO, Vector2(cache.native_size * cache.divisor)))
	busy = true
	_progress(0.0, "Preparing city graphics…")


func _progress(fraction: float, detail: String) -> void:
	app.city_dialogs.visual_preparation_progress.show_progress("Preparing Visual Enhancements", detail, fraction)


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
		return true
	if not busy:
		if ready:
			_background()
		return false
	var cache := banks[stage]
	preparing_view = stage / 2
	preparing_traffic = stage % 2
	app.render_caches.region_cache = cache
	cache.tick()
	if not cache.last_error.is_empty():
		failure = cache.last_error
		var failed_layout := layout
		reset()
		layout = failed_layout
		app.map_render.refresh_map()
		app.interface.show_error("Visual preparation failed: " + failure)
		return false
	var fraction := float(cache.entries.size()) / maxi(cache.wanted.size(), 1)
	var detail := "%s graphics: %d / %d areas" % [["Small", "Medium", "Large"][preparing_view], cache.entries.size(), cache.wanted.size()]
	if cache.prefetch_ready():
		if stage % 2 == 0:
			var lighting := app.visual_environment.night_lighting
			lighting._select_ground(preparing_view)
			var ground := lighting.ground
			ground.resident = true
			ground.prepare_entire_city = true
			ground.sync(app, 0.0, 0.0, true)
			fraction = 0.8 + 0.2 * float(ground.cache.size()) / maxi(ground.visible_tiles.size(), 1)
			detail = "%s lighting: %d / %d streets" % [["Small", "Medium", "Large"][preparing_view], ground.cache.size(), ground.visible_tiles.size()]
			if not ground.pending.is_empty():
				_progress((stage + fraction) / VARIANTS, detail)
				return true
			ground.prepare_entire_city = false
			ground.bounds = Rect2i()
			ground.sync(app, 0.0, 0.0, true)
		cache.update_viewport(app.map_view.visible_source_rect())
		# Completed meshes own their textures. Release the large temporary native
		# painter caches; later edits create workers only for affected regions.
		cache._close_gpu_workers()
		cache._gpu_has_work = false
		stage += 1
		completed = stage
		fraction = 0.0
		if stage == VARIANTS:
			preparing_view = -1
			preparing_traffic = -1
			ready = true
			busy = false
			app.map_render.refresh_map(false)
			app.visual_environment.process(0.0)
			app.city_dialogs.visual_preparation_progress.hide()
			return true
	_progress((completed + fraction * 0.8) / VARIANTS, detail)
	return true


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
	if ready and cache.generation != previous_generation:
		light_rescan[view] = true


func refresh(dirty := Rect2i()) -> void:
	var divisor := CityIsometricRenderer.view_configuration(app.static_render.city_view_size()).divisor
	for index in banks.size():
		var converted := Rect2i(dirty.position * divisor / banks[index].divisor, dirty.size * divisor / banks[index].divisor)
		_configure(index, converted)


func _background() -> void:
	# Visible work has its normal frame budget. One hidden bank catches up per
	# frame, updating only regions whose source tiles changed.
	background_cursor = (background_cursor + 1) % VARIANTS
	var cache := banks[background_cursor]
	if cache == app.render_caches.region_cache:
		return
	cache.tick()
	if not cache.lighting_changes.is_empty():
		app.visual_environment.night_lighting.invalidate_regions(cache.lighting_changes)
	var view := background_cursor / 2
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
	if light_rescan.has(view):
		ground.prepare_entire_city = true
		ground.sync(app, 0.0, 0.0, true)
		ground.prepare_entire_city = false
		ground.bounds = Rect2i()
		light_rescan.erase(view)
	ground.sync(app, 0.0, 0.0, true)
	preparing_view = -1
	preparing_traffic = -1
	app.render_caches.region_cache = previous_cache
