extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 24)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sprites := CityLifeSprites.new()
	var pixels := Image.create(64, 24, false, Image.FORMAT_RGBA8)
	CityLifeCanvas.stamp(pixels, Vector2i.ZERO, sprites.sprite(false, 0, 1, 0), Vector2i(3, 3), [])
	CityLifeCanvas.stamp(pixels, Vector2i.ZERO, sprites.sprite(true, 2, 0, 0), Vector2i(20, 8), [])
	CityLifeCanvas.stamp(pixels, Vector2i.ZERO, sprites.sprite(false, 0, 1, 0, CityLifeSprites.Vehicle.TRUCK), Vector2i(32, 3), [])
	CityLifeCanvas.stamp(pixels, Vector2i.ZERO, sprites.sprite(false, 0, 1, 0, CityLifeSprites.Vehicle.BUS), Vector2i(48, 3), [])
	var artwork := Sprite2D.new()
	artwork.centered = false
	artwork.texture = ImageTexture.create_from_image(pixels)
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/view/city_life/city_life.gdshader")
	artwork.material = material
	viewport.add_child(artwork)
	await process_frame
	await RenderingServer.frame_post_draw
	var original := viewport.get_texture().get_image()
	assert(original.get_pixel(0, 0).a == 0.0)
	assert(original.get_pixel(24, 6).a == 0.0)
	var car := original.get_pixel(7, 5)
	assert(car.a > 0.9 and car.r > car.b, "RGBA car colors must survive the palette-based map pipeline")
	assert(original.get_pixel(36, 6).a > 0.9 and original.get_pixel(52, 6).a > 0.9,
		"Truck cargo and bus body must survive GPU rendering")
	var cloud_field := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	cloud_field.fill(Color.WHITE)
	material.set_shader_parameter("cloud_field", ImageTexture.create_from_image(cloud_field))
	material.set_shader_parameter("cloud_enabled", true)
	await RenderingServer.frame_post_draw
	var shadow := viewport.get_texture().get_image()
	assert(shadow.get_pixel(7, 5).r < car.r, "Cloud shadows must also shade city-life figures")
	assert(shadow.get_pixel(36, 6).r < original.get_pixel(36, 6).r)
	assert(shadow.get_pixel(52, 6).r < original.get_pixel(52, 6).r)
	assert(shadow.get_pixel(0, 0).a == 0.0)
	material.set_shader_parameter("cloud_enabled", false)
	material.set_shader_parameter("environment_enabled", true)
	material.set_shader_parameter("environment_tint", Vector3(0.3, 0.4, 0.6))
	await RenderingServer.frame_post_draw
	var night := viewport.get_texture().get_image()
	assert(night.get_pixel(7, 5).r < car.r)
	assert(night.get_pixel(0, 0).a == 0.0, "Night grading must preserve sprite transparency")
	viewport.queue_free()
	await process_frame
	print("PASS: GPU city-life colors, transparent background, cloud shadows and environment lighting")
	quit()
