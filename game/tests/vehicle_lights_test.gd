extends SceneTree

const DocumentState = preload("res://tests/support/document_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := load("res://tests/city_life_test.gd").fixture() as CityState
	var before := DocumentState.capture(city.document)
	var sprites := CityLifeSprites.new()
	var lights := CityLifeLights.new()
	for kind in 3:
		for direction in 4:
			var sprite := sprites.sprite(false, 0, direction, 0, kind)
			var mask := lights.lamp_mask(sprite, kind, direction)
			assert(not mask.is_invisible(), "Each visible vehicle face needs a lamp")
			for y in mask.get_height():
				for x in mask.get_width():
					var lamp := mask.get_pixel(x, y)
					if lamp.a > 0.0:
						assert(sprite.get_pixel(x, y).a == 1.0)
						assert(lamp == CityLifeLights.HEADLIGHT if direction in [1, 2] else lamp == CityLifeLights.TAILLIGHT)
			var figure := CityLifeController.Figure.new()
			figure.tile = Vector2i(64, 64)
			figure.enter = (direction + 2) % 4
			figure.exit = direction
			figure.direction = direction
			figure.progress = 0.55
			figure.vehicle_kind = kind
			figure.position = CityLifePaths.point(city, figure.tile, figure.enter, direction, figure.progress, false)
			var surface := lights.surface(city, figure.tile, figure.enter, direction)
			assert(not surface.image.is_invisible(), "Connected road surface is missing")
			assert(lights.surface(city, figure.tile, figure.enter, direction).texture == surface.texture)
			var block := Image.create(96, 96, false, Image.FORMAT_RGBA8)
			block.fill(Color.WHITE)
			lights.surfaces.clear()
			var hidden := lights.surface(city, figure.tile, figure.enter, direction,
				func(_tile: Vector2i, _enter: int) -> Array: return [{"origin": surface.origin, "image": block}])
			assert(hidden.image.is_invisible(), "Road surface leaked through a foreground silhouette")
			lights.surfaces.clear()
	assert(DocumentState.capture(city.document) == before, "Light generation changed city data")
	await _check_moving_masks()
	print("PASS: vehicle lamp faces, four forward cones, road clipping, occlusion, matching moving-art lights and unchanged city")
	quit()


func _check_moving_masks() -> void:
	var graphics := OS.get_environment("OPENSC2K_GRAPHICS_PACK")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var app := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	root.add_child(app)
	await process_frame
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", graphics)
	app.set_process(false)
	app.main_menu.city_background.set_process(false)
	var lights := CityMovingLights.new()
	for key: String in CityMovingLightSources.DATA:
		var id := int(key)
		var archive: Sc2SpriteArchive = app.asset_state.large_sprites if id >= 1000 else app.asset_state.small_medium_sprites
		var mask := lights.mask(archive, id)
		assert(mask != null and not mask.is_invisible(), "Missing moving brightmap %d" % id)
		for flip in [false, true]:
			var entry := archive.find_sprite(id)
			var silhouette: Image = entry.create_image(app.asset_state.palette).image
			if flip:
				silhouette.flip_x()
			var result := CityBrightmaps.transform_mask(mask, silhouette, flip)
			assert(not result.is_invisible())
			for y in result.get_height():
				for x in result.get_width():
					if result.get_pixel(x, y).a > 0.0:
						assert(silhouette.get_pixel(x, y).a > 0.0, "Moving light escaped its silhouette")
	var wrong := Sc2SpriteArchive.new()
	var record: Dictionary = CityMovingLightSources.DATA["1359"]
	var pixels := PackedInt32Array()
	pixels.resize(int(record.width) * int(record.height))
	pixels.fill(1)
	var entry := Sc2SpriteArchive.entry_from_indices(1359, int(record.width), int(record.height), pixels)
	wrong.entries_by_id[1359] = entry
	assert(lights.mask(wrong, 1359) == null, "Default lights were attached to different artwork")
	var authored := Image.create(entry.width, entry.height, false, Image.FORMAT_RGBA8)
	authored.set_pixel(4, 4, Color.BLUE)
	wrong.visual_emission[1359] = authored
	assert(lights.mask(wrong, 1359) == authored, "A custom brightmap lost precedence")
	assert(lights.mask(wrong, 1490) == null, "Monster art received traffic lights")
	var traffic_test := load("res://tests/traffic_motion_test.gd") as GDScript
	var city: CityState = traffic_test.fixture(3)
	assert(app.city_session.activate_document(city.document))
	app.map_view.zoom_factor = 2.0
	app.map_view.center_on_tile(Vector2i(64, 64))
	var deadline := Time.get_ticks_msec() + 10000
	while app.map_view.city_source == null and Time.get_ticks_msec() < deadline:
		app.static_render.poll_static_render()
		app.static_render.start_pending_static_render()
		await process_frame
	assert(app.map_view.city_source != null)
	var engine := app.simulation_state.simulation_engine
	var random_before := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
	for type in [1, 2, 3]:
		traffic_test.write_thing(city, 1, {"type": type, "direction": 2, "z": 2 if type < 3 else 0})
		var before := DocumentState.capture(city.document)
		app.moving_sprites.refresh_moving_things()
		var bodies := app.map_view.dynamic_sprites.filter(func(v: CityDynamicVisual) -> bool: return not v.shadow)
		assert(not bodies.is_empty() and bodies[0].emission_texture != null, "Moving brightmap did not reach the production renderer")
		assert(app.map_view.dynamic_sprites.all(func(v: CityDynamicVisual) -> bool: return not v.shadow or v.emission_texture == null),
			"Aircraft shadows emitted light")
		if type == 3:
			assert(bodies[0].water_reflection != null and bodies[0].water_reflection.emission != null,
				"Ship brightmap did not reach the reflection source")
		assert(DocumentState.capture(city.document) == before)
	assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == random_before)
	app.queue_free()
	await process_frame
