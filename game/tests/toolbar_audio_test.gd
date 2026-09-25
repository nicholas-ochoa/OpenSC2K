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
	await _check_settings_feedback(main)

	# SCURK uses the same feedback for tools, clipboard transforms, zoom, and views.
	main.scurk_workspace._ensure_scurk_editor()
	var editor := main.scurk_editor as ScurkEditorControl
	editor.pixel_canvas.clipboard_width = 2
	editor.pixel_canvas.clipboard_height = 2
	editor.pixel_canvas.clipboard_pixels = PackedInt32Array([1, 2, 3, 4])
	for button in [editor.tool_buttons[0], editor.clipboard_action_buttons[0],
		editor.drawing_controls.zoom_in_button, editor.view_buttons[0]]:
		main.preferences.toolbar_sounds = true
		button.pressed.emit()
		assert(_has_sound(main, 505))
		await _clear(main)
		main.preferences.toolbar_sounds = false
		button.pressed.emit()
		assert(not _has_sound(main, 505))
	main.preferences.toolbar_sounds = true
	main.document_state.city.set_sound_enabled(false)
	editor.tool_buttons[0].pressed.emit()
	assert(not _has_sound(main, 505))
	main.document_state.city.set_sound_enabled(true)
	main.preferences.toolbar_sounds = false

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
	main.main_overlays.settings_dialog.sound_pack_edit.text = "/missing/sound-pack"
	var old_sound_folder: String = main.preferences.sound_pack_folder
	main.settings.apply_settings()
	await process_frame
	assert(main.main_overlays.settings_dialog.pack_error_label.visible)
	assert(not main.main_overlays.settings_dialog.pack_error_label.text.is_empty())
	assert(main.preferences.sound_pack_folder == old_sound_folder)
	main.queue_free()
	await process_frame
	print("PASS: city, Settings and SCURK interface feedback, Center WAV routing, independent terrain feedback, city sound mute")
	quit()


func _check_settings_feedback(main: Node) -> void:
	var dialog := main.main_overlays.settings_dialog as AppSettingsDialog
	main.preferences.toolbar_sounds = true
	main.settings.open_settings_dialog()
	assert(not _has_sound(main, 505), "Loading settings must not play feedback")
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	var actions: Array[Callable] = [dialog.fullscreen_check.pressed.emit,
		dialog.theme_selector.pressed.emit, dialog.theme_selector.item_selected.emit.bind(0),
		dialog.tabs.get_tab_bar().tab_clicked.emit.bind(3), dialog.music_slider.drag_started.emit,
		dialog.effects_slider.gui_input.emit.bind(key), dialog.get_node("%DataBrowse").pressed.emit,
		dialog.get_node("%ImportButton").pressed.emit, dialog.confirmed.emit, dialog.canceled.emit]

	for action_index in actions.size():
		var action := actions[action_index]

		for enabled in [true, false]:
			main.preferences.toolbar_sounds = enabled
			main.settings.open_settings_dialog()
			assert(not _has_sound(main, 505), "Refreshing settings must not play feedback")
			action.call()
			assert(_sound_count(main, 505) == int(enabled), "Settings action %d: enabled=%s, clicks=%d" % [
				action_index, enabled, _sound_count(main, 505)])
			await _clear(main)
			main.reference_import_dialog.hide()

			for child in dialog.get_children():
				if child is FileDialog:
					child.hide()

	main.preferences.toolbar_sounds = true
	main.document_state.city.set_sound_enabled(false)
	dialog.fullscreen_check.pressed.emit()
	assert(not _has_sound(main, 505), "City sound mute also applies to Settings")
	main.document_state.city.set_sound_enabled(true)
	dialog.hide()


func _has_sound(main: Node, id: int) -> bool:
	return _sound_count(main, id) > 0


func _sound_count(main: Node, id: int) -> int:
	var count := 0

	for player in get_nodes_in_group(CityAudioController.SOUND_EFFECT_GROUP):
		if player.stream == main.audio_controller.wave_stream_cache.get(id):
			count += 1

	return count


func _clear(main: Node) -> void:
	main.audio_controller.stop_sound_effects()
	await process_frame
