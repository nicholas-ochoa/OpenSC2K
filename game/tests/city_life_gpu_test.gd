extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 24)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sprites := CityLifeSprites.new()
	var pixels := Image.create(64, 24, false, Image.FORMAT_RGBA8)
	CityLifeCanvas.stamp(pixels, Vector2i.ZERO, sprites.sprite(false, 0, 1, 0), Vector2i(3, 3), [])
	CityLifeCanvas.stamp(pixels, Vector2i.ZERO, sprites.sprite(true, 2, 0, 0), Vector2i(20, 8), [])
	CityLifeCanvas.stamp(pixels, Vector2i.ZERO, sprites.sprite(false, 0, 1, 0, CityLifeSprites.Vehicle.TRUCK), Vector2i(32, 3), [])
	CityLifeCanvas.stamp(pixels, Vector2i.ZERO, sprites.sprite(false, 0, 1, 0, CityLifeSprites.Vehicle.BUS), Vector2i(48, 3), [])
	var artwork := Sprite2D.new()
	artwork.centered = false
	artwork.texture = ImageTexture.create_from_image(pixels)
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/view/city_life/city_life.gdshader")
	artwork.material = material
	viewport.add_child(artwork)
	await process_frame
	await RenderingServer.frame_post_draw
	var original := viewport.get_texture().get_image()
	assert(original.get_pixel(0, 0).a == 0.0)
	assert(original.get_pixel(24, 6).a == 0.0)
	var car := original.get_pixel(7, 5)
	assert(car.a > 0.9 and car.r > car.b, "RGBA car colors must survive the palette-based map pipeline")
	assert(original.get_pixel(36, 6).a > 0.9 and original.get_pixel(52, 6).a > 0.9,
		"Truck cargo and bus body must survive GPU rendering")
	var cloud_field := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	cloud_field.fill(Color.WHITE)
	material.set_shader_parameter("cloud_field", ImageTexture.create_from_image(cloud_field))
	material.set_shader_parameter("cloud_enabled", true)
	material.set_shader_parameter("cloud_density", 1.0)
	await RenderingServer.frame_post_draw
	var shadow := viewport.get_texture().get_image()
	assert(shadow.get_pixel(7, 5).r < car.r, "Cloud shadows must also shade city-life figures")
	assert(shadow.get_pixel(36, 6).r < original.get_pixel(36, 6).r)
	assert(shadow.get_pixel(52, 6).r < original.get_pixel(52, 6).r)
	assert(shadow.get_pixel(0, 0).a == 0.0)
	material.set_shader_parameter("cloud_enabled", false)
	material.set_shader_parameter("environment_enabled", true)
	material.set_shader_parameter("environment_tint", Vector3(0.3, 0.4, 0.6))
	await RenderingServer.frame_post_draw
	var night := viewport.get_texture().get_image()
	assert(night.get_pixel(7, 5).r < car.r)
	assert(night.get_pixel(0, 0).a == 0.0, "Night grading must preserve sprite transparency")
	viewport.queue_free()
	await process_frame
	await _check_headlight_batches(false)
	await _check_headlight_batches(true)
	await _check_sparse_artwork(false)
	await _check_sparse_artwork(true)
	print("PASS: GPU city-life colors, transparent background, cloud shadows and environment lighting")
	quit()


func _check_sparse_artwork(hdr: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(768, 512)
	viewport.transparent_bg = true
	viewport.use_hdr_2d = hdr
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := CityLifeCanvas.new()
	viewport.add_child(canvas)
	var bounds := Rect2i(-19, 17, 327, 199)
	var entries: Array[Dictionary] = []
	var sprites := CityLifeSprites.new()
	var lights := CityLifeLights.new()
	var pixels := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	var emission := pixels.duplicate() as Image
	for i in 100:
		var sprite := sprites.sprite(i % 4 == 3, i % 12, i % 8, i % 2, i % 3)
		var origin := bounds.position + Vector2i((i * 17) % 330 - 5, (i * 3) % 200 - 4)
		var lamps := lights.lamp_mask(sprite, i % 3, i % 8)
		var opacity: float = [0.0, 0.31, 1.0][i % 3]
		entries.append({"sprite": sprite, "origin": origin, "lamps": lamps, "opacity": opacity, "occluders": []})
		CityLifeCanvas.stamp(pixels, bounds.position, sprite, origin, [], opacity, emission, lamps)
	canvas.atlas.compose(bounds, entries, true)
	var reference := Sprite2D.new()
	reference.centered = false
	reference.texture = ImageTexture.create_from_image(pixels)
	reference.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reference.material = canvas.material.duplicate()
	viewport.add_child(reference)
	for item: CanvasItem in [canvas, reference]:
		var shader := item.material as ShaderMaterial
		shader.set_shader_parameter("environment_enabled", true)
		shader.set_shader_parameter("environment_tint", Vector3(0.3, 0.4, 0.6))
		shader.set_shader_parameter("environment_night", 0.7)
		shader.set_shader_parameter("vehicle_has_emission", true)
		shader.set_shader_parameter("vehicle_emission", canvas.emission_texture if item == canvas else ImageTexture.create_from_image(emission))
	for zoom in [0.5, 1.0, 2.0]:
		canvas.scale = Vector2.ONE * zoom
		reference.scale = canvas.scale
		canvas.position = Vector2(0.375, 0.125)
		reference.position = canvas.position
		canvas.hide()
		reference.show()
		await RenderingServer.frame_post_draw
		var expected := viewport.get_texture().get_image()
		reference.hide()
		canvas.show()
		canvas.queue_redraw()
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().get_data() == expected.get_data(),
			"Sparse GPU artwork differs at zoom %s, HDR %s" % [zoom, hdr])
	viewport.queue_free()
	await process_frame


