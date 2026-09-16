extends SceneTree
## Exercise the shared map shader on CPU texture and GPU mesh draw paths.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(16, 2)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var source := Image.create(8, 1, false, Image.FORMAT_RGBA8)
	source.set_pixel(0, 0, Color.WHITE)
	source.set_pixel(1, 0, Color.BLACK)
	source.set_pixel(2, 0, Color.BLUE)
	source.set_pixel(3, 0, Color.TRANSPARENT)
	source.set_pixel(4, 0, Color(0.7, 0.7, 0.7))
	source.set_pixel(5, 0, Color.GREEN)
	source.set_pixel(6, 0, Color(0.6, 0.5, 0.2))
	source.set_pixel(7, 0, Color(0.3, 0.3, 0.3))
	var before := source.get_data()
	var texture := ImageTexture.create_from_image(source)
	var material := ShaderMaterial.new()
	material.shader = CityMapControl.PALETTE_CYCLE_SHADER
	var source_palette := Sc2Palette.new()
	var source_indices := Image.create(8, 1, false, Image.FORMAT_RGBA8)

	for index in 256:
		source_palette.colors.append(source.get_pixel(index, 0) if index < 8 else Color.BLACK)

	for index in 8:
		source_indices.set_pixel(index, 0, Color8(index, index, index))

	var underground_texture := ImageTexture.create_from_image(source_palette.underground_animation_image(0))
	material.set_shader_parameter("palette_indices", ImageTexture.create_from_image(source_indices))
	material.set_shader_parameter("dark_underground_palette", underground_texture)
	material.set_shader_parameter("dark_underground", true)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.material = material
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(rect)
	var mesh := MeshInstance2D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(8, 1)
	mesh.mesh = quad
	mesh.position = Vector2(12, 0.5)
	mesh.texture = texture
	mesh.material = material
	mesh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(mesh)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var actual := viewport.get_texture().get_image()
		for offset in [0, 8]:
			assert(actual.get_pixel(offset, 0).v < 0.25, "Underground background is too bright")
			assert(actual.get_pixel(offset + 1, 0).v > 0.3, "Sprite edges disappeared in dark mode")
			assert(actual.get_pixel(offset + 2, 0).b > 0.9, "Network lost its blue hue")
			assert(actual.get_pixel(offset + 2, 0).g > 0.6, "Water pipes need luminance, not only saturated blue")
			assert(actual.get_pixel(offset + 3, 0).a == 0.0, "Transparent pixel became opaque")
			var subway := actual.get_pixel(offset + 5, 0)
			assert(subway.g > 0.7 and subway.g > subway.b, "Subway lost its green color")
			assert(actual.get_pixel(offset + 6, 0).v < 0.4, "Terrain grid is too bright")
			assert(actual.get_pixel(offset + 4, 0).v > actual.get_pixel(offset + 7, 0).v,
				"Neutral sprite shading inverted")
		material.set_shader_parameter("dark_underground", false)
		await RenderingServer.frame_post_draw
		actual = viewport.get_texture().get_image()
		assert(actual.get_pixel(0, 0) == Color.WHITE)
		assert(actual.get_pixel(1, 0) == Color.BLACK)
		assert(source.get_data() == before)
		# These palette entries are used by original dry and watered pipe sprites.
		var palette := Sc2Palette.load_bmp("res://../references/SIMCITY2000/BITMAPS/PAL_MSTR.BMP")
		assert(palette.is_valid())
		var palette_image := Image.create(256, 1, false, Image.FORMAT_RGBA8)
		for index in 256:
			palette_image.set_pixel(index, 0, palette.color(index))
		var palette_texture := ImageTexture.create_from_image(palette_image)
		var indices := [141, 145, 200, 204, 71, 74, 120, 255]
		for x in indices.size():
			source.set_pixel(x, 0, Color8(indices[x], indices[x], indices[x]))
		texture.update(source)
		underground_texture.update(palette.underground_animation_image(0))
		material.set_shader_parameter("animated_palette", palette_texture)
		material.set_shader_parameter("palette_lookup_all", true)
		material.set_shader_parameter("palette_cycle_enabled", true)
		material.set_shader_parameter("dark_underground", true)
		await RenderingServer.frame_post_draw
		actual = viewport.get_texture().get_image()
		for offset in [0, 8]:
			var dry := actual.get_pixel(offset, 0)
			var wet := actual.get_pixel(offset + 2, 0)
			assert(dry.r > dry.b * 1.5, "Dry pipe color is not warm")
			assert(wet.b > wet.r and wet.g > dry.g + 0.15, "Wet pipes are not bright cyan")
			assert(actual.get_pixel(offset + 2, 0) != actual.get_pixel(offset + 3, 0),
				"Flowing-water cycle must retain its highlights")
			assert(actual.get_pixel(offset + 4, 0).g > actual.get_pixel(offset + 5, 0).g,
				"Subway shading must survive")
		palette_image = palette.animation_image(4)
		palette_texture.update(palette_image)
		underground_texture.update(palette.underground_animation_image(4))
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().get_pixel(2, 0) != actual.get_pixel(2, 0),
			"Retained pipe pixels must animate with the palette")
		print("PASS: native dark underground texture/mesh pixels, network hue, alpha, toggle and unchanged source")
	else:
		print("PASS: underground shader setup; pixel checks require native rendering")
	viewport.queue_free()
	await process_frame
	quit()
