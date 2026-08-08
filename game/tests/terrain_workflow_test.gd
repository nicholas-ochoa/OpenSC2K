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
	main.map_view.zoom_factor = 0.25
	main.new_city._open_new_city_dialog()
	main.new_city_dialog.size_input.select(main.new_city_dialog.size_input.get_item_index(64))
	main.new_city._make_new_city_preview()
	while main.new_city_preview_job != null:
		await process_frame
	main.new_city._create_new_city_unchecked()
	await process_frame
	assert(main.landscape_editor and main.city_toolbar.start_city_button.visible)
	assert(not main.city_toolbar.toolbar_buttons[6].visible)
	assert(not main.city_toolbar.child_tool_buttons.has(4))

	for subtool in [2, 3]:
		main.current_tool.select_subtool(subtool)
		assert(main.map_view.shift_rectangle_enabled)
		main.map_view.selection_start = Vector2i(40, 40)
		main.map_view.selection_end = Vector2i(42, 43)
		main.map_view._shift_pressed = true
		main.map_view.selection._rebuild_selection_path()
		assert(main.map_view.selection_path.size() == 12)
		main.map_view._shift_pressed = false
		main.map_view.selection._rebuild_selection_path()
		assert(main.map_view.selection_path.size() == 6)

	main.current_tool.select_subtool(1)
	assert(main.map_view.uses_paint_brush() and main.map_view.shift_rectangle_enabled)
	main.map_view.brush_box_selection = true
	main.map_view.selection._rebuild_selection_path()
	assert(main.map_view.selection_path.size() == 12)
	main.map_view.brush_box_selection = false
	main.map_view.selection._clear_selection()

	for subtool in [6, 7]:
		var expected := TerrainToolIcons.terrain_action(main.asset_source.assets.city_ui_graphics, "sea_raise" if subtool == 6 else "sea_lower")
		assert(main.camera_input.tool_button_icon(0, subtool).get_image().get_data() == expected.get_image().get_data())

	var funds: int = main.city.funds()
	var day: int = main.city.age_in_days()
	main._process(0.5)
	assert(main.city.age_in_days() == day)
	main.current_tool.select_tool_group(6)
	assert(main.selected_group == 0)
	main.selected_group = 6
	var data: PackedByteArray = main.document_state.current_document.serialize().data
	var point := Vector2i(40, 40)
	var path: Array[Vector2i] = [point]
	main.city_edits._apply_map_selection(point, point, path, false)
	assert(main.document_state.current_document.serialize().data == data)
	main.current_tool.select_tool_group(0)
	main.current_tool.select_subtool(2)
	main.city_edits._apply_map_selection(point, point, path, false)
	assert(main.city.funds() == funds)
	assert(main.last_edit_command.ok)
	assert(main.last_edit_command.free_mode)
	main.new_city._start_city()
	assert(not main.landscape_editor and not main.city_toolbar.start_city_button.visible)
	assert(main.city_toolbar.toolbar_buttons[6].visible)
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	data = main.document_state.current_document.serialize().data
	var all_levels := CityIsometricRenderer.create_image(main.city, main.palette, main.small_medium_sprites, CityIsometricRenderer.VIEW_SMALL, 0, false, true, false, false)
	main.debug._debug_set_visible_altitude_levels(1)
	assert(main.city.visible_altitude_levels == 1)
	var hidden := 0

	for x in main.city.map_size:
		for y in main.city.map_size:
			if not main.city.tile_is_visible(x, y):
				hidden += 1

	assert(hidden > 0)
	var cutaway := CityIsometricRenderer.create_image(main.city, main.palette, main.small_medium_sprites, CityIsometricRenderer.VIEW_SMALL, 0, false, true, false, false)
	assert(all_levels.ok and cutaway.ok and all_levels.image.get_data() != cutaway.image.get_data())
	assert(CityViewFilter.surface_copy(main.city, {}).visible_altitude_levels == 1)
	assert(main.document_state.current_document.serialize().data == data)
	main.debug._debug_set_visible_altitude_levels(32)
	assert(main.city.tile_is_visible(40, 40))
	var restored := CityIsometricRenderer.create_image(main.city, main.palette, main.small_medium_sprites, CityIsometricRenderer.VIEW_SMALL, 0, false, true, false, false)
	assert(restored.image.get_data() == all_levels.image.get_data())
	assert(main.document_state.current_document.serialize().data == data)
	main.current_tool.select_tool_group(3)
	main.current_tool.select_subtool(2)
	assert(not main.current_tool._placement_preview_error(Vector2i(0, 0)).is_empty())
	main.menus.set_overlay(CityViewMode.Mode.UNDERGROUND)
	main.menus.set_underground_pipes_visible(false)
	main.menus.set_underground_subways_visible(false)
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

	main.scurk_workspace.open_scurk_dialog()
	await process_frame
	await process_frame
	main.scurk_editor._fit_canvas()
	assert(main.scurk_editor.pixel_canvas.zoom >= 1)
	main.queue_free()
	await process_frame
	print("PASS: free landscape stage and Start City, blocked structures, height cutoff without saved edits, placement reasons, bridge previews, layer status, SCURK tabs, live menu animation and source isolation")
	quit()
