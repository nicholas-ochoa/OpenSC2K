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
	var graphics_options := AppSettingsStore.SaveOptions.new()
	graphics_options.graphics_source = "folder"
	graphics_options.graphics_folder = values.graphics_folder
	graphics_options.city_renderer = "gpu"
	graphics_options.background_audio = false
	graphics_options.zoom_graphics = values.zoom_graphics
	assert(AppSettingsStore.save_values(0.5, 0.5, false, path, graphics_options) == OK)
	assert(AppSettingsStore.load_values(path).zoom_graphics == values.zoom_graphics)
	assert(values.overview_graphics == 0)
	assert(values.default_mayor_name == "Mayor")
	var city_options := AppSettingsStore.SaveOptions.new()
	city_options.default_mayor_name = "Alex"
	city_options.overview_graphics = 2
	assert(AppSettingsStore.save_values(0.5, 0.5, false, path, city_options) == OK)
	var updated := AppSettingsStore.load_values(path)
	assert(updated.default_mayor_name == "Alex")
	assert(updated.overview_graphics == 2)
	# the 10% size is the minimum for every higher zoom level
	assert(updated.zoom_graphics == [2, 2, 2, 2, 2, 2])
	assert(AppSettingsStore.normalize_zoom_graphics([0, 1, 2, 2, 2, 2], 1) == [1, 1, 2, 2, 2, 2])
	assert(AppSettingsStore.graphics_size_at_zoom(updated.zoom_graphics, 10, updated.overview_graphics) == 2)
	assert(AppSettingsStore.graphics_size_at_zoom(updated.zoom_graphics, 25, updated.overview_graphics) == 2)
	var dialog := preload("res://src/ui/settings/app_settings_dialog.tscn").instantiate() as AppSettingsDialog
	root.add_child(dialog)
	dialog.show_values(0.5, 0.5, false, "folder", values.graphics_folder, "gpu", false, values.zoom_graphics)

	for selector in dialog.zoom_graphics_selectors:
		assert(selector.item_count == 3)

	assert(dialog.selected_values().graphics_source == "folder")
	assert(dialog.selected_values().zoom_graphics == values.zoom_graphics)
	dialog.default_mayor_edit.text = updated.default_mayor_name
	dialog.overview_graphics_selector.select(updated.overview_graphics)
	assert(dialog.selected_values().default_mayor_name == "Alex")
	assert(dialog.selected_values().overview_graphics == 2)
	dialog.overview_graphics_selector.item_selected.emit(2)
	assert(dialog.selected_values().zoom_graphics == [2, 2, 2, 2, 2, 2], "A larger 10% size raises higher zoom levels")
	assert(dialog.zoom_graphics_selectors[0].is_item_disabled(1) and not dialog.zoom_graphics_selectors[0].is_item_disabled(2))
	dialog.overview_graphics_selector.select(0)
	dialog.overview_graphics_selector.item_selected.emit(0)
	assert(not dialog.zoom_graphics_selectors[0].is_item_disabled(0), "A smaller 10% size allows every 25% size")
	dialog.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS: native graphics settings, retained pack selection")
	quit()