func _check_headlight_batches(hdr: bool) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	for x in range(57, 73):
		for y in range(57, 73):
			city.set_building_id(x, y, BuildingTileIds.ROAD_CROSSROADS)
			city.set_land_altitude(x, y, 0)
			city.set_terrain_id(x, y, 0)
	var figures: Array = []
	for i in 130:
		var figure := CityLifeController.Figure.new()
		figure.id = i
		@warning_ignore("integer_division")
		figure.tile = Vector2i(58 + i % 13, 58 + i / 13)
		figure.direction = i % 8
		figure.enter = (figure.direction + 2) % 4
		figure.exit = figure.direction
		if figure.direction >= 4:
			var rotation := (figure.direction - 1) % 4
			figure.enter = rotation
			figure.exit = (rotation + 1) % 4
			city.set_building_id(figure.tile.x, figure.tile.y, BuildingTileIds.ROAD_CURVE_1 + rotation)
		figure.vehicle_kind = i % 3
		figure.progress = 0.2 + (i % 3) * 0.3
		figure.visibility = 0.2 + (i % 3) * 0.3
		figure.position = CityLifePaths.point(city, figure.tile, figure.enter, figure.exit, figure.progress, false)
		figures.append(figure)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 320)
	viewport.transparent_bg = true
	viewport.use_hdr_2d = hdr
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var batch := CityLifeHeadlights.new()
	viewport.add_child(batch)
	var lights := CityLifeLights.new()
	var offset := Vector2i(CityLifePaths.point(city, Vector2i(64, 64), 0, 2, 0.5, false)) - Vector2i(256, 150)
	for phase in 3:
		if phase == 1:
			for figure: CityLifeController.Figure in figures:
				figure.progress = 0.75
				figure.position = CityLifePaths.point(city, figure.tile, figure.enter, figure.exit, figure.progress, false)
		elif phase == 2:
			for i in 5:
				figures.pop_front()
			figures[0].id = 900
			figures[0].tile += Vector2i.RIGHT
			figures[0].position = CityLifePaths.point(city, figures[0].tile, figures[0].enter, figures[0].exit, figures[0].progress, false)
		var reference := Node2D.new()
		viewport.add_child(reference)
		var scale_value: float = [0.5, 1.0, 2.0][phase]
		reference.scale = Vector2.ONE * scale_value
		batch.scale = reference.scale
		reference.position = Vector2(0.375, 0.125)
		batch.position = reference.position
		for figure: CityLifeController.Figure in figures:
			var surface := lights.surface(city, figure.tile, figure.enter, figure.direction)
			var sprite := Sprite2D.new()
			sprite.centered = false
			sprite.texture = surface.texture
			sprite.position = Vector2(surface.origin - offset)
			var shader := ShaderMaterial.new()
			shader.shader = preload("res://src/view/city_life/city_life_road_light.gdshader")
			shader.set_shader_parameter("night", 0.65)
			shader.set_shader_parameter("vehicle_world", CityLifeLights.vehicle_world(city, figure))
			shader.set_shader_parameter("forward", CityLifePaths.forward(figure.direction))
			shader.set_shader_parameter("front", float([3, 4, 5][figure.vehicle_kind]))
			shader.set_shader_parameter("opacity", figure.opacity())
			sprite.material = shader
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			reference.add_child(sprite)
		batch.hide()
		await RenderingServer.frame_post_draw
		var expected := viewport.get_texture().get_image()
		reference.hide()
		batch.set_night(0.65)
		batch.render(city, figures, lights, offset, Callable())
		batch.show()
		await RenderingServer.frame_post_draw
		var actual := viewport.get_texture().get_image()
		assert(actual.get_data() == expected.get_data(), "Batched headlights differ from individual lights: hdr=%s phase=%d" % [hdr, phase])
		assert(batch.groups.size() == 3 and batch.slots.size() == figures.size())
		reference.free()
	viewport.queue_free()
	await process_frame
	print("PASS: batched headlights match individual GPU pixels at three zooms, including HDR, fades, movement and slot reuse")
