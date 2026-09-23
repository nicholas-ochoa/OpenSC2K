extends SceneTree


func _initialize() -> void:
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 0.01)
	call_deferred("_run")


func _run() -> void:
	AppUiTheme.select("light", true)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.gui_embed_subwindows = true
	root.add_child(viewport)
	var app := Control.new()
	app.size = Vector2(viewport.size)
	app.theme = AppUiTheme.current()
	viewport.add_child(app)
	app.add_child(AppTooltips.new())
	var source := Button.new()
	source.position = Vector2(24, 24)
	source.size = Vector2(120, 48)
	source.tooltip_text = "Tooltip test"
	app.add_child(source)
	await process_frame
	await _hover(viewport, source.get_global_rect().get_center())
	var popup := _find_popup(viewport)
	assert(popup != null, "A normal control must create its tooltip")
	var effect := _popup_effect(popup)
	assert(effect != null, "Dynamic tooltips must receive the shared backdrop")
	var layer := effect.get("_layer") as CanvasLayer
	var surface := effect.get("_surface") as PanelContainer
	assert(layer != null and layer.visible and effect.is_processing())
	assert(popup.canvas_cull_mask == 0, "The source tooltip must not draw twice")
	_assert_sharp_labels(surface)
	var old_position := surface.position
	popup.position += Vector2i(17, 11)
	await process_frame
	assert(surface.position == old_position + Vector2(17, 11), "Backdrop must follow popup placement")
	var copy := _find_copy(surface)
	assert(copy != null and copy.copy_mode != BackBufferCopy.COPY_MODE_DISABLED)
	for theme_name in ["dark", "light"]:
		AppUiTheme.select(theme_name, false)
		await process_frame
		assert(not layer.visible and not effect.is_processing())
		assert(popup.canvas_cull_mask != 0)
		assert(popup.get_theme_stylebox("panel").bg_color.a == 1.0)
		assert(copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED)
		AppUiTheme.select(theme_name, true)
		await process_frame
		assert(layer.visible and effect.is_processing())
		_assert_sharp_labels(surface)
	popup.hide()
	await process_frame
	assert(not layer.visible and not effect.is_processing())
	assert(copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED)
	var dialog := AcceptDialog.new()
	dialog.size = Vector2i(300, 180)
	app.add_child(dialog)
	var inner := Button.new()
	inner.position = Vector2(32, 32)
	inner.size = Vector2(100, 40)
	inner.tooltip_text = "Nested tooltip test"
	dialog.add_child(inner)
	dialog.popup(Rect2i(200, 160, 300, 180))
	await process_frame
	await _hover(dialog, inner.get_rect().get_center())
	var nested := _find_popup(dialog)
	assert(nested != null, "An embedded dialog must create its tooltip")
	var nested_effect := _popup_effect(nested)
	assert(nested_effect != null)
	var nested_layer := nested_effect.get("_layer") as CanvasLayer
	assert(nested_layer.custom_viewport == viewport, "Nested tooltips must sample the containing viewport")
	_assert_sharp_labels(nested_effect.get("_surface"))
	await _test_panel(app)
	var layer_ref: WeakRef = weakref(layer)
	var nested_ref: WeakRef = weakref(nested_layer)
	var app_ref: WeakRef = weakref(app)
	app.queue_free()
	await process_frame
	await process_frame
	assert(app_ref.get_ref() == null and layer_ref.get_ref() == null and nested_ref.get_ref() == null)
	viewport.free()
	print("PASS: dynamic and nested tooltip blur, live theme fallback, sharp content and cleanup")
	quit()


func _test_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"TooltipPanel"
	panel.position = Vector2(20, 120)
	var label := Label.new()
	label.text = "Placement reason"
	panel.add_child(label)
	parent.add_child(panel)
	await process_frame
	await process_frame
	assert(panel.material is ShaderMaterial)
	_assert_sharp_labels(panel)
	var copy := _find_copy(panel)
	assert(copy != null and copy.copy_mode != BackBufferCopy.COPY_MODE_DISABLED)
	FrostedTooltipPanel.bind(panel)
	assert(_count_copies(panel) == 1, "Repeated binding must reuse one backdrop")
	panel.hide()
	assert(copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED and panel.material == null)
	panel.show()
	assert(copy.copy_mode != BackBufferCopy.COPY_MODE_DISABLED)
	AppUiTheme.select("light", false)
	await process_frame
	assert(copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED and panel.material == null)
	AppUiTheme.select("light", true)
	panel.queue_free()


func _hover(viewport: Viewport, point: Vector2) -> void:
	viewport.notify_mouse_entered()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	await create_timer(0.08).timeout
	await process_frame
	await process_frame


func _find_popup(node: Node) -> PopupPanel:
	for child in node.get_children(true):
		if child is PopupPanel and child.theme_type_variation == &"TooltipPanel" and child.visible:
			return child
		var found := _find_popup(child)
		if found != null:
			return found
	return null


func _popup_effect(popup: PopupPanel) -> Node:
	for child in popup.get_children():
		if child.get_script() == preload("res://src/ui/shared/frosted_tooltip.gd"):
			return child
	return null


func _assert_sharp_labels(node: Node) -> void:
	var labels := 0
	for child in node.get_children():
		if child is Label:
			assert(child.material == null and not child.use_parent_material, "Tooltip text must not inherit blur")
			labels += 1
	assert(labels > 0)


func _find_copy(node: Node) -> BackBufferCopy:
	for child in node.get_children():
		if child is BackBufferCopy:
			return child
		var found := _find_copy(child)
		if found != null:
			return found
	return null


func _count_copies(node: Node) -> int:
	var count := int(node is BackBufferCopy)
	for child in node.get_children():
		count += _count_copies(child)
	return count
