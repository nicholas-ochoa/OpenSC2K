extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://native-graphics-settings-test.cfg"
	var config := ConfigFile.new()
	config.set_value("graphics", "zoom_graphics", [0, 1, 2, 3, 4, 4])
	config.set_value("graphics", "source", "folder")
	config.set_value("graphics", "folder", "/example/custom-pack")
	assert(config.save(path) == OK)
	var values := AppSettingsStore.load_values(path)
	assert(values.zoom_graphics == [0, 1, 2, 2, 2, 2])
	assert(values.graphics_source == "folder")
	assert(values.graphics_folder == "/example/custom-pack")
	assert(AppSettingsStore.save_values(0.5, 0.5, false, path, "folder", values.graphics_folder, null, "gpu", false, values.zoom_graphics) == OK)
	assert(AppSettingsStore.load_values(path).zoom_graphics == values.zoom_graphics)
	var dialog := AppSettingsDialog.new()
	root.add_child(dialog)
	dialog.show_values(0.5, 0.5, false, "folder", values.graphics_folder, "gpu", false, values.zoom_graphics)

	for selector in dialog.zoom_graphics_selectors:
		assert(selector.item_count == 3)

	assert(dialog.selected_values().graphics_source == "folder")
	assert(dialog.selected_values().zoom_graphics == values.zoom_graphics)
	dialog.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS: native graphics settings, retained pack selection")
	quit()
