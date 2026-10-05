extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(32, 16)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(32, 0), Vector2(32, 16), Vector2(0, 16)])
	background.color = Color(0.4, 0.8, 0.6)
	viewport.add_child(background)
	var source := Image.create(4, 2, false, Image.FORMAT_RGBA8)
	source.fill(Color.WHITE)
	source.set_pixel(3, 0, Color.TRANSPARENT)
	var visual := CityDynamicVisual.new()
	visual.image = CityAircraftShadow.create(source, null, Vector2i.ZERO, Vector2i(32, 16))
	visual.texture = ImageTexture.create_from_image(visual.image)
	visual.position = Vector2(3, 4)
	visual.size = Vector2(4, 2)
	visual.shadow = true
	visual.transparent_shadow = true
	var canvas := CityDynamicSpriteCanvas.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/view/map/palette_cycle.gdshader")
	# Palette entry zero is white: a black alpha shadow must bypass this lookup.
	var palette := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	palette.fill(Color.WHITE)
	material.set_shader_parameter("animated_palette", ImageTexture.create_from_image(palette))
	material.set_shader_parameter("palette_cycle_enabled", true)
	material.set_shader_parameter("palette_lookup_all", true)
	canvas.material = material
	viewport.add_child(canvas)
	canvas.set_visuals([visual], 1.0, Vector2.ZERO)
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	var ground := pixels.get_pixel(12, 4)
	var shadow := pixels.get_pixel(4, 4)
	assert(shadow.r < ground.r and shadow.g < ground.g and shadow.b < ground.b,
		"Transparent shadows must darken all underlying colors, rather than draw a palette color")
	assert(shadow.g > shadow.b and shadow.b > shadow.r and shadow.r > 0.1,
		"The ground must stay visible with its color relationships")
	assert(pixels.get_pixel(6, 4).is_equal_approx(ground), "Transparent silhouette holes must remain clear")
	visual.position.x = 9
	canvas.set_visuals([visual], 1.0, Vector2.ZERO)
	await RenderingServer.frame_post_draw
	pixels = viewport.get_texture().get_image()
	assert(pixels.get_pixel(4, 4).is_equal_approx(ground), "Moving shadows must leave no baked ground pixels behind")
	assert(pixels.get_pixel(10, 4).g < ground.g)
	background.color = Color(0.8, 0.4, 0.2)
	await RenderingServer.frame_post_draw
	pixels = viewport.get_texture().get_image()
	assert(pixels.get_pixel(10, 4).r > pixels.get_pixel(10, 4).g,
		"A shadow must immediately blend with a changed ground color")
	# Native one-pixel motion must produce smaller visible screen steps when zoomed.
	var helper := load("res://tests/traffic_motion_test.gd")
	var city: CityState = helper.fixture(3)
	var motion := CityTrafficMotion.new()
	var options := VisualEnhancementOptions.normalize({})
	motion.observe(city, options)
	helper.write_thing(city, 1, {"px": 9})
	motion.observe(city, options)
	var command := CityDynamicCommand.new()
	command.record = 1
	command.position = Vector2i(2, 1)
	visual.position = Vector2(command.position) + motion.display_offset(command, 1)
	canvas.set_visuals([visual], 4.0, Vector2.ZERO)
	await RenderingServer.frame_post_draw
	pixels = viewport.get_texture().get_image()
	ground = pixels.get_pixel(24, 7)
	assert(pixels.get_pixel(4, 7).r < ground.r)
	motion.advance(0.05)
	visual.position = Vector2(command.position) + motion.display_offset(command, 1)
	canvas.set_visuals([visual], 4.0, Vector2.ZERO)
	await RenderingServer.frame_post_draw
	pixels = viewport.get_texture().get_image()
	assert(pixels.get_pixel(4, 7).is_equal_approx(ground) and pixels.get_pixel(5, 7).r < ground.r,
		"A quarter-pixel source movement must become one screen pixel at 400 percent zoom")
	viewport.queue_free()
	await process_frame
	print("PASS: GPU transparent aircraft shadows preserve current ground colors, silhouette holes and movement")
	quit()
