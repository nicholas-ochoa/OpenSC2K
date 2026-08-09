extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("user://missing-assets"))
	var main = (load("res://main.tscn") as PackedScene).instantiate()
	main.preferences.settings_path = "user://import-runtime-test.cfg"
	root.add_child(main)
	await process_frame
	assert(not main.assets_ready)
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", "")
	var folder := ProjectSettings.globalize_path("user://runtime-import-test-%d" % OS.get_process_id())
	var result := OriginalPackImporter.import_executable(ProjectSettings.globalize_path("res://../references/SIMCITY2000/SIMCITY.EXE"), folder)
	assert(result.ok)
	var selected := GameAssetSource.load_source("", "folder", result.graphics)
	assert(selected.error.is_empty(), selected.error)
	assert(selected.assets.large_sprites.entries.size() == 501)
	assert(MediaPack.load_folder(result.sound, "sound").files.size() == 30)
	assert(MediaPack.load_folder(result.music, "music").files.size() == 19)
	assert(result.cities > 0 and result.scenarios > 0)
	var saved_root := folder.path_join("saved")
	var imported_city := saved_root.path_join("cities/ISLAND.SC2")
	var original_city := ProjectSettings.globalize_path("res://../references/SIMCITY2000/CITIES/ISLAND.SC2")
	assert(FileAccess.get_sha256(imported_city) == FileAccess.get_sha256(original_city))
	var file := FileAccess.open(imported_city, FileAccess.WRITE)
	file.store_string("player save")
	file.close()
	var again := OriginalCityImporter.import_saved_games(ProjectSettings.globalize_path("res://../references/SIMCITY2000"), saved_root)
	assert(again.ok and again.created.size() == 1)
	assert(FileAccess.get_file_as_string(imported_city) == "player save")
	assert(FileAccess.get_sha256(again.created[0]) == FileAccess.get_sha256(original_city))
	var repeated := OriginalCityImporter.import_saved_games(ProjectSettings.globalize_path("res://../references/SIMCITY2000"), saved_root)
	assert(repeated.ok and repeated.created.is_empty())
	main.assets.apply_graphics_source(selected)
	assert(main.assets_ready and not main.main_menu.import_button.visible)
	assert(main.audio_controller.set_media_packs(result.sound, result.music))
	assert(main.original_text_resources.newspaper_data != null and main.base_large_sprites != null)
	main.new_city.open_new_city_dialog()
	assert(main.new_city_dialog.visible)
	main.queue_free()
	await process_frame
	OriginalGameInstaller.remove_tree(folder)
	print("PASS: complete pack import, copied cities, non-overwrite, repeat import and runtime activation")
	quit()
