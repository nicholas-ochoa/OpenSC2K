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
		assert(replaced == (marker not in [0xff, 0xfb]), "Preserve classic fire and toxic cloud; replace water and people")
		effects.end_commands()
		assert(effects.markers.size() == (5 if marker in [0xfd, 0xfe] else 1))
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
	effects._settings_signature = [true, true, true, true, true]
	effects.process(0.2)
	assert(effects.clock == phase)
	assert(effects.pulses[0].age > 0.0, "Player demolition must settle while paused")
	for i in 8:
		effects.process(0.2)
	assert(effects.pulses.is_empty())
	assert(dust.sprite_id == 1392 and dust.frame == 0, "Presentation must not mutate source events")
	for side in [2, 3, 4]:
		var structure_events: Array[EffectEvent] = []
		for x in side:
			for y in side:
				var event := EffectEvent.new(tile + Vector2i(x, -y), 1392)
				event.depth_point = tile
				structure_events.append(event)
		var original := EffectEvent.copy_all(structure_events)
		assert(effects.consume_effects(structure_events, false).is_empty())
		assert(effects.pulses.size() == 1, "A whole building shares one retained dust cloud")
		var cloud := effects.pulses[0]
		assert(cloud.sprite.scale.x == side and cloud.sprite.scale.y > 1.0)
		assert((cloud.mask_signature[0] as Rect2i).size == Vector2i(Vector2(CityDisasterEffects.EXTENT) * cloud.sprite.scale), "Expanded dust needs matching foreground coverage")
		assert(EffectEvent.same_arrays(structure_events, original), "Dust grouping must preserve completed source events")
		for i in 9:
			effects.process(0.2)
		assert(effects.pulses.is_empty())
	app.preferences.visual_enhancements.pause_freezes = false
	effects.shake_view()
	for i in 4:
		effects.process(0.25)
	assert(effects._shake_remaining > 0.9 and effects.earthquake_blur.canvas.visible)
	for i in 5:
		effects.process(0.25)
	assert(effects._shake_remaining == 0.0 and not effects.earthquake_blur.canvas.visible)
	assert(app.map_view.presentation.shake_offset == Vector2.ZERO)
	assert(CityDisasterEffects.shake_envelope(0.0) == 0.0 and CityDisasterEffects.shake_envelope(1.0) == 1.0)
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
	_check_debris(app)
	_check_tornado_retention(app)
	_check_hazard_transitions(app)
	_check_cloud_styles(app)
	app.queue_free()
	await process_frame
	print("PASS: disaster marker replacement, dispatch layering, retained nodes, event deduplication, pause, fallback and unchanged city/RNG")
	quit()


