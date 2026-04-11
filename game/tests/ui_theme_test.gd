extends SceneTree
## Theme persistence, live switching, lazy windows, and shared control resources.

var checked_controls := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://theme-test-%d.cfg" % OS.get_process_id()
	assert(AppSettingsStore.load_values(path).ui_theme == "light")
	assert(AppSettingsStore.normalize_theme("invalid") == "light")
	var config := ConfigFile.new()
	config.set_value("general", "ui_theme", "invalid")
	assert(config.save(path) == OK)
	assert(AppSettingsStore.load_values(path).ui_theme == "light")
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	main.app_settings_path = path
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	main._load_city_unchecked(main.reference_root.path_join("DEFAULT.SC2"))
	main._select_speed(GameSpeedController.Speed.PAUSED)
	main._ensure_scurk_editor()
	var before: PackedByteArray = main.city.document.serialize().data
	var original_theme := AppUiTheme.current()
	var original_files := AppUiTheme.file_dialog()
	for selected in [1, 0, 1]:
		main._open_settings_dialog()
		var dialog: AppSettingsDialog = main.settings_dialog
		dialog.theme_selector.select(selected)
		# Cancel discards the selection when Settings next opens.
		dialog.hide()
		main._open_settings_dialog()
		assert(dialog.theme_selector.selected == (1 if main.app_ui_theme == "dark" else 0))
		dialog.theme_selector.select(selected)
		main._apply_settings()
		dialog.hide()
		await process_frame
		await process_frame
		assert(main.app_ui_theme == ("dark" if selected == 1 else "light"))
		var menu := main.main_menu.get_node("Center/Panel").get_theme_stylebox("panel") as StyleBoxFlat
		assert(is_equal_approx(menu.bg_color.a, 0.85 if selected == 1 else 1.0))
		var fields := dialog.theme_selector.get_parent()
		assert(fields.get_node("MayorHint").get_index() < fields.get_node("ThemeLabel").get_index())
		assert(dialog.fullscreen_check.get_index() > dialog.renderer_selector.get_index())
		assert(not fields.has_node("DisplayLabel"))
		assert(AppSettingsStore.load_values(path).ui_theme == main.app_ui_theme)
		assert(AppUiTheme.current() == original_theme and AppUiTheme.file_dialog() == original_files)
		assert(main.city.document.serialize().data == before)
		assert(dialog.tabs.get_theme_stylebox("panel").get_content_margin(SIDE_LEFT) == 12)
		_check_controls(main)
		var late := FileDialogFactory.city_open()
		main.add_child(late)
		assert(late.theme == original_files)
		late.free()
		var gallery := (load("res://tools/ui_gallery/ui_control_gallery.tscn") as PackedScene).instantiate()
		root.add_child(gallery)
		gallery.get_node("%ThemeSelector").select(selected)
		gallery._rebuild(selected)
		var sample := gallery.theme.get_stylebox("normal", "Button") as StyleBoxFlat
		var actual := main.theme.get_stylebox("normal", "Button") as StyleBoxFlat
		assert(sample.bg_color == actual.bg_color and sample.border_color == actual.border_color)
		gallery.free()
	main.free()
	await process_frame
	var restored := (load("res://main.tscn") as PackedScene).instantiate()
	restored.app_settings_path = path
	restored.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	root.add_child(restored)
	await process_frame
	assert(restored.app_ui_theme == "dark")
	restored.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	AppUiTheme.select("light")
	await process_frame
	print("PASS: theme save/cancel/reload, live and lazy controls, gallery parity, unchanged city; %d controls checked" % checked_controls)
	quit()


func _check_controls(node: Node, files := false) -> void:
	files = files or node is FileDialog
	var expected := AppUiTheme.file_dialog() if files else AppUiTheme.current()
	if node is Control or node is Window:
		if node.theme != null:
			assert(node.theme == expected, "Competing theme: " + str(node.get_path()))
	if node is Button and not node is CheckBox and not node is CheckButton and not node.flat:
		var box := node.get_theme_stylebox("normal") as StyleBoxFlat
		var reference := expected.get_stylebox("normal", "OptionButton" if node is OptionButton else "Button") as StyleBoxFlat
		assert(box != null and box.bg_color == reference.bg_color, "Button style: " + str(node.get_path()))
		checked_controls += 1
	for child in node.get_children(true):
		_check_controls(child, files)
