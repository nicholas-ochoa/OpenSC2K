extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = CityDisasterEffects.EXTENT
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var pixels := Image.create(CityDisasterEffects.EXTENT.x, CityDisasterEffects.EXTENT.y, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(pixels)
	var material := ShaderMaterial.new()
	material.shader = CityDisasterEffects.SHADER
	material.set_shader_parameter("people", ImageTexture.create_from_image(CityDisasterEffects.crowd_atlas()))
	material.set_shader_parameter("effect_time", 0.7)
	sprite.material = material
	viewport.add_child(sprite)
	await process_frame
	for kind in 14:
		if kind == CityDisasterEffects.MONSTER:
			continue
		material.set_shader_parameter("effect_kind", kind)
		material.set_shader_parameter("progress", 0.2 if kind in [CityDisasterEffects.DUST, CityDisasterEffects.DEBRIS] else -1.0)
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		assert(not image.is_invisible(), "Effect %d did not render" % kind)
		if kind != CityDisasterEffects.HURRICANE:
			assert(image.get_pixel(0, 0).a < 0.01, "An effect obscured unrelated city space")
		if kind in [CityDisasterEffects.FIRE, CityDisasterEffects.TORNADO, CityDisasterEffects.RIOT]:
			material.set_shader_parameter("effect_time", 1.3)
			await RenderingServer.frame_post_draw
			assert(viewport.get_texture().get_image().get_data() != image.get_data(), "Replacement artwork must animate")
			material.set_shader_parameter("effect_time", 0.7)
	material.set_shader_parameter("effect_kind", CityDisasterEffects.TOXIC)
	material.set_shader_parameter("progress", -1.0)
	for style in [0, 1, 2]:
		material.set_shader_parameter("cloud_style", style)
		await RenderingServer.frame_post_draw
		var gas := viewport.get_texture().get_image().get_pixel(48, 128)
		assert(gas.a > 0.1)
		if style == 1:
			assert(gas.g > gas.r and gas.g > gas.b * 2.0)
		elif style == 2:
			assert(gas.r > gas.g and gas.g > gas.b * 2.0)
		else:
			assert(absf(gas.r - gas.g) < 0.03)
	material.set_shader_parameter("effect_kind", CityDisasterEffects.FLOOD)
	material.set_shader_parameter("progress", -1.0)
	await RenderingServer.frame_post_draw
	var flood := viewport.get_texture().get_image()
	assert(flood.get_pixel(48, 128).a > 0.1 and flood.get_pixel(65, 128).a < 0.01, "Flood must stay inside the affected tile")
	material.set_shader_parameter("effect_strength", 0.05)
	for kind in [CityDisasterEffects.FLOOD, CityDisasterEffects.TOXIC]:
		material.set_shader_parameter("effect_kind", kind)
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().get_pixel(48, 128).a > 0.1,
			"Confirmed hazard tiles must remain readable at low cosmetic strength")
	material.set_shader_parameter("foreground", ImageTexture.create_from_image(pixels))
	material.set_shader_parameter("has_foreground", true)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().is_invisible(), "Foreground silhouettes must fully hide effects")
	material.set_shader_parameter("effect_kind", CityDisasterEffects.RIOT)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().is_invisible(), "Foreground must hide riot tile edges and people together")
	material.set_shader_parameter("sparse_crowd", true)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().is_invisible(), "Cosmetic crowds must not add false treatment markers")
	material.set_shader_parameter("sparse_crowd", false)
	material.set_shader_parameter("has_foreground", false)
	material.set_shader_parameter("effect_kind", CityDisasterEffects.DUST)
	material.set_shader_parameter("progress", 1.0)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().is_invisible(), "Settled demolition dust must disappear completely")
	viewport.queue_free()
	await _check_lighting()
	await _check_fullbright()
	await _check_hazard_blending()
	await _check_procedural_blending()
	await _check_tornado_mask()
	await _check_quake_blur()
	await _check_beam_glow()
	await process_frame
	print("PASS: GPU disaster effects, tile boundaries, transparent surroundings, foreground occlusion and dust lifetime")
	quit()