func _check_hazard_transitions(app: CityApplication) -> void:
	var city := app.document_state.city
	var options := app.preferences.visual_enhancements
	options.disaster_blending = true
	options.pause_freezes = false
	var animation := app.moving_sprites.hazard_animation
	var tile := Vector2i(63, 64)
	var order := (tile.x + tile.y) * city.map_size + tile.y
	city.set_text_overlay_id(tile.x, tile.y, 0xff)
	app.moving_sprites.refresh_moving_things()
	assert(animation.entries.has(order))
	var entry := animation.entries[order]
	assert(entry.animation.opacity == 0.0)
	var smoke := app.disaster_effects.markers["tile:63:64"]
	assert(app.disaster_effects._opacity(smoke) == 0.0)
	var texture := entry.visual.texture
	var before := DocumentState.capture(city.document)
	var engine := app.simulation_state.simulation_engine
	var random_before := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
	animation.process(0.125)
	app.disaster_effects.process(0.125)
	assert(is_equal_approx(entry.animation.opacity, 0.5))
	assert(is_equal_approx(app.disaster_effects._opacity(smoke), 0.5), "Fire smoke and lighting share the start envelope")
	app.moving_sprites.refresh_moving_things()
	assert(entry.visual.texture == texture, "Subframes reuse the indexed atlas and foreground mask")
	options.pause_freezes = true
	app.simulation_state.speed_controller.speed = GameSpeedController.Speed.PAUSED
	var phase := entry.animation.phase
	animation.process(0.1)
	assert(entry.animation.phase == phase and is_equal_approx(entry.animation.opacity, 0.5))
	options.pause_freezes = false
	animation.process(0.125)
	app.disaster_effects.process(0.125)
	assert(entry.animation.opacity == 1.0)
	assert(DocumentState.capture(city.document) == before)
	assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == random_before)
	city.set_text_overlay_id(tile.x, tile.y, 0)
	app.moving_sprites.refresh_moving_things()
	assert(entry.retired >= 0.0 and animation.entries.has(order))
	before = DocumentState.capture(city.document)
	animation.process(0.175)
	app.disaster_effects.process(0.175)
	assert(is_equal_approx(entry.animation.opacity, 0.5))
	assert(is_equal_approx(app.disaster_effects._opacity(smoke), 0.5), "Fire smoke and light also fade after extinction")
	assert(DocumentState.capture(city.document) == before, "The fading fire must not restore its treatment marker")
	city.set_text_overlay_id(tile.x, tile.y, 0xff)
	app.moving_sprites.refresh_moving_things()
	assert(is_equal_approx(entry.animation.opacity, 0.5), "Reignition must reverse the visual fade without a jump")
	animation.process(0.25)
	city.set_text_overlay_id(tile.x, tile.y, 0)
	app.moving_sprites.refresh_moving_things()
	animation.process(0.2)
	animation.process(0.2)
	assert(not animation.entries.has(order), "Expired afterimages must release their resources")
	city.set_text_overlay_id(tile.x, tile.y, 0xfb)
	app.moving_sprites.refresh_moving_things()
	assert(animation.entries[order].animation.opacity == 1.0)
	options.disaster_blending = false
	animation.process(0.0)
	assert(animation.entries.is_empty(), "The shared switch must restore the original drawing path immediately")
	options.disaster_blending = true
	app.moving_sprites.refresh_moving_things()
	assert(animation.entries.has(order))
	options.disaster_strength = 0.0
	options.disaster_enabled = false
	animation.process(0.0)
	assert(animation.entries.is_empty(), "The master switch also works at zero effect strength")
	options.disaster_enabled = true
	options.disaster_strength = 0.7
	city.set_text_overlay_id(tile.x, tile.y, 0)
	app.moving_sprites.refresh_moving_things()
	var flash := CityDisasterEffects.Visual.new()
	flash.kind = CityDisasterEffects.EXPLOSION
	flash.born = app.disaster_effects.clock
	assert(app.disaster_effects._opacity(flash) == 1.0, "The initial explosion flash must remain immediate")


func _check_tornado_retention(app: CityApplication) -> void:
	var city := app.document_state.city
	var support := load("res://tests/traffic_motion_test.gd")
	support.write_thing(city, 1, {"type": 15, "x": 64, "y": 64, "z": 0})
	app.moving_sprites.refresh_moving_things()
	var renderer := app.moving_sprites.tornado_renderer
	assert(renderer.entries.has(1))
	city.set_text_overlay_id(64, 64, 0)
	support.write_thing(city, 1, {"x": 65})
	app.moving_sprites.refresh_moving_things()
	var before := DocumentState.capture(city.document)
	app.moving_sprites.traffic_motion.advance(0.03)
	app.moving_sprites.refresh_moving_things()
	var builds := renderer.mask_builds
	var texture := renderer.entries[1].sprite.texture
	var position := renderer.entries[1].sprite.position
	app.moving_sprites.traffic_motion.advance(0.03)
	app.moving_sprites.refresh_moving_things()
	assert(renderer.mask_builds == builds, "Subpixel motion must reuse the padded GPU foreground mask")
	assert(renderer.entries[1].sprite.texture == texture and renderer.entries[1].sprite.position != position)
	assert(DocumentState.capture(city.document) == before)


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
		assert(not effects.observe_command(command), "Preserve original tornado, explosion and monster artwork")
		effects.end_commands()
		assert(effects.markers.size() == (0 if kind == 5 else 1))
		assert(DocumentState.capture(city.document) == before)
		app.preferences.visual_enhancements.disaster_enabled = false
		assert(not effects.observe_command(command), "The classic object must return when enhancements are disabled")
		app.preferences.visual_enhancements.disaster_enabled = true
	# Attack light is tied only to the original beam pose.
	support.write_thing(city, 1, {"dx": 0x80})
	var beam := CityDynamicCommand.new()
	beam.record = 1
	beam.depth_order = 128 * 128 + 64
	effects.begin_commands()
	assert(not effects.observe_command(beam))
	effects.end_commands()
	assert(effects.markers.size() == 1)
	support.write_thing(city, 1, {"dx": 0})
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
		if type == 5:
			assert(motion.tracks.is_empty(), "Monster retains original movement")
			continue
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
		motion.observe(city, options, false)
		assert(motion.tracks.has(1), "Hiding vehicles must not disable tornado smoothing")
		options.disaster_motion = false
		motion.observe(city, options)
		assert(motion.tracks.is_empty(), "Motion toggle immediately restores completed positions")


