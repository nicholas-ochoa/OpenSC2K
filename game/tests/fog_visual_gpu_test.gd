extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fog := CityVisualFog.new(null)
	fog.prepare()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var layer := ColorRect.new()
	layer.size = Vector2(256, 256)
	var material := ShaderMaterial.new()
	material.shader = CityVisualFog.SHADER
	material.set_shader_parameter("fog_field", fog.field)
	material.set_shader_parameter("fog_canvas_to_grid", CityVisualClouds.shader_basis(Transform2D(
		Vector2(0.5, 0), Vector2(0, 0.5), Vector2(-8, -8))))
	material.set_shader_parameter("fog_density", 0.65)
	layer.material = material
	viewport.add_child(layer)
	await process_frame
	await RenderingServer.frame_post_draw
	var original := viewport.get_texture().get_image()
	var minimum := 1.0
	var maximum := 0.0
	for y in range(24, 240, 4):
		for x in range(24, 240, 4):
			var alpha := original.get_pixel(x, y).a
			minimum = minf(minimum, alpha)
			maximum = maxf(maximum, alpha)
	assert(maximum - minimum > 0.15 and maximum < 0.7, "Fog must have distinct translucent sheets and gaps")
	assert(original.get_pixel(0, 0).a == 0.0, "Fog escaped the map edge")
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == original.get_data(), "Fog moved without advancing its clock")
	material.set_shader_parameter("fog_drift", Vector2.ONE * CityVisualFog.WRAP)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == original.get_data(), "Fog drift wrap introduced a seam")
	var pan := Vector2(12, 8)
	layer.position = pan
	viewport.canvas_transform = Transform2D(0.0, -pan)
	material.set_shader_parameter("fog_canvas_to_grid", CityVisualClouds.shader_basis(Transform2D(
		Vector2(0.5, 0), Vector2(0, 0.5), Vector2(-8, -8) - pan * 0.5)))
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == original.get_data(), "Fog slipped relative to the city during a camera pan")
	material.set_shader_parameter("fog_drift", Vector2(6, 3))
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() != original.get_data(), "Fog sheets did not drift")
	material.set_shader_parameter("fog_density", 0.0)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().is_invisible(), "Zero strength left visible fog")
	viewport.queue_free()
	await process_frame
	print("PASS: visible translucent fog wisps, map bounds, pause, seamless drift and zero strength")
	quit()
