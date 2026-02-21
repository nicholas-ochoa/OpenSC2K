extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "user://renderer_settings_%d.cfg" % OS.get_process_id()
	assert(AppSettingsStore.load_values(path).city_renderer == "gpu")
	assert(AppSettingsStore.save_values(0.5, 0.5, false, path, "", "", null, "cpu") == OK)
	assert(AppSettingsStore.load_values(path).city_renderer == "cpu")
	assert(AppSettingsStore.save_values(0.4, 0.4, false, path) == OK)
	assert(AppSettingsStore.load_values(path).city_renderer == "cpu")
	assert(AppSettingsStore.normalize_renderer("invalid") == "gpu")
	var dialog := AppSettingsDialog.new()
	root.add_child(dialog)
	dialog.show_values(0.5, 0.5, false, "auto", "", "cpu")
	assert(dialog.selected_values().city_renderer == "cpu")
	dialog.renderer_selector.select(0)
	assert(dialog.selected_values().city_renderer == "gpu")
	dialog.free()
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	assert(main._activate_document(Sc2File.load_path("res://../local/large-cities/stitched-512.sc2x")))
	var before: PackedByteArray = main.city.document.serialize().data
	# The environment override remains explicit, independent of the saved default.
	OS.set_environment("OPENSC2K_CITY_RENDERER", "gpu")
	main.app_city_renderer = "gpu"
	main._set_city_renderer("cpu")
	assert(main.region_cache.gpu_enabled)
	OS.set_environment("OPENSC2K_CITY_RENDERER", "cpu")
	main._set_city_renderer("gpu")
	assert(not main.region_cache.gpu_enabled)
	assert(main.city.document.serialize().data == before, "Changing renderer altered saved data")
	for menu_index in main.options_menu.get_popup().item_count:
		assert(main.options_menu.get_popup().get_item_text(menu_index) != "Renderer")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS: renderer preference persistence, preservation, settings selection, live replacement, removed renderer menu and save state")
	quit()
