extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var folder := "user://runtime-pack-%d" % OS.get_process_id()
	var source := ProjectSettings.globalize_path("res://../ext/graphics")

	if not FileAccess.file_exists(source.path_join("pack.json")):
		print("SKIP: export original graphics pack first")
		quit()

		return

	var original_folder := folder.path_join("original-fixture")
	DirAccess.make_dir_recursive_absolute(folder)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("pack.json")))
	manifest.name = "Runtime test"

	for field in ["city_ui", "desktop", "scurk", "runtime_data"]:
		manifest.erase(field)

	var record: Dictionary = manifest.large_sprites.back()
	# Keep flat terrain at all views and the edited sprite; other sprites are not used.
	manifest.large_sprites = manifest.large_sprites.filter(func(item): return int(item.id) in [1256, int(record.id)])
	manifest.small_medium_sprites = manifest.small_medium_sprites.filter(func(item): return int(item.id) in [256, 756])
	var files: Array = [manifest.palette, manifest.scenario_palette]
	files.append_array(manifest.ui.values())
	for item in manifest.large_sprites + manifest.small_medium_sprites:
		files.append(item.png)
	for relative in files:
		var target: String = folder.path_join(str(relative))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		assert(DirAccess.copy_absolute(source.path_join(str(relative)), target) == OK)
	# Startup and restore use the same small real pack, before the pixel edit.
	for relative in files:
		var target: String = original_folder.path_join(str(relative))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		assert(DirAccess.copy_absolute(source.path_join(str(relative)), target) == OK)
	var original_manifest := manifest.duplicate(true)
	original_manifest.name = "Original fixture"
	var original_file := FileAccess.open(original_folder.path_join("pack.json"), FileAccess.WRITE)
	original_file.store_string(JSON.stringify(original_manifest))
	original_file.close()
	var sprite := IndexedPng.load_path(folder.path_join(record.png))
	sprite.pixels[0] = 171 if sprite.pixels[0] != 171 else 172
	var encoded := IndexedPng.encode(sprite.width, sprite.height, sprite.pixels, sprite.palette)
	assert(encoded.ok)
	var file := FileAccess.open(folder.path_join(record.png), FileAccess.WRITE)
	file.store_buffer(encoded.bytes)
	file.close()
	file = FileAccess.open(folder.path_join("pack.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path(original_folder))
	main.asset_state.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	main.preferences.settings_path = folder.path_join("settings.cfg")
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	main.map_view.zoom_factor = 0.25
	assert(main.city_session.activate_document(EmptyCityTemplate.create()))
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	var before: PackedByteArray = main.document_state.city.document.serialize().data
	main.settings.open_settings_dialog()
	var dialog: AppSettingsDialog = main.main_overlays.settings_dialog
	assert(dialog.folder_row.visible)

	for kind in ["sound", "music"]:
		var active_name: String = main.audio_controller.sound_pack.pack_name if kind == "sound" else main.audio_controller.music_pack.pack_name
		assert(dialog.pack_name_labels[kind].text == active_name)
		var edit: LineEdit = dialog.pack_edits[kind]
		var old_path := edit.text
		edit.text = "user://pending-%s/pack.json" % kind
		assert(dialog.pack_name_labels[kind].text.is_empty())
		edit.text = old_path
		assert(dialog.pack_name_labels[kind].text == active_name)

	assert(not ("soundtrack_folder" in dialog.selected_values()))
	var pickers := 0

	for child in dialog.get_children():
		if child is FileDialog:
			pickers += 1
			assert(child.file_mode == FileDialog.FILE_MODE_OPEN_FILE and child.filters[0].begins_with("pack.json"))

	assert(pickers == 3)
	assert(dialog.folder_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE)
	assert(dialog.folder_dialog.filters[0].begins_with("pack.json"))

	dialog.folder_dialog.file_selected.emit(folder.path_join("pack.json"))
	dialog.default_mayor_edit.text = "Alex"
	dialog.overview_graphics_selector.select(2)
	main.settings.apply_settings()
	assert(main.preferences.default_mayor_name == "Alex")
	assert(main.preferences.overview_graphics == 2)
	assert(AppSettingsStore.load_values(main.preferences.settings_path).default_mayor_name == "Alex")
	assert(main.asset_state.asset_source.graphics_name == "Runtime test")
	assert(dialog.pack_name_labels.graphics.text == "Runtime test")
	assert(main.asset_state.base_large_sprites.find_sprite(record.id).decode_indices().pixels == sprite.pixels)
	assert(main.main_menu.city_background.demo_sprites == main.asset_state.large_sprites)
	assert(main.document_state.city.document.serialize().data == before)
	dialog.folder_edit.text = original_folder.path_join("pack.json")
	main.settings.apply_settings()
	assert(main.asset_state.asset_source.graphics_name == original_manifest.name)
	assert(main.asset_state.base_large_sprites.find_sprite(record.id).decode_indices().pixels != sprite.pixels)
	assert(main.document_state.city.document.serialize().data == before)
	main.main_overlays.settings_dialog.hide()
	main.new_city.open_new_city_dialog()
	assert(main.city_dialogs.new_city_dialog.mayor_name_input.text == "Alex")
	assert(main.document_state.city.document.serialize().data == before)
	main.city_dialogs.new_city_dialog.hide()
	main.queue_free()
	await process_frame
	_remove_folder(ProjectSettings.globalize_path(folder))
	print("PASS: pack file pickers, compact settings, live graphics Apply and restore, unchanged city bytes")
	quit()


func _remove_folder(folder: String) -> void:
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))

	for name in DirAccess.get_directories_at(folder):
		_remove_folder(folder.path_join(name))

	DirAccess.remove_absolute(folder)
