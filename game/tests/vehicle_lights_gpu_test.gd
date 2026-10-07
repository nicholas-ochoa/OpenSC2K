extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_monster_panels()
	await _check_monster_beam()
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
		for direction in 8:
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
						assert(pixel.g > 0.8 if direction in [1, 2, 4, 5] else pixel.g < 0.3, "Lamp color was ambient-graded")
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


func _check_monster_panels() -> void:
	var graphics := GraphicsPack.load_root(ProjectSettings.globalize_path("res://../ext/graphics"))
	assert(graphics.error.is_empty())
	var lights := CityMovingLights.new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 96)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := CityDynamicSpriteCanvas.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(canvas)
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/view/map/palette_cycle.gdshader")
	material.set_shader_parameter("environment_enabled", true)
	material.set_shader_parameter("environment_tint", Vector3(0.28, 0.34, 0.52))
	canvas.material = material
	for id in [1490, 1491, 990, 991, 490, 491]:
		var archive := graphics.large_sprites if id >= 1000 else graphics.small_medium_sprites
		var source: Image = archive.find_sprite(id).create_image(graphics.palette).image
		var mask := lights.mask(archive, id)
		for flip in [false, true]:
			var image := source.duplicate() as Image
			if flip:
				image.flip_x()
			var emission := CityBrightmaps.transform_mask(mask, image, flip)
			var visual := CityDynamicVisual.new(ImageTexture.create_from_image(image))
			canvas.set_visuals([visual], 1.0, Vector2.ZERO)
			await process_frame
			await RenderingServer.frame_post_draw
			var unlit := viewport.get_texture().get_image()
			visual.emission_texture = ImageTexture.create_from_image(emission)
			canvas.set_visuals([visual], 1.0, Vector2.ZERO)
			for strength in [0.0, 0.5, 1.0]:
				material.set_shader_parameter("environment_night", strength)
				await process_frame
				await RenderingServer.frame_post_draw
				var rendered := viewport.get_texture().get_image()
				if strength == 0.0:
					assert(rendered.get_data() == unlit.get_data(), "Disabled monster brightmaps changed original artwork")
				for y in image.get_height():
					for x in image.get_width():
						var lamp := emission.get_pixel(x, y)
						var pixel := rendered.get_pixel(x, y)
						assert(is_equal_approx(pixel.a, image.get_pixel(x, y).a))
						var expected := unlit.get_pixel(x, y).lerp(lamp, lamp.a * strength)
						assert(absf(pixel.r - expected.r) < 0.015 and absf(pixel.g - expected.g) < 0.015 and absf(pixel.b - expected.b) < 0.015,
							"Monster panel emission changed hue, alignment or strength")
	viewport.queue_free()
	await process_frame


func _check_monster_beam() -> void:
	var graphics := GraphicsPack.load_root(ProjectSettings.globalize_path("res://../ext/graphics"))
	assert(graphics.error.is_empty())
	var lights := CityMovingLights.new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 96)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := CityDynamicSpriteCanvas.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(canvas)
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/view/map/palette_cycle.gdshader")
	material.set_shader_parameter("palette_cycle_enabled", true)
	material.set_shader_parameter("palette_lookup_all", true)
	material.set_shader_parameter("environment_enabled", true)
	var tint := Color(0.28, 0.34, 0.52)
	material.set_shader_parameter("environment_tint", Vector3(tint.r, tint.g, tint.b))
	canvas.material = material
	for id in [1385, 885, 385]:
		var archive := graphics.large_sprites if id >= 1000 else graphics.small_medium_sprites
		var entry := archive.find_sprite(id)
		var source: Image = entry.create_image(Sc2Palette.index_encoding()).image
		var mask := lights.mask(archive, id)
		for phase in 4:
			var image := source.duplicate() as Image
			var flip := phase % 2 == 1
			if flip:
				image.flip_x()
			var emission := CityBrightmaps.transform_mask(mask, image, flip)
			assert(emission.get_format() == Image.FORMAT_LA8)
			var visual := CityDynamicVisual.new(ImageTexture.create_from_image(image))
			visual.emission_texture = ImageTexture.create_from_image(emission)
			canvas.set_visuals([visual], 1.0, Vector2.ZERO)
			var indices := graphics.palette.animation_index_map_steps(phase, 0)
			var palette := Image.create(256, 1, false, Image.FORMAT_RGBA8)
			for index in 256:
				palette.set_pixel(index, 0, graphics.palette.color(indices[index]))
			material.set_shader_parameter("animated_palette", ImageTexture.create_from_image(palette))
			for strength in [0.0, 0.5, 1.0]:
				material.set_shader_parameter("environment_night", strength)
				await process_frame
				await RenderingServer.frame_post_draw
				var rendered := viewport.get_texture().get_image()
				for y in image.get_height():
					for x in image.get_width():
						var original := image.get_pixel(x, y)
						var pixel := rendered.get_pixel(x, y)
						assert(is_equal_approx(pixel.a, original.a), "Plasma light filled a transparent ring gap")
						if original.a == 0.0:
							continue
						var color := palette.get_pixel(original.r8, 0)
						var expected := (color * tint).lerp(color, strength)
						assert(absf(pixel.r - expected.r) < 0.015 and absf(pixel.g - expected.g) < 0.015 and absf(pixel.b - expected.b) < 0.015,
							"Plasma brightmap froze the palette cycle or changed its original ring colors")
			material.set_shader_parameter("environment_enabled", false)
			await process_frame
			await RenderingServer.frame_post_draw
			var disabled := viewport.get_texture().get_image()
			visual.emission_texture = null
			canvas.set_visuals([visual], 1.0, Vector2.ZERO)
			await process_frame
			await RenderingServer.frame_post_draw
			assert(viewport.get_texture().get_image().get_data() == disabled.get_data(), "Disabling the environment left a visible plasma mask")
			material.set_shader_parameter("environment_enabled", true)
	viewport.queue_free()
	await process_frame
