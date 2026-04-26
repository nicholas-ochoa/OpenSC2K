extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var preview := "--preview" in OS.get_cmdline_user_args()
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	root.add_child(main)
	await process_frame
	assert(main.map_view.zoom_percent() == 100, "Default zoom changed")
	var doc := Sc2File.load_path("res://../references/SIMCITY2000/CITIES/SYDNEY.SC2")
	assert(main._activate_document(doc))
	main._select_speed(GameSpeedController.Speed.PAUSED)
	var before: PackedByteArray = doc.serialize().data
	var map: CityMapControl = main.map_view
	main.app_zoom_graphics = AppSettingsStore.normalize_zoom_graphics([2, 2, 2, 2, 2, 2])
	map.zoom_factor = 0.25
	map.center_on_tile(Vector2i(64, 64))
	assert(map.zoom_out(Vector2.INF) and map.zoom_percent() == 10)
	assert(not map.can_zoom_out() and not map.zoom_out(Vector2.INF))
	assert(main.zoom_out_button.disabled and not main.zoom_in_button.disabled)
	assert(main._city_view_size() == CityIsometricRenderer.VIEW_SMALL)
	assert(AppSettingsStore.graphics_size_at_zoom(main.app_zoom_graphics, 25) == 2, "Graphics choice indices changed")

	for mode in ["underground", "height", "land_value", "city"]:
		main._set_overlay(mode)
		assert(map.zoom_percent() == 10)
		var point := Vector2i(64, 64)
		var polygon := CityIsometricRenderer.tile_polygon(main.city, point.x, point.y, mode == "height")
		var center := (polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.25
		var local := map._draw_offset(map._view_scale()) + center * map._view_scale()
		assert(map._tile_at(local) == point, "Overview picking uses the displayed tile")

	for graphics_size in [1, 2, 0]:
		main.app_overview_graphics = graphics_size
		main._close_region_cache()
		main._refresh_map()
		assert(main._city_view_size() == graphics_size)
		await process_frame

	assert(map.zoom_in(Vector2.INF) and map.zoom_percent() == 25)
	assert(map.zoom_out(Vector2.INF) and map.zoom_percent() == 10)
	assert(doc.serialize().data == before, "Overview is display-only")

	if preview:
		print("PREVIEW: 10% overview; source city is not saved")
		return

	main.queue_free()
	await process_frame
	print("PASS: 10% zoom, default zoom, limits, toolbar/status, native Small, view switching, picking and unchanged city bytes")
	quit()