func _check_hazard_blending() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(8, 8)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var palette := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	palette.fill(Color.BLUE)
	palette.set_pixel(20, 0, Color.RED)
	palette.set_pixel(220, 0, Color.GREEN)
	var atlas := Image.create(8, 64, false, Image.FORMAT_RGBA8)
	for frame in 8:
		atlas.fill_rect(Rect2i(0, frame * 8, 8, 8), Color8(20 if frame % 2 == 0 else 220, 0, 0))
		atlas.set_pixel(0, frame * 8, Color.TRANSPARENT)
	atlas.set_pixel(1, 0, Color.TRANSPARENT)
	var visual := CityDynamicVisual.new(ImageTexture.create_from_image(atlas), Vector2.ZERO, Vector2(8, 8))
	visual.hazard_animation = CitySpriteFrameBlend.new()
	visual.fullbright = true
	var canvas := CityDynamicSpriteCanvas.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var material := ShaderMaterial.new()
	material.shader = load("res://src/view/map/palette_cycle.gdshader")
	material.set_shader_parameter("animated_palette", ImageTexture.create_from_image(palette))
	material.set_shader_parameter("palette_lookup_all", true)
	material.set_shader_parameter("palette_cycle_enabled", true)
	material.set_shader_parameter("environment_enabled", true)
	material.set_shader_parameter("environment_night", 1.0)
	material.set_shader_parameter("environment_tint", Vector3(0.1, 0.1, 0.2))
	canvas.material = material
	viewport.add_child(canvas)
	canvas.set_visuals([visual], 1.0, Vector2.ZERO)
	for phase in [0.0, 0.5, 1.0, 7.5]:
		visual.hazard_animation.phase = phase
		canvas.queue_redraw()
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var pixel := image.get_pixel(3, 3)
		assert(pixel.b < 0.01, "Blend resolved palette colors, not their encoded indices")
		assert(pixel.a > 0.98, "Overlapping opaque frames must not darken or lose coverage")
		if phase == 0.0:
			assert(pixel.r > 0.98 and pixel.g < 0.01)
		elif phase == 1.0:
			assert(pixel.g > 0.98 and pixel.r < 0.01)
		else:
			assert(absf(pixel.r - 0.5) < 0.02 and absf(pixel.g - 0.5) < 0.02)
		assert(image.get_pixel(0, 0).a == 0.0)
		if phase == 0.5:
			var edge := image.get_pixel(1, 0)
			# SubViewport readback already contains premultiplied RGB.
			assert(absf(edge.a - 0.5) < 0.02 and absf(edge.g - 0.5) < 0.02 and edge.r < 0.01,
				"Transparent frame edges must use premultiplied interpolation: %s" % edge)
	visual.hazard_animation.opacity = 0.4
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	assert(absf(viewport.get_texture().get_image().get_pixel(3, 3).a - 0.4) < 0.02)
	visual.hazard_animation.opacity = 0.0
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().is_invisible())
	visual.hazard_animation.opacity = 1.0
	visual.toxic_cloud = true
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	var gas := viewport.get_texture().get_image().get_pixel(3, 3)
	assert(gas.g > gas.r * 1.5 and gas.g > gas.b * 2.0)
	visual.toxic_cloud = false
	visual.warm_cloud = true
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	var ash := viewport.get_texture().get_image().get_pixel(3, 3)
	assert(ash.r > ash.g and ash.g > ash.b * 2.0 and ash.a > 0.98, "Blended volcanic ash must be amber without losing coverage")
	assert(viewport.get_texture().get_image().get_pixel(0, 0).a == 0.0)
	visual.warm_cloud = false
	visual.fullbright = false
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	var neutral := viewport.get_texture().get_image().get_pixel(3, 3)
	assert(neutral.r < 0.2 and neutral.g < 0.2, "Unknown cloud origins retain normal environmental lighting")
	# The tornado uses a pair of observed frames and the same resolved-color rule.
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(atlas.get_region(Rect2i(0, 0, 8, 16)))
	sprite.scale = Vector2(1.0, 0.5)
	var tornado := ShaderMaterial.new()
	tornado.shader = CityTornadoRenderer.SHADER
	tornado.set_shader_parameter("animated_palette", ImageTexture.create_from_image(palette))
	tornado.set_shader_parameter("frame_blending", true)
	tornado.set_shader_parameter("frame_mix", 0.5)
	tornado.set_shader_parameter("sprite_size", Vector2(8, 8))
	sprite.material = tornado
	canvas.hide()
	viewport.add_child(sprite)
	await RenderingServer.frame_post_draw
	var mixed := viewport.get_texture().get_image().get_pixel(3, 3)
	assert(absf(mixed.r - 0.5) < 0.02 and absf(mixed.g - 0.5) < 0.02 and mixed.b < 0.01)
	var mask := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	mask.fill(Color.WHITE)
	tornado.set_shader_parameter("foreground", ImageTexture.create_from_image(mask))
	tornado.set_shader_parameter("has_foreground", true)
	tornado.set_shader_parameter("mask_size", Vector2(8, 8))
	tornado.set_shader_parameter("mask_offset", Vector2.ZERO)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().is_invisible(), "Foreground must cover both tornado frames")
	viewport.queue_free()
	await process_frame


