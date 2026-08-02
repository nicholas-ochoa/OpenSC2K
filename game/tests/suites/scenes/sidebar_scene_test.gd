extends "res://tests/support/scene_case.gd"

const SidebarScene = preload("res://src/ui/shell/city_toolbar.tscn")
var clicks := 0
var requested_modes: Array[CityViewMode.Mode] = []
var rotations: Array[bool] = []
var requested_groups: Array[int] = []


func run() -> void:
	var first := SidebarScene.instantiate() as CityToolbar
	var second := SidebarScene.instantiate() as CityToolbar
	root.add_child(first)
	root.add_child(second)
	assert(first.toolbar_buttons.size() == ToolCatalog.GROUPS.size())
	first.group_requested.connect(func(index: int) -> void: requested_groups.append(index))
	for index in first.toolbar_buttons.size():
		first.toolbar_buttons[index].pressed.emit()
	assert(requested_groups == range(ToolCatalog.GROUPS.size()))
	assert(first.view_mode_buttons[CityViewMode.Mode.CITY].button_group != second.view_mode_buttons[CityViewMode.Mode.CITY].button_group)
	first.view_mode_buttons[CityViewMode.Mode.UNDERGROUND].button_pressed = true
	assert(second.view_mode_buttons[CityViewMode.Mode.CITY].button_pressed)
	first.button_clicked.connect(func() -> void:
		clicks += 1)
	first.overlay_requested.connect(func(mode: CityViewMode.Mode) -> void:
		requested_modes.append(mode))
	first.rotate_requested.connect(func(counter_clockwise: bool) -> void:
		rotations.append(counter_clockwise))
	first.view_mode_buttons[CityViewMode.Mode.UNDERGROUND].pressed.emit()
	first.rotate_clockwise_button.pressed.emit()
	first.rotate_counter_clockwise_button.pressed.emit()
	assert(clicks == 3 and rotations == [false, true])
	first.data_view_input.item_selected.emit(1)
	assert(requested_modes == [CityViewMode.Mode.UNDERGROUND, CityViewMode.DATA_MODES[0]])
	first.show_tool_group(9, null)
	first.child_tool_buttons[0].pressed.emit()
	assert(clicks == 4, "Wrong click connection count on a child button")
	first.set_landscape_editor(true)
	assert(first.start_city_button.visible and first.view_mode_buttons[CityViewMode.Mode.UNDERGROUND].disabled)
	assert(not first.toolbar_buttons[17].visible)
	assert(first.zoom_in_button.visible and first.rotate_clockwise_button.visible)
	assert(not second.start_city_button.visible and not second.view_mode_buttons[CityViewMode.Mode.UNDERGROUND].disabled)
	first.set_landscape_editor(false)
	assert(not first.start_city_button.visible and not first.view_mode_buttons[CityViewMode.Mode.UNDERGROUND].disabled)
	first.free()
	second.free()
	await process_frame
	print("PASS: Sidebar independent groups, dynamic buttons and signals")
