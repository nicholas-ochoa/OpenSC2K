extends SceneTree
## Keys and mouse buttons start their bound actions in the city view. The
## keyboard and mouse cases share one application fixture.

const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")

var main: CityApplication


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	root.add_child(main)
	await process_frame
	main.city_session.activate_document(EmptyCityTemplate.create())
	main.interface.hide_main_menu()
	main.frame.select_speed(GameSpeed.Speed.PAUSED)
	await process_frame
	await preload("res://tests/support/app_fixture.gd").wait_for_visuals(main)
	assert(main.camera_input.camera_keys_allowed(), "The city view accepts map keys")

	_test_speed_keys()
	_test_tool_and_zoom_keys()
	_test_camera_keys()
	_test_menu_hints_and_rebinding()
	_test_focus_and_extras()
	_test_mouse_buttons()
	_test_tool_modifiers()

	main.queue_free()
	await process_frame
	print("PASS: control dispatch for speed, tools, camera, menus, rebinding, and mouse buttons")
	quit()


func _test_speed_keys() -> void:
	var controller := main.simulation_state.speed_controller
	var popup := main.speed_menu.get_popup()

	for pair in [[KEY_1, GameSpeed.Speed.TURTLE], [KEY_2, GameSpeed.Speed.LLAMA], [KEY_3, GameSpeed.Speed.CHEETAH],
			[KEY_4, GameSpeed.Speed.AFRICAN_SWALLOW]]:
		_press(pair[0])
		assert(controller.speed == pair[1], "Key %s selects its speed" % OS.get_keycode_string(pair[0]))
		assert(popup.is_item_checked(popup.get_item_index(pair[1] - GameSpeed.Speed.PAUSED)), "The Speed menu follows the key")

	_press(KEY_SPACE)
	assert(controller.speed == GameSpeed.Speed.PAUSED)
	assert(popup.is_item_checked(popup.get_item_index(0)))
	_press(KEY_SPACE)
	assert(controller.speed == GameSpeed.Speed.AFRICAN_SWALLOW, "Space resumes the remembered speed")
	# a city that opened paused has no remembered speed and resumes at Turtle
	main.frame.select_speed(GameSpeed.Speed.PAUSED)
	main.simulation_state.resume_speed = GameSpeed.Speed.PAUSED
	_press(KEY_SPACE)
	assert(controller.speed == GameSpeed.Speed.TURTLE)
	_press(KEY_SPACE)
	assert(controller.speed == GameSpeed.Speed.PAUSED)


func _test_tool_and_zoom_keys() -> void:
	for pair in [[KEY_Z, CityToolIds.Group.QUERY], [KEY_X, CityToolIds.Group.BULLDOZER], [KEY_C, CityToolIds.Group.CENTERING]]:
		_press(pair[0])
		assert(main.tool_state.selected_group == pair[1], "Key %s selects its tool" % OS.get_keycode_string(pair[0]))

	main.camera_input.choose_tool_group(CityToolIds.Group.ROADS)
	var subtool := main.tool_state.selected_subtool
	_press(KEY_TAB)
	assert(main.tool_state.selected_subtool != subtool, "Tab selects the next tool in the group")
	_press(KEY_TAB, true)
	assert(main.tool_state.selected_subtool == subtool, "Shift+Tab selects the previous tool")
	var zoom := main.map_view.zoom_percent()
	_press(KEY_E)
	assert(main.map_view.zoom_percent() > zoom)
	_press(KEY_Q)
	_press(KEY_Q)
	assert(main.map_view.zoom_percent() < zoom)
	_press(KEY_0)
	assert(main.map_view.zoom_percent() == 100, "0 resets the zoom")


func _test_camera_keys() -> void:
	var motion := main.view_state.camera_motion
	_press(KEY_W)
	_press(KEY_UP)
	assert(motion.held_direction() == Vector2.UP)
	# releasing one key keeps the camera moving for the other key
	main.camera_input.input(_key(KEY_W, false))
	assert(motion.held_direction() == Vector2.UP and motion.held_keys.size() == 1)
	main.camera_input.input(_key(KEY_UP, false))
	assert(motion.held_direction() == Vector2.ZERO)
	_press(KEY_LEFT)
	_press(KEY_D)
	assert(motion.held_direction() == Vector2.ZERO)
	main.camera_input.input(_key(KEY_LEFT, false))
	assert(motion.held_direction() == Vector2.RIGHT)
	main.camera_input.input(_key(KEY_D, false))


