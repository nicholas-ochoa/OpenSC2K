extends SceneTree
## Native-art fallback at the new zoom, with an optional isolated live scene.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var preview := "--preview" in OS.get_cmdline_user_args()
	if preview:
		var leftmost := 0
		for screen in DisplayServer.get_screen_count():
			if DisplayServer.screen_get_position(screen).x < DisplayServer.screen_get_position(leftmost).x:
				leftmost = screen
		root.current_screen = leftmost
		root.position = DisplayServer.screen_get_usable_rect(leftmost).position + Vector2i(20, 30)
		root.mode = Window.MODE_MAXIMIZED
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main._load_city_unchecked(ProjectSettings.globalize_path("res://../references/CITIES/SYDNEY.SC2"))
	main._select_speed(GameSpeedController.Speed.PAUSED)
	var map: CityMapControl = main.map_view
	var city: CityState = main.city
	assert(city != null and city.is_valid())
	assert(SignCommand.set_sign(city, Vector2i(64, 64), "Zoom check").ok)
	map.zoom_factor = 4.0
	map.center_on_tile(Vector2i(64, 64))
	map.zoom_changed.emit(400)
	if preview:
		print("PREVIEW: native artwork at 400%; temporary sign; no source city writes")
		return
	await process_frame
	var saved: PackedByteArray = city.document.serialize().data
	assert(map.zoom_percent() == 400 and not map.can_zoom_in())
	assert(main.zoom_in_button.disabled and not main.zoom_out_button.disabled)
	assert(main.city_status_bar.zoom_label.text == "Zoom: 400%")
	assert(main._city_view_size() == CityIsometricRenderer.VIEW_LARGE)
	assert(main._sprite_archive_for_view(2) == main.large_sprites)
	var anchor := map.size * Vector2(0.4, 0.6)
	var source := (anchor - map._draw_offset(map._view_scale())) / map._view_scale()
	assert(map.zoom_out(anchor) and map.zoom_percent() == 200)
	assert(map.zoom_in(anchor) and map.zoom_percent() == 400)
	var after := (anchor - map._draw_offset(map._view_scale())) / map._view_scale()
	assert(source.distance_to(after) <= 0.5, "Zoom moved the map point under the pointer")
	assert(not map.zoom_in(anchor))
	assert(CityMapControl.sign_display_multiplier(4.0) == 4.0)
	for mode in ["underground", "city"]:
		main._set_overlay(mode)
		assert(map.zoom_percent() == 400 and main._city_view_size() == 2)
	assert(city.document.serialize().data == saved, "Zoom or layer change altered saved data")
	main.queue_free()
	await process_frame
	print("PASS: 400 percent zoom limits, toolbar/status, pointer anchor, native fallback, signs, underground and unchanged city bytes")
	quit()