func _check_procedural_blending() -> void:
	var viewport := SubViewport.new()
	viewport.size = CityDisasterEffects.EXTENT
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rect := ColorRect.new()
	rect.size = Vector2(viewport.size)
	var material := ShaderMaterial.new()
	material.shader = CityDisasterEffects.SHADER
	rect.material = material
	viewport.add_child(rect)
	for kind in [CityDisasterEffects.FIRE, CityDisasterEffects.FLOOD, CityDisasterEffects.TOXIC,
			CityDisasterEffects.TORNADO, CityDisasterEffects.DUST, CityDisasterEffects.EXPLOSION, CityDisasterEffects.TRAIL]:
		material.set_shader_parameter("effect_kind", kind)
		material.set_shader_parameter("progress", 0.2 if kind == CityDisasterEffects.DUST else -1.0)
		material.set_shader_parameter("frame_blending", false)
		material.set_shader_parameter("effect_time", 0.6)
		await RenderingServer.frame_post_draw
		var a := viewport.get_texture().get_image()
		material.set_shader_parameter("effect_time", 0.6 + 1.0 / 15.0)
		await RenderingServer.frame_post_draw
		var b := viewport.get_texture().get_image()
		material.set_shader_parameter("frame_blending", true)
		material.set_shader_parameter("effect_time", 0.6 + 0.5 / 15.0)
		await RenderingServer.frame_post_draw
		var middle := viewport.get_texture().get_image()
		assert(not middle.is_invisible())
		for y in range(0, middle.get_height(), 3):
			for x in range(0, middle.get_width(), 3):
				var first := a.get_pixel(x, y)
				var last := b.get_pixel(x, y)
				var pixel := middle.get_pixel(x, y)
				assert(absf(pixel.a - (first.a + last.a) * 0.5) < 0.015, "Intermediate effect coverage must interpolate")
				for channel in 3:
					assert(absf(pixel[channel] - (first[channel] + last[channel]) * 0.5) < 0.02,
						"Procedural effect colors must interpolate after premultiplication")
	material.set_shader_parameter("lifecycle_opacity", 0.0)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().is_invisible())
	viewport.queue_free()
	await process_frame


