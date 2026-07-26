extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	root.add_child(main)
	await process_frame
	main.new_city._open_new_city_dialog()
	var dialog: NewCityTerrainDialog = main.new_city_dialog
	main.map_view.zoom_factor = 0.25
	# Exercise the workflow with simple terrain; layout algorithms have their own tests.
	dialog.hills_input.value = 0
	dialog.water_input.value = 0
	dialog.trees_input.value = 0
	await process_frame
	await process_frame
	_assert_editor_controls(main, false)
	assert(dialog.get_viewport_rect().grow(1.0).encloses(dialog.panel.get_global_rect()), "New City controls fit the viewport")
	assert(not dialog.compatibility_input.button_pressed)
	assert(dialog.native_maps_input.button_pressed)
	assert(dialog.done_button.disabled and main.new_city_session.preview_document == null)
	for key in ["bay", "delta", "peninsula", "island", "islands", "meander", "crossing", "branch", "rejoin", "valley", "cliffs"]:
		dialog.reset_features()
		dialog.ocean_input.button_pressed = false
		dialog.river_input.button_pressed = false
		dialog.feature_inputs[key].button_pressed = true
		if key in ["bay", "delta", "peninsula", "island", "islands", "cliffs"]:
			assert(dialog.ocean_input.button_pressed)
		if key in ["delta", "meander", "crossing", "branch", "rejoin", "valley"]:
			assert(dialog.river_input.button_pressed)
		dialog.ocean_input.button_pressed = false
		dialog.river_input.button_pressed = false
		assert(not dialog.feature_inputs[key].button_pressed)
	dialog.reset_features()
	dialog.river_input.button_pressed = true
	dialog.feature_inputs.canyon.button_pressed = true
	assert(not dialog.river_input.button_pressed and dialog.river_input.disabled)
	for key in dialog.RIVER_FEATURES:
		assert(dialog.feature_inputs[key].disabled and not dialog.feature_inputs[key].button_pressed)
	for group in dialog.EXCLUSIVE_GROUPS:
		for selected in group:
			dialog.reset_features()
			dialog.feature_inputs[selected].button_pressed = true
			for other in group:
				if other != selected:
					assert(dialog.feature_inputs[other].disabled)
			dialog.feature_inputs[selected].button_pressed = false
			for other in group:
				assert(not dialog.feature_inputs[other].disabled)
	dialog.reset_features()
	dialog.feature_inputs.branch.button_pressed = true
	dialog.feature_inputs.bay.button_pressed = true
	assert(dialog.selected_features() == ["branch", "bay"])
	dialog.feature_inputs.meander.button_pressed = true
	dialog.feature_inputs.island.button_pressed = true
	assert(dialog.river_input.disabled and not dialog.river_input.button_pressed)
	assert(dialog.feature_inputs.delta.disabled)
	assert(dialog.feature_inputs.meander.disabled and not dialog.feature_inputs.meander.button_pressed)
	assert(dialog.feature_inputs.branch.disabled and not dialog.feature_inputs.branch.button_pressed)
	dialog.feature_inputs.islands.button_pressed = true
	assert(not dialog.feature_inputs.island.button_pressed)
	dialog.reset_features()
	dialog.river_input.button_pressed = false
	var peek := InputEventMouseButton.new()
	peek.position = dialog.panel.get_global_rect().get_center()
	peek.button_index = MOUSE_BUTTON_RIGHT
	peek.pressed = true
	root.push_input(peek, true)
	assert(dialog.panel.modulate.a == 0.0 and dialog.visible)
	_assert_editor_controls(main, false)
	peek.position = Vector2.ZERO
	peek.pressed = false
	root.push_input(peek, true)
	assert(dialog.panel.modulate.a == 1.0)
	dialog.size_input.select(dialog.size_input.get_item_index(512))
	dialog.compatibility_input.button_pressed = true
	assert(dialog.size_input.get_selected_id() == 128)
	assert(dialog.size_input.disabled and dialog.native_maps_input.disabled)
	assert(not dialog.native_maps_input.button_pressed)
	main.audio_controller.application_has_focus = true
	main.audio_controller.wave_sound_gate.stop()
	main.new_city._make_new_city_preview()
	assert(dialog.generating and dialog.done_button.disabled)
	assert(dialog._busy_spinner.is_visible_in_tree() and dialog._busy_spinner.is_processing())
	while main.new_city_preview_job != null:
		await process_frame
	assert(not dialog.generating)
	assert(not dialog._busy_spinner.is_processing())
	assert(main.audio_controller.wave_sound_gate.current_sound_id == 529)
	assert(dialog.candidate_valid and not dialog.done_button.disabled)
	assert(dialog.landscape_background.texture != null)
	assert(NewCityPreviewJob.preview_view_size(128, Vector2(3000, 1800)) == CityIsometricRenderer.VIEW_LARGE)
	assert(NewCityPreviewJob.preview_view_size(512, Vector2(1920, 1080)) == CityIsometricRenderer.VIEW_SMALL)
	assert(dialog.landscape_background.texture.get_width() >= dialog.size.x)
	var candidate: Sc2File = main.new_city_session.preview_document
	var bytes: PackedByteArray = candidate.serialize().data
	var cursor: int = main.new_city_session.preview_process_cursor
	var revision := dialog.generation_revision
	dialog.city_name_input.text = "New Cedar Grove"
	dialog.city_name_input.text_changed.emit(dialog.city_name_input.text)
	dialog.mayor_name_input.text = "Cedar Mayor"
	dialog.mayor_name_input.text_changed.emit(dialog.mayor_name_input.text)
	dialog.difficulty_input.select(1)
	dialog.difficulty_input.item_selected.emit(1)
	dialog.year_input.select(1)
	dialog.year_input.item_selected.emit(1)
	dialog._random_name()
	assert(dialog.candidate_valid and not dialog.done_button.disabled)
	assert(dialog.generation_revision == revision)
	assert(main.new_city_session.preview_document == candidate)
	assert(candidate.serialize().data == bytes)
	assert(main.new_city_session.preview_process_cursor == cursor)
	dialog.hills_input.value += 1
	await create_timer(0.25).timeout
	assert(dialog.done_button.disabled and not dialog.candidate_valid)
	assert(candidate.serialize().data == bytes)
	assert(main.new_city_session.preview_process_cursor == cursor)
	main.new_city._create_new_city_unchecked()
	assert(main.city == null)
	dialog.compatibility_input.button_pressed = false
	dialog.size_input.select(dialog.size_input.get_item_index(16))
	assert(not dialog.size_input.disabled and not dialog.native_maps_input.disabled)
	dialog._random_name()
	assert(dialog.city_name_input.text.length() <= 30)
	main.new_city._make_new_city_preview()
	while main.new_city_preview_job != null:
		await process_frame
	var generated: Sc2File = main.new_city_session.preview_document
	dialog.city_name_input.text = "New Cedar Grove"
	dialog.city_name_input.text_changed.emit(dialog.city_name_input.text)
	main.new_city._create_new_city_unchecked()
	assert(main.city.city_name() == "New Cedar Grove")
	assert(main.city.mayor_name() == "Cedar Mayor")
	assert(main.city.founding_year() == dialog.year_input.get_selected_id())
	assert(main.city.difficulty() == dialog.difficulty_input.get_selected_id())
	assert(main.landscape_editor)
	for id in ["ALTM", "XTER", "XBLD", "XBIT"]:
		assert(main.document_state.current_document.find_chunk(id).decoded_payload == generated.find_chunk(id).decoded_payload)
	assert(main.city_toolbar.regenerate_button.visible)
	assert(not main.city_toolbar.child_palette.visible)
	assert(main.city_toolbar.landscape_buttons.size() == 12)
	assert(not main.city_toolbar.landscape_buttons.has(Vector2i(16, 1)))
	assert(not main.city_toolbar.view_mode_buttons.underground.visible)
	assert(main.city_toolbar.view_mode_buttons.height.visible)
	assert(not main.city_toolbar.data_view_input.visible)
	for key in main.city_toolbar.view_visibility_checks:
		assert(main.city_toolbar.view_visibility_checks[key].visible == (key in ["water", "trees"]))
	main.city_toolbar.view_mode_buttons.height.pressed.emit()
	assert(main.overlay_mode == "height")
	await process_frame
	main.city_toolbar.view_mode_buttons.city.pressed.emit()
	main.current_tool._select_tool_group(16)
	main.current_tool._select_subtool(1)
	assert(main.selected_subtool == 0)
	await process_frame
	main.current_tool._select_tool_group(1)
	main.current_tool._select_subtool(0)
	await process_frame
	await process_frame
	assert(main.map_view.continuous_placement and main.map_view.landscape_brush)
	assert(main.city_toolbar.brush_controls.visible)
	assert(main.city_toolbar.brush_shape_input.selected == 1 and main.map_view.brush_round)
	var wheel := InputEventMouseButton.new()
	wheel.position = main.city_toolbar.brush_size_input.get_global_rect().get_center()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	root.push_input(wheel, true)
	assert(main.city_toolbar.brush_size_input.value == 2)
	root.push_input(wheel, true)
	assert(main.city_toolbar.brush_size_input.value == 2)
	var wheel_time := Time.get_ticks_msec()
	while Time.get_ticks_msec() - wheel_time < 60:
		await process_frame
	wheel.position = main.city_toolbar.brush_size_input.get_global_rect().get_center()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	root.push_input(wheel, true)
	assert(main.city_toolbar.brush_size_input.value == 1)
	main.current_tool._select_tool_group(1)
	main.current_tool._select_subtool(0)

	main.city_toolbar.brush_size_input.value = 5
	main.city_toolbar.brush_shape_input.select(1)
	main.city_toolbar.brush_shape_input.item_selected.emit(1)
	var brush: Array[Vector2i] = main.map_view.selection.brush_tiles(Vector2i(8, 8))
	assert(brush.size() == 21)
	main.current_tool._select_subtool(1)
	assert(main.map_view.brush_size == 5 and main.map_view.brush_round)
	main.current_tool._select_subtool(2)
	assert(not main.city_toolbar.brush_controls.visible)
	main.current_tool._select_subtool(3)
	assert(main.city_toolbar.brush_controls.visible)
	assert(main.map_view.brush_size == 5)
	for tool in 4:
		var expected := TerrainToolIcons.terrain_action(main.asset_source.assets.city_ui_graphics, ["tree", "water", "stream", "forest"][tool])
		assert(main.camera_input._tool_button_icon(1, tool).get_image().get_data() == expected.get_image().get_data())
	var original: PackedByteArray = main.document_state.current_document.serialize().data
	main.new_city._reopen_terrain_dialog()
	assert(dialog.visible and dialog.done_button.disabled)
	_assert_editor_controls(main, false)
	dialog.water_input.value += 1
	main.new_city._cancel_new_city()
	assert(main.document_state.current_document.serialize().data == original and main.landscape_editor)
	_assert_editor_controls(main, true)
	main.new_city._reopen_terrain_dialog()
	main.new_city._make_new_city_preview()
	while main.new_city_preview_job != null:
		await process_frame
	main.new_city._create_new_city()
	assert(main.landscape_editor and not dialog.visible)
	_assert_editor_controls(main, true)
	main.new_city._start_city()
	assert(not main.city_toolbar.regenerate_button.visible)
	assert(main.city_toolbar.child_palette.visible)
	main.new_city._open_new_city_dialog()
	main.new_city._make_new_city_preview()
	main.new_city._cancel_new_city()
	while main.new_city_preview_job != null:
		await process_frame
	assert(not dialog.visible and main.new_city_session.preview_document == null)
	main.new_city._open_new_city_dialog()
	main.new_city._make_new_city_preview()
	dialog.hills_input.value += 1
	while main.new_city_preview_job != null:
		await process_frame
	assert(not dialog.candidate_valid and main.new_city_session.preview_document == null)
	main.new_city._cancel_new_city()
	main.queue_free()
	await process_frame
	print("New City workflow checks passed")
	quit()


func _assert_editor_controls(main: Node, expected: bool) -> void:
	for control in [main.city_menu_bar, main.city_toolbar, main.city_status_bar]:
		assert(control.is_visible_in_tree() == expected)
	assert(main.map_view.is_visible_in_tree())
