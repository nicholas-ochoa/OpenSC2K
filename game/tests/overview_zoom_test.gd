extends SceneTree

# The animated menu has its own tests. Do not render a random second city here.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var preview := "--preview" in OS.get_cmdline_user_args()
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	if not preview:
		main.set_script(preload("res://tests/support/app_fixture.gd").NoMenuApp)
	main.asset_state.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	root.add_child(main)
	await process_frame
	assert(main.map_view.zoom_percent() == 100, "Default zoom changed")
	# Keep the manual preview populated; automated picking needs only known terrain.
	if not preview:
		main.set_process(false)
		main.main_menu.city_background.set_process(false)
	var doc := Sc2File.load_path("res://../references/SIMCITY2000/CITIES/SYDNEY.SC2") if preview else EmptyCityTemplate.create(128)
	if not preview:
		var city := CityState.from_document(doc)
		assert(city.set_land_altitude(64, 64, 7))
		assert(city.set_building_id(64, 64, BuildingTileIds.ROAD_STRAIGHT_1))
	# Start near overview; a full-size initial render is not part of this check.
	main.map_view.zoom_factor = 0.25
	assert(main.city_session.activate_document(doc))
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	var before: PackedByteArray = doc.serialize().data
	var map: CityMapControl = main.map_view
	main.preferences.zoom_graphics = AppSettingsStore.normalize_zoom_graphics([2, 2, 2, 2, 2, 2])
	map.zoom_factor = 0.25
	map.center_on_tile(Vector2i(64, 64))
	assert(map.zoom_out(Vector2.INF) and map.zoom_percent() == 10)
	assert(not map.can_zoom_out() and not map.zoom_out(Vector2.INF))
	assert(main.zoom_out_button.disabled and not main.zoom_in_button.disabled)
	assert(main.static_render.city_view_size() == CityIsometricRenderer.VIEW_SMALL)
	assert(AppSettingsStore.graphics_size_at_zoom(main.preferences.zoom_graphics, 25) == 2, "Graphics choice indices changed")

	for mode: CityViewMode.Mode in [CityViewMode.Mode.UNDERGROUND, CityViewMode.Mode.HEIGHT, CityViewMode.Mode.LAND_VALUE, CityViewMode.Mode.CITY]:
		main.menus.set_overlay(mode)
		assert(map.zoom_percent() == 10)
		var point := Vector2i(64, 64)
		var polygon := CityIsometricRenderer.tile_polygon(main.document_state.city, point.x, point.y, mode == CityViewMode.Mode.HEIGHT)
		var center := (polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.25
		var local := map.camera._draw_offset(map.camera._view_scale()) + center * map.camera._view_scale()
		assert(map.camera._tile_at(local) == point, "Overview picking uses the displayed tile")

	# Selection is a settings lookup. The mode/picking checks above exercise rendering.
	for graphics_size in [1, 2, 0]:
		main.preferences.overview_graphics = graphics_size
		assert(main.static_render.city_view_size() == graphics_size)

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