func _test_menu_hints_and_rebinding() -> void:
	var speed_popup := main.speed_menu.get_popup() as ScurkContextMenu
	assert(speed_popup.hints.get(speed_popup.get_item_index(1)) == "1", "The Speed menu shows the Turtle key")
	var file_popup := main.city_menu_bar.file_menu.get_popup() as ScurkContextMenu
	assert(file_popup.hints.has(file_popup.get_item_index(CityMenuBar.MENU_SAVE_CITY)))
	var bindings := ControlBindings.defaults()
	bindings.remove_binding("tool_query", ControlBinding.key(KEY_Z))
	bindings.add("tool_query", ControlBinding.key(KEY_K))
	bindings.remove_binding("speed_turtle", ControlBinding.key(KEY_1))
	bindings.add("speed_turtle", ControlBinding.key(KEY_7))
	main.preferences.control_bindings = bindings
	main.settings.apply_control_bindings()
	assert(speed_popup.hints.get(speed_popup.get_item_index(1)) == "7", "Menu hints follow the new binding")
	main.camera_input.choose_tool_group(CityToolIds.Group.ROADS)
	_press(KEY_Z)
	assert(main.tool_state.selected_group == CityToolIds.Group.ROADS, "The old key does nothing")
	_press(KEY_K)
	assert(main.tool_state.selected_group == CityToolIds.Group.QUERY, "The new key selects the tool")
	main.preferences.control_bindings = ControlBindings.defaults()
	main.settings.apply_control_bindings()


func _test_focus_and_extras() -> void:
	var field := LineEdit.new()
	main.add_child(field)
	field.grab_focus()
	main.camera_input.choose_tool_group(CityToolIds.Group.ROADS)
	_press(KEY_Z)
	assert(main.tool_state.selected_group == CityToolIds.Group.ROADS, "No map key starts while a text field has focus")
	field.release_focus()
	field.queue_free()
	# a focused button does not take Space or the arrow keys
	main.zoom_in_button.grab_focus()
	var controller := main.simulation_state.speed_controller
	var space := _key(KEY_SPACE)
	main.camera_input.input(space)
	assert(controller.speed == GameSpeed.Speed.TURTLE, "Space reaches the map before a focused button")
	main.zoom_in_button.release_focus()
	main.frame.select_speed(GameSpeed.Speed.PAUSED)
	_press(KEY_U)
	assert(main.view_state.overlay_mode == CityViewMode.Mode.UNDERGROUND)
	_press(KEY_V)
	assert(main.view_state.overlay_mode == CityViewMode.Mode.CITY)
	_press(KEY_PERIOD)
	assert(main.status_label.text == "Rotated clockwise")
	_press(KEY_COMMA)
	assert(main.status_label.text == "Rotated counterclockwise")
	_press(KEY_G)
	assert(main.city_dialogs.graph_window.visible, "G opens the graphs")
	main.city_dialogs.graph_window.hide()


func _test_mouse_buttons() -> void:
	var map := main.map_view
	var interaction := map.interaction
	var centers: Array[Vector2i] = []
	map.center_requested.connect(func(point: Vector2i) -> void: centers.append(point))
	var middle := _mouse(MOUSE_BUTTON_MIDDLE, map.size * 0.5, true)
	interaction._handle_mouse_button(middle)
	interaction._handle_mouse_button(_mouse(MOUSE_BUTTON_MIDDLE, map.size * 0.5, false))
	assert(centers.size() == 1, "A middle click centers the map")
	interaction._handle_mouse_button(_mouse(MOUSE_BUTTON_RIGHT, map.size * 0.5, true))
	interaction._handle_mouse_button(_mouse(MOUSE_BUTTON_RIGHT, map.size * 0.5, false))
	assert(map.context_menu.visible, "A right click opens the context menu")
	map.context_menu.hide()

	# a drag with either button moves the map and runs no click action
	for button in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		var center := map.source_center
		interaction._handle_mouse_button(_mouse(button, map.size * 0.5, true))
		var drag := InputEventMouseMotion.new()
		drag.relative = Vector2(30, 20)
		drag.position = map.size * 0.5 + drag.relative
		drag.button_mask = 1 << (button - 1)
		interaction._handle_mouse_motion(drag)
		interaction._handle_mouse_button(_mouse(button, drag.position, false))
		assert(map.source_center != center, "A drag moves the map")

	assert(centers.size() == 1 and not map.context_menu.visible, "A drag runs no click action")
	# a right click cancels an active selection before it opens the menu
	var canceled := [0]
	map.selection_canceled.connect(func() -> void: canceled[0] += 1)
	map.selection_start = Vector2i(10, 10)
	map.selection_end = Vector2i(12, 12)
	interaction._handle_mouse_button(_mouse(MOUSE_BUTTON_RIGHT, map.size * 0.5, true))
	interaction._handle_mouse_button(_mouse(MOUSE_BUTTON_RIGHT, map.size * 0.5, false))
	assert(canceled[0] == 1 and not map.context_menu.visible, "Right click first cancels the selection")
	# the wheel and the extra buttons use their bindings
	var zoom := map.zoom_percent()
	interaction._handle_mouse_button(_mouse(MOUSE_BUTTON_WHEEL_DOWN, map.size * 0.5, true))
	assert(map.zoom_percent() < zoom, "Wheel down zooms out")
	interaction._handle_mouse_button(_mouse(MOUSE_BUTTON_XBUTTON1, map.size * 0.5, true))
	assert(main.status_label.text == "Rotated counterclockwise", "Mouse 4 rotates counterclockwise")
	# a mouse button bound to a camera direction moves while it is down
	main.preferences.control_bindings.add("camera_left", ControlBinding.mouse(MOUSE_BUTTON_XBUTTON2))
	main.preferences.control_bindings.remove_binding("rotate_clockwise", ControlBinding.mouse(MOUSE_BUTTON_XBUTTON2))
	interaction._handle_mouse_button(_mouse(MOUSE_BUTTON_XBUTTON2, map.size * 0.5, true))
	assert(main.view_state.camera_motion.held_direction() == Vector2.LEFT)
	main.camera_input.input(_mouse(MOUSE_BUTTON_XBUTTON2, map.size * 0.5, false))
	assert(main.view_state.camera_motion.held_direction() == Vector2.ZERO)
	main.preferences.control_bindings = ControlBindings.defaults()
	main.settings.apply_control_bindings()


