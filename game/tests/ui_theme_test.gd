extends SceneTree
## Theme persistence, live switching, and lazy windows.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://theme-test-%d.cfg" % OS.get_process_id()
	assert(AppSettingsStore.load_values(path).ui_theme == "light")
	assert(not AppSettingsStore.load_values(path).dark_underground)
	assert(AppSettingsStore.normalize_theme("invalid") == "light")
	var config := ConfigFile.new()
	config.set_value("general", "ui_theme", "invalid")
	assert(config.save(path) == OK)
	assert(AppSettingsStore.load_values(path).ui_theme == "light")
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("user://missing-test-art"))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.reference_root = ProjectSettings.globalize_path("user://missing-test-originals")
	main.app_settings_path = path
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	assert(main.city_session._activate_document(EmptyCityTemplate.create(128)))
	main.frame._select_speed(GameSpeedController.Speed.PAUSED)
	var before: PackedByteArray = main.city.document.serialize().data
	for selected in [1, 0, 1]:
		main.settings._open_settings_dialog()
		var dialog: AppSettingsDialog = main.settings_dialog
		dialog.theme_selector.select(selected)
		dialog.dark_underground_check.button_pressed = not main.app_dark_underground
		# Cancel discards the selection when Settings next opens.
		dialog.hide()
		main.settings._open_settings_dialog()
		assert(dialog.theme_selector.selected == (1 if main.app_ui_theme == "dark" else 0))
		assert(dialog.dark_underground_check.button_pressed == main.app_dark_underground)
		var previous_mode: String = main.app_ui_theme
		var previous_color: Color = main.theme.get_stylebox("normal", "Button").bg_color
		dialog.theme_selector.select(selected)
		dialog.dark_underground_check.button_pressed = true
		main.settings._apply_settings()
		dialog.hide()
		await process_frame
		await process_frame
		assert(AppSettingsStore.load_values(path).dark_underground)
		assert(main.app_ui_theme == ("dark" if selected == 1 else "light"))
		assert(AppSettingsStore.load_values(path).ui_theme == main.app_ui_theme)
		if previous_mode != main.app_ui_theme:
			assert(main.theme.get_stylebox("normal", "Button").bg_color != previous_color)
		assert(main.city.document.serialize().data == before)
		var late := FileDialogFactory.city_open()
		main.add_child(late)
		assert(late.theme.get_color("font_color", "Label") == AppUiTheme.file_dialog().get_color("font_color", "Label"), "New dialogs use the active theme")
		late.free()
	# Style selection follows the published texture mode, independent of renderer.
	# Actual CPU/GPU pixels belong to dark_underground_shader_test.
	for state in [["underground", true, true], ["underground", false, false], ["city", true, false]]:
		main.render_caches.static_render_mode = state[0]
		main.map_view.base_palette_lookup_all = state[1]
		main.app_dark_underground = true
		main.menus._sync_map_style()
		assert(main.map_view.dark_underground == state[2])
		assert(main.map_view._base_material.get_shader_parameter("dark_underground") == state[2])
		main.app_dark_underground = false
		main.menus._sync_map_style()
		assert(not main.map_view.dark_underground)
		assert(not main.map_view._base_material.get_shader_parameter("dark_underground"))
	assert(main.city.document.serialize().data == before)
	main.free()
	await process_frame
	var restored := (load("res://main.tscn") as PackedScene).instantiate()
	restored.app_settings_path = path
	restored.reference_root = ProjectSettings.globalize_path("user://missing-test-originals")
	root.add_child(restored)
	await process_frame
	assert(restored.app_ui_theme == "dark")
	assert(restored.app_dark_underground)
	restored.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	AppUiTheme.select("light")
	await process_frame
	print("PASS: theme save/cancel/reload, live and lazy themes, renderer flags and unchanged city")
	quit()
