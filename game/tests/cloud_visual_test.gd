extends SceneTree

const DocumentState = preload("res://tests/support/document_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_situations()
	var sunny := CityVisualClouds.weather_density(0.4, CityVisualWeather.Kind.SUNNY, 1, 0.0)
	var overcast := CityVisualClouds.weather_density(0.4, CityVisualWeather.Kind.SUNNY, 5, 0.0)
	var storm := CityVisualClouds.weather_density(0.4, CityVisualWeather.Kind.RAIN_STORM, -1, 0.0)
	assert(sunny < overcast and overcast < storm, "Cloud coverage must follow the actual weather")
	assert(not is_equal_approx(sunny, CityVisualClouds.weather_density(0.4, CityVisualWeather.Kind.SUNNY, 1, 75.0)))
	assert(is_equal_approx(sunny, CityVisualClouds.weather_density(0.4, CityVisualWeather.Kind.SUNNY, 1, 900.0)))
	assert(CityVisualClouds.weather_density(0.0, CityVisualWeather.Kind.RAIN_STORM, -1, 75.0) >= 0.58)
	assert(CityVisualClouds.weather_fog(CityVisualWeather.Kind.SUNNY, 3, 0.0) > 0.15)
	assert(CityVisualClouds.weather_fog(CityVisualWeather.Kind.SUNNY, 1, 0.0) == 0.0)
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
	main.preferences.visual_enhancements.weather_enabled = true
	main.preferences.visual_enhancements.weather_mode = 2
	main.preferences.visual_enhancements.weather_fixed = CityVisualWeather.Kind.HEAVY_RAIN
	var before_front := clouds.density
	main.visual_environment.process(1.0)
	assert(absf(clouds.density - before_front) <= 0.081, "An explicit weather preview jumped the cloud coverage")
	assert(clouds.parameters.cloud_formation > 0.0 and clouds.fog > 0.0)
	for _frame in 20:
		main.visual_environment.process(1.0)
	main.preferences.visual_enhancements.pause_freezes = true
	main.simulation_state.speed_controller.speed = GameSpeedController.Speed.PAUSED
	var frozen := [clouds.density, clouds.fog, clouds.weather_clock]
	main.visual_environment.process(60.0)
	assert([clouds.density, clouds.fog, clouds.weather_clock] == frozen, "Paused weather coverage or mist moved")
	main.preferences.visual_enhancements.cloud_enabled = false
	main.visual_environment.process(0.0)
	assert(not clouds.parameters.cloud_enabled and clouds.parameters.cloud_fog_density == 0.0,
		"The cloud master must also disable ground fog, including while paused")
	assert(clouds.fog_overlay.layer == null or not clouds.fog_overlay.layer.visible)
	main.preferences.visual_enhancements.cloud_enabled = true
	main.preferences.visual_enhancements.weather_enabled = false
	main.preferences.visual_enhancements.cloud_mode = 6
	clouds.reset()
	main.visual_environment.process(0.0)
	assert(clouds.fog > 0.0 and clouds.fog_overlay.layer.visible, "Fog must be a cloud situation")
	main.preferences.visual_enhancements.weather_enabled = true
	for mode in range(1, 7):
		main.preferences.visual_enhancements.cloud_mode = mode
		for kind in range(1, 7):
			main.preferences.visual_enhancements.weather_fixed = kind
			clouds.reset()
			main.visual_environment.process(0.0)
			assert(clouds.situations.current == mode - 1, "Weather replaced a fixed cloud type")
			assert(clouds.precipitation_readiness == 1.0, "A fixed cloud type suppressed precipitation")
			var weather := main.visual_environment.weather
			if weather.layer != null and weather.layer.visible:
				assert(is_equal_approx(weather.material.get_shader_parameter("rain"), weather.rain))
				assert(is_equal_approx(weather.material.get_shader_parameter("snow"), weather.snow))
	main.preferences.visual_enhancements.cloud_mode = 0
	clouds.reset()
	main.preferences.visual_enhancements.cloud_enabled = true
	main.preferences.visual_enhancements.weather_enabled = false
	main.visual_environment.process(0.0)
	assert(clouds.density == main.preferences.visual_enhancements.cloud_density and clouds.fog == 0.0)
	main.view_state.overlay_mode = CityViewMode.Mode.HEIGHT
	main.visual_environment.process(1.0)
	assert(not clouds.parameters.cloud_enabled and not clouds.layer.visible)
	main.view_state.overlay_mode = CityViewMode.Mode.CITY
	main.preferences.visual_enhancements.cloud_enabled = false
	main.visual_environment.process(1.0)
	assert(not main.map_view.layers.environment_parameters.cloud_enabled)
	assert(main.map_view.layers.environment_parameters.cloud_fog_density == 0.0)
	assert(DocumentState.capture(main.document_state.city.document) == before)
	assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == rng_before)
	main.queue_free()
	await process_frame
	print("PASS: cloud zoom variants, canonical rotation, camera anchoring, pause/speed, disable and unchanged city/RNG")
	quit()


func _check_situations() -> void:
	var state := CityCloudSituations.new()
	state.advance(4, 0, -1, 0.0, 0.0, false)
	assert(state.current == CityCloudSituations.Type.CIRRUS)
	state.advance(1, 0, -1, 1.0, 1.0, false)
	assert(state.current == CityCloudSituations.Type.CIRRUS and state.target == CityCloudSituations.Type.CUMULUS)
	assert(state.weight() > 0.0 and state.weight() < 0.001, "Cloud front started abruptly")
	var frozen := state.blend
	state.advance(2, 0, -1, 60.0, 0.0, false)
	assert(state.blend == frozen and state.target == CityCloudSituations.Type.CUMULUS,
		"Paused/interrupted fronts must retain their two silhouettes")
	var previous := state.weight()
	for frame in 88:
		state.advance(1, 0, -1, 1.0, 1.0, false)
		assert(absf(state.weight() - previous) < 0.018, "A front jumped its silhouette weight")
		previous = state.weight()
	state.advance(1, 0, -1, 1.0, 1.0, false)
	assert(state.current == state.target and state.current == CityCloudSituations.Type.CUMULUS)
	state.advance(6, 0, -1, 1.0, 0.0, true)
	assert(state.blend > 0.0, "An explicit paused menu preview must progress")
	for mode in range(7):
		for kind in range(1, 7):
			var chosen := CityCloudSituations.choose(mode, kind, -1)
			if mode == 0:
				assert(chosen in [CityCloudSituations.Type.CUMULUS, CityCloudSituations.Type.STRATUS, CityCloudSituations.Type.ALTOSTRATUS])
			else:
				assert(chosen == mode - 1, "Fixed types must take precedence over wet weather")
			assert(CityVisualClouds.weather_density(0.0, kind, -1, 0.0) >= 0.4,
				"Wet weather must retain cloud cover even with zero preferred coverage")
	assert(CityCloudSituations.choose(0, 0, 3) == CityCloudSituations.Type.FOG)
	assert(CityCloudSituations.choose(0, 0, 1) != CityCloudSituations.Type.FOG)
	assert(CityCloudSituations.choose(0, 0, 5) == CityCloudSituations.Type.STRATUS)