func _check_debris(app: CityApplication) -> void:
	var city := app.document_state.city
	var effects := app.disaster_effects
	var tile := Vector2i(64, 64)
	effects._tornado_sites[tile] = 0x70
	city.set_building_id(64, 64, 1)
	var before := DocumentState.capture(city.document)
	var tick := SimulationTickResult.new()
	var movement := MovingThingResult.new()
	tick.moving_results.append(movement)
	effects.observe_simulation_result(tick)
	assert(effects.pulses.is_empty(), "Unrelated demolition must not throw tornado fragments")
	movement.tornado_demolitions = 1
	effects.observe_simulation_result(tick)
	assert(effects.pulses.size() == 1 and effects.pulses[0].kind == CityDisasterEffects.DEBRIS)
	effects.observe_simulation_result(tick)
	assert(effects.pulses.size() == 1, "Do not replay confirmed debris")
	assert(DocumentState.capture(city.document) == before)


func _check_cloud_styles(app: CityApplication) -> void:
	var effects := app.disaster_effects
	var engine := app.simulation_state.simulation_engine
	var city := app.document_state.city
	var tile := Vector2i(64, 64)
	var order := (tile.x + tile.y) * city.map_size + tile.y
	city.set_text_overlay_id(tile.x, tile.y, 0xfb)
	var before := DocumentState.capture(city.document)
	var random_before := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
	var original_disaster := engine.active_disaster_type
	for disaster in range(19):
		var expected := 1 if disaster in [4, 15] else (2 if disaster == 11 else 0)
		assert(CityDisasterEffects.cloud_style_for_disaster(disaster) == expected)
		engine.active_disaster_type = disaster
		effects._cloud_styles.clear()
		effects._cloud_context = 0
		app.moving_sprites.refresh_moving_things()
		var visual := app.moving_sprites.hazard_animation.entries[order].visual
		assert(visual.toxic_cloud == (expected == 1) and visual.warm_cloud == (expected == 2))
		var gas: CityDisasterEffects.Visual = effects.markers["tile:64:64"]
		assert(gas.sprite.material.get_shader_parameter("cloud_style") == expected)
		var tint := effects.cloud_light_color(expected)
		assert((tint.g > tint.r) == (expected == 1), "Only toxic and pollution clouds may cast green light")
	# An observed volcanic cloud keeps its identity after the event ends.
	engine.active_disaster_type = 11
	effects._cloud_styles.clear()
	assert(effects.cloud_style(tile) == 2)
	engine.active_disaster_type = 4
	assert(effects.cloud_style(tile) == 2)
	# Removal releases provenance, so the next cloud at this tile can be toxic.
	city.set_text_overlay_id(tile.x, tile.y, 0)
	effects.begin_commands()
	city.set_text_overlay_id(tile.x, tile.y, 0xfb)
	assert(effects.cloud_style(tile) == 1)
	# The completed start callback also colors a cloud when the first tick has
	# already ended its disaster, and refreshes paused presentation immediately.
	engine.active_disaster_type = 0
	effects._cloud_styles.clear()
	effects._cloud_context = 0
	var result := DisasterStartResult.new()
	result.ok = true
	result.started = true
	result.disaster_type = 11
	result.point = tile
	effects.disaster_started(result)
	assert(app.moving_sprites.hazard_animation.entries[order].visual.warm_cloud)
	app.preferences.visual_enhancements.disaster_blending = false
	app.moving_sprites.refresh_moving_things()
	assert(effects.cloud_style(tile) == 2)
	assert(app.map_view.dynamic_sprites.any(func(visual: CityDynamicVisual) -> bool: return visual.warm_cloud and not visual.toxic_cloud), "Unblended rendering must receive volcanic styling too")
	app.preferences.visual_enhancements.disaster_blending = true
	engine.active_disaster_type = original_disaster
	assert(DocumentState.capture(city.document) == before, "Cloud color must not change city data")
	assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == random_before)
