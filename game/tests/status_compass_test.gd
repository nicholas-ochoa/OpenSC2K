extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var main = (load("res://main.tscn") as PackedScene).instantiate()
	main.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	main.app_settings_path = "user://status-compass-test.cfg"
	root.add_child(main)
	await process_frame
	var status := main.city_status_bar as CityStatusBar
	main.city = null
	main._refresh_status_summary()
	assert(status.compass.compass_rotation == -1)
	assert(status.speed_label.get_index() < status.compass.get_index())
	assert(status.compass.get_index() < status.zoom_label.get_index())

	# Project north toward the same neighbor used by the Neighbors window.
	for rotation in range(4):
		var slot := SimNationWindowControl.display_neighbor_indices(rotation).find(0)
		var expected: Vector2 = SimNationWindowControl.SPRITE_POSITIONS[slot + 1] - SimNationWindowControl.SPRITE_POSITIONS[0]
		assert(StatusCompass.north_direction(rotation).normalized().is_equal_approx(expected.normalized()))
		var projected := StatusCompass.rose_transform(rotation) * Vector2.UP
		assert(projected.normalized().is_equal_approx(expected.normalized()))
		# The other cardinal points must follow the same projected tile axes.
		var east_slot := SimNationWindowControl.display_neighbor_indices(rotation).find(1)
		var east: Vector2 = SimNationWindowControl.SPRITE_POSITIONS[east_slot + 1] - SimNationWindowControl.SPRITE_POSITIONS[0]
		assert((StatusCompass.rose_transform(rotation) * Vector2.RIGHT).normalized().is_equal_approx(east.normalized()))

	# Load an already rotated city without clicking Rotate.
	for saved_rotation in range(4):
		var document := Sc2File.load_path(ProjectSettings.globalize_path(
			"res://../references/SIMCITY2000/DEFAULT.SC2"))
		assert(document.set_misc_u32(0x0008, saved_rotation))
		assert(main._activate_document(document))
		main._select_speed(GameSpeedController.Speed.PAUSED)
		assert(status.compass.compass_rotation == saved_rotation)
		var before: PackedByteArray = document.serialize().data
		main._refresh_status_summary()
		assert(document.serialize().data == before, "Compass refresh changed saved data")

	# Exercise the same handlers as the rotation buttons, including wraparound.
	for counter_clockwise in [false, true]:
		for step in range(4):
			var previous: int = main.city.compass_rotation()
			main._rotate_city(counter_clockwise)
			var expected := (previous + (1 if counter_clockwise else 3)) & 3
			assert(status.compass.compass_rotation == expected)
			assert(status.compass.tooltip_text ==
				"North points %s." % ["lower-right", "upper-right", "upper-left", "lower-left"][expected])

	for mode in ["light", "dark"]:
		AppUiTheme.select(mode)
		await process_frame
		await process_frame
		assert(status.compass.get_theme_color("font_color", "Label") ==
			status.speed_label.get_theme_color("font_color"))
		assert(status.compass.size.x >= 24 and status.compass.size.y >= 24)
		assert(status.speed_label.get_rect().end.x < status.compass.position.x)
		assert(status.compass.get_rect().end.x < status.zoom_label.position.x)

	main.queue_free()
	await process_frame
	print("PASS: Status compass loads, rotates both ways, preserves refresh bytes, and fits both themes")
	quit()
