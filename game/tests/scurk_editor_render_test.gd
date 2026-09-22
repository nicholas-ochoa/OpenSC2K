extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "SCURK render coverage needs a native renderer")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 300)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var palette := Sc2Palette.load_bmp("res://../references/SIMCITY2000/BITMAPS/PAL_MSTR.BMP")
	assert(palette.is_valid())
	var swatches := ScurkPaletteControl.new()
	swatches.set_palette(palette)
	viewport.add_child(swatches)
	var pixels := PackedInt32Array()
	pixels.resize(4 * 4)
	pixels.fill(171)
	var canvas := ScurkPixelCanvas.new()
	canvas.position = Vector2(300, 0)
	canvas.set_sprite_data(4, 4, pixels, palette)
	canvas.show_grid = false
	canvas.set_zoom(16)
	viewport.add_child(canvas)
	canvas.set_process(false)
	var preview := ScurkViewPreview.new()
	preview.position = Vector2(400, 0)
	pixels.resize(32 * 64)
	pixels.fill(171)
	preview.set_preview(2, 32, 64, pixels, 128, palette, PackedInt32Array(), false)
	viewport.add_child(preview)
	preview.set_process(false)
	var textures := ScurkTextureControl.new()
	textures.position = Vector2(300, 100)
	textures.set_palette(palette)
	var pattern := PackedInt32Array()
	pattern.resize(64)
	pattern.fill(255)
	textures.set_patterns([pattern])
	textures.set_colors(171, 255)
	viewport.add_child(textures)
	var colors: Array[Color] = []
	for tick in [0, 20, 40]:
		swatches.set_cycle_tick(tick)
		textures.set_cycle_tick(tick)
		canvas.palette_cycle_ticks = tick
		canvas.queue_redraw()
		preview.palette_cycle_ticks = tick
		preview._rebuild_texture()
		preview.queue_redraw()
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var expected := palette.color(palette.scurk_animation_index_map(tick)[171])
		colors.append(expected)
		assert(image.get_pixel(207, 189).is_equal_approx(expected), "Palette swatch must cycle")
		assert(image.get_pixel(308, 8).is_equal_approx(expected), "Canvas must match the swatch")
		assert(image.get_pixel(408, 8).is_equal_approx(expected), "Display view must match the swatch")
		var texture_center := Vector2i(textures.position + textures.cell_rect(0).get_center())
		assert(image.get_pixelv(texture_center).is_equal_approx(expected), "Texture pattern must match the swatch")
	assert(colors[0] != colors[1] or colors[0] != colors[2])
	# A three-pixel footprint has visible edges around its complete affected region.
	canvas.set_brush(3, false)
	canvas.hover_point = Vector2i(1, 1)
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	var outline := viewport.get_texture().get_image()
	assert(outline.get_pixel(320, 47).v > 0.9)
	assert(outline.get_pixel(320, 24) == colors[-1])
	assert(canvas.pixels == PackedInt32Array([171, 171, 171, 171, 171, 171, 171, 171, 171, 171, 171, 171, 171, 171, 171, 171]))
	# Cached display images follow direct pixel edits, backgrounds, and clip display.
	canvas.hover_point = Vector2i(-1, -1)
	canvas.pixels[0] = 42
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(308, 8).is_equal_approx(palette.color(42)))
	canvas.pixels[0] = -1
	canvas.clear_background_pixels.resize(16)
	canvas.clear_background_pixels.fill(55)
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(308, 8).is_equal_approx(palette.color(55)))
	var clip_background := PackedInt32Array()
	clip_background.resize(16)
	clip_background.fill(66)
	canvas.clip_background_pixels = [clip_background]
	canvas.clip_base_size = 1
	canvas.set_clip_region_visible(true)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(308, 8).is_equal_approx(palette.color(66)))
	canvas.clear_background_pixels.clear()
	canvas.clip_background_pixels.clear()
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	var checker := viewport.get_texture().get_image()
	assert(checker.get_pixel(308, 8).is_equal_approx(Color("d8d8d8")))
	# Hidden previews retain the clock and catch up when shown again.
	preview.hide()
	preview.set_cycle_tick(80)
	preview.show()
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(408, 8).is_equal_approx(
		palette.color(palette.scurk_animation_index_map(80)[171])))
	preview.preview_indices[0] = 42
	preview._rebuild_texture()
	preview.queue_redraw()
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(401, 1).is_equal_approx(palette.color(42)))
	viewport.free()
	print("PASS: native SCURK palette, canvas and display cycling pixels, brush outline and unchanged indices")
	quit()
