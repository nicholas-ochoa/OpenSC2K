extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 96)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var artwork := Sprite2D.new()
	artwork.centered = false
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(artwork)
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/view/city_life/city_life.gdshader")
	artwork.material = material
	material.set_shader_parameter("environment_enabled", true)
	material.set_shader_parameter("environment_night", 1.0)
	material.set_shader_parameter("environment_tint", Vector3(0.05, 0.08, 0.2))
	material.set_shader_parameter("vehicle_has_emission", true)
	var sprites := CityLifeSprites.new()
	var lights := CityLifeLights.new()
	for kind in 3:
		for direction in 4:
			var sprite := sprites.sprite(false, 0, direction, 0, kind)
			var mask := lights.lamp_mask(sprite, kind, direction)
			artwork.texture = ImageTexture.create_from_image(sprite)
			material.set_shader_parameter("vehicle_emission", ImageTexture.create_from_image(mask))
			await process_frame
			await RenderingServer.frame_post_draw
			var rendered := viewport.get_texture().get_image()
			for y in mask.get_height():
				for x in mask.get_width():
					if mask.get_pixel(x, y).a > 0.0:
						var pixel := rendered.get_pixel(x, y)
						assert(pixel.r > 0.9)
						assert(pixel.g > 0.8 if direction in [1, 2] else pixel.g < 0.3, "Lamp color was ambient-graded")
	material.set_shader_parameter("environment_night", 0.0)
	await RenderingServer.frame_post_draw
	var off := viewport.get_texture().get_image()
	material.set_shader_parameter("vehicle_has_emission", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == off.get_data(), "Disabled lights changed artwork")
	artwork.queue_free()
	var road := ColorRect.new()
	road.size = Vector2(viewport.size)
	road.color = Color(0.1, 0.1, 0.1)
	viewport.add_child(road)
	var beam := Sprite2D.new()
	beam.centered = false
	var additive := ShaderMaterial.new()
	additive.shader = preload("res://src/view/city_life/city_life_road_light.gdshader")
	beam.material = additive
	viewport.add_child(beam)
	var city := load("res://tests/city_life_test.gd").fixture() as CityState
	for direction in 4:
		for kind in 3:
			var figure := CityLifeController.Figure.new()
			figure.tile = Vector2i(64, 64)
			figure.enter = (direction + 2) % 4
			figure.exit = direction
			figure.direction = direction
			figure.progress = 0.55
			figure.vehicle_kind = kind
			figure.position = CityLifePaths.point(city, figure.tile, figure.enter, direction, figure.progress, false)
			var surface := lights.surface(city, figure.tile, figure.enter, direction)
			beam.texture = surface.texture
			var world := CityLifeLights.vehicle_world(city, figure)
			additive.set_shader_parameter("vehicle_world", world)
			additive.set_shader_parameter("forward", CityLifeLights.FORWARD[direction])
			additive.set_shader_parameter("front", float([3, 4, 5][kind]))
			additive.set_shader_parameter("night", 0.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var baseline := viewport.get_texture().get_image()
			additive.set_shader_parameter("night", 1.0)
			await RenderingServer.frame_post_draw
			var illuminated := viewport.get_texture().get_image()
			var changed := 0
			var warm_peak := false
			for y in 96:
				for x in 96:
					var pixel := illuminated.get_pixel(x, y)
					if pixel == baseline.get_pixel(x, y):
						continue
					changed += 1
					assert(pixel.r >= pixel.b and pixel.r >= baseline.get_pixel(x, y).r, "Additive cone reduced the road color")
					warm_peak = warm_peak or pixel.r - pixel.b > 0.02
					var point: Color = surface.image.get_pixel(x, y)
					assert(point.a == 1.0, "Headlights leaked off the road or through an occluder")
					assert((Vector2(point.r, point.g) - world).dot(CityLifeLights.FORWARD[direction]) > 0.0,
						"Headlight cone pointed backwards")
			assert(changed > 5 and warm_peak, "The GPU road cone is missing for kind %d, direction %d" % [kind, direction])
			additive.set_shader_parameter("night", 0.0)
			await RenderingServer.frame_post_draw
			assert(viewport.get_texture().get_image().get_data() == baseline.get_data(), "Day/off mode left road glow")
	viewport.queue_free()
	await process_frame
	print("PASS: GPU red/yellow lamps in all vehicle orientations, warm additive road light and exact Off output")
	quit()
