extends SceneTree
## Run scene cases in one process. The Python runner owns the disposable profile.

const SceneTestCase = preload("res://tests/support/scene_test_case.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	assert(arguments.size() == 1, "Expected a scene batch manifest")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
	assert(OS.get_user_data_dir() == str(manifest.profile)
		and "/OpenSC2K-validation-" in str(manifest.profile), "Expected a disposable validation profile")
	if DisplayServer.get_name() != "headless":
		assert(root.unfocusable and root.gui_embed_subwindows, "Native tests must not take keyboard focus or open extra windows")
		print("PASS: shared native window disables keyboard focus and embeds subwindows")
	var failed := false
	var baseline_children := root.get_children()
	var baseline_filter := root.canvas_item_default_texture_filter
	var baseline_theme := root.theme
	var baseline_scale_size := root.content_scale_size
	var baseline_scale_factor := root.content_scale_factor
	var baseline_scale_mode := root.content_scale_mode
	var baseline_scale_aspect := root.content_scale_aspect
	var baseline_auto_quit := auto_accept_quit
	var baseline_pixels := ScreenPixels.scale
	var baseline_environment := {}

	for key in ["OPENSC2K_GRAPHICS_PACK", "OPENSC2K_DATA_PACK"]:
		baseline_environment[key] = OS.get_environment(key) if OS.has_environment(key) else null

	for entry: Dictionary in manifest.entries:
		var started := Time.get_ticks_msec()
		var progress := FileAccess.open(manifest.progress, FileAccess.WRITE)
		progress.store_string(JSON.stringify({"id": entry.id, "timeout": entry.timeout}))
		progress.close()
		print("SCENE_CASE_START ", JSON.stringify({"id": entry.id, "pid": OS.get_process_id()}))
		AppUiTheme.select("light", true)
		var test := load("res://" + str(entry.script)).new() as SceneTestCase
		assert(test != null, "Batch entries must extend SceneTestCase")
		root.add_child(test)
		test.call("_initialize")

		while not test.completed:
			await process_frame

			if Time.get_ticks_msec() - started > float(entry.timeout) * 1000.0:
				push_error("Scene test exceeded its timeout: " + str(entry.id))
				quit(1)
				return

		var code := test.exit_code
		# Let the test's final stack unwind before removing its nodes and workers.
		await process_frame

		for child in root.get_children():
			if child not in baseline_children:
				child.queue_free()

		await process_frame
		root.canvas_item_default_texture_filter = baseline_filter
		root.theme = baseline_theme
		root.content_scale_size = baseline_scale_size
		root.content_scale_factor = baseline_scale_factor
		root.content_scale_mode = baseline_scale_mode
		root.content_scale_aspect = baseline_scale_aspect
		auto_accept_quit = baseline_auto_quit
		ScreenPixels.set_scale(baseline_pixels)

		for key: String in baseline_environment:
			if baseline_environment[key] == null:
				OS.unset_environment(key)
			else:
				OS.set_environment(key, baseline_environment[key])

		AppUiTheme.select("light", true)
		# Keep the engine's open logs and GPU shader cache.
		for child in DirAccess.get_directories_at("user://"):
			if child not in ["logs", "shader_cache"]:
				_clear_directory("user://" + child)

		for file in DirAccess.get_files_at("user://"):
			assert(DirAccess.remove_absolute("user://" + file) == OK)

		print("SCENE_CASE_END ", JSON.stringify({"id": entry.id, "code": code,
			"seconds": (Time.get_ticks_msec() - started) / 1000.0}))
		failed = failed or code != 0
		if code != 0 and not bool(manifest.keep_going):
			break

	quit(1 if failed else 0)


func _clear_directory(path: String) -> void:
	for child in DirAccess.get_directories_at(path):
		_clear_directory(path.path_join(child))

	for file in DirAccess.get_files_at(path):
		assert(DirAccess.remove_absolute(path.path_join(file)) == OK)

	assert(DirAccess.remove_absolute(path) == OK)
