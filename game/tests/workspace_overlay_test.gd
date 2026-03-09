extends SceneTree

var map_presses := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	root.add_child(viewport)
	var workspace := preload("res://src/ui/shell/city_workspace.tscn").instantiate() as CityWorkspace
	workspace.theme = ClassicUiStyle.create_theme()
	viewport.add_child(workspace)
	await process_frame
	await process_frame
	workspace.map_view.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			map_presses += 1)
	_press(viewport, Vector2(900, 400))
	assert(map_presses == 1, "The open overlay area must deliver input to the map")
	_press(viewport, workspace.toolbar.global_position + Vector2(2, 200))
	_press(viewport, Vector2(900, 10))
	_press(viewport, Vector2(900, 790))
	assert(map_presses == 1, "Sidebar, top bar and status bar must block map clicks")
	assert(workspace.map_view.get_rect() == Rect2(Vector2.ZERO, Vector2(viewport.size)))
	assert(not workspace.has_node("Page/Content/MapPanel"))
	var panel := workspace.toolbar.get_theme_stylebox("panel") as StyleBoxFlat
	assert(panel.border_width_left == 0 and panel.border_width_right == 2)
	assert(panel.border_width_top == 0 and panel.border_width_bottom == 0)
	assert(panel.border_color == Color("808080"))
	var menu_panel := workspace.menu_bar.get_theme_stylebox("panel") as StyleBoxFlat
	assert(menu_panel.border_color == Color("808080"))
	assert(menu_panel.border_width_left == 2 and menu_panel.border_width_right == 2)
	assert(menu_panel.border_width_top == 2 and menu_panel.border_width_bottom == 2)

	for state in ["normal", "hover"]:
		var box := workspace.toolbar.toolbar_buttons[0].get_theme_stylebox(state) as StyleBoxFlat
		assert(box.border_color == Color("808080"))

	var menu_count := 0

	for child in workspace.menu_bar.file_menu.get_parent().get_children():
		if child is MenuButton:
			assert(child.switch_on_hover)

			if child.text == "Windows":
				var popup: PopupMenu = child.get_popup()
				assert(popup.get_item_text(popup.item_count - 1) == "Debug Info")
				assert(popup.get_item_id(popup.item_count - 1) == 7)
			elif child.text == "Help":
				assert(child.get_popup().item_count == 1 and child.get_popup().get_item_text(0) == "About")

			menu_count += 1

	assert(menu_count == 8)
	viewport.free()
	await process_frame
	print("PASS: Full-window map, overlay input blocking, toolbar borders and menu hover settings")
	quit()


func _press(viewport: SubViewport, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	viewport.push_input(motion, true)
	var button := InputEventMouseButton.new()
	button.position = position
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	viewport.push_input(button, true)
	button = button.duplicate() as InputEventMouseButton
	button.pressed = false
	viewport.push_input(button, true)
