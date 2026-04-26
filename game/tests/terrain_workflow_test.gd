extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main)
	root.add_child(main)
	await process_frame
	var background := main.main_menu.city_background as MainMenuCityBackground

	for frame in 300:
		if background.demo_texture != null:
			break

		await create_timer(0.02).timeout

	assert(background.demo_texture != null)
	var revision := background.animation_revision
	var before_source := FileAccess.get_file_as_bytes(background.source_path)
	var palette_before := background.demo_palette.animation_image(int(background.elapsed * 5.0)).get_data()
	background._process(0.4)
	assert(background.animation_revision > revision)
	assert(background.demo_palette.animation_image(int(background.elapsed * 5.0)).get_data() != palette_before)
	assert(FileAccess.get_file_as_bytes(background.source_path) == before_source)
	assert(background.static_image.get_pixel(0, 0).a == 0.0)
	main._open_new_city_dialog()
	main._make_new_city_preview()
	while main.new_city_preview_job != null:
		await process_frame
	main._create_new_city_unchecked()
	await process_frame
	assert(main.landscape_editor and main.city_toolbar.start_city_button.visible)
	assert(not main.city_toolbar.toolbar_buttons[6].visible)
	assert(not main.city_toolbar.child_tool_buttons.has(4))
	assert(main.city_toolbar.child_tool_buttons[2].text == "Raise Terrain")

	for subtool in [1, 2, 3]:
		main._select_subtool(subtool)
		assert(main.map_view.shift_rectangle_enabled)
		main.map_view.selection_start = Vector2i(40, 40)
		main.map_view.selection_end = Vector2i(42, 43)
		main.map_view._shift_pressed = true
		main.map_view._rebuild_selection_path()
		assert(main.map_view.selection_path.size() == 12)
		main.map_view._shift_pressed = false
		main.map_view._rebuild_selection_path()
		assert(main.map_view.selection_path.size() == 6)

	main.map_view._clear_selection()

	for subtool in [6, 7]:
		var expected := TerrainToolIcons.terrain_action(main.asset_source.assets.city_ui_graphics, "sea_raise" if subtool == 6 else "sea_lower")
		assert(main._tool_button_icon(0, subtool).get_image().get_data() == expected.get_image().get_data())

	var funds: int = main.city.funds()
	var day: int = main.city.age_in_days()
	main._process(0.5)
	assert(main.city.age_in_days() == day)
	main._select_tool_group(6)
	assert(main.selected_group == 0)
	main.selected_group = 6
	var data: PackedByteArray = main.current_document.serialize().data
	var point := Vector2i(40, 40)
	var path: Array[Vector2i] = [point]
	main._apply_map_selection(point, point, path, false)
	assert(main.current_document.serialize().data == data)
	main._select_tool_group(0)
	main._select_subtool(2)
	main._apply_map_selection(point, point, path, false)
	assert(main.city.funds() == funds)
	assert(main.last_edit_command.get("ok", false))
	assert(main.last_edit_command.get("free_mode", false))
	main._start_city()
	assert(not main.landscape_editor and not main.city_toolbar.start_city_button.visible)
	assert(main.city_toolbar.toolbar_buttons[6].visible)
	main._select_speed(GameSpeedController.Speed.PAUSED)
	data = main.current_document.serialize().data
	var all_levels := CityIsometricRenderer.create_image(main.city, main.palette, main.small_medium_sprites, CityIsometricRenderer.VIEW_SMALL, 0, false, true, false, false)
	main._debug_set_visible_altitude_levels(1)
	assert(main.city.visible_altitude_levels == 1)
	var hidden := 0

	for x in 128:
		for y in 128:
			if not main.city.tile_is_visible(x, y):
				hidden += 1

	assert(hidden > 0)
	var cutaway := CityIsometricRenderer.create_image(main.city, main.palette, main.small_medium_sprites, CityIsometricRenderer.VIEW_SMALL, 0, false, true, false, false)
	assert(all_levels.ok and cutaway.ok and all_levels.image.get_data() != cutaway.image.get_data())
	assert(CityViewFilter.surface_copy(main.city, {}).visible_altitude_levels == 1)
	assert(main.current_document.serialize().data == data)
	main._debug_set_visible_altitude_levels(32)
	assert(main.city.tile_is_visible(40, 40))
	var restored := CityIsometricRenderer.create_image(main.city, main.palette, main.small_medium_sprites, CityIsometricRenderer.VIEW_SMALL, 0, false, true, false, false)
	assert(restored.image.get_data() == all_levels.image.get_data())
	assert(main.current_document.serialize().data == data)
	main._select_tool_group(3)
	main._select_subtool(2)
	assert(main._placement_preview_error(Vector2i(0, 0)).contains("outside"))
	main._set_overlay("underground")
	main._set_underground_pipes_visible(false)
	main._set_underground_subways_visible(false)
	assert(main.status_label.text == "Underground subways hidden.")
	var bridge := main.bridge_dialog as BridgeSelectionDialog
	bridge.preview_palette = main.palette
	bridge.preview_sprites = main.large_sprites
	var images := {}

	for type in [2, 3, 4, 5, 6]:
		var texture := bridge.preview_image("highway" if type >= 5 else "network", type)
		assert(texture != null)
		var signature := hash(texture.get_image().get_data())
		assert(not images.has(signature))
		images[signature] = true

	main._open_scurk_dialog()
	await process_frame
	await process_frame
	assert(main.scurk_editor.palette_panel.tabs.get_tab_count() == 3)
	assert(main.scurk_editor.canvas_panel.previews_panel.get_parent() == main.scurk_editor.palette_panel.tabs)
	main.scurk_editor._fit_canvas()
	assert(main.scurk_editor.pixel_canvas.zoom >= 1)
	main.queue_free()
	await process_frame
	print("PASS: free landscape stage and Start City, blocked structures, height cutoff without saved edits, placement reasons, bridge previews, layer status, SCURK tabs, live menu animation and source isolation")
	quit()