func _check_fullbright() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(40, 8)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var palette := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	palette.fill(Color(1.0, 0.5, 0.1))
	var palette_texture := ImageTexture.create_from_image(palette)
	var indexed := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	indexed.fill(Color8(17, 17, 17))
	indexed.set_pixel(0, 0, Color.TRANSPARENT)
	var texture := ImageTexture.create_from_image(indexed)
	var visuals: Array[CityDynamicVisual] = []
	for i in 5:
		var visual := CityDynamicVisual.new(texture, Vector2(i * 8, 0))
		visual.image = indexed
		visual.special_overlay = true
		visual.fullbright = i < 2
		visual.toxic_cloud = i == 3
		visual.warm_cloud = i == 4
		visuals.append(visual)
	var batched := CityDynamicSpriteCanvas.batch_special_visuals(visuals)
	assert(batched.size() == 4 and batched[3].warm_cloud and batched[0].fullbright and not batched[1].fullbright and batched[2].toxic_cloud)
	var canvas := CityDynamicSpriteCanvas.new()
	var material := ShaderMaterial.new()
	material.shader = load("res://src/view/map/palette_cycle.gdshader")
	material.set_shader_parameter("animated_palette", palette_texture)
	material.set_shader_parameter("palette_lookup_all", true)
	material.set_shader_parameter("palette_cycle_enabled", true)
	material.set_shader_parameter("environment_enabled", true)
	material.set_shader_parameter("environment_night", 1.0)
	material.set_shader_parameter("environment_tint", Vector3(0.1, 0.1, 0.2))
	canvas.material = material
	viewport.add_child(canvas)
	canvas.set_visuals(batched, 1.0, Vector2.ZERO)
	await RenderingServer.frame_post_draw
	var frame := viewport.get_texture().get_image()
	assert(frame.get_pixel(2, 2).r > 0.98 and frame.get_pixel(18, 2).r < 0.2, "Fire remains fullbright while its surroundings darken")
	assert(frame.get_pixel(0, 0).a == 0.0)
	var gas := frame.get_pixel(26, 2)
	assert(gas.g > 0.5 and gas.g > gas.r * 1.5 and gas.g > gas.b * 2.0, "The original toxic cloud must glow green at night")
	assert(frame.get_pixel(24, 0).a == 0.0, "Toxic recoloring preserves original transparent pixels")
	var ash := frame.get_pixel(34, 2)
	assert(ash.r > ash.g and ash.g > ash.b * 2.0, "Unblended volcanic cloud must render amber")
	assert(frame.get_pixel(32, 0).a == 0.0, "Volcanic recoloring preserves transparent pixels")
	assert(batched[3].copy().matches(batched[3]))
	palette.fill(Color.GREEN)
	palette_texture.update(palette)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(2, 2).g > 0.98, "Fullbright fire must retain palette animation")
	viewport.queue_free()
	await process_frame


func _check_tornado_mask() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(8, 8)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var palette := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	palette.fill(Color.RED)
	var mask := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	mask.fill_rect(Rect2i(8, 0, 8, 16), Color.WHITE)
	var sprite := ColorRect.new()
	sprite.size = Vector2(8, 8)
	var material := ShaderMaterial.new()
	material.shader = CityTornadoRenderer.SHADER
	material.set_shader_parameter("animated_palette", ImageTexture.create_from_image(palette))
	material.set_shader_parameter("foreground", ImageTexture.create_from_image(mask))
	material.set_shader_parameter("has_foreground", true)
	material.set_shader_parameter("sprite_size", Vector2(8, 8))
	material.set_shader_parameter("mask_size", Vector2(16, 16))
	material.set_shader_parameter("mask_offset", Vector2(4, 0))
	sprite.material = material
	viewport.add_child(sprite)
	await RenderingServer.frame_post_draw
	var frame := viewport.get_texture().get_image()
	assert(frame.get_pixel(1, 3).r > 0.98 and frame.get_pixel(6, 3).a == 0.0)
	material.set_shader_parameter("mask_offset", Vector2(6, 0))
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(3, 3).a == 0.0, "Foreground must stay fixed while tornado art moves")
	viewport.queue_free()
	await process_frame


func _check_quake_blur() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(32, 16)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(32, 16)
	background.color = Color.BLACK
	viewport.add_child(background)
	var stripe := ColorRect.new()
	stripe.position.x = 16
	stripe.size = Vector2(16, 16)
	viewport.add_child(stripe)
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	viewport.add_child(copy)
	var rect := ColorRect.new()
	rect.size = background.size
	var material := ShaderMaterial.new()
	material.shader = CityEarthquakeBlur.SHADER
	rect.material = material
	viewport.add_child(rect)
	await RenderingServer.frame_post_draw
	var original := viewport.get_texture().get_image()
	material.set_shader_parameter("amount", 1.0)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(15, 8).r > original.get_pixel(15, 8).r + 0.05)
	assert(viewport.get_texture().get_image().get_pixel(10, 8).r > original.get_pixel(10, 8).r + 0.02, "Camera smear extends beyond the old small cross blur")
	material.set_shader_parameter("amount", 0.0)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == original.get_data(), "Earthquake blur must return to exact original pixels")
	viewport.queue_free()
	await process_frame


