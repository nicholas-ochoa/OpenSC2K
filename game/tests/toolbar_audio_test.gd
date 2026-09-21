extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	root.add_child(main)
	await process_frame
	main.map_view.zoom_factor = 0.25
	assert(main.city_session.activate_document(EmptyCityTemplate.create()))
	main.new_city._enter_landscape_editor()
	main.document_state.city.set_sound_enabled(true)
	main.audio_controller.application_has_focus = true
	main.preferences.toolbar_sounds = true
	main.city_toolbar.toolbar_buttons[0].pressed.emit()
	assert(_has_sound(main, 505))
	await _clear(main)
	main.preferences.toolbar_sounds = false
	main.city_toolbar.toolbar_buttons[0].pressed.emit()
	assert(not _has_sound(main, 505))

	# Terrain use still plays the tractor with toolbar feedback disabled.
	for tool in [2, 3, 5, 6, 7]:
		main.current_tool.select_tool_group(0)
		main.current_tool.select_subtool(tool)
		var point := Vector2i(60, 60)
		var path: Array[Vector2i] = [point]
		main.city_edits.apply_map_selection(point, point, path, false)
		assert(_has_sound(main, 508), "Missing tractor sound for terrain tool %d" % tool)
		await _clear(main)

	for x in range(70, 77):
		for y in range(70, 77):
			main.document_state.city.set_terrain_id(x, y, 0)
			main.document_state.city.set_building_id(x, y, BuildingTileIds.EMPTY)
			main.document_state.city.set_tile_flag(x, y, 4, false)

	# Both tree tools use the original tree plop in free landscape mode.
	for subtool in [0, 3]:
		main.current_tool.select_tool_group(1)
		main.current_tool.select_subtool(subtool)
		var point := Vector2i(70, 70)
		var tree_path: Array[Vector2i] = [point]

		if subtool == 3:
			main.map_view.selection._emit_brush_dab(point, false)
		else:
			main.city_edits.apply_map_selection(point, point, tree_path, false)

		assert(_has_sound(main, ToolSoundRules.SOUND_TREE))
		await _clear(main)

	main.document_state.city.set_sound_enabled(false)
	main.current_tool.select_tool_group(0)
	main.current_tool.select_subtool(2)
	var muted_path: Array[Vector2i] = [Vector2i(60, 60)]
	main.city_edits.apply_map_selection(muted_path[0], muted_path[0], muted_path, false)
	assert(not _has_sound(main, 508))
	main.settings.open_settings_dialog()
	main.settings_dialog.sound_pack_edit.text = "/missing/sound-pack"
	var old_sound_folder: String = main.preferences.sound_pack_folder
	main.settings.apply_settings()
	await process_frame
	assert(main.settings_dialog.pack_error_label.visible)
	assert(not main.settings_dialog.pack_error_label.text.is_empty())
	assert(main.preferences.sound_pack_folder == old_sound_folder)
	main.queue_free()
	await process_frame
	print("PASS: toolbar preference, Center WAV routing, terrain tractor feedback independent of toolbar setting, city sound mute")
	quit()


func _has_sound(main: Node, id: int) -> bool:
	for player in get_nodes_in_group(CityAudioController.SOUND_EFFECT_GROUP):
		if player.stream == main.audio_controller.wave_stream_cache.get(id):
			return true

	return false


func _clear(main: Node) -> void:
	main.audio_controller.stop_sound_effects()
	await process_frame
