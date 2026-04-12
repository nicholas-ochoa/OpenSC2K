extends SceneTree
## Exercise the shared map shader on CPU texture and GPU mesh draw paths.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(8, 2)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var source := Image.create(4, 1, false, Image.FORMAT_RGBA8)
	source.set_pixel(0, 0, Color.WHITE)
	source.set_pixel(1, 0, Color.BLACK)
	source.set_pixel(2, 0, Color.BLUE)
	source.set_pixel(3, 0, Color.TRANSPARENT)
	var before := source.get_data()
	var texture := ImageTexture.create_from_image(source)
	var shader := Shader.new()
	shader.code = CityMapControl.PALETTE_CYCLE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("dark_underground", true)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.material = material
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(rect)
	var mesh := MeshInstance2D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(4, 1)
	mesh.mesh = quad
	mesh.position = Vector2(6, 0.5)
	mesh.texture = texture
	mesh.material = material
	mesh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(mesh)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var actual := viewport.get_texture().get_image()
		for offset in [0, 4]:
			assert(actual.get_pixel(offset, 0).v < 0.25, "Underground background is too bright")
			assert(actual.get_pixel(offset + 1, 0).v > 0.7, "Black wireframe must become light")
			assert(actual.get_pixel(offset + 2, 0).b > 0.9, "Network lost its blue hue")
			assert(actual.get_pixel(offset + 3, 0).a == 0.0, "Transparent pixel became opaque")
		material.set_shader_parameter("dark_underground", false)
		await RenderingServer.frame_post_draw
		actual = viewport.get_texture().get_image()
		assert(actual.get_pixel(0, 0) == Color.WHITE)
		assert(actual.get_pixel(1, 0) == Color.BLACK)
		assert(source.get_data() == before)
		print("PASS: native dark underground texture/mesh pixels, network hue, alpha, toggle and unchanged source")
	else:
		print("PASS: underground shader setup; pixel checks require native rendering")
	viewport.queue_free()
	await process_frame
	quit()
