extends SceneTree
## Gallery theme switching and independent scale persistence.

const GALLERY := preload("res://tools/ui/ui_control_gallery.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://gallery-test-%d.cfg" % OS.get_process_id()
	var game_settings_existed := FileAccess.file_exists(AppSettingsStore.SETTINGS_PATH)
	var game_settings := FileAccess.get_file_as_bytes(AppSettingsStore.SETTINGS_PATH) if game_settings_existed else PackedByteArray()
	var original_scale := root.content_scale_factor
	var gallery := GALLERY.instantiate()
	gallery.settings_path = path
	root.add_child(gallery)
	assert(root.content_scale_factor == 1.0)
	var tabs := gallery.get_node("%Tabs") as TabContainer
	assert(tabs.current_tab == 0)
	tabs.current_tab = 3
	var light_color: Color = gallery.theme.get_stylebox("normal", "Button").bg_color
	var toggle := gallery.get_node("%ThemeToggle") as Button
	toggle.button_pressed = true
	await process_frame
	assert(gallery.theme.get_stylebox("normal", "Button").bg_color != light_color)
	assert(tabs.current_tab == 3, "Theme switching keeps the selected tab")
	for dialog in gallery.preview_dialogs:
		assert(dialog.theme == gallery.theme, "Preview dialogs use the selected theme")
	toggle.button_pressed = false
	await process_frame
	assert(gallery.theme.get_stylebox("normal", "Button").bg_color == light_color)
	assert(tabs.current_tab == 3)
	var selector := gallery.get_node("%ScaleSelector") as OptionButton
	selector.select(2)
	selector.item_selected.emit(2)
	assert(root.content_scale_factor == 1.5)
	gallery.free()
	await process_frame
	root.content_scale_factor = original_scale
	gallery = GALLERY.instantiate()
	gallery.settings_path = path
	root.add_child(gallery)
	assert(root.content_scale_factor == 1.5, "A new gallery restores its saved scale")
	assert(gallery.get_node("%ScaleSelector").selected == 2)
	gallery.free()
	var config := ConfigFile.new()
	config.set_value("gallery", "ui_scale", "invalid")
	assert(config.save(path) == OK)
	gallery = GALLERY.instantiate()
	gallery.settings_path = path
	root.add_child(gallery)
	assert(root.content_scale_factor == 1.0, "Invalid saved scale uses the gallery default")
	gallery.free()
	assert(FileAccess.file_exists(AppSettingsStore.SETTINGS_PATH) == game_settings_existed)
	if game_settings_existed:
		assert(FileAccess.get_file_as_bytes(AppSettingsStore.SETTINGS_PATH) == game_settings)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	root.content_scale_factor = original_scale
	await process_frame
	print("PASS: gallery theme toggle, selected tab, scale reload, invalid scale and separate settings")
	quit()
