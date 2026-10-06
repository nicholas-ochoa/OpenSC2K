extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = CityDisasterEffects.EXTENT
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var pixels := Image.create(CityDisasterEffects.EXTENT.x, CityDisasterEffects.EXTENT.y, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(pixels)
	var material := ShaderMaterial.new()
	material.shader = CityDisasterEffects.SHADER
	material.set_shader_parameter("people", ImageTexture.create_from_image(CityDisasterEffects.crowd_atlas()))
	material.set_shader_parameter("effect_time", 0.7)
	sprite.material = material
	viewport.add_child(sprite)
	await process_frame
	for kind in 14:
		if kind == CityDisasterEffects.MONSTER:
			continue
		material.set_shader_parameter("effect_kind", kind)
		material.set_shader_parameter("progress", 0.2 if kind in [CityDisasterEffects.DUST, CityDisasterEffects.DEBRIS] else -1.0)
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		assert(not image.is_invisible(), "Effect %d did not render" % kind)
		if kind != CityDisasterEffects.HURRICANE:
			assert(image.get_pixel(0, 0).a < 0.01, "An effect obscured unrelated city space")
		if kind in [CityDisasterEffects.FIRE, CityDisasterEffects.TORNADO, CityDisasterEffects.RIOT]:
			material.set_shader_parameter("effect_time", 1.3)
			await RenderingServer.frame_post_draw
			assert(viewport.get_texture().get_image().get_data() != image.get_data(), "Replacement artwork must animate")
			material.set_shader_parameter("effect_time", 0.7)
	material.set_shader_parameter("effect_kind", CityDisasterEffects.FLOOD)
	material.set_shader_parameter("progress", -1.0)
	await RenderingServer.frame_post_draw
	var flood := viewport.get_texture().get_image()
	assert(flood.get_pixel(48, 128).a > 0.1 and flood.get_pixel(65, 128).a < 0.01, "Flood must stay inside the affected tile")
	material.set_shader_parameter("effect_strength", 0.05)
	for kind in [CityDisasterEffects.FLOOD, CityDisasterEffects.TOXIC]:
		material.set_shader_parameter("effect_kind", kind)
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().get_pixel(48, 128).a > 0.1,
			"Confirmed hazard tiles must remain readable at low cosmetic strength")
	material.set_shader_parameter("foreground", ImageTexture.create_from_image(pixels))
	material.set_shader_parameter("has_foreground", true)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().is_invisible(), "Foreground silhouettes must fully hide effects")
	material.set_shader_parameter("has_foreground", false)
	material.set_shader_parameter("effect_kind", CityDisasterEffects.DUST)
	material.set_shader_parameter("progress", 1.0)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().is_invisible(), "Settled demolition dust must disappear completely")
	viewport.queue_free()
	await _check_lighting()
	await process_frame
	print("PASS: GPU disaster effects, tile boundaries, transparent surroundings, foreground occlusion and dust lifetime")
	quit()


func _check_lighting() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(192, 144)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(192, 144)
	background.color = Color(0.3, 0.35, 0.4)
	viewport.add_child(background)
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	viewport.add_child(copy)
	var light := ColorRect.new()
	light.size = background.size
	var material := ShaderMaterial.new()
	material.shader = CityDisasterLighting.SHADER
	material.set_shader_parameter("heat_amount", 0.0)
	light.material = material
	viewport.add_child(light)
	await process_frame
	for color in [Vector3(1.0, 0.24, 0.025), Vector3(0.28, 1.0, 0.035), Vector3(0.025, 0.35, 1.0)]:
		material.set_shader_parameter("light_color", color)
		await RenderingServer.frame_post_draw
		var frame := viewport.get_texture().get_image()
		var center := frame.get_pixel(96, 76)
		var outside := frame.get_pixel(0, 0)
		assert(absf(outside.r - background.color.r) < 0.01 and absf(outside.g - background.color.g) < 0.01 and absf(outside.b - background.color.b) < 0.01, "The light must not tint unrelated city space")
		if color.x == 1.0:
			assert(center.r > center.g and center.r > outside.r)
		elif color.y == 1.0:
			assert(center.g > center.r and center.g > outside.g)
		else:
			assert(center.b > center.r and center.b > outside.b)
	material.set_shader_parameter("light_amount", 0.0)
	await RenderingServer.frame_post_draw
	var off := viewport.get_texture().get_image()
	assert(off.get_pixel(96, 76).is_equal_approx(off.get_pixel(0, 0)), "Zero light strength must preserve city colors exactly")
	viewport.queue_free()
	await process_frame
