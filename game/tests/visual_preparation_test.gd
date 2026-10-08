extends SceneTree

const DocumentState = preload("res://tests/support/document_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	main.preferences.visual_enhancements = VisualEnhancementOptions.normalize({"day_mode": 1, "day_hour": 0.0})
	main.visual_environment.configure()
	var city := main.document_state.city
	var before := DocumentState.capture(city.document)
	var engine := main.simulation_state.simulation_engine
	var random_before := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
	var prepare := main.visual_preparation
	assert(prepare.process())
	assert(prepare.busy and main.frame._simulation_suspended())
	assert(not main.camera_input.camera_keys_allowed())
	var progress := 0.0
	var started := Time.get_ticks_msec()
	while not prepare.ready:
		main.frame.process(0.016)
		assert(prepare.failure.is_empty())
		var value := main.city_dialogs.visual_preparation_progress.bar.value
		assert(value >= progress, "Preparation progress moved backwards")
		progress = value
		assert(Time.get_ticks_msec() - started < 60000, "City preparation did not finish")
		await process_frame
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
	for cache in prepare.banks:
		assert(cache.prefetch_ready())
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
	# Traffic repaints must not rediscover every road in each prepared variant.
	# The first update may align a hidden receiver's viewport after the zooms.
	for density in [0, 255]:
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
	# Teardown cancels in-flight workers; a replacement document cannot inherit banks.
	var old_banks := prepare.banks.duplicate()
	assert(main.city_session.activate_document(EmptyCityTemplate.create(128)))
	assert(prepare.banks.is_empty())
	for cache in old_banks:
		assert(cache.entries.is_empty() and cache.gpu_workers.is_empty())
	prepare.process()
	prepare.process()
	prepare.reset()
	assert(not prepare.busy and prepare.preparing_view == -1 and prepare.archives.is_empty())
	main.queue_free()
	await process_frame
	print("PASS: full-city visual preparation, all zoom variants, cloud order, local edits, pause and cancellation")
	quit()


func _settle(main: CityApplication) -> void:
	var started := Time.get_ticks_msec()
	while true:
		main.frame.process(0.016)
		var complete := main.visual_preparation.light_rescan.is_empty()
		for cache in main.visual_preparation.banks:
			complete = complete and cache.prefetch_ready()
		for ground in main.visual_environment.night_lighting.ground_views.values():
			complete = complete and ground.pending.is_empty()
		if complete:
			return
		assert(Time.get_ticks_msec() - started < 60000, "Hidden variants did not receive a city edit")
		await process_frame
