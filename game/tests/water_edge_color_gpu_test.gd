extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pack := FixtureGraphics.pack()
	var profiles := CityVisualLuts.new()
	profiles.reload("")
	for spec in [[0, false, false], [1, true, false], [2, false, false], [2, true, true]]:
		await _check(pack, profiles, spec[0], spec[1], spec[2])
	print("PASS: water sides match surface seasons/LUTs/night, all sizes, mirroring/HDR, shared tone, original off state and unchanged soil")
	quit()


func _check(pack: GraphicsPack, profiles: CityVisualLuts, view: int, flip: bool, hdr: bool) -> void:
	var archive := pack.large_sprites if view == 2 else pack.small_medium_sprites
	CitySeasonColors.prepare(archive, pack.palette)
	var id := view * 500 + 284
	assert(archive.visual_seasons.has(id), "Water-side sprite has no color mask")
	var entry := archive.find_sprite(id)
	var pixels: Image = entry.create_image(Sc2Palette.index_encoding()).image
	var mask: Image = archive.visual_seasons[id].duplicate()
	if flip:
		pixels.flip_x()
		mask.flip_x()
	var surface := Image.create(entry.width, entry.height, false, Image.FORMAT_RGBA8)
	var samples: Array[Vector2i] = []
	for y in entry.height:
		for x in entry.width:
			var pixel := pixels.get_pixel(x, y)
			var mark := mask.get_pixel(x, y)
			assert(mark.r == 0.0 and mark.g == 0.0 and mark.b < 0.5, "Water-side marker overlaps soil, foliage or power warnings")
			if pixel.a > 0.0:
				assert(mark.b > 0.2 and mark.a == 1.0)
				surface.set_pixel(x, y, Color(6.0 / 255.0, pixel.r, 0, 1))
				samples.append(Vector2i(x, y))
			else:
				assert(mark.a == 0.0)
	var palette := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for index in 256:
		palette.set_pixel(index, 0, pack.palette.color(index))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(entry.width * 3, entry.height)
	viewport.use_hdr_2d = hdr
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var materials: Array[ShaderMaterial] = []
	for column in 3:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.position.x = column * entry.width
		sprite.texture = ImageTexture.create_from_image(pixels)
		var shader := ShaderMaterial.new()
		shader.shader = load("res://src/view/water/water_surface.gdshader" if column == 1 else "res://src/view/map/palette_cycle.gdshader")
		shader.set_shader_parameter("animated_palette", ImageTexture.create_from_image(palette))
		shader.set_shader_parameter("palette_cycle_enabled", true)
		shader.set_shader_parameter("palette_lookup_all", true)
		shader.set_shader_parameter("environment_has_seasons", column == 0)
		shader.set_shader_parameter("environment_season_mask", ImageTexture.create_from_image(mask))
		shader.set_shader_parameter("water_surface", ImageTexture.create_from_image(surface))
		shader.set_shader_parameter("water_padding", 0.0)
		shader.set_shader_parameter("water_geometry_preview", true)
		shader.set_shader_parameter("water_reflections_enabled", false)
		shader.set_shader_parameter("water_topography", false)
		shader.set_shader_parameter("water_enabled", column == 1)
		sprite.material = shader
		viewport.add_child(sprite)
		materials.append(shader)
	await process_frame
	await RenderingServer.frame_post_draw
	var original := viewport.get_texture().get_image()
	for season in 4:
		for lut in [false, true]:
			var weights := Vector4.ZERO
			weights[season] = 1.0
			for column in 2:
				var shader := materials[column]
				shader.set_shader_parameter("water_enabled", true)
				shader.set_shader_parameter("water_season_strength", 1.0)
				shader.set_shader_parameter("environment_enabled", true)
				shader.set_shader_parameter("environment_seasons", weights)
				shader.set_shader_parameter("environment_lut_linear_canvas", hdr)
				shader.set_shader_parameter("environment_season_luts", profiles.atlases.season)
				shader.set_shader_parameter("environment_season_lut_weights", weights)
				shader.set_shader_parameter("environment_season_lut_strength", 0.8 if lut else 0.0)
				shader.set_shader_parameter("environment_tint", Vector3(0.28, 0.34, 0.52) if lut else Vector3.ONE)
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			for point in samples:
				var side := image.get_pixelv(point)
				var top := image.get_pixelv(point + Vector2i(entry.width, 0))
				assert(_distance(side, top) < 0.01, "Water side and surface grading diverged")
			assert(image.get_region(Rect2i(entry.width * 2, 0, entry.width, entry.height)).get_data()
				== original.get_region(Rect2i(entry.width * 2, 0, entry.width, entry.height)).get_data(), "Untagged artwork changed")
	# Shared body tone also works when all environment grading is disabled.
	for column in 2:
		materials[column].set_shader_parameter("environment_enabled", false)
		materials[column].set_shader_parameter("water_topography", true)
		materials[column].set_shader_parameter("water_geometry_preview", false)
	await RenderingServer.frame_post_draw
	var toned := viewport.get_texture().get_image()
	for point in samples:
		assert(_distance(toned.get_pixelv(point), toned.get_pixelv(point + Vector2i(entry.width, 0))) < 0.055,
			"Water side missed the surface body tone")
	materials[0].set_shader_parameter("water_enabled", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_region(Rect2i(0, 0, entry.width, entry.height)).get_data()
		== original.get_region(Rect2i(0, 0, entry.width, entry.height)).get_data(), "Water off failed to restore original side shading")
	viewport.queue_free()
	await process_frame


func _distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
