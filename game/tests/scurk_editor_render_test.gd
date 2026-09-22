extends SceneTree

@warning_ignore_start("integer_division")


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
	canvas.clear_background_pixels.clear()
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	assert(canvas.display_texture.get_image().get_pixel(0, 0).a == 0.0)
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
	await _test_clip_display(palette)
	await _test_modern_display(palette)
	await _test_selection_animation(palette)
	print("PASS: native SCURK cycling, clipping, layers, paste, comparison, palette highlights and selection animation")
	quit()


func _test_clip_display(palette: Sc2Palette) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(520, 520)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := ScurkPixelCanvas.new()
	canvas.position = Vector2(4, 4)
	canvas.show_grid = false
	viewport.add_child(canvas)
	canvas.set_process(false)
	var pixels := PackedInt32Array()
	pixels.resize(128 * 256)
	pixels.fill(42)
	canvas.clear_background_pixels.resize(pixels.size())
	canvas.clear_background_pixels.fill(252)
	for pair in [Vector2i(32, 1), Vector2i(128, 2)]:
		canvas.clear_edit_region()
		canvas.set_sprite_data(128, 256, pixels, palette)
		canvas.set_zoom(pair.y)
		canvas.set_edit_region(ScurkDrawingWorkspace.clip_mask(pair.x), pair.x / 32)
		var before := canvas.pixels.duplicate()
		canvas.set_clip_region_visible(true)
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var left := 4 + canvas.DISPLAY_MARGIN + canvas.clip_columns.x * canvas.zoom - 1
		var right := 4 + canvas.DISPLAY_MARGIN + (canvas.clip_columns.y + 1) * canvas.zoom
		for y in [4, 4 + 256 * canvas.zoom - 1]:
			assert(image.get_pixel(left, y).is_equal_approx(Color.WHITE))
			assert(image.get_pixel(right, y).is_equal_approx(Color.WHITE))
		assert(image.get_pixel(left + 1, 4).is_equal_approx(palette.color(42)))
		assert(image.get_pixel(right - 1, 4).is_equal_approx(palette.color(42)))
		assert(canvas.pixels == before)
		assert(canvas._point_from_position(Vector2(canvas.DISPLAY_MARGIN, 0)) == Vector2i.ZERO)
		assert(canvas._point_from_position(Vector2.ZERO).x == -1)
		canvas.set_clip_region_visible(false)
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().get_pixel(left, 4).a == 0.0)
	# Terrain uses the same nearest-neighbor sampling as each selected artwork view.
	canvas.clear_edit_region()
	pixels.resize(64)
	pixels.fill(-1)
	canvas.set_sprite_data(8, 8, pixels, palette)
	canvas.clear_background_pixels.resize(64)
	for index in 64:
		canvas.clear_background_pixels[index] = 50 + index
	for view in 3:
		canvas.set_background_view(view)
		await RenderingServer.frame_post_draw
		var image := canvas.display_texture.get_image()
		var divisor := ScurkDrawingWorkspace.view_divisor(view)
		for y in 8:
			for x in 8:
				var source_x := (x / divisor) * divisor + divisor - 1
				var source_y := (y / divisor) * divisor + divisor - 1
				assert(image.get_pixel(x, y).is_equal_approx(palette.color(50 + source_y * 8 + source_x)))
	canvas.clear_background_pixels.fill(252)
	canvas.pixels[0] = 252
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	var transparent := canvas.display_texture.get_image()
	assert(transparent.get_pixel(0, 0).is_equal_approx(palette.color(252)))
	assert(transparent.get_pixel(1, 0).a == 0.0)
	viewport.free()


