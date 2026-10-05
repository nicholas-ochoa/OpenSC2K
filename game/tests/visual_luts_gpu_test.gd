extends "res://tests/support/scene_test_case.gd"

var viewport: SubViewport
var material: ShaderMaterial


func _initialize() -> void:
	call_deferred("_run")


func _pixel(x := 4) -> Color:
	return viewport.get_texture().get_image().get_pixel(x, 4)


func _parameters(values: Dictionary) -> void:
	for key in values:
		material.set_shader_parameter(key, values[key])


func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(16, 16)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.45, 0.7, 0.8))
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(image)
	material = ShaderMaterial.new()
	material.shader = preload("res://src/view/map/palette_cycle.gdshader")
	sprite.material = material
	viewport.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	var original := _pixel()
	var profiles := CityVisualLuts.new()
	profiles.reload("")
	var options := VisualEnhancementOptions.normalize({})
	_parameters(profiles.parameters(options, 12.0, Vector4(0, 1, 0, 0)))
	material.set_shader_parameter("environment_enabled", true)
	await RenderingServer.frame_post_draw
	assert(_pixel().is_equal_approx(original), "Built-in neutral profiles changed pixels")
	_parameters(profiles.parameters(options, 7.0, Vector4(0, 1, 0, 0)))
	await RenderingServer.frame_post_draw
	var morning := _pixel()
	assert(morning.r < original.r and morning.b > original.b, "Morning LUT must cool the light: %s -> %s" % [original, morning])
	assert(morning.is_equal_approx(_pixel(12)), "LUT introduced a spatial gradient")
	_parameters(profiles.parameters(options, 19.0, Vector4(0, 1, 0, 0)))
	await RenderingServer.frame_post_draw
	assert(_pixel().r > original.r and _pixel().b < original.b)
	options.day_lut_strength = 0.0
	await _check_zero(options, profiles, original)
	# A known axis swap checks blue slices, bilinear R/G and alpha preservation.
	var swap := (CityVisualLuts.BUILTINS.neutral as Texture2D).get_image()
	swap.convert(Image.FORMAT_RGB8)
	for y in range(32):
		for x in range(1024):
			var c := swap.get_pixel(x, y)
			swap.set_pixel(x, y, Color(c.b, c.g, c.r))
	var atlas := Image.create(1024, 128, false, Image.FORMAT_RGB8)
	for i in range(4):
		atlas.blit_rect(swap, Rect2i(0, 0, 1024, 32), Vector2i(0, i * 32))
	_parameters({"environment_day_luts": ImageTexture.create_from_image(atlas), "environment_day_lut_weights": Vector4(1, 0, 0, 0), "environment_day_lut_strength": 1.0})
	await RenderingServer.frame_post_draw
	var swapped := _pixel()
	assert(absf(swapped.r - original.b) < 0.015 and absf(swapped.b - original.r) < 0.015 and swapped.a == original.a, "Trilinear lookup or alpha failed")
	material.set_shader_parameter("environment_day_lut_strength", 0.5)
	await RenderingServer.frame_post_draw
	assert(absf(_pixel().r - (original.r + swapped.r) * 0.5) < 0.015, "Strength did not blend original and lookup output")
	material.set_shader_parameter("environment_lut_linear_canvas", true)
	material.set_shader_parameter("environment_day_lut_strength", 1.0)
	await RenderingServer.frame_post_draw
	assert(absf(_pixel().r - swapped.r) < 0.015 and absf(_pixel().b - swapped.b) < 0.015, "Linear/sRGB conversion changed an axis swap")
	material.set_shader_parameter("environment_lut_linear_canvas", false)
	# Seasons must stay on the natural-art mask, even for matching source RGB.
	var mask := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	mask.fill_rect(Rect2i(0, 0, 8, 16), Color(1, 0, 0, 1))
	_parameters({"environment_day_lut_strength": 0.0, "environment_season_luts": ImageTexture.create_from_image(atlas), "environment_season_lut_weights": Vector4(0, 1, 0, 0), "environment_season_lut_strength": 1.0, "environment_season_mask": ImageTexture.create_from_image(mask), "environment_has_seasons": true})
	await RenderingServer.frame_post_draw
	assert(_pixel().r > original.r and _pixel(12).is_equal_approx(original), "Season LUT reached buildings outside the mask")
	# Fully emissive colored lights are inserted after all LUTs.
	image.fill(Color(0.9, 0.15, 0.05, 1.0))
	_parameters({"environment_emission": ImageTexture.create_from_image(image), "environment_has_emission": true, "environment_night": 1.0})
	await RenderingServer.frame_post_draw
	assert(_pixel().r > original.b and _pixel().r > _pixel().g * 4.0 and _pixel().b < 0.1, "LUT altered a brightmap's authored color")
	_parameters({"environment_has_emission": false, "environment_has_seasons": false, "environment_season_lut_strength": 0.0})
	# Every authored weather profile is reachable; sunny returns exact originals.
	for kind in range(7):
		profiles.advance_weather(kind, 4.0, 4.0, true)
		_parameters(profiles.parameters(options, 12.0, Vector4(0, 1, 0, 0)))
		await RenderingServer.frame_post_draw
		if kind == 0:
			assert(_pixel().is_equal_approx(original))
		else:
			assert(not _pixel().is_equal_approx(original), "Weather LUT absent: %d" % kind)
	material.set_shader_parameter("environment_enabled", false)
	await RenderingServer.frame_post_draw
	assert(_pixel().is_equal_approx(original))
	await _measure_profiles(sprite, profiles)
	viewport.queue_free()
	await process_frame
	print("PASS: GPU LUT interpolation, neutral/zero bypass, uniform time grading, masked seasons, seven weathers, alpha, sRGB/linear conversion and ungraded brightmaps")
	quit()


