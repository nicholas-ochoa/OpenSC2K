extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	assert(GameAssetSource.default_reference_root() == ProjectSettings.globalize_path("user://original_game").simplify_path())

	for kind in ["graphics", "sound", "music"]:
		assert(MediaPack.default_folder(kind) == ProjectSettings.globalize_path("user://packs").path_join(kind))

	OS.set_environment("OPENSC2K_GRAPHICS_PACK", "/tmp/no-city-assets")
	var main = (load("res://main.tscn") as PackedScene).instantiate()
	main.app_settings_path = "user://no-assets-test.cfg"
	root.add_child(main)
	await process_frame
	assert(main.runtime_initialized and not main.assets_ready)
	assert(main.city == null and main.palette == null)
	assert(main.main_menu.import_button.visible)

	for button in main.main_menu.game_buttons:
		assert(button.disabled)

	main._open_new_city_dialog()
	assert(not main.new_city_dialog.visible)
	main._open_import_settings()
	assert(main.settings_dialog.visible and main.settings_dialog.tabs.current_tab == 3)
	main.settings_dialog.hide()
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", "")
	main.queue_free()
	await process_frame
	print("PASS: empty startup, disabled tools, Import Data shortcut")
	quit()
