extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("user://missing-test-art"))
	var main = (load("res://main.tscn") as PackedScene).instantiate()
	main.reference_root = ProjectSettings.globalize_path("user://missing-test-originals")
	main.preferences.settings_path = "user://status-compass-test.cfg"
	root.add_child(main)
	await process_frame
	main.set_process(false)
	var status := main.city_status_bar as CityStatusBar
	main.document_state.city = null
	main.interface.refresh_status_summary()
	assert(status.compass.compass_rotation == -1)

	# The display uses fixed diagonals and exact screen-space quarter turns.
	for rotation in range(4):
		var north := StatusCompass.north_direction(rotation).normalized()
		var next := StatusCompass.north_direction(rotation + 1).normalized()
		assert(is_equal_approx(absf(north.x), absf(north.y)))
		assert(is_zero_approx(north.dot(next)))
		assert(is_equal_approx(north.cross(next), -1.0))

	# Load an already rotated city without clicking Rotate.
	for saved_rotation in range(4):
		var document := EmptyCityTemplate.create(128)
		assert(document.set_misc_u32(0x0008, saved_rotation))
		assert(main.city_session.activate_document(document))
		main.frame.select_speed(GameSpeedController.Speed.PAUSED)
		assert(status.compass.compass_rotation == saved_rotation)
		var before: PackedByteArray = document.serialize().data
		main.interface.refresh_status_summary()
		assert(document.serialize().data == before, "Compass refresh changed saved data")

	# Exercise the same handlers as the rotation buttons, including wraparound.
	for counter_clockwise in [false, true]:
		for step in range(4):
			var previous: int = main.document_state.city.compass_rotation()
			main.camera_input.rotate_city(counter_clockwise)
			var expected := (previous + (1 if counter_clockwise else 3)) & 3
			assert(status.compass.compass_rotation == expected)

	main.queue_free()
	await process_frame
	print("PASS: Status compass loads, rotates both ways, preserves refresh bytes")
	quit()
