extends SceneTree

const DocumentState = preload("res://tests/support/document_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_special_motion()
	var graphics_override := OS.get_environment("OPENSC2K_GRAPHICS_PACK")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var app := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	root.add_child(app)
	await process_frame
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", graphics_override)
	app.set_process(false)
	app.main_menu.city_background.set_process(false)
	assert(app.city_session.activate_document(EmptyCityTemplate.create(128)))
	app.map_view.zoom_factor = 2.0
	app.map_view.center_on_tile(Vector2i(64, 64))
	var deadline := Time.get_ticks_msec() + 10000
	while app.map_view.city_source == null and Time.get_ticks_msec() < deadline:
		app.static_render.poll_static_render()
		app.static_render.start_pending_static_render()
		await process_frame
	assert(app.map_view.city_source != null)
	var city := app.document_state.city
	var before := DocumentState.capture(city.document)
	var engine := app.simulation_state.simulation_engine
	var random_before := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
	var effects := app.disaster_effects
	var tile := Vector2i(64, 64)
	for marker in [0xff, 0xfc, 0xfb, 0xfd, 0xfe]:
		effects.begin_commands()
		var command := CityDynamicCommand.new()
		command.depth_order = (tile.x + tile.y) * 128 + tile.y
		command.overlay = marker
		var replaced := effects.observe_command(command)
		assert(replaced, "Enhanced fire, water, gas and people must replace the classic markers")
		effects.end_commands()
		assert(effects.markers.size() == 1)
		var visual: CityDisasterEffects.Visual = effects.markers.values()[0]
		var node_id := visual.sprite.get_instance_id()
		effects.begin_commands()
		effects.observe_command(command)
		effects.end_commands()
		assert(effects.markers.values()[0].sprite.get_instance_id() == node_id, "Reuse nodes across display frames")
		assert(effects.canvas.get_index() < app.map_view.layers.dynamic_canvas.get_index(), "Dispatch sprites must remain above effects")
	var dust := EffectEvent.new(tile, 1392)
	var events: Array[EffectEvent] = [dust, dust.copy()]
	assert(effects.consume_effects(events, false).is_empty())
	assert(effects.pulses.size() == 1, "A building dust sequence must not create a cloud per animation frame")
	var phase := effects.clock
	app.preferences.visual_enhancements.pause_freezes = true
	app.simulation_state.speed_controller.speed = GameSpeedController.Speed.PAUSED
	# Avoid a settings refresh removing the synthetic marker used above.
	effects._settings_signature = [true, true, true, true]
	effects.process(0.2)
	assert(effects.clock == phase)
	assert(effects.pulses[0].age > 0.0, "Player demolition must settle while paused")
	for i in 8:
		effects.process(0.2)
	assert(effects.pulses.is_empty())
	assert(dust.sprite_id == 1392 and dust.frame == 0, "Presentation must not mutate source events")
	var source := DisasterStartResult.new()
	source.ok = true
	source.started = true
	source.point = tile
	source.disaster_type = 10
	source.damage_points = [tile, tile + Vector2i(1, 0)]
	effects.disaster_started(source)
	assert(effects.pulses.size() == 2)
	assert(effects.pulses[1].age < 0.0, "Microwave display follows completed damage points with bounded delays")
	app.preferences.visual_enhancements.disaster_enabled = false
	effects.process(0.0)
	assert(effects.pulses.is_empty() and effects.markers.is_empty())
	assert(effects.consume_effects(events, false) == events, "Disabled effects must preserve classic dust")
	assert(not effects.observe_command(CityDynamicCommand.new()))
	assert(DocumentState.capture(city.document) == before, "Visual effects wrote city data")
	assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == random_before, "Visual effects advanced simulation RNG")
	await _check_object_replacements(app)
	app.queue_free()
	await process_frame
	print("PASS: disaster marker replacement, dispatch layering, retained nodes, event deduplication, pause, fallback and unchanged city/RNG")
	quit()


func _check_object_replacements(app: CityApplication) -> void:
	app.preferences.visual_enhancements.disaster_enabled = true
	var city := app.document_state.city
	var effects := app.disaster_effects
	var support := load("res://tests/traffic_motion_test.gd")
	for kind in [15, 6, 5]:
		support.write_thing(city, 1, {"type": kind, "x": 64, "y": 64, "z": 0})
		var before := DocumentState.capture(city.document)
		var command := CityDynamicCommand.new()
		command.record = 1
		command.depth_order = 128 * 128 + 64
		effects.begin_commands()
		assert(effects.observe_command(command) == (kind != 5), "Replace the tornado and explosion, preserve the monster artwork")
		effects.end_commands()
		assert(effects.markers.size() == (2 if kind == 5 else 1))
		assert(DocumentState.capture(city.document) == before)
		app.preferences.visual_enhancements.disaster_enabled = false
		assert(not effects.observe_command(command), "The classic object must return when enhancements are disabled")
		app.preferences.visual_enhancements.disaster_enabled = true
	# A hovering monster has no contact dust.
	support.write_thing(city, 1, {"z": 15})
	var hovering := CityDynamicCommand.new()
	hovering.record = 1
	hovering.depth_order = 128 * 128 + 64
	effects.begin_commands()
	assert(not effects.observe_command(hovering))
	effects.end_commands()
	assert(effects.markers.is_empty())
	await process_frame


func _check_special_motion() -> void:
	var support := load("res://tests/traffic_motion_test.gd")
	for type in [5, 15]:
		var city: CityState = support.fixture(type)
		var motion := CityTrafficMotion.new()
		var options := VisualEnhancementOptions.normalize({})
		motion.observe(city, options)
		var old := motion.tracks[1].current
		support.write_thing(city, 1, {"px": 255, "py": 255})
		motion.observe(city, options)
		assert(motion.tracks[1].target == old, "Monster pose and tornado bytes are not sub-tile movement")
		city.set_text_overlay_id(64, 64, 0)
		support.write_thing(city, 1, {"x": 65})
		var before := DocumentState.capture(city.document)
		motion.observe(city, options)
		assert(motion.tracks[1].current == old)
		motion.advance(0.1)
		assert(motion.tracks[1].current.is_equal_approx(old.lerp(motion.tracks[1].target, 0.5)))
		assert(DocumentState.capture(city.document) == before)
		options.disaster_motion = false
		motion.observe(city, options)
		assert(motion.tracks.is_empty(), "Motion toggle immediately restores completed positions")
