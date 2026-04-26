extends "res://tests/support/scene_case.gd"

const SidebarScene = preload("res://src/ui/shell/city_toolbar.tscn")
var clicks := 0
var requested_modes: Array[String] = []
var rotations: Array[bool] = []
var requested_groups: Array[int] = []


func run() -> void:
	var first := SidebarScene.instantiate() as CityToolbar
	var second := SidebarScene.instantiate() as CityToolbar
	assert(first.get_node("%CityView").owner == first)
	assert(first.get_node("%ToolGroups").get_child_count() == 0)
	root.add_child(first)
	root.add_child(second)
	assert(first.toolbar_buttons.size() == ToolCatalog.GROUPS.size())
	assert(first.get_node("%SpecialTools").get_children() == [first.toolbar_buttons[15], first.toolbar_buttons[16]])
	assert(first.get_node("%ZoomButtons").get_children() == [first.zoom_out_button, first.zoom_in_button, first.toolbar_buttons[17]])
	first.group_requested.connect(func(index: int) -> void: requested_groups.append(index))
	for index in first.toolbar_buttons.size():
		first.toolbar_buttons[index].pressed.emit()
	assert(requested_groups == range(ToolCatalog.GROUPS.size()))
	var assets := OriginalGameAssets.new()
	assets.load_ui(ProjectSettings.globalize_path("res://../references/SIMCITY2000"))
	first.replace_artwork(assets.toolbar_art)
	for mode in ["light", "dark"]:
		first.theme = AppUiTheme.build(mode)
		await process_frame
		await process_frame
		var grid := first.get_node("%ToolGroups") as GridContainer
		var specials := first.get_node("%SpecialTools") as GridContainer
		var zoom := first.get_node("%ZoomButtons") as HBoxContainer
		assert(grid.get_child_count() == 15 and grid.columns == 3)
		assert(is_equal_approx(grid.get_global_rect().get_center().x, specials.get_global_rect().get_center().x))
		assert(is_equal_approx(grid.size.x, zoom.size.x))
		assert(is_equal_approx(grid.global_position.x, zoom.global_position.x))
		var rotation_row := first.rotate_clockwise_button.get_parent() as Control
		assert(is_equal_approx(rotation_row.get_global_rect().get_center().x, grid.get_global_rect().get_center().x))
		assert(first.rotate_clockwise_button.size == Vector2(32, 32))
		assert(first.rotate_counter_clockwise_button.size == Vector2(32, 32))
		for index in first.toolbar_buttons.size():
			assert(first.toolbar_buttons[index].size == Vector2(32, 32))
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
	assert(not first.toolbar_buttons[17].visible)
	assert(first.zoom_in_button.visible and first.rotate_clockwise_button.visible)
	assert(not second.start_city_button.visible and not second.view_mode_buttons.underground.disabled)
	first.set_landscape_editor(false)
	assert(not first.start_city_button.visible and not first.view_mode_buttons.underground.disabled)
	first.free()
	second.free()
	await process_frame
	print("PASS: Sidebar scene ownership, independent groups, dynamic buttons and signals")
