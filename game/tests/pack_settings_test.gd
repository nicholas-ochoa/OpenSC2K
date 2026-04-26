extends SceneTree

const Fixture = preload("res://tests/indexed_png_test.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var folder := "user://runtime-pack-%d" % OS.get_process_id()
	var source := ProjectSettings.globalize_path("res://../ext/graphics")

	if not FileAccess.file_exists(source.path_join("pack.json")):
		print("SKIP: export original graphics pack first")
		quit()

		return

	_copy_folder(source, ProjectSettings.globalize_path(folder))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("pack.json")))
	manifest.name = "Runtime test"
	var record: Dictionary = manifest.large_sprites.back()
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
	main.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	main.app_settings_path = folder.path_join("settings.cfg")
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	main._load_city_unchecked(ProjectSettings.globalize_path("res://../references/SIMCITY2000/DEFAULT.SC2"))
	main._select_speed(GameSpeedController.Speed.PAUSED)
	var before: PackedByteArray = main.city.document.serialize().data
	main._open_settings_dialog()
	var dialog: AppSettingsDialog = main.settings_dialog
	assert(dialog.tabs.get_tab_count() == 5 and dialog.tabs.get_tab_title(3) == "Import Data")
	assert(dialog.toolbar_sounds_check.text == "Play toolbar sounds")
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

	assert(not dialog.selected_values().has("soundtrack_folder"))
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
	main._apply_settings()
	assert(main.app_default_mayor_name == "Alex")
	assert(main.app_overview_graphics == 2)
	assert(AppSettingsStore.load_values(main.app_settings_path).default_mayor_name == "Alex")
	assert(main.asset_source.graphics_name == "Runtime test")
	assert(dialog.pack_name_labels.graphics.text == "Runtime test")
	assert(main.base_large_sprites.find_sprite(record.id).decode_indices().pixels == sprite.pixels)
	assert(main.main_menu.city_background.demo_sprites == main.large_sprites)
	assert(main.city.document.serialize().data == before)
	assert(not main.status_label.text.contains("Restart"))
	dialog.folder_edit.text = source.path_join("pack.json")
	main._apply_settings()
	assert(main.asset_source.graphics_name == "Original SimCity 2000")
	assert(dialog.pack_name_labels.graphics.text == "Original SimCity 2000")
	assert(main.base_large_sprites.find_sprite(record.id).decode_indices().pixels != sprite.pixels)
	assert(main.city.document.serialize().data == before)
	main.settings_dialog.hide()
	main._open_new_city_dialog()
	assert(main.new_city_dialog.mayor_name_input.text == "Alex")
	assert(main.city.document.serialize().data == before)
	main.new_city_dialog.hide()
	main.queue_free()
	await process_frame
	_remove_folder(ProjectSettings.globalize_path(folder))
	print("PASS: pack file pickers, compact settings, live graphics Apply and restore, unchanged city bytes")
	quit()


func _copy_folder(source: String, target: String) -> void:
	DirAccess.make_dir_recursive_absolute(target)

	for name in DirAccess.get_files_at(source):
		assert(DirAccess.copy_absolute(source.path_join(name), target.path_join(name)) == OK)

	for name in DirAccess.get_directories_at(source):
		_copy_folder(source.path_join(name), target.path_join(name))


func _remove_folder(folder: String) -> void:
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))

	for name in DirAccess.get_directories_at(folder):
		_remove_folder(folder.path_join(name))

	DirAccess.remove_absolute(folder)
