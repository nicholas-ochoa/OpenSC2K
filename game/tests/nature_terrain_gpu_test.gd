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
		assert(absf(a.r - b.r) < 0.012 and absf(a.g - b.g) < 0.012, "Terrain variation has a hard seam")
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == enhanced.get_data(), "Static terrain animated")
	# Move the canvas and compensate its world transform, as camera panning does.
	sprite.position.x = 8
	material.set_shader_parameter("nature_canvas_to_grid", Basis(Vector3.RIGHT, Vector3.UP, Vector3(-8, 0, 1)))
	await RenderingServer.frame_post_draw
	var panned := viewport.get_texture().get_image()
	assert(panned.get_region(Rect2i(8, 0, 248, 64)).get_data() == enhanced.get_region(Rect2i(0, 0, 248, 64)).get_data(),
		"Terrain texture moved relative to the map")
	sprite.position.x = 0
	material.set_shader_parameter("nature_canvas_to_grid", Basis.IDENTITY)
	material.set_shader_parameter("nature_terrain_enabled", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == classic.get_data())
	viewport.queue_free()
	await process_frame
	print("PASS: native GPU terrain masks, quiet continuous patches, stationary texture and exact off state")
	quit()
