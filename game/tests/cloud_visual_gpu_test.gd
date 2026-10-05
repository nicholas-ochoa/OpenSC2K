extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var pixels := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	pixels.fill(Color(0.55, 0.65, 0.45))
	pixels.fill_rect(Rect2i(0, 0, 256, 8), Color.TRANSPARENT)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(pixels)
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/view/map/palette_cycle.gdshader")
	sprite.material = material
	viewport.add_child(sprite)
	var marker := ColorRect.new()
	marker.position = Vector2(100, 100)
	marker.size = Vector2(12, 12)
	marker.color = Color(1, 0, 0)
	marker.z_index = 2
	viewport.add_child(marker)
	await process_frame
	await RenderingServer.frame_post_draw
	var original := viewport.get_texture().get_image()
	var field := CityVisualClouds.make_field()
	var canvas_to_grid := CityVisualClouds.shader_basis(Transform2D(Vector2(0.5, 0), Vector2(0, 0.5), Vector2.ZERO))
	for pair in [["cloud_field", field], ["cloud_canvas_to_grid", canvas_to_grid], ["cloud_enabled", true]]:
		material.set_shader_parameter(pair[0], pair[1])
	await RenderingServer.frame_post_draw
	var shaded := viewport.get_texture().get_image()
	var changed := 0
	var sunny := 0
	for y in range(12, 256, 4):
		for x in range(0, 256, 4):
			var a := original.get_pixel(x, y)
			var b := shaded.get_pixel(x, y)
			if a.r > b.r + 0.01:
				changed += 1
			else:
				sunny += 1
			assert(b.r <= a.r + 0.01 and b.r >= a.r * 0.75, "Shadows changed hue or exceeded strength")
			assert(is_equal_approx(a.a, b.a), "Shadows changed the city silhouette")
	assert(changed > 30 and sunny > 30, "The field must have both cloud shadows and sunny gaps")
	assert(shaded.get_pixel(0, 0).a == 0.0)
	assert(shaded.get_pixel(105, 105).is_equal_approx(original.get_pixel(105, 105)), "Clouds reached a foreground marker")
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == shaded.get_data(), "Shader time advanced a frozen cloud field")
	material.set_shader_parameter("cloud_drift", Vector2(CityVisualClouds.FIELD_SPAN, CityVisualClouds.FIELD_SPAN))
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == shaded.get_data(), "Cloud drift wrap introduced a visible seam")
	material.set_shader_parameter("cloud_density", 0.0)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == original.get_data(), "Zero density left shadows behind")
	material.set_shader_parameter("cloud_density", 0.4)
	material.set_shader_parameter("cloud_drift", Vector2(13, 8))
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() != shaded.get_data(), "Cloud shadows did not move")
	material.set_shader_parameter("cloud_drift", Vector2.ZERO)
	# Two neighboring source textures must publish the same field at their seam.
	sprite.texture = ImageTexture.create_from_image(pixels.get_region(Rect2i(0, 0, 128, 256)))
	var right := Sprite2D.new()
	right.centered = false
	right.position = Vector2(128, 0)
	right.texture = ImageTexture.create_from_image(pixels.get_region(Rect2i(128, 0, 128, 256)))
	right.material = material
	viewport.add_child(right)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == shaded.get_data(), "Cloud field restarted at a source region boundary")
	var pan := Vector2(17, 11)
	sprite.position += pan
	right.position += pan
	marker.position += pan
	viewport.canvas_transform = Transform2D(0.0, -pan)
	material.set_shader_parameter("cloud_canvas_to_grid", CityVisualClouds.shader_basis(
		Transform2D(Vector2(0.5, 0), Vector2(0, 0.5), -pan * 0.5)))
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == shaded.get_data(), "The GPU lost the camera translation column")
	sprite.position -= pan
	right.position -= pan
	marker.position -= pan
	viewport.canvas_transform = Transform2D.IDENTITY
	material.set_shader_parameter("cloud_canvas_to_grid", canvas_to_grid)
	var body := ColorRect.new()
	body.size = Vector2(256, 256)
	body.z_index = 1
	var body_material := ShaderMaterial.new()
	body_material.shader = preload("res://src/view/clouds/cloud_bodies.gdshader")
	for pair in [["cloud_enabled", true], ["cloud_field", field], ["cloud_canvas_to_body_grid", canvas_to_grid]]:
		body_material.set_shader_parameter(pair[0], pair[1])
	body.material = body_material
	viewport.add_child(body)
	await RenderingServer.frame_post_draw
	var cloudy := viewport.get_texture().get_image()
	var tops := 0
	for y in range(12, 256, 4):
		for x in range(0, 256, 4):
			if cloudy.get_pixel(x, y).r > shaded.get_pixel(x, y).r + 0.08:
				tops += 1
	assert(tops > 30, "The overview cloud tops are missing")
	assert(cloudy.get_pixel(105, 105).is_equal_approx(original.get_pixel(105, 105)))
	body_material.set_shader_parameter("cloud_opacity", 0.0)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == shaded.get_data(), "Cloud bodies remain in the near view")
	material.set_shader_parameter("cloud_enabled", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == original.get_data(), "Disable did not restore the original pixels")
	viewport.queue_free()
	await process_frame
	print("PASS: GPU cloud tops/shadows, sunny gaps, movement, frozen clock, region seams, transparency, foreground and exact disable")
	quit()
