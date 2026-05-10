extends SceneTree
var main: Control
var point := Vector2i(60, 60)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	root.add_child(main)
	await process_frame
	main.map_view.zoom_factor = 0.25
	assert(main.city_session._activate_document(EmptyCityTemplate.create()))
	main.new_city._enter_landscape_editor()
	main.current_tool._select_tool_group(0)
	main.current_tool._select_subtool(5)
	await _wait_for_render()
	var displayed_before: int = hash(main.static_city_image.get_data())
	var bytes: PackedByteArray = main.current_document.serialize().data
	var random_before: int = main.tool_random.state
	_begin()
	_motion(-36, false)
	assert(main.current_document.serialize().data != bytes, "Terrain did not change during the drag")
	await _wait_for_render()
	assert(main.map_view.is_left_drag_active())
	assert(hash(main.static_city_image.get_data()) != displayed_before, "The displayed terrain must update during the held drag")
	var raised: PackedByteArray = main.current_document.serialize().data
	_motion(-36, false)
	assert(main.current_document.serialize().data == raised, "Repeated pointer motion raised the tile again")
	_motion(-24, true)
	assert(main.current_document.serialize().data == bytes, "Shift drag changed terrain before release")
	_motion(-24, false)
	assert(main.current_document.serialize().data != bytes)
	main.map_view.cancel_active_selection()
	assert(main.current_document.serialize().data == bytes)
	assert(main.tool_random.state == random_before)
	_begin()
	_motion(-36, true)
	assert(main.current_document.serialize().data == bytes)
	_release(-36, true)
	assert(main.current_document.serialize().data != bytes, "Shift drag did not change terrain on release")
	assert(not main.terrain_stretch.active)
	assert(TerrainCommand.undo(main.city, main.last_edit_command, main.tool_random).ok)
	assert(main.current_document.serialize().data == bytes)
	_begin()
	_motion(-24, false)
	_motion(0, false)
	_release(0, false)
	assert(main.current_document.serialize().data == bytes, "Tile stayed raised after the drag returned to its origin")
	_begin()
	_motion(-24, false)
	_release(-24, false)
	assert(main.current_document.serialize().data != bytes)
	assert(TerrainCommand.undo(main.city, main.last_edit_command, main.tool_random).ok)
	assert(main.current_document.serialize().data == bytes, "Undo did not restore the whole live drag")
	main.audio_controller.stop_sound_effects()
	main.queue_free()
	await process_frame
	print("PASS: live stretch before release, Shift deferral and switching, no repeated raise, cancellation, reversed drag and single exact Undo")
	quit()


func _begin() -> void:
	main.map_view.selection_start = point
	main.map_view.selection_end = point
	main.map_view.selection_moved = false
	main.map_view._stretch_press_y = 200.0
	main.camera_input._on_map_selection_started()


func _motion(offset: float, shift: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = Vector2(200, 200 + offset)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.shift_pressed = shift
	main.map_view.interaction._handle_mouse_motion(event)


func _release(offset: float, shift: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = Vector2(200, 200 + offset)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.shift_pressed = shift
	main.map_view.interaction._handle_mouse_button(event)


func _wait_for_render() -> void:
	for frame in 300:
		await create_timer(0.02).timeout

		if main.static_city_image != null and main.static_render_thread == null:
			return

	assert(false, "Terrain render did not finish")
