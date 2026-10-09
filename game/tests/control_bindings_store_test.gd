extends SceneTree
## Saved control bindings: defaults, empty lists, unknown entries, and the
## migration of the earlier mouse button choices.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://control-bindings-store-test-%d.cfg" % OS.get_process_id()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# a file without a controls section uses the defaults
	var config := ConfigFile.new()
	config.set_value("general", "ui_theme", "dark")
	assert(config.save(path) == OK)
	var loaded := AppSettingsStore.load_values(path)
	assert(loaded.control_bindings.equals(ControlBindings.defaults()))

	# an empty list stays empty, bad text is skipped, and unknown actions stay in the file
	config.set_value("controls", "binding/tool_query", PackedStringArray())
	config.set_value("controls", "binding/zoom_in", PackedStringArray(["key:NoSuchKey", "key:K", "key:K"]))
	config.set_value("controls", "binding/future_action", PackedStringArray(["key:J"]))
	assert(config.save(path) == OK)
	loaded = AppSettingsStore.load_values(path)
	assert(loaded.control_bindings.for_action("tool_query").is_empty())
	assert(loaded.control_bindings.to_texts("zoom_in") == PackedStringArray(["key:K"]))
	assert(loaded.control_bindings.to_texts("tool_bulldozer") == PackedStringArray(["key:X"]), "A missing key uses the defaults")
	loaded.control_bindings.add("tool_residential", ControlBinding.key(KEY_R))
	var options := AppSettingsStore.SaveOptions.new()
	options.control_bindings = loaded.control_bindings
	assert(AppSettingsStore.save_values(0.5, 0.5, false, path, options) == OK)
	config = ConfigFile.new()
	assert(config.load(path) == OK)
	assert(config.get_value("controls", "binding/future_action") == PackedStringArray(["key:J"]))
	assert(config.get_value("controls", "bindings_version") == AppSettingsStore.BINDINGS_VERSION)
	assert(config.get_value("controls", "binding/tool_query") == PackedStringArray())
	assert(config.get_value("general", "ui_theme") == "dark")
	loaded = AppSettingsStore.load_values(path)
	assert(loaded.control_bindings.to_texts("tool_residential") == PackedStringArray(["key:R"]))
	assert(loaded.control_bindings.for_action("tool_query").is_empty())

	# save_controls writes only the controls section
	config.set_value("general", "ui_theme", "light")
	assert(config.save(path) == OK)
	assert(AppSettingsStore.save_controls(ControlBindings.defaults(), path) == OK)
	config = ConfigFile.new()
	assert(config.load(path) == OK)
	assert(config.get_value("general", "ui_theme") == "light")
	assert(AppSettingsStore.load_values(path).control_bindings.equals(ControlBindings.defaults()))

	_test_migration(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS: control bindings storage and migration")
	quit()


func _test_migration(path: String) -> void:
	# a changed middle button choice moves to the new bindings. the earlier
	# right button default takes the new Context Menu default
	var config := ConfigFile.new()
	config.set_value("controls", "right_button", "center")
	config.set_value("controls", "middle_button", "context_menu")
	assert(config.save(path) == OK)
	var bindings := AppSettingsStore.load_values(path).control_bindings
	assert(bindings.has_mouse_button("map_context_menu", MOUSE_BUTTON_MIDDLE))
	assert(bindings.has_mouse_button("map_context_menu", MOUSE_BUTTON_RIGHT))
	assert(not bindings.has_mouse_button("map_center_on_tile", MOUSE_BUTTON_MIDDLE))
	assert(bindings.has_mouse_button("map_pan", MOUSE_BUTTON_MIDDLE), "A drag still moves the map")
	var options := AppSettingsStore.SaveOptions.new()
	options.control_bindings = bindings
	assert(AppSettingsStore.save_values(0.5, 0.5, false, path, options) == OK)
	config = ConfigFile.new()
	assert(config.load(path) == OK)
	assert(not config.has_section_key("controls", "right_button") and not config.has_section_key("controls", "middle_button"))
	assert(AppSettingsStore.load_values(path).control_bindings.equals(bindings))
	# a saved version stops the migration
	config.set_value("controls", "middle_button", "context_menu")
	config.set_value("controls", "binding/map_context_menu", PackedStringArray(["mouse:Right"]))
	assert(config.save(path) == OK)
	assert(not AppSettingsStore.load_values(path).control_bindings.has_mouse_button("map_context_menu", MOUSE_BUTTON_MIDDLE))
	_test_budget_migration(path)


# version 1 opened the budget with B. B now bulldozes while it is down, and the
# budget moves to Command+B, the Ctrl+B of the original menu
func _test_budget_migration(path: String) -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "binding/window_budget", PackedStringArray(["key:B"]))
	config.set_value("controls", "bindings_version", 1)
	assert(config.save(path) == OK)
	var bindings := AppSettingsStore.load_values(path).control_bindings
	assert(bindings.to_texts("window_budget") == PackedStringArray(["key:Command+B"]))
	assert(bindings.to_texts("tool_bulldoze_modifier") == PackedStringArray(["key:B"]))
	# a saved action keeps B, and the new action does without it
	config.set_value("controls", "binding/speed_pause", PackedStringArray(["key:B"]))
	assert(config.save(path) == OK)
	bindings = AppSettingsStore.load_values(path).control_bindings
	assert(bindings.to_texts("speed_pause") == PackedStringArray(["key:B"]))
	assert(bindings.for_action("tool_bulldoze_modifier").is_empty())
	assert(bindings.to_texts("tool_center_modifier") == PackedStringArray(["key:Alt"]))
