extends SceneTree

const DocumentState = preload("res://tests/support/document_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Exercise the production GPU region banks even under a headless test host.
	OS.set_environment("OPENSC2K_CITY_RENDERER", "gpu")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	OS.set_environment("OPENSC2K_DATA_PACK", ProjectSettings.globalize_path("res://../ext/data"))
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "folder")
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	var fixture := load("res://tests/city_life_test.gd").fixture() as CityState
	for y in range(12, 20):
		fixture.set_building_id(12, y, BuildingTileIds.ROAD_STRAIGHT_1)
	assert(main.city_session.activate_document(fixture.document))
	main.preferences.visual_enhancements = VisualEnhancementOptions.normalize({"day_mode": 1, "day_hour": 0.0, "detail_lights_min_zoom": 0})
	main.visual_environment.configure()
	var city := main.document_state.city
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	var before := DocumentState.capture(city.document)
	var engine := main.simulation_state.simulation_engine
	var random_before := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
	var prepare := main.visual_preparation
	main.preferences.zoom_graphics = [0, 1, 2, 2, 2, 2]
	assert(prepare.required_variants() == [0, 3, 5], "Preload only the variants reachable at configured zooms")
	main.preferences.zoom_graphics = [1, 2, 2, 2, 2, 2]
	assert(prepare.required_variants() == [0, 2, 5])
	main.preferences.visual_enhancements.life_cars_enabled = false
	assert(prepare.required_variants() == [0, 2, 4])
	main.preferences.visual_enhancements.life_cars_enabled = true
	assert(not prepare.process())
	assert(prepare.busy and not main.frame._simulation_suspended())
	assert(main.city_dialogs.visual_preparation_progress.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	for window_size in [Vector2i(1280, 800), Vector2i(1024, 720)]:
		root.size = window_size
		await process_frame
		await process_frame
		var panel := main.city_dialogs.visual_preparation_progress.get_node("Center/Panel") as Control
		assert(panel.get_global_rect().end.y <= main.city_status_bar.get_global_rect().position.y,
			"Background progress covers the status bar")
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	var edited_during_load := false
	var continuous_repaints := 0
	var progress := 0.0
	var started := Time.get_ticks_msec()
	while not prepare.ready:
		if prepare.stage == 0 and prepare.banks[0].covered():
			# Keep publishing traffic generations while lights are prepared.
			# Waiting for every region to match the latest generation starves this.
			continuous_repaints += 1
			var repaint := city.document.find_chunk("XTRF")
			var repaint_payload := repaint.decoded_payload.duplicate()
			repaint_payload.fill(255 if continuous_repaints % 2 else 0)
			assert(repaint.set_decoded_payload(repaint_payload, true))
			before = DocumentState.capture(city.document)
			main.map_render.refresh_map(false)
		if prepare.stage > 0 and not edited_during_load:
			edited_during_load = true
			city.set_building_id(12, 17, BuildingTileIds.EMPTY)
			before = DocumentState.capture(city.document)
			var retained := prepare.banks[0]
			for zoom in [0.25, 0.5]:
				main.map_view.zoom_factor = zoom
				main.camera_input.on_city_zoom_changed(roundi(zoom * 100))
			main.map_render.refresh_map(false)
			assert(prepare.busy and prepare.banks[0] == retained, "Zoom restarted background preparation")
		main.frame.process(0.016)
		assert(prepare.preparing_view == -1 and prepare.preparing_traffic == -1, "Background context leaked into the visible renderer")
		assert(prepare.failure.is_empty())
		var value := main.city_dialogs.visual_preparation_progress.bar.value
		assert(value >= progress, "Preparation progress moved backwards")
		progress = value
		assert(Time.get_ticks_msec() - started < 60000, "City preparation did not finish")
		await process_frame
	assert(edited_during_load and continuous_repaints > 0)
	for archive in prepare.archives:
		assert(archive.visual_nature_enabled and archive.visual_terrain_enabled, "Prepared view dropped nature options")
		assert(not archive.visual_nature.is_empty(), "Prepared view dropped nature artwork")
		assert(not archive.visual_nature_masks.is_empty(), "Prepared view dropped nature masks")
	await _settle(main)
	assert(not prepare.busy and not main.city_dialogs.visual_preparation_progress.visible)
	assert(DocumentState.capture(city.document) == before, "Precache advanced or edited the city")
	assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == random_before)
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	var lights := main.visual_environment.night_lighting
	var snapshots := {}
	for view in 3:
		var ground := lights.ground_views[view]
		assert(ground.cache.has(Vector2i(12, 16)), "Offscreen streets were not prepared")
		assert(ground.cache.has(Vector2i(64, 64)))
		snapshots[view] = ground.cache.duplicate()
	for index in prepare.banks.size():
		var cache := prepare.banks[index]
		assert(index not in prepare.stages or cache.prefetch_ready())
		if index not in prepare.stages:
			assert(cache.entries.is_empty(), "Unused traffic variant was prepared twice")
	main.preferences.zoom_graphics = [1, 2, 2, 2, 2, 2]
	for zoom in [0.25, 0.1, 0.5, 0.25]:
		main.map_view.zoom_factor = zoom
		main.camera_input.on_city_zoom_changed(roundi(zoom * 100))
		main.map_view.center_on_tile(Vector2i(12, 16))
		main.frame.process(0.016)
		var view := main.static_render.city_view_size()
		assert(main.render_caches.region_cache.ready(), "Zoom exposed a cold region")
		assert(lights.ground.pending.is_empty(), "A camera-only change scheduled light work")
		for tile in snapshots[view]:
			assert(is_same(snapshots[view][tile], lights.ground.cache[tile]), "Zoom rebuilt prepared lights")
		assert(main.visual_environment.clouds.layer != null)
		assert(lights.ground.get_index() < main.visual_environment.clouds.layer.get_index())
		assert(lights.output.get_index() < main.visual_environment.clouds.layer.get_index())
	# Finish camera alignment in hidden variants before isolating traffic work.
	for view in 3:
		prepare.light_rescan[view] = true
	await _settle(main)
	# Traffic repaints must not rediscover every road in each prepared variant.
	# The first update may align a hidden receiver's viewport after the zooms.
	for density in [64, 255]:
		var collections := []
		for view in 3:
			collections.append(lights.ground_views[view].collection)
		var traffic := city.document.find_chunk("XTRF")
		var payload := traffic.decoded_payload.duplicate()
		payload.fill(density)
		assert(traffic.set_decoded_payload(payload, true))
		main.map_render.refresh_map(false)
		await _settle(main)
		if density == 255:
			for view in 3:
				assert(lights.ground_views[view].collection == collections[view], "Traffic triggered a road discovery scan")
	# An edit outside the current camera must reach every retained variant.
	var before_building := city.building_id(64, 64)
	city.set_building_id(64, 64, BuildingTileIds.EMPTY)
	var added := Vector2i(100, 100)
	for view in 3:
		assert(not lights.ground_views[view].cache.has(added))
	city.set_building_id(added.x, added.y, BuildingTileIds.ROAD_CROSSROADS)
	assert(prepare.banks[0].source_payloads["XBLD"][64 * 128 + 64] == before_building, "Native edit mutated the cached before-image")
	main.map_render.refresh_map(false)
	await _settle(main)
	for view in 3:
		var ground := lights.ground_views[view]
		assert(ground.cache[Vector2i(64, 64)].texture.get_image().is_invisible(), "Removed street retained its light")
		assert(ground.cache.has(added) and not ground.cache[added].texture.get_image().is_invisible(), "New offscreen street was not prepared")
		assert(is_same(snapshots[view][Vector2i(12, 16)], ground.cache[Vector2i(12, 16)]), "Local edit rebuilt a distant light")
	var old_layout := prepare._layout()
	main.asset_state.large_sprites.visual_nature_enabled = false
	assert(prepare._layout() != old_layout, "Nature switch retained stale prepared views")
	main.asset_state.large_sprites.visual_nature_enabled = true
	# A layout change after completion must attach a live renderer immediately.
	main.view_state.surface_visibility.trees = not main.view_state.surface_visibility.trees
	prepare.process()
	assert(prepare.busy and not main.frame._simulation_suspended())
	assert(main.render_caches.region_cache != null or main.static_render_state.pending
		or main.static_render_state.task != null or main.render_caches.static_city_image != null)
	# Teardown cancels in-flight workers; a replacement document cannot inherit banks.
	var old_banks := prepare.banks.duplicate()
	assert(main.city_session.activate_document(EmptyCityTemplate.create(128)))
	assert(prepare.banks.is_empty())
	for cache in old_banks:
		assert(cache.entries.is_empty() and cache.gpu_workers.is_empty())
	prepare.process()
	main.frame.select_speed(GameSpeedController.Speed.CHEETAH)
	var ticks := main.palette_clock.cycle_ticks
	main.frame.process(0.25)
	assert(prepare.busy and not main.frame._simulation_suspended())
	assert(main.palette_clock.cycle_ticks > ticks, "Background preload froze the game frame")
	prepare.reset()
	assert(not prepare.busy and prepare.preparing_view == -1 and prepare.archives.is_empty())
	main.queue_free()
	await process_frame
	print("PASS: full-city visual preparation, all zoom variants, cloud order, edits and zoom during background loading, playable frames and cancellation")
	quit()


func _settle(main: CityApplication) -> void:
	var started := Time.get_ticks_msec()
	while true:
		main.frame.process(0.016)
		var complete := main.visual_preparation.light_rescan.is_empty()
		for index in main.visual_preparation.stages:
			complete = complete and main.visual_preparation.banks[index].prefetch_ready()
		for ground in main.visual_environment.night_lighting.ground_views.values():
			complete = complete and ground.pending.is_empty()
		if complete:
			return
		assert(Time.get_ticks_msec() - started < 60000, "Hidden variants did not receive a city edit")
		await process_frame
