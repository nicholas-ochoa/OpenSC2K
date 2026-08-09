extends SceneTree
const DocumentState = preload("res://tests/support/document_state.gd")


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
	var dialog := preload("res://src/ui/settings/app_settings_dialog.tscn").instantiate() as AppSettingsDialog
	root.add_child(dialog)
	dialog.show_values(0.5, 0.5, false, "auto", "", "cpu")
	assert(dialog.selected_values().city_renderer == "cpu")
	dialog.renderer_selector.select(0)
	assert(dialog.selected_values().city_renderer == "gpu")
	dialog.free()
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	assert(main.city_session.activate_document(EmptyCityTemplate.create(256)))
	var before: Array = DocumentState.capture(main.document_state.city.document)
	# The environment override remains explicit, independent of the saved default.
	OS.set_environment("OPENSC2K_CITY_RENDERER", "gpu")
	main.preferences.city_renderer = "gpu"
	main.settings._set_city_renderer("cpu")
	assert(main.render_caches.region_cache.gpu_enabled)
	OS.set_environment("OPENSC2K_CITY_RENDERER", "cpu")
	main.settings._set_city_renderer("gpu")
	assert(not main.render_caches.region_cache.gpu_enabled)
	assert(DocumentState.capture(main.document_state.city.document) == before, "Changing renderer altered saved data")


	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS: renderer preference persistence, preservation, settings selection, live replacement, removed renderer menu and save state")
	quit()
