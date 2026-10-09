extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for zoom in [0.1, 0.25, 0.5, 1.0]:
		await _check_zoom(zoom)
	print("PASS: per-light fades at 10/25/50/100 percent, invisible prefetch, cache and camera continuity")
	quit()


func _check_zoom(zoom: float) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 64)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var fades := CityLightFade.new()
	fades.advance(17.0) # Timestamps must survive the vertex color's >1 range.
	var ground := CityNightGround.new()
	ground.fades = fades
	ground.scale = Vector2.ONE * zoom
	viewport.add_child(ground)
	(ground.material as ShaderMaterial).set_shader_parameter("strength", 1.0)
	var first := Vector2i(30, 42)
	var second := Vector2i(31, 42)
	var light := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	light.fill_rect(Rect2i(0, 16, 32, 16), Color(0.8, 0.4, 0.1, 1))
	var lamp := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	lamp.fill_rect(Rect2i(0, 0, 32, 8), Color(0.2, 0.6, 0.9, 1))
	var entry := {"texture": ImageTexture.create_from_image(light), "fixtures": ImageTexture.create_from_image(lamp), "signals": [], "origin": Vector2i.ZERO}
	ground._store(first, entry)
	ground.visible_tiles.append(first)
	ground.sync_fade_clock()
	ground.hide()
	ground.start_visible_fades(Rect2(0, 0, 128, 64))
	await RenderingServer.frame_post_draw
	assert(fades.starts.is_empty(), "Hidden preloading consumed the fade")
	ground.show()
	ground.start_visible_fades(Rect2(1000, 1000, 128, 64))
	await RenderingServer.frame_post_draw
	assert(fades.starts.is_empty(), "Offscreen drawing consumed the fade")
	ground.start_visible_fades(Rect2(0, 0, 128, 64))
	var draws := [0]
	ground.draw.connect(func() -> void: draws[0] += 1)
	await process_frame
	await RenderingServer.frame_post_draw
	var dark := viewport.get_texture().get_image()
	assert(_pixel(dark, 8, 24, zoom).r < 0.01 and _pixel(dark, 8, 4, zoom).a < 0.01, "New light appeared instantly")
	var initial_draws: int = draws[0]
	fades.advance(CityLightFade.DURATION * 0.5)
	ground.sync_fade_clock()
	await RenderingServer.frame_post_draw
	var middle := viewport.get_texture().get_image()
	assert(_pixel(middle, 8, 24, zoom).r > 0.1 and _pixel(middle, 8, 24, zoom).r < 0.7, "Ground light did not fade")
	assert(_pixel(middle, 8, 4, zoom).a > 0.35 and _pixel(middle, 8, 4, zoom).a < 0.65, "Lamp did not fade with its receiver")
	assert(draws[0] == initial_draws, "Advancing the fade rebuilt the draw list")
	var later := entry.duplicate()
	later.origin = Vector2i(48, 0)
	ground._store(second, later)
	ground.visible_tiles.append(second)
	ground.start_visible_fades(Rect2(0, 0, 128, 64))
	ground.queue_redraw()
	ground.fixtures.queue_redraw()
	await RenderingServer.frame_post_draw
	var staggered := viewport.get_texture().get_image()
	assert(_pixel(staggered, 8, 4, zoom).a > 0.35 and _pixel(staggered, 56, 4, zoom).a < 0.01, "Lights share one global fade instead of individual arrival times")
	fades.advance(CityLightFade.DURATION)
	ground.sync_fade_clock()
	await RenderingServer.frame_post_draw
	var complete := viewport.get_texture().get_image()
	assert(_pixel(complete, 8, 4, zoom).a > 0.99 and _pixel(complete, 56, 4, zoom).a > 0.99)
	assert(ground.cache[first].texture == entry.texture, "Fade replaced a cached texture")
	# A fresh artwork-size cache must reuse the same world light history.
	var small := CityNightGround.new()
	small.fades = fades
	small.scale = Vector2.ONE * zoom
	small._store(first, entry)
	small.visible_tiles.append(first)
	viewport.add_child(small)
	(small.material as ShaderMaterial).set_shader_parameter("strength", 1.0)
	small.sync_fade_clock()
	ground.hide()
	await RenderingServer.frame_post_draw
	assert(_pixel(viewport.get_texture().get_image(), 8, 4, zoom).a > 0.99, "Switching artwork size restarted a completed light")
	var birth := fades.birth(first, 128, 0)
	var rotated := first
	for rotation in range(1, 5):
		rotated = CityRotationCommand.rotate_point(rotated, 128, true)
		assert(fades.birth(rotated, 128, rotation) == birth, "Rotation restarted the light")
	small._store(first, entry.duplicate())
	small.queue_redraw()
	small.fixtures.queue_redraw()
	await RenderingServer.frame_post_draw
	assert(_pixel(viewport.get_texture().get_image(), 8, 4, zoom).a > 0.99, "Refreshing an occlusion mask restarted the light")
	fades.reset()
	small.sync_fade_clock()
	small.queue_redraw()
	small.fixtures.queue_redraw()
	await RenderingServer.frame_post_draw
	assert(_pixel(viewport.get_texture().get_image(), 8, 4, zoom).a < 0.01, "A newly opened city inherited the previous light timestamps")
	viewport.queue_free()
	await process_frame


func _pixel(pixels: Image, x: int, y: int, zoom: float) -> Color:
	return pixels.get_pixel(floori(x * zoom), floori(y * zoom))
