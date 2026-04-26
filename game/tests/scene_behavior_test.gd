extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cases := ["about", "picture_notice", "scenario", "player_dialog",
		"city_window", "settings", "sidebar", "workspace"]
	var selected := OS.get_cmdline_user_args()
	for name in selected:
		assert(name in cases, "Unknown scene case: " + name)
	for name in cases:
		if not selected.is_empty() and name not in selected:
			continue
		var original_size := root.size
		var children := root.get_children()
		var test = load("res://tests/suites/scenes/%s_scene_test.gd" % name).new()
		test.tree = self
		AppUiTheme.select("light")
		await test.run()
		test = null
		await process_frame
		assert(root.get_children() == children, "Scene case leaked a root child: " + name)
		root.size = original_size
		AppUiTheme.select("light")
		await process_frame
	print("PASS: isolated scene instances, signals, viewport limits, input and cleanup")
	quit()
