extends SceneTree
## Binding text, modifier matching, and default bindings for player controls.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_text_round_trip()
	_test_matching()
	_test_catalog_defaults()
	_test_binding_set()
	print("PASS: control binding text, matching, defaults, and conflicts")
	quit()


func _test_text_round_trip() -> void:
	for text in ["key:W", "key:Up", "key:Command+S", "key:Command+Shift+S", "key:Alt+F4", "key:Kp Add",
			"key:BracketRight", "key:Shift", "key:Alt", "key:Meta", "key:Ctrl", "mouse:Middle", "mouse:WheelUp", "mouse:Extra1", "mouse:Shift+Right"]:
		var binding := ControlBinding.from_text(text)
		assert(binding != null, "Cannot parse " + text)
		assert(binding.to_text() == text, "Text round trip changed %s to %s" % [text, binding.to_text()])
		assert(not binding.display_text().is_empty())

	for text in ["", "W", "key:", "key:NoSuchKey", "pad:A", "mouse:Button9", "key:Hyper+A", "mouse:"]:
		assert(ControlBinding.from_text(text) == null, "Accepted invalid binding " + text)

	# Ctrl is Command on systems other than macOS
	var ctrl := ControlBinding.from_text("key:Ctrl+S")
	assert(ctrl.modifiers == (ControlBinding.CONTROL if OS.has_feature("macos") else ControlBinding.COMMAND))
	var command := ControlBinding.from_text("key:Command+Z")
	assert(command.key_with_masks() == ((KEY_MASK_META if OS.has_feature("macos") else KEY_MASK_CTRL) | KEY_Z))


func _test_matching() -> void:
	var z := ControlBinding.from_text("key:Z")
	var undo := ControlBinding.from_text("key:Command+Z")
	var event := _key(KEY_Z)
	assert(z.matches(event) and not undo.matches(event))
	_set_command(event)
	assert(undo.matches(event) and not z.matches(event), "Z must not start when Command+Z is pressed")
	# held camera keys ignore Shift. other bindings need the exact modifiers
	var shifted := _key(KEY_W)
	shifted.shift_pressed = true
	var w := ControlBinding.from_text("key:W")
	assert(not w.matches(shifted) and w.matches(shifted, true))
	# letters use the physical key. symbol keys also match the layout key code
	var layout_w := InputEventKey.new()
	layout_w.pressed = true
	layout_w.physical_keycode = KEY_W
	layout_w.keycode = KEY_Z
	assert(w.matches(layout_w) and not z.matches(layout_w))
	var plus := InputEventKey.new()
	plus.pressed = true
	plus.physical_keycode = KEY_BRACKETRIGHT
	plus.keycode = KEY_PLUS
	assert(ControlBinding.from_text("key:Plus").matches(plus))
	# a modifier key alone matches while its own modifier flag is set
	var shift := _key(KEY_SHIFT)
	shift.shift_pressed = true
	assert(ControlBinding.from_text("key:Shift").matches(shift))
	assert(ControlBinding.from_event(shift).to_text() == "key:Shift")
	# a mouse binding without modifiers matches any modifiers
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.shift_pressed = true
	assert(ControlBinding.from_text("mouse:WheelUp").matches(wheel))
	assert(not ControlBinding.from_text("mouse:Alt+WheelUp").matches(wheel))
	assert(ControlBinding.from_event(wheel).to_text() == "mouse:Shift+WheelUp")


func _test_catalog_defaults() -> void:
	var ids: Dictionary[String, bool] = {}

	for action in ControlActions.all():
		assert(not ids.has(action.id), "Duplicate action " + action.id)
		ids[action.id] = true
		assert(action.category in ControlActions.CATEGORIES)

		for text in action.defaults:
			assert(ControlBinding.from_text(text) != null, "Invalid default %s for %s" % [text, action.id])

	var defaults := ControlBindings.defaults()

	for pair in [["speed_turtle", "key:1"], ["speed_llama", "key:2"], ["speed_cheetah", "key:3"],
			["speed_african_swallow", "key:4"], ["speed_toggle_pause", "key:Space"], ["tool_query", "key:Z"],
			["tool_bulldozer", "key:X"], ["tool_center", "key:C"], ["camera_up", "key:Up"], ["zoom_out", "mouse:WheelDown"],
			["map_context_menu", "mouse:Right"], ["map_center_on_tile", "mouse:Middle"], ["map_pan", "mouse:Right"],
			["map_pan", "mouse:Middle"], ["undo", "key:Command+Z"], ["window_debug", "key:F12"]]:
		assert(pair[1] in defaults.to_texts(pair[0]), "%s is not a default of %s" % [pair[1], pair[0]])

	assert(defaults.for_action("speed_pause").is_empty())
	assert(not ControlActions.has("file_quit"), "The system handles Quit")
	# music keys work on every screen, so they conflict with city and SCURK keys
	assert(defaults.conflicts(ControlBinding.from_text("key:Command+S"), "music_stop") == ["file_save", "scurk_save"])
	# the default bindings have no conflicts
	for id in ControlActions.bindable_ids():
		for binding in defaults.for_action(id):
			assert(defaults.conflicts(binding, id).is_empty(), "%s conflicts for %s" % [binding.to_text(), id])