func _check_zero(options: Dictionary, profiles: CityVisualLuts, original: Color) -> void:
	_parameters(profiles.parameters(options, 19.0, Vector4(0, 1, 0, 0)))
	await RenderingServer.frame_post_draw
	assert(_pixel().is_equal_approx(original), "Zero LUT strength is not a true bypass")


func _measure_profiles(sprite: Sprite2D, profiles: CityVisualLuts) -> void:
	# Report actual GPU time, without a timing assertion tied to one machine.
	viewport.size = Vector2i(1024, 768)
	sprite.scale = Vector2(64, 48)
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	var options := VisualEnhancementOptions.normalize({})
	_parameters(profiles.parameters(options, 0.0, Vector4(0, 0, 0, 1)))
	material.set_shader_parameter("environment_enabled", true)
	var mask := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	mask.fill(Color(1, 0, 0, 1))
	_parameters({"environment_has_seasons": true, "environment_season_mask": ImageTexture.create_from_image(mask), "environment_day_lut_weights": Vector4(0.33, 0, 0.33, 0.34), "environment_season_lut_weights": Vector4(0.33, 0, 0.33, 0.34), "environment_weather_lut_weights_a": Vector4(0, 0.15, 0.15, 0.15), "environment_weather_lut_weights_b": Vector3(0.15, 0.15, 0.25)})
	var times := PackedFloat64Array()
	for strength in [0.0, 0.5]:
		_parameters({"environment_day_lut_strength": strength, "environment_season_lut_strength": strength, "environment_weather_lut_strength": strength})
		for _i in range(8):
			await RenderingServer.frame_post_draw
		var samples := PackedFloat64Array()
		for _i in range(16):
			await RenderingServer.frame_post_draw
			samples.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()))
		samples.sort()
		times.append(samples[8])
	print("LUT_GPU_MS 1024x768 median off=%.3f stress_mix=%.3f (all non-neutral profiles active)" % [times[0], times[1]])
