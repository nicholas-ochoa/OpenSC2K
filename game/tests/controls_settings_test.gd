extends SceneTree
## The Controls tab applies and saves each binding change at once. Use Defaults
## resets the controls after a warning. Other settings also apply at once.

var main: CityApplication
var dialog: AppSettingsDialog
var settings_path := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	# the fixture keeps preferences in the disposable test profile
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	settings_path = main.preferences.settings_path
	root.add_child(main)
	await process_frame
	main.city_session.activate_document(EmptyCityTemplate.create())
	main.interface.hide_main_menu()
	dialog = main.main_overlays.settings_dialog

	await _test_tab_visibility()
	await _test_row_layout()
	_test_capture_and_conflicts()
	_test_use_defaults()
	_test_immediate_apply()

	main.queue_free()
	await process_frame
	print("PASS: Controls tab capture, conflicts, Use Defaults, and immediate settings changes")
	quit()


func _test_tab_visibility() -> void:
	main.settings.open_settings_dialog()
	assert(dialog.visible and not dialog.use_defaults_button.is_visible_in_tree(), "Use Defaults is hidden on other tabs")
	dialog.tabs.current_tab = AppSettingsDialog.CONTROLS_TAB
	await process_frame
	assert(dialog.use_defaults_button.is_visible_in_tree())
	assert(dialog.use_defaults_button.get_parent() != dialog.get_ok_button().get_parent(), "Use Defaults has its own row")
	assert(dialog.use_defaults_button.get_global_rect().position.y > dialog.tabs.get_global_rect().end.y - 1.0,
		"Use Defaults is below the tab panel")
	assert(dialog.use_defaults_button.get_global_rect().end.y <= dialog.get_ok_button().get_global_rect().position.y,
		"Use Defaults is above the dialog buttons")
	dialog.tabs.current_tab = 0
	assert(not dialog.use_defaults_button.is_visible_in_tree())
	dialog.tabs.current_tab = AppSettingsDialog.CONTROLS_TAB


func _test_row_layout() -> void:
	var list := dialog.controls_list
	var starts := {}
	var previous: Node

	for row in list.get_children():
		if row is HBoxContainer:
			assert(previous is HSeparator, "A separator is above %s" % row.name)
			var label := row.get_node("Label") as Label
			starts[roundi(label.get_global_rect().end.x)] = true
			assert(label.get_global_rect().size.x == ControlsBindingList.LABEL_WIDTH, "%s label wraps" % row.name)

		previous = row

	assert(starts.size() == 1, "Bindings start at the same place on every row")
	# chips name the binding in words
	var chip := list.get_node("zoom_out").get_child(1).get_child(0) as Control
	assert(chip.tooltip_text == ControlBindings.defaults().for_action("zoom_out")[0].full_text())
	# a later open starts the Controls tab at the top
	var scroll := dialog.tabs.get_child(AppSettingsDialog.CONTROLS_TAB) as ScrollContainer
	scroll.scroll_vertical = 400
	await process_frame
	assert(scroll.scroll_vertical > 0)
	dialog.hide()
	main.settings.open_settings_dialog()
	dialog.tabs.current_tab = AppSettingsDialog.CONTROLS_TAB
	assert(scroll.scroll_vertical == 0, "The Controls tab opens at the top")


func _test_capture_and_conflicts() -> void:
	var list := dialog.controls_list
	# the next key becomes the binding
	list.start_capture("tool_residential")
	assert(list.is_capturing() and list.capture_overlay.visible)
	assert(list.capture_input(_key(KEY_R)))
	assert(not list.is_capturing() and not list.capture_overlay.visible)
	assert(list.pending.to_texts("tool_residential") == PackedStringArray(["key:R"]))
	# Esc cancels, and the left button stays the tool button
	list.start_capture("tool_commercial")
	assert(list.capture_input(_mouse(MOUSE_BUTTON_LEFT)))
	assert(list.is_capturing(), "The left button cannot be bound")
	list.capture_input(_key(KEY_ESCAPE))
	assert(not list.is_capturing() and list.pending.for_action("tool_commercial").is_empty())
	# a modifier key alone does not end the capture of a press action
	list.start_capture("tool_commercial")
	var shift := _key(KEY_SHIFT)
	shift.shift_pressed = true
	list.capture_input(shift)
	list.capture_input(_key(KEY_SHIFT, false))
	assert(list.is_capturing())
	var shifted_f := _key(KEY_F)
	shifted_f.shift_pressed = true
	list.capture_input(shifted_f)
	assert(list.pending.to_texts("tool_commercial") == PackedStringArray(["key:Shift+F"]))
	# a hold action takes a modifier key alone on its release
	list.start_capture("camera_fast")
	var alt := _key(KEY_ALT)
	alt.alt_pressed = true
	list.capture_input(alt)
	list.capture_input(_key(KEY_ALT, false))
	assert("key:Alt" in list.pending.to_texts("camera_fast"))
	# a modifier action takes one key without its modifiers, and no mouse button
	list.start_capture("tool_shape_modifier")
	list.capture_input(_mouse(MOUSE_BUTTON_MIDDLE))
	assert(list.is_capturing(), "A modifier action needs a key")
	var alt_l := _key(KEY_L)
	alt_l.alt_pressed = true
	list.capture_input(alt_l)
	assert("key:L" in list.pending.to_texts("tool_shape_modifier"))
	# a mouse button capture
	list.start_capture("rotate_clockwise")
	list.capture_input(_mouse(MOUSE_BUTTON_MIDDLE))
	assert(not list.is_capturing() and list.conflict_dialog.visible, "Middle is already Center on tile")
	list.conflict_dialog.hide()
	assert(not list.pending.has_mouse_button("rotate_clockwise", MOUSE_BUTTON_MIDDLE), "Cancel keeps the old binding")
	# a used key asks to reassign
	list.start_capture("tool_residential")
	list.capture_input(_key(KEY_X))
	assert(list.conflict_dialog.visible and list.conflict_dialog.dialog_text.contains("Bulldozer"))
	list.conflict_dialog.confirmed.emit()
	list.conflict_dialog.hide()
	assert(list.pending.for_action("tool_bulldozer").is_empty())
	assert("key:X" in list.pending.to_texts("tool_residential"))
	# remove a binding with its chip button
	var chips := list._rows["tool_query"]
	var remove := chips.get_child(0).find_child("Remove", true, false) as Button
	remove.pressed.emit()
	assert(list.pending.for_action("tool_query").is_empty())
	# each change applies at once, and Escape keeps it
	assert(main.preferences.control_bindings.equals(list.pending))
	assert(main.map_view.control_bindings.equals(list.pending), "The running game uses the changed bindings")
	dialog.canceled.emit()
	dialog.hide()
	main.settings.open_settings_dialog()
	assert(dialog.controls_list.pending.equals(main.preferences.control_bindings), "Reopened settings show the saved bindings")
	assert(dialog.controls_list.pending.for_action("tool_query").is_empty())


