extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	assert(GameAssetSource.default_reference_root() == MediaPack.default_folder("graphics").path_join("runtime"))

	for kind in ["graphics", "sound", "music"]:
		assert(MediaPack.default_folder(kind) == ProjectSettings.globalize_path("user://packs").path_join(kind))

	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("user://missing-assets"))
	var main = (load("res://main.tscn") as PackedScene).instantiate()
	main.preferences.settings_path = "user://no-assets-test.cfg"
	root.add_child(main)
	await process_frame
	assert(main.asset_state.runtime_initialized and not main.asset_state.assets_ready)
	assert(main.document_state.city == null and main.asset_state.palette == null)
	assert(main.main_menu.import_button.visible)

	for button in main.main_menu.game_buttons:
		assert(button.disabled)

	main.new_city.open_new_city_dialog()
	assert(not main.city_dialogs.new_city_dialog.visible)
	main.settings.open_import_settings()
	assert(main.main_overlays.settings_dialog.visible and main.main_overlays.settings_dialog.tabs.current_tab == 3)
	main.main_overlays.settings_dialog.hide()
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", "")
	main.queue_free()
	await process_frame
	print("PASS: empty startup, disabled tools, Import Data shortcut")
	quit()
