extends SceneTree

const DocumentState = preload("res://tests/support/document_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for pair in [[0.1, 1.0], [0.25, 1.0], [1.0, 0.0], [2.0, 0.0], [4.0, 0.0]]:
		assert(is_equal_approx(CityVisualClouds.body_opacity(pair[0]), pair[1]))
	assert(CityVisualClouds.body_opacity(0.5) > 0.0 and CityVisualClouds.body_opacity(0.5) < 1.0)
	var point := Vector2(27, 43)
	for edge in [64, 128, 256, 512]:
		var viewed := point
		for rotation in 4:
			var source := Vector2(48 + edge * 16 + (viewed.x - viewed.y) * 16, 520 + (viewed.x + viewed.y) * 8)
			assert((CityVisualClouds.source_to_grid(edge, rotation) * source).is_equal_approx(point))
			viewed = Vector2(viewed.y, edge - 1 - viewed.x)
	var options := VisualEnhancementOptions.normalize({"cloud_density": 4.0, "cloud_speed": NAN, "cloud_shadow_strength": -0.5})
	assert(options.cloud_density == 1.0 and options.cloud_speed == 1.0 and options.cloud_shadow_strength == 0.0)
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	assert(main.city_session.activate_document(EmptyCityTemplate.create(128)))
	# This clock/camera check needs map bounds, not imported game artwork.
	main.map_view.city_source = CityMapSource.new(CityIsometricRenderer.output_size_for_view(IsometricConstants.VIEW_LARGE, 128))
	main.preferences.visual_enhancements = VisualEnhancementOptions.normalize({"day_enabled": false, "season_enabled": false, "weather_enabled": false, "pause_freezes": false})
	var before := DocumentState.capture(main.document_state.city.document)
	var engine := main.simulation_state.simulation_engine
	var rng_before := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
	main.map_view.zoom_factor = 0.25
	main.visual_environment.process(0.0)
	var clouds := main.visual_environment.clouds
	assert(clouds.parameters.cloud_enabled and clouds.layer.visible)
	var texture := clouds.field
	var initial := clouds.drift
	main.visual_environment.process(2.0)
	assert(clouds.drift != initial and clouds.field == texture)
	main.preferences.visual_enhancements.pause_freezes = true
	main.simulation_state.speed_controller.speed = GameSpeedController.Speed.PAUSED
	var paused := clouds.drift
	main.visual_environment.process(60.0)
	assert(clouds.drift == paused)
	main.preferences.visual_enhancements.pause_freezes = false
	for speed in [2, 3, 5]:
		main.simulation_state.speed_controller.speed = speed as GameSpeedController.Speed
		clouds.drift = Vector2.ZERO
		main.visual_environment.process(1.0)
		assert(clouds.drift.is_equal_approx(CityVisualClouds.WIND * VisualEnhancementOptions.speed_factor(speed)))
	main.map_view.zoom_factor = 1.0
	main.visual_environment.process(1.0)
	assert(not clouds.layer.visible and clouds.parameters.cloud_enabled)
	var hidden_drift: Vector2 = clouds.material.get_shader_parameter("cloud_drift")
	main.visual_environment.process(2.0)
	assert(clouds.material.get_shader_parameter("cloud_drift") == hidden_drift)
	main.map_view.zoom_factor = 0.25
	main.visual_environment.process(1.0)
	assert(clouds.layer.visible and clouds.material.get_shader_parameter("cloud_drift") == clouds.drift,
		"Clouds must catch up to their current position when shown again")
	var source_point := Vector2(1450, 880)
	var fixed_grid := CityVisualClouds.source_to_grid(128, main.document_state.city.compass_rotation()) * source_point
	for zoom in [0.1, 0.25, 0.5, 1.0, 2.0, 4.0]:
		main.map_view.zoom_factor = zoom
		main.map_view.source_center += Vector2(80, 40)
		main.visual_environment.process(0.0)
		var scale := main.map_view.camera._view_scale()
		var canvas_point := main.map_view.get_global_transform() * (main.map_view.camera._draw_offset(scale) + source_point * scale)
		var grid: Vector3 = clouds.parameters.cloud_canvas_to_grid * Vector3(canvas_point.x, canvas_point.y, 1)
		assert(Vector2(grid.x, grid.y).is_equal_approx(fixed_grid))
	main.view_state.overlay_mode = CityViewMode.Mode.HEIGHT
	main.visual_environment.process(1.0)
	assert(not clouds.parameters.cloud_enabled and not clouds.layer.visible)
	main.view_state.overlay_mode = CityViewMode.Mode.CITY
	main.preferences.visual_enhancements.cloud_enabled = false
	main.visual_environment.process(1.0)
	assert(not main.map_view.layers.environment_parameters.cloud_enabled)
	assert(DocumentState.capture(main.document_state.city.document) == before)
	assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == rng_before)
	main.queue_free()
	await process_frame
	print("PASS: cloud zoom variants, canonical rotation, camera anchoring, pause/speed, disable and unchanged city/RNG")
	quit()