func _test_modern_display(palette: Sc2Palette) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := ScurkPixelCanvas.new()
	canvas.show_grid = false
	canvas.set_palette_cycle_enabled(false)
	canvas.set_zoom(8)
	var pixels := PackedInt32Array()
	pixels.resize(16)
	pixels.fill(-1)
	pixels[0] = 10
	canvas.set_sprite_data(4, 4, pixels, palette)
	canvas.layer_below_pixels = pixels.duplicate()
	canvas.layer_below_pixels.fill(42)
	canvas.layer_above_pixels = pixels.duplicate()
	canvas.layer_above_pixels.fill(-1)
	canvas.layer_above_pixels[1] = 30
	viewport.add_child(canvas)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	assert(image.get_pixel(5, 4).is_equal_approx(palette.color(10)))
	assert(image.get_pixel(13, 4).is_equal_approx(palette.color(30)))
	assert(image.get_pixel(21, 4).is_equal_approx(palette.color(42)))
	canvas.active_layer_visible = false
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	assert(image.get_pixel(5, 4).is_equal_approx(palette.color(42)))
	assert(image.get_pixel(13, 4).is_equal_approx(palette.color(30)))
	assert(canvas.pixels == pixels)
	canvas.active_layer_visible = true
	canvas.clipboard_width = 1
	canvas.clipboard_height = 1
	canvas.clipboard_pixels = PackedInt32Array([55])
	canvas.begin_paste(Vector2i(2, 2))
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	assert(image.get_pixel(21, 20).is_equal_approx(palette.color(55)))
	assert(canvas.pixels == pixels)
	canvas.cancel_paste()
	canvas.comparison_pixels = pixels.duplicate()
	canvas.comparison_pixels.fill(60)
	canvas.comparison_mode = 1
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	assert(image.get_pixel(5, 4).is_equal_approx(palette.color(60)))
	canvas.comparison_mode = 2
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	assert(_color_near(image.get_pixel(5, 4), palette.color(10).lerp(palette.color(60), 0.5)))
	canvas.comparison_mode = 3
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	assert(_color_near(image.get_pixel(5, 4), Color(1.0, 0.25, 0.7)))
	canvas.comparison_mode = 0
	canvas.highlighted_palette_index = 42
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	assert(_color_near(image.get_pixel(21, 4), palette.color(42).lerp(Color.WHITE, 0.6)))
	assert(canvas.pixels == pixels)
	viewport.free()


func _test_selection_animation(palette: Sc2Palette) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 96)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := ScurkPixelCanvas.new()
	canvas.position = Vector2(16, 16)
	canvas.show_grid = false
	canvas.set_palette_cycle_enabled(false)
	canvas.set_zoom(8)
	var pixels := PackedInt32Array()
	pixels.resize(64)
	pixels.fill(42)
	canvas.set_sprite_data(8, 8, pixels, palette)
	viewport.add_child(canvas)
	canvas.set_process(false)
	var art_draws := [0]
	canvas.draw.connect(func() -> void: art_draws[0] += 1)
	var outline := ScurkSelectionOutline.new()
	outline.position = Vector2(canvas.DISPLAY_MARGIN, 0)
	canvas.add_child(outline)
	var edges := PackedVector2Array()
	for offset in range(8, 56):
		edges.append_array(PackedVector2Array([
			Vector2(offset, 8), Vector2(offset + 1, 8),
			Vector2(56, offset), Vector2(56, offset + 1),
			Vector2(offset + 1, 56), Vector2(offset, 56),
			Vector2(8, offset + 1), Vector2(8, offset),
		]))
	outline.configure(edges, true)
	outline.set_process(false)
	await RenderingServer.frame_post_draw
	var first := viewport.get_texture().get_image()
	var first_draws: int = art_draws[0]
	outline._process(outline.FRAME_SECONDS * 4.0)
	await RenderingServer.frame_post_draw
	var second := viewport.get_texture().get_image()
	assert(first.get_region(Rect2i(25, 23, 48, 3)).get_data() != second.get_region(Rect2i(25, 23, 48, 3)).get_data())
	assert(first.get_region(Rect2i(30, 30, 36, 36)).get_data() == second.get_region(Rect2i(30, 30, 36, 36)).get_data())
	assert(canvas.pixels == pixels)
	assert(art_draws[0] == first_draws, "Selection animation must not redraw the artwork")
	outline.configure(edges, false)
	assert(not outline.is_processing())
	outline._process(1.0)
	assert(outline.phase == 0)
	outline.configure(edges, true)
	canvas.hide()
	assert(not outline.is_processing())
	outline._process(1.0)
	assert(outline.phase == 0)
	canvas.show()
	assert(outline.is_processing())
	outline.configure(PackedVector2Array(), true)
	assert(not outline.is_processing())
	outline._process(1.0)
	assert(outline.phase == 0)
	viewport.free()


func _color_near(value: Color, expected: Color) -> bool:
	return absf(value.r - expected.r) < 0.01 and absf(value.g - expected.g) < 0.01 and absf(value.b - expected.b) < 0.01 and absf(value.a - expected.a) < 0.01
