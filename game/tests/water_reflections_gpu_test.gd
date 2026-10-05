extends "res://tests/support/scene_test_case.gd"

const SHADER := preload("res://src/view/water/water_surface.gdshader")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(32, 32)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(32, 32)
	background.color = Color(0.08, 0.16, 0.65)
	viewport.add_child(background)
	var palette := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	palette.fill(Color(0.08, 0.16, 0.65))
	palette.set_pixel(40, 0, Color(0.7, 0.2, 0.1))
	var surface := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	surface.fill(Color(6.0 / 255.0, 96.0 / 255.0, 0, 1))
	surface.fill_rect(Rect2i(16, 0, 16, 32), Color.TRANSPARENT)
	var mirror := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	mirror.fill(Color(40.0 / 255.0, 0, 0, 1))
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(mirror)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("animated_palette", ImageTexture.create_from_image(palette))
	material.set_shader_parameter("water_surface", ImageTexture.create_from_image(surface))
	material.set_shader_parameter("water_enabled", false)
	material.set_shader_parameter("water_geometry_preview", true)
	sprite.material = material
	viewport.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	var original := viewport.get_texture().get_image()
	material.set_shader_parameter("water_enabled", true)
	await RenderingServer.frame_post_draw
	var reflected := viewport.get_texture().get_image()
	assert(reflected.get_pixel(8, 8).r > 0.6, "Geometric reflection lost its source color")
	assert(reflected.get_pixel(24, 8).is_equal_approx(original.get_pixel(24, 8)), "Water shader changed land")
	assert(reflected.get_pixel(1, 8).is_equal_approx(original.get_pixel(1, 8)), "Padded region edge was drawn twice")
	material.set_shader_parameter("water_geometry_preview", false)
	material.set_shader_parameter("water_clock", 0.0)
	await RenderingServer.frame_post_draw
	var subtle := viewport.get_texture().get_image()
	assert(subtle.get_pixel(8, 8).r < reflected.get_pixel(8, 8).r)
	material.set_shader_parameter("water_reflections_enabled", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(8, 8).r < subtle.get_pixel(8, 8).r,
		"Reflection Off ignored the independent mirror switch")
	material.set_shader_parameter("water_reflections_enabled", true)
	var emission := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	emission.fill(Color(0.9, 0.2, 0.05, 0.75))
	material.set_shader_parameter("environment_enabled", true)
	material.set_shader_parameter("environment_tint", Vector3(0.28, 0.34, 0.52))
	material.set_shader_parameter("environment_night", 1.0)
	material.set_shader_parameter("environment_emission", ImageTexture.create_from_image(emission))
	material.set_shader_parameter("environment_has_emission", true)
	await RenderingServer.frame_post_draw
	var night := viewport.get_texture().get_image()
	assert(night.get_pixel(8, 8).r > original.get_pixel(8, 8).r * 0.28, "Colored reflected brightmaps disappeared")
	material.set_shader_parameter("environment_enabled", false)
	mirror.fill(Color(0, 0, 0, 0))
	(sprite.texture as ImageTexture).update(mirror)
	var bottom := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	bottom.fill(Color(5.0 / 31.0, 0.8, 0, 1))
	material.set_shader_parameter("water_seabed", ImageTexture.create_from_image(bottom))
	material.set_shader_parameter("water_has_seabed", true)
	material.set_shader_parameter("water_topography", true)
	await RenderingServer.frame_post_draw
	var shallow := viewport.get_texture().get_image().get_pixel(8, 8)
	bottom.fill(Color(0, 0.8, 0, 1))
	(material.get_shader_parameter("water_seabed") as ImageTexture).update(bottom)
	await RenderingServer.frame_post_draw
	var deep := viewport.get_texture().get_image().get_pixel(8, 8)
	assert(shallow.r > deep.r, "Shallow water did not reveal more real seabed than deep water")
	material.set_shader_parameter("water_topography", false)
	await RenderingServer.frame_post_draw
	var unshadowed := viewport.get_texture().get_image().get_pixel(8, 8)
	var cloud_field := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	cloud_field.fill(Color.WHITE)
	material.set_shader_parameter("cloud_field", ImageTexture.create_from_image(cloud_field))
	material.set_shader_parameter("cloud_enabled", true)
	material.set_shader_parameter("cloud_density", 1.0)
	material.set_shader_parameter("cloud_shadow_strength", 0.3)
	await RenderingServer.frame_post_draw
	var shadowed := viewport.get_texture().get_image().get_pixel(8, 8)
	assert(shadowed.b < unshadowed.b, "Water pass erased cloud shadows")
	material.set_shader_parameter("cloud_enabled", false)
	await _check_seasonal_water(viewport, material)
	material.set_shader_parameter("water_enabled", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == original.get_data(), "Off did not restore exact original pixels")
	viewport.queue_free()
	await process_frame
	var fixture: Dictionary = load("res://tests/water_reflections_test.gd").fixture()
	var context := CityGpuBuildContext.new()
	context.builder = fixture.builder
	var archive := Sc2SpriteArchive.new()
	archive.water_reflections = true
	archive.water_indices = fixture.indices
	var source := CityMapSource.new(Vector2i(1024, 1024))
	var layer := CityWaterLayer.new()
	root.add_child(layer)
	layer.configure_whole(context, archive, 1, source.get_instance_id())
	layer.set_environment({"water_enabled": true, "water_frozen": true})
	layer.sync(source, 1.0, Vector2.ZERO, ImageTexture.create_from_image(palette), Rect2(fixture.bounds))
	assert(layer.visible and not layer.nodes.is_empty(), "Whole-image CPU path omitted the water pass")
	var retained := layer.whole_regions.duplicate()
	layer.sync(source, 1.0, Vector2.ZERO, ImageTexture.create_from_image(palette), Rect2(fixture.bounds))
	assert(layer.whole_regions == retained, "Unchanged camera rebuilt water geometry")
	var target: Sprite2D = layer.nodes.values()[0]
	var region: WaterReflectionRegion = target.get_meta("region")
	var receiver := Vector2i(-1, -1)
	for y in region.surface.get_height():
		for x in region.surface.get_width():
			if region.surface.get_pixel(x, y).a > 0:
				receiver = Vector2i(x, y)
				break
		if receiver.x >= 0:
			break
	assert(receiver.x >= 0)
	var floating := WaterReflectionSprite.new()
	floating.position = region.bounds.position + receiver
	floating.level = roundi(region.surface.get_pixelv(receiver).r * 255.0) - 1
	floating.image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	floating.image.fill(Color(0.8, 0, 0, 1))
	floating.emission = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	var visual := CityDynamicVisual.new()
	visual.water_reflection = floating
	layer.set_moving([visual])
	assert(target.texture.get_image().get_pixelv(receiver).r > 0.79, "Moving boat reflection was omitted")
	layer.set_moving([])
	assert(target.texture == region.textures.reflected, "Departed boat left a stale reflection")
	layer.set_environment({"water_enabled": false})
	assert(not layer.visible)
	layer.queue_free()
	await process_frame
	print("PASS: GPU reflection source colors, static occlusion, region clipping, subtle attenuation, brightmaps, depth-dependent transmission and exact Off output")
	quit()


