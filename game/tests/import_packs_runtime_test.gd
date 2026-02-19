extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", "/tmp/no-city-assets")
	var main = (load("res://main.tscn") as PackedScene).instantiate()
	main.app_settings_path = "user://import-runtime-test.cfg"
	root.add_child(main)
	await process_frame
	assert(not main.assets_ready)
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", "")
	var folder := ProjectSettings.globalize_path("user://runtime-import-test-%d" % OS.get_process_id())
	var result := OriginalPackImporter.import_executable(ProjectSettings.globalize_path("res://../references/SIMCITY.EXE"), folder)
	assert(result.ok)
	var selected := GameAssetSource.load_source("", "folder", result.graphics)
	main._apply_graphics_source(selected)
	assert(main.assets_ready and not main.main_menu.import_button.visible)
	assert(main.audio_controller.set_media_packs(result.sound, result.music))
	assert(main.newspaper_data != null and main.base_large_sprites != null)
	main._open_new_city_dialog()
	assert(main.new_city_dialog.visible)
	main.queue_free()
	await process_frame
	OriginalGameInstaller.remove_tree(folder)
	print("PASS: imported packs activate the empty runtime without restart")
	quit()