func _test_use_defaults() -> void:
	var list := dialog.controls_list
	var custom := ControlBindings.defaults()
	custom.remove("zoom_in", 0)
	main.preferences.control_bindings = custom
	assert(AppSettingsStore.save_controls(custom, settings_path) == OK)
	main.settings.open_settings_dialog()
	dialog.tabs.current_tab = AppSettingsDialog.CONTROLS_TAB
	list.remove_binding("tool_query", 0)
	assert(main.preferences.control_bindings.for_action("tool_query").is_empty())
	var saved_before := FileAccess.get_file_as_string(settings_path)
	# Cancel on the warning changes nothing
	dialog.use_defaults_button.pressed.emit()
	assert(dialog.reset_controls_dialog.visible)
	dialog.reset_controls_dialog.canceled.emit()
	dialog.reset_controls_dialog.hide()
	assert(list.pending.for_action("tool_query").is_empty(), "Cancel on the warning keeps earlier edits")
	assert(FileAccess.get_file_as_string(settings_path) == saved_before, "Cancel on the warning saves nothing")
	# Reset Controls saves the defaults at once
	dialog.use_defaults_button.pressed.emit()
	dialog.reset_controls_dialog.confirmed.emit()
	dialog.reset_controls_dialog.hide()
	var config := ConfigFile.new()
	assert(config.load(settings_path) == OK)
	for id in ControlActions.bindable_ids():
		if AppSettingsStore.load_bindings(config).to_texts(id) != ControlBindings.defaults().to_texts(id):
			assert(AppSettingsStore.load_bindings(config).equals(ControlBindings.defaults()))
	assert(main.preferences.control_bindings.equals(ControlBindings.defaults()))
	assert(main.map_view.control_bindings.equals(ControlBindings.defaults()), "The running game uses the defaults")
	assert(list.pending.equals(ControlBindings.defaults()), "The Controls list shows the defaults")
	assert(dialog.visible and dialog.tabs.current_tab == AppSettingsDialog.CONTROLS_TAB)
	dialog.hide()


func _test_immediate_apply() -> void:
	main.settings.open_settings_dialog()
	var list := dialog.controls_list
	list.start_capture("window_population")
	list.capture_input(_key(KEY_P))
	assert(main.preferences.control_bindings.to_texts("window_population") == PackedStringArray(["key:P"]))
	var config := ConfigFile.new()
	assert(config.load(settings_path) == OK)
	assert(config.get_value("controls", "binding/window_population") == PackedStringArray(["key:P"]))
	# a check box applies and saves at once
	var dark := not main.preferences.dark_underground
	dialog.dark_underground_check.button_pressed = dark
	assert(main.preferences.dark_underground == dark)
	assert(AppSettingsStore.load_values(settings_path).dark_underground == dark)
	var corrections := not main.preferences.sprite_corrections
	dialog.sprite_corrections_check.button_pressed = corrections
	assert(main.preferences.sprite_corrections == corrections)
	assert(AppSettingsStore.load_values(settings_path).sprite_corrections == corrections)
	assert((main.asset_state.large_sprites != main.asset_state.base_large_sprites) == corrections,
		"The sc2kfix corrections change the original sprites only while they are on")
	dialog.sprite_corrections_check.button_pressed = not corrections
	assert(main.asset_state.large_sprites == main.asset_state.base_large_sprites or corrections == false)
	# a text field applies on Enter, and the Close button applies a field that has focus
	dialog.default_mayor_edit.text = "Entered Mayor"
	assert(main.preferences.default_mayor_name != "Entered Mayor", "Typing alone does not apply")
	dialog.default_mayor_edit.text_submitted.emit(dialog.default_mayor_edit.text)
	assert(main.preferences.default_mayor_name == "Entered Mayor")
	dialog.default_mayor_edit.text = "Closed Mayor"
	dialog.get_ok_button().pressed.emit()
	assert(not dialog.visible and main.preferences.default_mayor_name == "Closed Mayor")
	assert(AppSettingsStore.load_values(settings_path).default_mayor_name == "Closed Mayor")
	# opening Settings applies and saves nothing
	var saved := FileAccess.get_file_as_string(settings_path)
	main.settings.open_settings_dialog()
	assert(FileAccess.get_file_as_string(settings_path) == saved)
	dialog.hide()


func _key(keycode: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = pressed
	event.keycode = keycode
	event.physical_keycode = keycode

	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true

	return event
