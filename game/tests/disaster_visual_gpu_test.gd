extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = CityDisasterEffects.EXTENT
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var pixels := Image.create(64, 96, false, Image.FORMAT_RGBA8)
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
	for kind in 13:
		material.set_shader_parameter("effect_kind", kind)
		material.set_shader_parameter("progress", 0.2 if kind == CityDisasterEffects.DUST else -1.0)
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		assert(not image.is_invisible(), "Effect %d did not render" % kind)
		if kind != CityDisasterEffects.HURRICANE:
			assert(image.get_pixel(0, 0).a < 0.01, "An effect obscured unrelated city space")
	material.set_shader_parameter("effect_kind", CityDisasterEffects.FLOOD)
	material.set_shader_parameter("progress", -1.0)
	await RenderingServer.frame_post_draw
	var flood := viewport.get_texture().get_image()
	assert(flood.get_pixel(32, 80).a > 0.1 and flood.get_pixel(49, 80).a < 0.01, "Flood must stay inside the affected tile")
	material.set_shader_parameter("effect_strength", 0.05)
	for kind in [CityDisasterEffects.FLOOD, CityDisasterEffects.TOXIC]:
		material.set_shader_parameter("effect_kind", kind)
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().get_pixel(32, 80).a > 0.1,
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
	await process_frame
	print("PASS: GPU disaster effects, tile boundaries, transparent surroundings, foreground occlusion and dust lifetime")
	quit()
