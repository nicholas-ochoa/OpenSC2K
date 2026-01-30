extends SceneTree
const ForegroundPalette = preload("res://src/view/city_foreground_palette.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(16, 8)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var palette := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	palette.fill(Color.WHITE)
	palette.set_pixel(17, 0, Color.RED)
	var palette_texture := ImageTexture.create_from_image(palette)
	var indexed := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	indexed.fill(Color8(17, 17, 17, 255))
	indexed.set_pixel(0, 0, Color.TRANSPARENT)
	var texture := ImageTexture.create_from_image(indexed)
	var canvas := Node2D.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.material = ForegroundPalette.create_material(palette_texture)
	viewport.add_child(canvas)
	canvas.draw.connect(func() -> void:
		canvas.draw_rect(Rect2(0, 0, 4, 4), Color.BLUE)
		canvas.draw_texture_rect(texture, Rect2(4, 0, 4, 4), false, ForegroundPalette.INDEXED_DRAW_COLOR)
		canvas.draw_texture_rect(texture, Rect2(8, 0, 4, 4), false)
	)
	canvas.queue_redraw()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var actual := viewport.get_texture().get_image()
		assert(actual.get_pixel(1, 1) == Color.BLUE)
		assert(actual.get_pixel(5, 1) == Color.RED)
		assert(actual.get_pixel(4, 0).a == 0.0)
		assert(actual.get_pixel(9, 1) == Color8(17, 17, 17, 255))
		palette.set_pixel(17, 0, Color.GREEN)
		palette_texture.update(palette)
		await RenderingServer.frame_post_draw
		actual = viewport.get_texture().get_image()
		assert(actual.get_pixel(5, 1) == Color.GREEN, "Cached commands did not use the new palette")
		print("PASS: GPU foreground palette pixels, normal overlay colors, transparency and retained animation")
	else:
		print("PASS: foreground palette material setup; pixel checks require native rendering")
	viewport.queue_free()
	await process_frame
	quit()