func _check_beam_glow() -> void:
	var buffers: Array[SubViewport] = []
	var palette := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	palette.fill(Color.RED)
	var palette_texture := ImageTexture.create_from_image(palette)
	var source := Image.create(32, 32, false, Image.FORMAT_LA8)
	source.fill_rect(Rect2i(14, 14, 4, 4), Color8(195, 195, 195, 255))
	for i in 3:
		var buffer := SubViewport.new()
		buffer.size = Vector2i(32, 32)
		buffer.transparent_bg = true
		buffer.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(buffer)
		buffers.append(buffer)
		var rect := TextureRect.new()
		rect.texture = ImageTexture.create_from_image(source) if i == 0 else buffers[i - 1].get_texture()
		rect.size = Vector2(32, 32)
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var material := ShaderMaterial.new()
		rect.material = material
		material.shader = CityDisasterBeamGlow.EMISSION if i == 0 else CityDisasterBeamGlow.BLUR
		if i == 0:
			material.set_shader_parameter("indexed", true)
			material.set_shader_parameter("animated_palette", palette_texture)
		else:
			material.set_shader_parameter("radius", 1.5)
			material.set_shader_parameter("direction", Vector2.RIGHT if i == 1 else Vector2.DOWN)
		buffer.add_child(rect)
	for i in 4:
		await RenderingServer.frame_post_draw
	var glow: Image = buffers.back().get_texture().get_image()
	assert(glow.get_pixel(12, 16).r > 0.01 and glow.get_pixel(12, 16).g < 0.01, "Beam glow extends beyond the silhouette in resolved palette color")
	palette.fill(Color.GREEN)
	palette_texture.update(palette)
	for i in 4:
		await RenderingServer.frame_post_draw
	glow = buffers.back().get_texture().get_image()
	assert(glow.get_pixel(12, 16).g > 0.01 and glow.get_pixel(12, 16).r < 0.01, "Glow follows palette cycling without blurring palette addresses")
	for buffer in buffers:
		buffer.queue_free()
	await process_frame


func _check_lighting() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(192, 144)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(192, 144)
	background.color = Color(0.3, 0.35, 0.4)
	viewport.add_child(background)
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	viewport.add_child(copy)
	var light := ColorRect.new()
	light.size = background.size
	var material := ShaderMaterial.new()
	material.shader = CityDisasterLighting.SHADER
	material.set_shader_parameter("heat_amount", 0.0)
	light.material = material
	viewport.add_child(light)
	await process_frame
	for color in [Vector3(1.0, 0.24, 0.025), Vector3(0.28, 1.0, 0.035), Vector3(0.025, 0.35, 1.0)]:
		material.set_shader_parameter("light_color", color)
		await RenderingServer.frame_post_draw
		var frame := viewport.get_texture().get_image()
		var center := frame.get_pixel(96, 76)
		var outside := frame.get_pixel(0, 0)
		assert(absf(outside.r - background.color.r) < 0.01 and absf(outside.g - background.color.g) < 0.01 and absf(outside.b - background.color.b) < 0.01, "The light must not tint unrelated city space")
		if color.x == 1.0:
			assert(center.r > center.g and center.r > outside.r)
		elif color.y == 1.0:
			assert(center.g > center.r and center.g > outside.g)
		else:
			assert(center.b > center.r and center.b > outside.b)
	material.set_shader_parameter("light_amount", 0.0)
	await RenderingServer.frame_post_draw
	var off := viewport.get_texture().get_image()
	assert(off.get_pixel(96, 76).is_equal_approx(off.get_pixel(0, 0)), "Zero light strength must preserve city colors exactly")
	viewport.queue_free()
	await process_frame
