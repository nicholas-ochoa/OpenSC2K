class_name ApplicationStaticRender
extends RefCounted


@warning_ignore_start("integer_division")

const CityModel = preload("res://src/model/city_state.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const RenderJob = preload("res://src/view/city_render_job.gd")
const UndergroundView = preload("res://src/view/city_underground_view.gd")
const ViewFilter = preload("res://src/view/city_view_filter.gd")
const SettingsStore = preload("res://src/ui/settings/app_settings_store.gd")
const ACTIVE_DISASTER_RENDER_INTERVAL_MSEC := 1200
const STATIC_EDIT_PATCH_MAX_AREA_RATIO := 0.25

var app: CityApplication
var caches: RenderCaches
var state: StaticRenderState
var palette_clock: PaletteAnimationClock


func _init(application: CityApplication) -> void:
	app = application
	caches = application.render_caches
	state = application.static_render_state
	palette_clock = application.palette_clock


func refresh_after_city_edit(command: EditCommandResult) -> void:
	app.assets.refresh_scurk_artwork()

	if command.command_type == "scurk_artwork":
		return

	if not _apply_static_edit_patch(command):
		app.map_render.refresh_map(false)


func _apply_static_edit_patch(command: EditCommandResult) -> bool:
	if caches.region_cache != null:
		var region_start := Time.get_ticks_usec()
		var indices := _edit_dirty_indices(command, app.document_state.city.map_size)
		app.timing_state.edit_display_timings = {
			"dirty_ms": (Time.get_ticks_usec() - region_start) / 1000.0,
			"dirty_tiles": indices.size(),
		}

		if indices.is_empty():
			return false

		region_start = Time.get_ticks_usec()
		var dirty := IsometricRenderer.dirty_screen_rect(indices, sprite_archive_for_view(city_view_size()), city_view_size(), Vector2i.ZERO,
				app.document_state.city.map_size)
		app.map_render.refresh_region_map(false, dirty)
		app.timing_state.edit_display_timings.region_ms = (Time.get_ticks_usec() - region_start) / 1000.0

		return true

	var map_edge: int = app.document_state.city.map_size if app.document_state.city != null else 128

	if (
		app.view_state.overlay_mode != CityViewMode.Mode.CITY
		or app.document_state.city == null
		or app.asset_state.palette_index_encoding == null
		or caches.static_city_image == null
		or caches.static_city_image.is_empty()
		or caches.static_render_mode != CityViewMode.Mode.CITY
		or caches.static_display_city == null
		or state.task != null
	):
		return false

	var profile_start := Time.get_ticks_usec()
	var dirty_indices := _edit_dirty_indices(command, map_edge)

	if dirty_indices.is_empty():
		return false

	var view_size := city_view_size()
	var sprite_archive := sprite_archive_for_view(view_size)
	var dirty_rect := IsometricRenderer.dirty_screen_rect(
		dirty_indices, sprite_archive, view_size, Vector2i.ZERO, map_edge
	)
	var full_area := IsometricRenderer.output_size_for_view(view_size, map_edge).x * (
		IsometricRenderer.output_size_for_view(view_size, map_edge).y
	)

	if (
		dirty_rect.get_area() <= 0
		or float(dirty_rect.get_area()) / float(full_area)
			> STATIC_EDIT_PATCH_MAX_AREA_RATIO
	):
		return false

	app.timing_state.edit_display_timings = {"dirty_ms": (Time.get_ticks_usec() - profile_start) / 1000.0}
	profile_start = Time.get_ticks_usec()
	var display_city := ViewFilter.surface_copy(app.document_state.city, app.view_state.surface_visibility)

	if display_city == null or not display_city.is_valid():
		return false

	app.timing_state.edit_display_timings.copy_ms = (Time.get_ticks_usec() - profile_start) / 1000.0
	profile_start = Time.get_ticks_usec()
	var patched := IsometricRenderer.patch_static_image(
		caches.static_city_image,
		display_city,
		app.asset_state.palette_index_encoding,
		sprite_archive,
		dirty_indices,
		view_size,
		int(Time.get_ticks_msec() / 100),
		false
	)

	if not patched.ok:
		return false

	app.timing_state.edit_display_timings.patch_ms = (Time.get_ticks_usec() - profile_start) / 1000.0
	profile_start = Time.get_ticks_usec()
	state.epoch += 1
	caches.static_city_image = patched.image
	caches.static_display_city = display_city
	caches.static_visual_signature = static_signature_for_mode(CityViewMode.Mode.CITY, view_size)
	caches.static_render_mode = CityViewMode.Mode.CITY
	state.pending = false
	app.moving_sprites.set_static_occlusion_commands(
		IsometricRenderer.patch_static_occlusion_commands(
			caches.static_occlusion_commands,
			display_city,
			sprite_archive,
			dirty_indices,
			view_size
		),
		view_size
	)
	caches.static_view_cache[CityViewMode.Mode.CITY] = RenderCaches.StaticView.new(
		caches.static_city_image, caches.static_occlusion_commands, caches.static_visual_signature,
		caches.static_display_city, view_size
	)
	app.timing_state.edit_display_timings.occlusion_ms = (Time.get_ticks_usec() - profile_start) / 1000.0
	profile_start = Time.get_ticks_usec()
	var source := CityMapTexture.update_region(app.map_view.city_source, caches.static_city_image, patched.output_rect)
	app.map_view.set_city_view(caches.static_display_city, source, null, true)
	app.menus.sync_map_style()
	app.moving_sprites.refresh_moving_things(view_size)
	app.timing_state.edit_display_timings.upload_ms = (Time.get_ticks_usec() - profile_start) / 1000.0

	return true


static func _collect_changed_tiles(before: PackedByteArray, after: PackedByteArray, stride: int, dirty: PackedByteArray,
		indices: PackedInt32Array, plane_cells := 0) -> void:
	# native word comparisons skip unchanged runs without allocating. only
	# changed words need per-tile gdscript work, including remote power/water
	# changes after edits
	if before == after:
		return

	# chunk strides are one or two bytes per tile, so a shift replaces the
	# per-byte division that maps a byte offset back to a tile
	var tile_shift := 1 if stride == 2 else 0
	var size := mini(before.size(), after.size())
	var full_bytes := size - size % 8

	for offset in range(0, full_bytes, 8):
		if before.decode_u64(offset) == after.decode_u64(offset):
			continue

		for byte_offset in range(offset, offset + 8):
			if before[byte_offset] == after[byte_offset]:
				continue

			var index := byte_offset >> tile_shift

			if plane_cells > 0:
				index %= plane_cells

			if dirty[index] == 0:
				dirty[index] = 1
				indices.append(index)

	for byte_offset in range(full_bytes, size):
		if before[byte_offset] == after[byte_offset]:
			continue

		var index := byte_offset >> tile_shift

		if plane_cells > 0:
			index %= plane_cells

		if dirty[index] == 0:
			dirty[index] = 1
			indices.append(index)


static func _mark_dirty_tile(index: int, dirty: PackedByteArray, indices: PackedInt32Array) -> void:
	if index < 0 or index >= dirty.size() or dirty[index] != 0:
		return

	dirty[index] = 1
	indices.append(index)


static func _edit_dirty_indices(command: EditCommandResult, map_edge: int = 128) -> PackedInt32Array:
	# a flag byte per tile deduplicates without a dictionary, and the collected
	# indices sort natively instead of as variants
	var cells := map_edge * map_edge
	var dirty := PackedByteArray()
	dirty.resize(cells)
	var indices := PackedInt32Array()
	var old_payloads := command.old_payloads
	var new_payloads := command.new_payloads

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XBIT", "XTXT"]:
		if not old_payloads.has(chunk_id) or not new_payloads.has(chunk_id):
			continue

		var old_bytes: PackedByteArray = old_payloads[chunk_id]
		var new_bytes: PackedByteArray = new_payloads[chunk_id]
		var stride := 2 if chunk_id == "ALTM" or (chunk_id == "XTXT" and map_edge > 128) else 1

		if old_bytes.size() != cells * stride or new_bytes.size() != old_bytes.size():
			continue

		_collect_changed_tiles(old_bytes, new_bytes, 1 if chunk_id == "XTXT" else stride,
			dirty, indices, cells if chunk_id == "XTXT" else 0)

	# dispatch compares its whole text overlay instead of xtxt payloads
	if command is DispatchEditResult:
		var dispatch := command as DispatchEditResult

		if OverlayData.count(dispatch.old_text) == cells and OverlayData.count(dispatch.new_text) == cells:
			_collect_changed_tiles(dispatch.old_text, dispatch.new_text, 1, dirty, indices, cells)

		if dispatch.target.x >= 0 and dispatch.target.x < map_edge and dispatch.target.y >= 0 and dispatch.target.y < map_edge:
			_mark_dirty_tile(dispatch.target.x * map_edge + dispatch.target.y, dirty, indices)

	for index in command.tile_indices:
		_mark_dirty_tile(index, dirty, indices)

	for point in command.points:
		if point.x >= 0 and point.x < map_edge and point.y >= 0 and point.y < map_edge:
			_mark_dirty_tile(point.x * map_edge + point.y, dirty, indices)

	if command is SignEditResult:
		var placed := command as SignEditResult

		if placed.point.x >= 0 and placed.point.x < map_edge and placed.point.y >= 0 and placed.point.y < map_edge:
			_mark_dirty_tile(placed.point.x * map_edge + placed.point.y, dirty, indices)

		_mark_dirty_tile(placed.tile_index, dirty, indices)

	if command.site.has_area():
		var site := command.site

		for x in range(site.position.x, site.end.x):
			for y in range(site.position.y, site.end.y):
				if x >= 0 and x < map_edge and y >= 0 and y < map_edge:
					_mark_dirty_tile(x * map_edge + y, dirty, indices)

	indices.sort()

	return indices


func request_static_render(
	signature: Array, view_size: int, sprite_archive: Sc2SpriteArchive, render_mode := CityViewMode.Mode.CITY
) -> void:
	if state.task != null:
		return

	var now_msec := Time.get_ticks_msec()

	if (
		app.simulation_state.simulation_engine != null
		and app.simulation_state.simulation_engine.active_disaster_type != 0
		and now_msec - state.last_started_msec
			< ACTIVE_DISASTER_RENDER_INTERVAL_MSEC
	):
		state.pending = true

		return

	state.pending = false
	var snapshot_document := app.document_state.current_document.duplicate_document(true)
	var snapshot := CityModel.from_document(snapshot_document)

	if not snapshot.is_valid():
		app.interface.show_error("Cannot prepare the city for drawing: %s" % snapshot.load_error)

		return

	snapshot.visible_altitude_levels = app.document_state.city.visible_altitude_levels
	state.job = RenderJob.new()
	state.job.city_snapshot = snapshot
	state.job.index_palette = app.asset_state.palette_index_encoding
	state.job.sprites = sprite_archive
	state.job.view_size = view_size
	state.job.animation_phase = int(Time.get_ticks_msec() / 100)
	state.job.signature = signature.duplicate()
	state.job.epoch = state.epoch
	state.job.render_mode = render_mode
	state.job.surface_visibility = app.view_state.surface_visibility.duplicate()
	state.job.show_underground_subways = app.view_state.show_underground_subways
	state.job.show_underground_water_mains = app.view_state.show_underground_water_mains
	state.job.show_underground_pipes = app.view_state.show_underground_pipes
	state.task = CityRenderTask.new()
	var start_error := state.task.start(
		state.job.run
	)

	if start_error != OK:
		state.task = null
		state.job = null
		app.interface.show_error("Cannot start the city renderer: %s" % error_string(start_error))
	else:
		state.last_started_msec = now_msec


func start_pending_static_render() -> void:
	if (
		not state.pending
		or state.task != null
		or app.document_state.city == null
		or not CityViewMode.is_map(app.view_state.overlay_mode)
	):
		return

	var view_size := city_view_size()
	request_static_render(
		static_signature_for_mode(app.view_state.overlay_mode, view_size),
		view_size,
		sprite_archive_for_view(view_size),
		app.view_state.overlay_mode,
	)


func poll_static_render() -> void:
	app.map_render.poll_region_cache()

	if state.task == null or state.task.is_running():
		return

	var rendered: CityRenderJob.Result = state.task.finish()
	state.task = null
	state.job = null

	if not rendered.ok:
		app.interface.show_error(rendered.error)

		return

	if (
		app.document_state.city == null
		or int(rendered.epoch) != state.epoch
		or int(rendered.view_size) != city_view_size()
		or rendered.render_mode != app.view_state.overlay_mode
	):
		if app.document_state.city != null and CityViewMode.is_map(app.view_state.overlay_mode):
			app.map_render.refresh_map(false)

		return

	caches.static_city_image = rendered.index_image
	app.moving_sprites.set_static_occlusion_commands(rendered.occlusion_commands, int(rendered.view_size))
	caches.static_visual_signature = rendered.signature
	caches.static_render_mode = int(rendered.render_mode) as CityViewMode.Mode
	caches.static_display_city = rendered.display_city
	caches.static_view_cache[caches.static_render_mode] = RenderCaches.StaticView.new(
		caches.static_city_image, caches.static_occlusion_commands, caches.static_visual_signature,
		caches.static_display_city, int(rendered.view_size)
	)
	var source := CityMapTexture.create(caches.static_city_image)
	app.map_view.set_city_view(
		caches.static_display_city, source, null, true
	)
	app.menus.sync_map_style()

	if app.view_state.overlay_mode == CityViewMode.Mode.CITY:
		app.moving_sprites.refresh_moving_things(int(rendered.view_size))
	else:
		caches.dynamic_sign_occluders.clear()
		caches.dynamic_sign_occlusion_grid.clear()
		app.map_view.set_dynamic_sprites([])
		app.map_render.refresh_sign_occlusion(int(rendered.view_size))

	var latest_signature := static_signature_for_mode(
		app.view_state.overlay_mode, int(rendered.view_size)
	)

	if latest_signature != caches.static_visual_signature:
		request_static_render(
			latest_signature,
			int(rendered.view_size),
			sprite_archive_for_view(int(rendered.view_size)),
			app.view_state.overlay_mode,
		)


func static_signature_for_mode(mode: CityViewMode.Mode, view_size: int) -> Array:
	if mode == CityViewMode.Mode.UNDERGROUND:
		return UndergroundView.visual_signature(
			app.document_state.city, view_size, app.view_state.show_underground_pipes, app.view_state.show_underground_subways,
					app.view_state.show_underground_water_mains
		)

	var result := IsometricRenderer.static_visual_signature(app.document_state.city, view_size)
	result.append_array([
		bool(app.view_state.surface_visibility.buildings),
		bool(app.view_state.surface_visibility.networks),
		bool(app.view_state.surface_visibility.water),
		bool(app.view_state.surface_visibility.trees),
		bool(app.view_state.surface_visibility.zones),
	])

	return result


func update_palette_cycle_texture() -> void:
	if app.asset_state.palette == null or not app.asset_state.palette.is_valid():
		return

	palette_clock.toolbar_palette = Sc2Palette.new()

	for color_index in app.asset_state.palette.animation_index_map(palette_clock.cycle_ticks):
		palette_clock.toolbar_palette.colors.append(app.asset_state.palette.colors[color_index])

	app.camera_input.refresh_child_tool_icons()
	var image := app.asset_state.palette.animation_image(palette_clock.cycle_ticks)

	if palette_clock.cycle_texture == null:
		palette_clock.cycle_texture = ImageTexture.create_from_image(image)
	else:
		palette_clock.cycle_texture.update(image)

	var underground_image := app.asset_state.palette.underground_animation_image(palette_clock.cycle_ticks)

	if palette_clock.underground_cycle_texture == null:
		palette_clock.underground_cycle_texture = ImageTexture.create_from_image(underground_image)
	else:
		palette_clock.underground_cycle_texture.update(underground_image)

	if app.map_view != null:
		app.map_view.set_animated_palette(palette_clock.cycle_texture)
		app.map_view.set_dark_underground_palette(palette_clock.underground_cycle_texture)


func _city_graphics_size() -> int:
	return SettingsStore.graphics_size_at_zoom(app.preferences.zoom_graphics, app.map_view.zoom_percent(), app.preferences.overview_graphics)


func city_view_size() -> int:
	return mini(_city_graphics_size(), IsometricRenderer.VIEW_LARGE)


func sprite_archive_for_view(view_size: int) -> Sc2SpriteArchive:
	return app.asset_state.small_medium_sprites if view_size < IsometricRenderer.VIEW_LARGE else app.asset_state.large_sprites


# waits for the running static render and discards its job
func stop_render_job() -> void:
	if state.task != null:
		state.task.finish()

	state.task = null
	state.job = null


# stops the static render and forgets cached views so the next refresh renders again
func restart_static_render() -> void:
	stop_render_job()
	state.pending = false
	caches.static_view_cache.clear()


# discards every rendered image of the city after an artwork or document change
func invalidate_rendered_city() -> void:
	app.map_render.close_region_cache()
	state.epoch += 1
	caches.static_city_image = null
	caches.static_occlusion_commands.clear()
	caches.static_occlusion_grid.clear()
	caches.static_visual_signature = []
	caches.static_render_mode = CityViewMode.Mode.NONE
	caches.static_display_city = null
	caches.static_view_cache.clear()
	state.pending = false
	clear_dynamic_composition_cache()
	caches.dynamic_sign_occluders.clear()
	caches.dynamic_sign_occlusion_grid.clear()


# discards static views after a layer visibility change. sprite caches remain valid
func invalidate_view_render() -> void:
	state.epoch += 1
	caches.static_visual_signature.clear()
	caches.static_render_mode = CityViewMode.Mode.NONE
	caches.static_view_cache.clear()
	caches.static_occlusion_commands.clear()
	caches.static_occlusion_grid.clear()
	caches.dynamic_occluder_cache.clear()
	caches.dynamic_sign_occluders.clear()
	caches.dynamic_sign_occlusion_grid.clear()


func clear_dynamic_composition_cache() -> void:
	caches.dynamic_sprite_cache.clear()
	caches.dynamic_foreground_cache.clear()
	caches.dynamic_occluder_cache.clear()
	caches.dynamic_visual_cache.clear()
	caches.dynamic_special_batch_cache.clear()
	caches.sign_foreground_cache.clear()