func _test_binding_set() -> void:
	var bindings := ControlBindings.defaults()
	assert(bindings.action_for(_key(KEY_Z)) == "tool_query")
	var undo := _key(KEY_Z)
	_set_command(undo)
	assert(bindings.action_for(undo) == "undo")
	assert(bindings.action_for(_key(KEY_UP)) == "camera_up")
	var shifted_up := _key(KEY_UP)
	shifted_up.shift_pressed = true
	assert(bindings.action_for(shifted_up) == "camera_up", "Shift does not stop a held camera key")
	assert(bindings.action_for(_key(KEY_F9)).is_empty())
	# a drag action shares buttons with click actions without a conflict
	assert(bindings.conflicts(ControlBinding.mouse(MOUSE_BUTTON_RIGHT), "map_pan").is_empty())
	assert(bindings.conflicts(ControlBinding.mouse(MOUSE_BUTTON_RIGHT), "map_center_on_tile") == ["map_context_menu"])
	assert(bindings.conflicts(ControlBinding.key(KEY_Z), "tool_residential") == ["tool_query"])
	assert(not bindings.add("tool_query", ControlBinding.key(KEY_Z)), "A duplicate binding is not added")
	assert(bindings.add("tool_residential", ControlBinding.key(KEY_R)))
	assert(bindings.action_for(_key(KEY_R)) == "tool_residential")
	var copy := bindings.duplicate_set()
	copy.remove("tool_residential", 0)
	assert(bindings.for_action("tool_residential").size() == 1 and copy.for_action("tool_residential").is_empty())
	assert(not copy.equals(bindings))
	_test_modifiers_and_scopes()


func _test_modifiers_and_scopes() -> void:
	var bindings := ControlBindings.defaults()
	# modifier actions share Shift, but a modifier cannot use a key that starts another action
	assert(bindings.conflicts(ControlBinding.key(KEY_SHIFT), "tool_shape_modifier").is_empty())
	assert(bindings.conflicts(ControlBinding.key(KEY_Q), "tool_shape_modifier") == ["zoom_out"])
	assert(bindings.conflicts(ControlBinding.key(KEY_Q), "zoom_in") == ["zoom_out"])
	# SCURK keys use their own scope
	var save := ControlBinding.from_text("key:Command+S")
	assert(bindings.conflicts(save, "scurk_save").is_empty())
	assert(bindings.conflicts(save, "file_open") == ["file_save"])
	var save_event := _key(KEY_S)
	_set_command(save_event)
	assert(bindings.action_for(save_event) == "file_save")
	assert(bindings.action_for(save_event, [ControlActions.KIND_PRESS], [ControlActions.SCOPE_SCURK]) == "scurk_save")
	# the SCURK editor takes Ctrl and Cmd as Command on every system
	var ctrl_save := _key(KEY_S)
	ctrl_save.ctrl_pressed = true
	var meta_save := _key(KEY_S)
	meta_save.meta_pressed = true

	for event in [ctrl_save, meta_save]:
		assert(bindings.action_for(event, [ControlActions.KIND_PRESS], [ControlActions.SCOPE_SCURK]) == "scurk_save")

	# a modifier key reads the flags of any event, and another key reads its own key event
	var click := InputEventMouseButton.new()
	click.shift_pressed = true
	assert(bindings.modifier_held("tool_query_modifier", click))
	bindings.remove_binding("tool_query_modifier", ControlBinding.key(KEY_SHIFT))
	bindings.add("tool_query_modifier", ControlBinding.key(KEY_L))
	assert(not bindings.modifier_held("tool_query_modifier", click))
	assert(bindings.modifier_held("tool_query_modifier", _key(KEY_L)))
	assert(not bindings.modifier_held("tool_query_modifier", _key(KEY_L, false)))
	assert(bindings.uses_key("tool_query_modifier", _key(KEY_L, false)))


func _key(keycode: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = pressed
	event.keycode = keycode
	event.physical_keycode = keycode

	return event


func _set_command(event: InputEventKey) -> void:
	event.meta_pressed = OS.has_feature("macos")
	event.ctrl_pressed = not OS.has_feature("macos")
