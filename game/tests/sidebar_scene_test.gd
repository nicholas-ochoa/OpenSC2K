extends SceneTree

const SidebarScene = preload("res://src/ui/shell/city_toolbar.tscn")
var clicks := 0
var requested_modes: Array[String] = []
var rotations: Array[bool] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var first := SidebarScene.instantiate() as CityToolbar
	var second := SidebarScene.instantiate() as CityToolbar
	assert(first.get_node("%CityView").owner == first)
	assert(first.get_node("%ToolGroups").get_child_count() == 0)
	root.add_child(first)
	root.add_child(second)
	assert(first.toolbar_buttons.size() == ToolCatalog.GROUPS.size())
	assert(first.view_mode_buttons.city.button_group != second.view_mode_buttons.city.button_group)
	first.view_mode_buttons.underground.button_pressed = true
	assert(second.view_mode_buttons.city.button_pressed)
	first.button_clicked.connect(func() -> void:
		clicks += 1)
	first.overlay_requested.connect(func(mode: String) -> void:
		requested_modes.append(mode))
	first.rotate_requested.connect(func(counter_clockwise: bool) -> void:
		rotations.append(counter_clockwise))
	first.view_mode_buttons.underground.pressed.emit()
	first.rotate_clockwise_button.pressed.emit()
	first.rotate_counter_clockwise_button.pressed.emit()
	assert(clicks == 3 and rotations == [false, true])
	first.data_view_input.item_selected.emit(1)
	assert(requested_modes == ["underground", CityDataView.MODES[0]])
	first.show_tool_group(9, null)
	first.child_tool_buttons[0].pressed.emit()
	assert(clicks == 4, "Wrong click connection count on a child button")
	first.set_landscape_editor(true)
	assert(first.start_city_button.visible and first.view_mode_buttons.underground.disabled)
	assert(not second.start_city_button.visible and not second.view_mode_buttons.underground.disabled)
	first.set_landscape_editor(false)
	assert(not first.start_city_button.visible and not first.view_mode_buttons.underground.disabled)
	first.free()
	second.free()
	await process_frame
	print("PASS: Sidebar scene ownership, independent groups, dynamic buttons and signals")
	quit()
