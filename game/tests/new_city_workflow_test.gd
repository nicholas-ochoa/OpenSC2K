extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main._open_new_city_dialog()
	var dialog: NewCityTerrainDialog = main.new_city_dialog
	assert(not dialog.compatibility_input.button_pressed)
	assert(dialog.native_maps_input.button_pressed)
	assert(dialog.done_button.disabled and main.new_city_session.preview_document == null)
	dialog.size_input.select(3)
	dialog.compatibility_input.button_pressed = true
	assert(dialog.size_input.get_selected_id() == 128)
	assert(dialog.size_input.disabled and dialog.native_maps_input.disabled)
	assert(not dialog.native_maps_input.button_pressed)
	main.audio_controller.application_has_focus = true
	main.audio_controller.wave_sound_gate.stop()
	main._make_new_city_preview()
	assert(main.audio_controller.wave_sound_gate.current_sound_id == 529)
	assert(dialog.candidate_valid and not dialog.done_button.disabled)
	assert(dialog.landscape_background.texture != null)
	var candidate: Sc2File = main.new_city_session.preview_document
	var bytes: PackedByteArray = candidate.serialize().data
	var cursor: int = main.new_city_session.preview_process_cursor
	dialog.hills_input.value += 1
	await create_timer(0.25).timeout
	assert(dialog.done_button.disabled and not dialog.candidate_valid)
	assert(candidate.serialize().data == bytes)
	assert(main.new_city_session.preview_process_cursor == cursor)
	main._create_new_city_unchecked()
	assert(main.city == null)
	dialog.compatibility_input.button_pressed = false
	assert(not dialog.size_input.disabled and not dialog.native_maps_input.disabled)
	dialog._random_name()
	assert(dialog.city_name_input.text.length() <= 30)
	main._make_new_city_preview()
	var generated: Sc2File = main.new_city_session.preview_document
	main._create_new_city_unchecked()
	assert(main.landscape_editor)
	for id in ["ALTM", "XTER", "XBLD", "XBIT"]:
		assert(main.current_document.find_chunk(id).decoded_payload == generated.find_chunk(id).decoded_payload)
	assert(main.city_toolbar.regenerate_button.visible)
	assert(not main.city_toolbar.child_palette.visible)
	assert(main.city_toolbar.landscape_buttons.size() == 12)
	assert(not main.city_toolbar.landscape_buttons.has(Vector2i(16, 1)))
	assert(not main.city_toolbar.view_mode_buttons.underground.visible)
	assert(main.city_toolbar.view_mode_buttons.height.visible)
	assert(not main.city_toolbar.data_view_input.visible)
	for key in main.city_toolbar.view_visibility_checks:
		assert(main.city_toolbar.view_visibility_checks[key].visible == (key in ["water", "trees"]))
	for key in main.city_toolbar.landscape_buttons:
		var button: Button = main.city_toolbar.landscape_buttons[key]
		assert(button.icon.get_height() <= 23)
	main.city_toolbar.view_mode_buttons.height.pressed.emit()
	assert(main.overlay_mode == "height")
	main.city_toolbar.view_mode_buttons.city.pressed.emit()
	main._select_tool_group(16)
	main._select_subtool(1)
	assert(main.selected_subtool == 0)
	await process_frame
	var toolbar_width: float = main.city_toolbar.size.x
	main._select_tool_group(1)
	main._select_subtool(0)
	await process_frame
	await process_frame
	assert(is_equal_approx(main.city_toolbar.size.x, toolbar_width))
	assert(main.map_view.continuous_placement and main.map_view.landscape_brush)
	assert(main.city_toolbar.brush_controls.visible)
	assert(main.city_toolbar.brush_size_input.get_parent() == main.city_toolbar.brush_shape_input.get_parent())
	var random_button: Button = dialog.city_name_input.get_parent().get_node("RandomName")
	assert(random_button.position.x > dialog.city_name_input.position.x and random_button.icon != null)
	main.city_toolbar.brush_size_input.value = 5
	main.city_toolbar.brush_shape_input.select(1)
	main.city_toolbar.brush_shape_input.item_selected.emit(1)
	var brush: Array[Vector2i] = main.map_view.brush_tiles(Vector2i(64, 64))
	assert(brush.size() == 21)
	main._select_subtool(1)
	assert(main.map_view.brush_size == 5 and main.map_view.brush_round)
	main._select_subtool(2)
	assert(not main.city_toolbar.brush_controls.visible)
	main._select_subtool(3)
	assert(main.city_toolbar.brush_controls.visible)
	assert(main.map_view.brush_size == 5)
	for tool in 4:
		var expected := TerrainToolIcons.terrain_action(main.asset_source.assets.city_ui_graphics, ["tree", "water", "stream", "forest"][tool])
		assert(main._tool_button_icon(1, tool).get_image().get_data() == expected.get_image().get_data())
	var original: PackedByteArray = main.current_document.serialize().data
	main._reopen_terrain_dialog()
	assert(dialog.visible and dialog.done_button.disabled)
	dialog.water_input.value += 1
	main._cancel_new_city()
	assert(main.current_document.serialize().data == original and main.landscape_editor)
	main._reopen_terrain_dialog()
	main._make_new_city_preview()
	main._create_new_city()
	assert(main.landscape_editor and not dialog.visible)
	main._start_city()
	assert(not main.city_toolbar.regenerate_button.visible)
	assert(main.city_toolbar.child_palette.visible)
	main.queue_free()
	await process_frame
	print("New City workflow checks passed")
	quit()
