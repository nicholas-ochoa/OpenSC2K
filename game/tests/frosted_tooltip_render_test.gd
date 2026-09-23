extends SceneTree

@warning_ignore_start("integer_division")

class Checker extends Control:
	var first := Color.BLACK
	var second := Color.WHITE


	func _draw() -> void:
		for y in range(0, int(size.y), 4):
			for x in range(0, int(size.x), 4):
				draw_rect(Rect2(x, y, 4, 4), first if (x / 4 + y / 4) % 2 == 0 else second)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Tooltip pixels need a native renderer")
	AppUiTheme.select("light", true)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384, 288)
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := Checker.new()
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	viewport.add_child(AppTooltips.new())
	await RenderingServer.frame_post_draw
	var before := viewport.get_texture().get_image()
	await _test_panel(viewport, before)
	var popup := _make_popup(viewport)
	popup.popup(Rect2i(64, 48, 224, 160))
	await _frames(3)
	var area := Rect2i(96, 96, 128, 64)
	var blurred := viewport.get_texture().get_image()
	var tint: Color = AppUiTheme.current().get_stylebox("panel", "TooltipPanel").bg_color
	var tinted_contrast := _contrast(before, area) * (1.0 - tint.a)
	assert(_contrast(blurred, area) < tinted_contrast * 0.2, "Tooltip must blur background detail")
	var expected := Color(0.5, 0.5, 0.5).lerp(Color(tint, 1.0), tint.a)
	assert(_distance(_average(blurred, area), expected) < 0.025, "Tooltip must sample the scene behind it")
	var stable := blurred.get_region(area).get_data()
	await _frames(4)
	assert(viewport.get_texture().get_image().get_region(area).get_data() == stable, "Tooltip must not sample its own prior frame")
	background.first = Color(0, 1, 0)
	background.second = Color(0, 0, 1)
	background.queue_redraw()
	await _frames(2)
	var changed := viewport.get_texture().get_image()
	assert(_average(blurred, area).r - _average(changed, area).r > 0.03, "Backdrop must follow live scene changes")
	AppUiTheme.select("dark", false)
	await _frames(2)
	var opaque := viewport.get_texture().get_image()
	assert(_contrast(opaque, area) < 0.005)
	tint = AppUiTheme.current().get_stylebox("panel", "TooltipPanel").bg_color
	assert(_distance(_average(opaque, area), tint) < 0.01, "Disabled translucency must draw an opaque tooltip")
	AppUiTheme.select("dark", true)
	popup.hide()
	var dialog := Window.new()
	dialog.borderless = true
	dialog.size = Vector2i(320, 240)
	viewport.add_child(dialog)
	var modal_background := ColorRect.new()
	modal_background.color = Color(1, 0, 0)
	modal_background.size = Vector2(dialog.size)
	dialog.add_child(modal_background)
	dialog.popup(Rect2i(24, 24, 320, 240))
	var nested := _make_popup(dialog)
	nested.popup(Rect2i(64, 48, 224, 160))
	await _frames(3)
	var modal_image := viewport.get_texture().get_image()
	tint = AppUiTheme.current().get_stylebox("panel", "TooltipPanel").bg_color
	expected = modal_background.color.lerp(Color(tint, 1.0), tint.a)
	assert(_distance(_average(modal_image, area), expected) < 0.025, "A dialog tooltip must sample the dialog surface")
	nested.hide()
	await _frames(2)
	assert(_distance(_average(viewport.get_texture().get_image(), area), modal_background.color) < 0.01)
	viewport.free()
	await process_frame
	print("PASS: native tooltip blur, placement panels, live backgrounds, opaque fallback, nested dialogs and stable frames")
	quit()


func _test_panel(viewport: SubViewport, before: Image) -> void:
	var parent := Control.new()
	parent.position = Vector2(24, 16)
	viewport.add_child(parent)
	var panel := PanelContainer.new()
	panel.theme = AppUiTheme.current()
	panel.theme_type_variation = &"TooltipPanel"
	panel.position = Vector2(40, 32)
	panel.size = Vector2(224, 160)
	panel.z_index = 10
	parent.add_child(panel)
	await _frames(3)
	var area := Rect2i(96, 96, 128, 64)
	var image := viewport.get_texture().get_image()
	var tint: Color = AppUiTheme.current().get_stylebox("panel", "TooltipPanel").bg_color
	var expected := Color(0.5, 0.5, 0.5).lerp(Color(tint, 1.0), tint.a)
	assert(_contrast(image, area) < _contrast(before, area) * (1.0 - tint.a) * 0.2)
	assert(_distance(_average(image, area), expected) < 0.025, "A placement tooltip must sample its viewport")
	panel.hide()
	await _frames(2)
	assert(viewport.get_texture().get_image().get_data() == before.get_data(), "Hiding a placement tooltip must restore the scene")
	parent.free()


func _make_popup(parent: Node) -> PopupPanel:
	var popup := PopupPanel.new()
	popup.unfocusable = true
	popup.popup_window = false
	popup.mouse_passthrough = true
	popup.theme = AppUiTheme.current()
	popup.theme_type_variation = &"TooltipPanel"
	var label := Label.new()
	label.custom_minimum_size = Vector2(200, 140)
	popup.add_child(label)
	parent.add_child(popup)
	return popup


func _frames(count: int) -> void:
	for frame in count:
		await RenderingServer.frame_post_draw


func _average(image: Image, area: Rect2i) -> Color:
	var total := Color(0, 0, 0, 0)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			total += image.get_pixel(x, y)
	return total / float(area.size.x * area.size.y)


func _contrast(image: Image, area: Rect2i) -> float:
	var minimum := 1.0
	var maximum := 0.0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var brightness := image.get_pixel(x, y).v
			minimum = minf(minimum, brightness)
			maximum = maxf(maximum, brightness)
	return maximum - minimum


func _distance(first: Color, second: Color) -> float:
	return maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b)))
