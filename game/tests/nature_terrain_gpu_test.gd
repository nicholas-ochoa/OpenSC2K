extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 128)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var pixels := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	pixels.fill(Color(0.55, 0.48, 0.30))
	var mask := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	mask.fill_rect(Rect2i(0, 0, 256, 64), Color(0, 1, 0, 1))
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(pixels)
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/view/map/palette_cycle.gdshader")
	material.set_shader_parameter("environment_has_seasons", true)
	material.set_shader_parameter("environment_season_mask", ImageTexture.create_from_image(mask))
	material.set_shader_parameter("nature_ground", CityNatureArtwork.ground_texture())
	material.set_shader_parameter("nature_terrain_strength", 1.0)
	# One terrain tile spans many pixels. Test seams at actual artwork scale.
	var projection := Basis(Vector3(0.0625, 0, 0), Vector3(0, 0.0625, 0), Vector3(0, 0, 1))
	material.set_shader_parameter("nature_canvas_to_grid", projection)
	sprite.material = material
	viewport.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	var classic := viewport.get_texture().get_image()
	material.set_shader_parameter("nature_terrain_enabled", true)
	await RenderingServer.frame_post_draw
	var enhanced := viewport.get_texture().get_image()
	assert(enhanced.get_data() != classic.get_data())
	assert(enhanced.get_region(Rect2i(0, 64, 256, 64)).get_data() == classic.get_region(Rect2i(0, 64, 256, 64)).get_data(),
		"Terrain effect reached buildings, rocks or zone markings")
	for x in range(1, 256):
		var a := enhanced.get_pixel(x - 1, 32)
		var b := enhanced.get_pixel(x, 32)
		assert(absf(a.r - b.r) < 0.065 and absf(a.g - b.g) < 0.065, "Terrain detail exceeds the restrained contrast budget")
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == enhanced.get_data(), "Static terrain animated")
	material.set_shader_parameter("nature_terrain_strength", 0.0)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == classic.get_data(), "Zero overlay did not restore original ground")
	material.set_shader_parameter("nature_terrain_strength", 0.5)
	await RenderingServer.frame_post_draw
	var half_strength := viewport.get_texture().get_image()
	for x in range(0, 256, 7):
		var expected := classic.get_pixel(x, 32).lerp(enhanced.get_pixel(x, 32), 0.5)
		var actual := half_strength.get_pixel(x, 32)
		assert(absf(actual.r - expected.r) < 0.008 and absf(actual.g - expected.g) < 0.008 and absf(actual.b - expected.b) < 0.008,
			"Half overlay strength did not blend original and enhanced ground")
	assert(half_strength.get_region(Rect2i(0, 64, 256, 64)).get_data() == classic.get_region(Rect2i(0, 64, 256, 64)).get_data())
	material.set_shader_parameter("nature_terrain_strength", 1.0)
	# Move the canvas and compensate its world transform, as camera panning does.
	sprite.position.x = 8
	material.set_shader_parameter("nature_canvas_to_grid", Basis(Vector3(0.0625, 0, 0), Vector3(0, 0.0625, 0), Vector3(-0.5, 0, 1)))
	await RenderingServer.frame_post_draw
	var panned := viewport.get_texture().get_image()
	assert(panned.get_region(Rect2i(8, 0, 248, 64)).get_data() == enhanced.get_region(Rect2i(0, 0, 248, 64)).get_data(),
		"Terrain texture moved relative to the map")
	sprite.position.x = 0
	material.set_shader_parameter("nature_canvas_to_grid", projection)
	material.set_shader_parameter("nature_terrain_enabled", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == classic.get_data())
	# Exercise the same mask contract used by all generated tree variants and
	# terrain aliases. Include an unmasked trunk/building and a shaded field edge.
	mask.fill(Color(0, 0, 0, 0))
	for species in 3:
		mask.fill_rect(Rect2i(species * 64, 0, 64, 64), Color(1, float(species + 1) * 0.1, 0, 1))
	mask.fill_rect(Rect2i(0, 64, 256, 64), Color(0, 1, 0, 1))
	pixels.fill(Color(0.20, 0.48, 0.12))
	pixels.fill_rect(Rect2i(0, 96, 256, 1), Color(0.10, 0.24, 0.06))
	sprite.texture = ImageTexture.create_from_image(pixels)
	material.set_shader_parameter("environment_season_mask", ImageTexture.create_from_image(mask))
	material.set_shader_parameter("nature_forests_enabled", true)
	material.set_shader_parameter("nature_terrain_enabled", true)
	await RenderingServer.frame_post_draw
	var summer := viewport.get_texture().get_image()
	# Seasonal processing must also work on a partially blended overlay.
	material.set_shader_parameter("nature_terrain_strength", 0.5)
	await RenderingServer.frame_post_draw
	summer = viewport.get_texture().get_image()
	material.set_shader_parameter("environment_enabled", true)
	var seasons: Array[Image] = []
	for season in 4:
		var weights := Vector4.ZERO
		weights[season] = 1.0
		material.set_shader_parameter("environment_seasons", weights)
		await RenderingServer.frame_post_draw
		var result := viewport.get_texture().get_image()
		seasons.append(result)
		assert(result.get_region(Rect2i(192, 0, 64, 64)).get_data() == summer.get_region(Rect2i(192, 0, 64, 64)).get_data(),
			"Season color reached unmasked trunks or buildings")
		assert(result.get_pixel(128, 96).get_luminance() < result.get_pixel(128, 95).get_luminance(),
			"Season color erased the field edge shading")
		if season == 1:
			assert(result.get_data() == summer.get_data())
		else:
			for region in [Rect2i(0, 64, 256, 64), Rect2i(0, 0, 64, 64), Rect2i(64, 0, 64, 64), Rect2i(128, 0, 64, 64)]:
				assert(result.get_region(region).get_data() != summer.get_region(region).get_data(),
					"New terrain or tree species ignored the selected season")
	var autumn_pine := seasons[2].get_pixel(32, 32)
	var autumn_oak := seasons[2].get_pixel(96, 32)
	var autumn_birch := seasons[2].get_pixel(160, 32)
	assert(autumn_pine.g > autumn_pine.r, "Evergreen became autumn foliage")
	assert(autumn_oak.r > autumn_oak.g and autumn_birch.g > autumn_oak.g, "Broadleaf autumn species lost their colors")
	assert(seasons[3].get_pixel(128, 80).get_luminance() > summer.get_pixel(128, 80).get_luminance(), "Winter ground did not receive snow shading")
	# Reference pixels captured before the foliage contrast correction. Snow
	# and autumn broadleaves must retain their approved colors, while spring
	# receives a smaller lift than summer and autumn conifers stay green.
	var original_spring := [Color("1e510c"), Color("326b18"), Color("326b18")]
	var original_winter := [Color("647b6b"), Color("97a1aa"), Color("97a1aa")]
	for species in 3:
		var x := species * 64 + 32
		assert(seasons[1].get_pixel(x, 32).get_luminance() > Color("1d490c").get_luminance() + 0.05)
		assert(seasons[0].get_pixel(x, 32).get_luminance() > original_spring[species].get_luminance() + 0.02)
		assert(_color_distance(seasons[3].get_pixel(x, 32), original_winter[species]) < 0.008,
			"Foliage correction changed the approved winter palette")
	assert(_color_distance(autumn_oak, Color("794514")) < 0.008)
	assert(_color_distance(autumn_birch, Color("726021")) < 0.008)
	assert(autumn_pine.get_luminance() > Color("1c440b").get_luminance() + 0.05)
	material.set_shader_parameter("environment_enabled", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == summer.get_data(), "Seasons off did not restore the nature artwork")
	viewport.queue_free()
	await process_frame
	print("PASS: native GPU terrain masks, quiet patches, stationary texture, all tree species and terrain in four seasons, field edges and exact off state")
	quit()


func _color_distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
