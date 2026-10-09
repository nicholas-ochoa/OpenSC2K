extends "res://tests/support/scene_test_case.gd"

const DocumentState = preload("res://tests/support/document_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	assert(main.city_session.activate_document(EmptyCityTemplate.create(128)))
	var city := main.document_state.city
	city.document.set_misc_u32(Sc2MiscLayout.WATER_LEVEL, 1)
	var peak := Vector2i(64, 64)
	city.set_land_altitude(peak.x, peak.y, 8)
	city.set_water_altitude(96, 96, 8)
	city.set_terrain_id(96, 96, 16)
	city.set_land_altitude(80, 32, 3)
	city.set_terrain_id(80, 32, 2) # Raised top and right corners.
	main.map_view.city_source = CityMapSource.new(CityIsometricRenderer.output_size_for_view(IsometricConstants.VIEW_LARGE, 128))
	var fog := CityVisualFog.new(main)
	fog.process(0.0, true, 0.2, Color.WHITE)
	var texture := fog.altitude_texture
	var uploads := fog.height_updates
	fog.process(1.0, true, 0.1, Color(0.5, 0.5, 0.7))
	assert(fog.height_updates == uploads and fog.altitude_texture == texture, "Drift, density and light rebuilt the terrain mask")
	main.map_view.source_center += Vector2(60, 40)
	fog.process(0.0, true, 0.2, Color.WHITE)
	assert(fog.height_updates == uploads + 1 and fog.altitude_texture == texture, "Camera pan failed to refresh only the projected mask")
	main.map_view.zoom_factor = 0.25
	fog.process(0.0, true, 0.2, Color.WHITE)
	assert(fog.height_updates == uploads + 2 and fog.altitude_texture == texture)
	assert(maxi(fog.height_viewport.size.x, fog.height_viewport.size.y) <= 768)
	await RenderingServer.frame_post_draw
	assert(fog.height_viewport.render_target_update_mode in [SubViewport.UPDATE_ONCE, SubViewport.UPDATE_DISABLED], "Height pass requested continuous rendering")

	# Independently center the mask on real, altitude-lifted tile surfaces.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rect := ColorRect.new()
	rect.size = Vector2(viewport.size)
	var material := ShaderMaterial.new()
	material.shader = CityVisualFog.HEIGHT_SHADER
	material.set_shader_parameter("fog_altitudes", fog.altitude_texture)
	material.set_shader_parameter("fog_terrain", fog.terrain_texture)
	material.set_shader_parameter("fog_ceiling", 3.5)
	rect.material = material
	viewport.add_child(rect)
	var before := DocumentState.capture(city.document)
	var engine := main.simulation_state.simulation_engine
	var rng := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
	assert(await _sample(viewport, material, Vector2(32, 32), 0.0) > 0.98, "Lowland lost fog")
	assert(await _sample(viewport, material, Vector2(peak), 8.0) < 0.02, "Fog covers the projected mountain summit")
	assert(await _sample(viewport, material, Vector2(96, 96), 8.0) < 0.02, "Fog used the lake bed instead of the water surface")
	var upper := await _sample(viewport, material, Vector2(80, 31.7), 3.8)
	var lower := await _sample(viewport, material, Vector2(80, 32.3), 3.2)
	assert(upper < lower - 0.15 and upper > 0.0 and lower < 1.0, "Slopes lack a smooth height fade")
	assert(await _sample(viewport, material, Vector2(-40, -40), 0.0) < 0.02, "Fog escaped the actual terrain outline")
	assert(DocumentState.capture(city.document) == before)
	assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == rng)

	for turn in 4:
		assert(CityRotationCommand.apply(city, true).ok)
		peak = CityRotationCommand.rotate_point(peak, 128, true)
		fog._sync_terrain(city)
		assert(await _sample(viewport, material, Vector2(peak), 8.0) < 0.02, "Mountain fog mask drifted after rotation")
	city.set_land_altitude(peak.x, peak.y, 0)
	fog.process(0.0, true, 0.2, Color.WHITE)
	assert(fog.altitude_texture == texture, "Terrain edits discarded the resident texture")
	assert(await _sample(viewport, material, Vector2(peak), 0.0) > 0.98, "Terrain edit left a stale mountain mask")
	fog.process(0.0, false, 0.2, Color.WHITE)
	assert(not fog.layer.visible)
	viewport.queue_free()
	main.queue_free()
	await process_frame
	print("PASS: fog height GPU pixels, slopes, water, rotation, resident cache, camera invalidation and read-only rendering")
	quit()


func _sample(viewport: SubViewport, material: ShaderMaterial, tile: Vector2, altitude: float) -> float:
	var source := Vector2(48 + 128 * 16 + (tile.x - tile.y) * 16, 520 + (tile.x + tile.y) * 8 - altitude * 12)
	var transform := CityVisualClouds.source_to_grid(128, 0) * Transform2D(0.0, source - Vector2(64.5, 64.5))
	material.set_shader_parameter("fog_mask_to_tiles", CityVisualClouds.shader_basis(transform))
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image().get_pixel(64, 64).r