# the line or rectangle and query modifiers follow their bindings
func _test_tool_modifiers() -> void:
	var interaction := main.map_view.interaction
	var bindings := ControlBindings.defaults()
	bindings.remove_binding("tool_shape_modifier", ControlBinding.key(KEY_SHIFT))
	bindings.add("tool_shape_modifier", ControlBinding.key(KEY_L))
	bindings.remove_binding("tool_query_modifier", ControlBinding.key(KEY_SHIFT))
	bindings.add("tool_query_modifier", ControlBinding.key(KEY_ALT))
	main.preferences.control_bindings = bindings
	main.settings.apply_control_bindings()
	interaction._input(_key(KEY_L))
	assert(interaction.shape_held and not interaction.query_held)
	interaction._input(_key(KEY_L, false))
	assert(not interaction.shape_held)
	var shift := _key(KEY_SHIFT)
	shift.shift_pressed = true
	interaction._input(shift)
	assert(interaction.shift_pressed and not interaction.shape_held and not interaction.query_held, "Shift is not bound")
	interaction._input(_key(KEY_SHIFT, false))
	var queries: Array[Vector2i] = []
	main.map_view.query_requested.connect(func(point: Vector2i) -> void: queries.append(point))
	main.map_view.edit_enabled = true
	main.map_view.shift_query_enabled = true
	main.map_view.shift_line_enabled = false
	main.map_view.shift_rectangle_enabled = false
	var click := _mouse(MOUSE_BUTTON_LEFT, main.map_view.size * 0.5, true)
	click.alt_pressed = true
	interaction._handle_mouse_button(click)
	assert(queries.size() == 1, "The bound query modifier queries the tile")
	main.query_choices.close_query()
	# the SCURK editor menus show its own bindings
	main.scurk_workspace._ensure_scurk_editor()
	var file_popup := (main.scurk_editor.get_node("Panel/Content/Toolbar/Row/File") as MenuButton).get_popup() as ScurkContextMenu
	var save_index := file_popup.get_item_index(2)
	assert(file_popup.hints.get(save_index) == ControlBinding.from_text("key:Command+S").display_text())
	bindings.remove_binding("scurk_save", ControlBinding.from_text("key:Command+S"))
	bindings.add("scurk_save", ControlBinding.key(KEY_F2))
	main.settings.apply_control_bindings()
	assert(file_popup.hints.get(save_index) == ControlBinding.key(KEY_F2).display_text())
	assert(main.scurk_editor.pixel_canvas.control_bindings == bindings)
	main.preferences.control_bindings = ControlBindings.defaults()
	main.settings.apply_control_bindings()
	# the music keys are bindable and still work on every screen
	assert(main.controls.handle_music_key(_key(KEY_MEDIANEXT)))
	main.preferences.control_bindings.remove_binding("music_next", ControlBinding.key(KEY_MEDIANEXT))
	main.preferences.control_bindings.add("music_next", ControlBinding.key(KEY_F8))
	assert(not main.controls.handle_music_key(_key(KEY_MEDIANEXT)))
	assert(main.controls.handle_music_key(_key(KEY_F8)))
	main.preferences.control_bindings = ControlBindings.defaults()
	main.settings.apply_control_bindings()


func _press(keycode: Key, shift := false) -> void:
	var event := _key(keycode)
	event.shift_pressed = shift
	main.camera_input.unhandled_key_input(event)


func _key(keycode: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = pressed
	event.keycode = keycode
	event.physical_keycode = keycode

	return event


func _mouse(button: MouseButton, position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.pressed = pressed

	return event