func _check_seasonal_water(viewport: SubViewport, material: ShaderMaterial) -> void:
	for pair in [["water_geometry_preview", true], ["water_reflections_enabled", false], ["water_topography", false],
		["environment_enabled", true], ["environment_has_emission", false], ["environment_tint", Vector3.ONE],
		["environment_saturation", 1.0], ["environment_weather", Vector3.ONE], ["environment_frost", 0.0],
		["environment_day_lut_strength", 0.0], ["environment_weather_lut_strength", 0.0],
		["environment_season_lut_strength", 0.0], ["water_season_strength", 0.0]]:
		material.set_shader_parameter(pair[0], pair[1])
	await RenderingServer.frame_post_draw
	var original := viewport.get_texture().get_image()
	var water := original.get_pixel(8, 8)
	var colors: Array[Color] = []
	material.set_shader_parameter("water_season_strength", 1.0)
	for season in range(4):
		var weights := Vector4.ZERO
		weights[season] = 1.0
		material.set_shader_parameter("environment_seasons", weights)
		await RenderingServer.frame_post_draw
		var result := viewport.get_texture().get_image()
		colors.append(result.get_pixel(8, 8))
		assert(result.get_pixel(24, 8) == original.get_pixel(24, 8), "Seasonal water color reached dry land")
		assert(colors[-1] != water, "Seasonal water color missing: %d" % season)
	assert(colors[0].g > colors[1].g and colors[2].r > colors[0].r and colors[2].b < colors[1].b)
	assert(colors[3].g > colors[1].g and colors[3].b > colors[2].b)
	material.set_shader_parameter("environment_seasons", Vector4(0.5, 0.5, 0, 0))
	await RenderingServer.frame_post_draw
	var blended := viewport.get_texture().get_image().get_pixel(8, 8)
	var expected := colors[0].lerp(colors[1], 0.5)
	assert(maxf(absf(blended.r - expected.r), maxf(absf(blended.g - expected.g), absf(blended.b - expected.b))) < 0.01, "Water season transition is discontinuous")
	material.set_shader_parameter("water_season_strength", 0.0)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(8, 8) == water, "Zero seasonal water strength changed pixels")
	material.set_shader_parameter("water_season_strength", 1.0)
	material.set_shader_parameter("environment_enabled", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(8, 8) == water, "Disabled environment still colored the water")
	# A reflected fully emissive object retains its authored light color.
	var reflected := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	reflected.fill(Color(40.0 / 255.0, 0, 0, 1))
	(viewport.get_child(1) as Sprite2D).texture = ImageTexture.create_from_image(reflected)
	var emission := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	emission.fill(Color(0.9, 0.15, 0.05, 1))
	material.set_shader_parameter("environment_emission", ImageTexture.create_from_image(emission))
	material.set_shader_parameter("environment_has_emission", true)
	material.set_shader_parameter("environment_night", 1.0)
	material.set_shader_parameter("environment_enabled", true)
	material.set_shader_parameter("water_reflections_enabled", true)
	await RenderingServer.frame_post_draw
	var light := viewport.get_texture().get_image().get_pixel(8, 8)
	assert(light.r > 0.89 and light.g < 0.16 and light.b < 0.06, "Water tint recolored reflected night lights")
	material.set_shader_parameter("water_season_strength", 0.0)
