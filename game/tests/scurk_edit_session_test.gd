extends SceneTree
## Generated editor state. No imported graphics or original game files are required.

const EditorScene = preload("res://src/ui/scurk/scurk_editor_control.tscn")
const Workspace = preload("res://src/tools/scurk/scurk_drawing_workspace.gd")
const LARGE_ID := 1000
const FIRST_DESCRIPTION := "First generated stroke"
const NEXT_DESCRIPTION := "Stroke after rejected input"

var editor: ScurkEditorControl
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 1000)
	var mif := ScurkMif.from_archives([])
	for view in 3:
		var pixels := PackedInt32Array()
		pixels.resize(128 >> view)
		pixels.fill(42)
		assert(mif.set_shape_indices(ScurkEditorRules.view_sprite_id(LARGE_ID, view), pixels.size(), 1, pixels).ok)
	editor = EditorScene.instantiate() as ScurkEditorControl
	root.add_child(editor)
	editor.configure(Sc2Palette.index_encoding(), mif.archive, mif.archive, "")
	assert(editor.load_tile_set(mif).ok)
	editor._set_cycle_colors(false)
	editor._set_clipping_enabled(false)
	await process_frame
	editor.studio.sync_editor_state()
	editor.studio.update_modified()
	assert(editor.active_workspace and editor.pixel_canvas.sprite_width == 128 and editor.pixel_canvas.sprite_height == 256)
	var initial := _state()
	_test_no_op_and_cancel(initial)
	_test_locked_input(initial)
	_test_unchanged_stroke(initial)

	var ordinary: PackedInt32Array = initial.pixels.duplicate()
	ordinary[255 * 128] = 43
	editor.pixel_canvas._commit_changed_pixels(ordinary, FIRST_DESCRIPTION)
	_check_pixels(ordinary, "Ordinary edit")
	_check(editor.edit_history.undo_stack.size() == 1 and editor.edit_history.redo_stack.is_empty(), "Ordinary edit records one action")
	if not editor.edit_history.undo_stack.is_empty():
		var action: ScurkEditorHistory.Record = editor.edit_history.undo_stack.back()
		_check(action.description == FIRST_DESCRIPTION, "Capture preserves the supplied action description")
		_check(action.before == initial.mif and action.after == editor.tile_set.to_bytes().bytes, "History records both MIF states")
		_check(action.project_before == initial.project, "History records the original project")
	_check(editor.dirty and editor.studio.modified, "Ordinary edit marks the artwork modified")
	_check_pending_clear("Ordinary edit")
	editor.undo()
	_check_artwork(initial, "Undo ordinary edit")
	_check(editor.edit_history.redo_stack.size() == 1, "Undo keeps one redo action")
	var before_failure := _state()

	var rejected: PackedInt32Array = initial.pixels.duplicate()
	rejected.fill(-1)
	for x in 128:
		if x % 2 == 0:
			rejected[255 * 128 + x] = 42
	var shape := Workspace.shape_from_workspace(rejected, editor.active_base_width, editor.current_view, false)
	assert(shape.ok and shape.width == 128 and shape.height == 1)
	var writer := ScurkMif.new()
	assert(writer.parse(initial.mif))
	var refused := writer.set_shape_indices(LARGE_ID, shape.width, shape.height, shape.pixels)
	assert(not refused.ok and writer.to_bytes().bytes == initial.mif, "Alternating runs exceed the existing MIF row limit")
	editor.pixel_canvas._commit_changed_pixels(rejected, "Rejected alternating row")
	_check_artwork(before_failure, "Rejected edit")
	_check(_history(editor.edit_history.undo_stack) == before_failure.undo, "Rejected edit keeps undo history")
	_check(_history(editor.edit_history.redo_stack) == before_failure.redo, "Rejected edit keeps redo history")
	_check_pending_clear("Rejected edit")

	var next: PackedInt32Array = initial.pixels.duplicate()
	next[255 * 128] = 44
	editor.pixel_canvas._commit_changed_pixels(next, NEXT_DESCRIPTION)
	_check_pixels(next, "Edit after failure")
	_check(editor.edit_history.undo_stack.size() == 1 and editor.edit_history.redo_stack.is_empty(), "Valid edit replaces redo with one action")
	if not editor.edit_history.undo_stack.is_empty():
		var action: ScurkEditorHistory.Record = editor.edit_history.undo_stack.back()
		_check(action.description == NEXT_DESCRIPTION, "Valid edit has its own description")
		_check(action.project_before == initial.project, "Rejected pixels never enter the next history record")
	_check_pending_clear("Edit after failure")
	var after_valid := _state()
	editor.undo()
	_check_artwork(initial, "Undo after rejected input")
	_check_pending_clear("Undo")
	editor.redo()
	_check_artwork(after_valid, "Redo after rejected input")
	_check_pending_clear("Redo")
	_test_history_rejection(initial, after_valid)
	_test_active_stroke_history()
	_test_layer_names()
	_test_object_revert()
	await _test_layer_clicks()
	_test_persistence()
	_test_generation_sampling()
	_test_size_generation()
	editor.free()
	await process_frame
	print("SCURK edit session: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_no_op_and_cancel(before: Dictionary) -> void:
	var canvas := editor.pixel_canvas
	canvas._commit_changed_pixels(canvas.pixels.duplicate(), "Unchanged pixels")
	_check_artwork(before, "No-op canvas commit")
	_check(editor.edit_history.undo_stack.is_empty() and editor.edit_history.redo_stack.is_empty(), "No-op adds no history")
	_check_pending_clear("No-op")
	canvas.selection.combine(canvas.selection.rectangle(Vector2i(0, 255), Vector2i(0, 255)))
	assert(canvas.copy_selection())
	assert(canvas.begin_paste(Vector2i(1, 255)))
	assert(canvas.paste_active)
	canvas.cancel_paste()
	_check(not canvas.paste_active, "Cancel ends the floating paste")
	_check_artwork(before, "Canceled paste")
	_check(editor.edit_history.undo_stack.is_empty() and editor.edit_history.redo_stack.is_empty(), "Canceled paste adds no history")
	_check_pending_clear("Canceled paste")
	canvas.clear_selection()


func _test_locked_input(initial: Dictionary) -> void:
	var canvas := editor.pixel_canvas
	var key := editor.studio.key()
	assert(editor.studio.project.set_layer_locked(key, 0, true))
	editor.studio.bind_canvas()
	editor.studio.update_modified()
	assert(canvas.editing_disabled)
	var locked := _state()
	var foreground := canvas.selected_color_index
	canvas.selected_color_index = 43
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(ScurkPixelCanvas.DISPLAY_MARGIN, 0) + Vector2(0.5, 255.5) * canvas.zoom
	click.pressed = true
	canvas._gui_input(click)
	click.pressed = false
	canvas._gui_input(click)
	_check_artwork(locked, "Locked canvas input")
	_check(editor.edit_history.undo_stack.is_empty() and editor.edit_history.redo_stack.is_empty(), "Locked input adds no history")
	_check_pending_clear("Locked input")
	canvas.selected_color_index = foreground
	assert(editor.studio.project.set_layer_locked(key, 0, false))
	editor.studio.bind_canvas()
	editor.studio.update_modified()
	_check_artwork(initial, "Unlocked fixture")


func _test_unchanged_stroke(before: Dictionary) -> void:
	var canvas := editor.pixel_canvas
	var foreground := canvas.selected_color_index
	canvas.selected_color_index = 42
	canvas._begin_stroke(Vector2i(0, 255), MOUSE_BUTTON_LEFT)
	_check(editor.session.has_pending_edit(), "A stroke captures its starting state")
	canvas._finish_stroke()
	_check_artwork(before, "Same-color stroke")
	_check(editor.edit_history.undo_stack.is_empty() and editor.edit_history.redo_stack.is_empty(), "Same-color stroke adds no history")
	_check_pending_clear("Same-color stroke")
	canvas.selected_color_index = foreground


func _state() -> Dictionary:
	var encoded := editor.tile_set.to_bytes()
	assert(encoded.ok)
	return {"mif": encoded.bytes, "project": editor.studio.project.snapshot(),
		"pixels": editor.pixel_canvas.pixels.duplicate(), "blank": editor.edit_history.blank_shape_ids.duplicate(),
		"undo": _history(editor.edit_history.undo_stack), "redo": _history(editor.edit_history.redo_stack),
		"modified": editor.studio.modified, "dirty": editor.dirty, "history_dirty": editor.edit_history.dirty}


func _history(records: Array[ScurkEditorHistory.Record]) -> Array:
	var result: Array = []
	for record in records:
		result.append([record.description, record.before.duplicate(), record.after.duplicate(),
			record.project_before.duplicate(true), record.project_after.duplicate(true),
			record.blank_before.duplicate(), record.blank_after.duplicate()])
	return result


func _check_artwork(expected: Dictionary, label: String) -> void:
	_check(editor.tile_set.to_bytes().bytes == expected.mif, label + " preserves MIF bytes")
	_check(editor.studio.project.snapshot() == expected.project, label + " preserves the project snapshot")
	_check(editor.studio.project.current_mif == expected.mif, label + " keeps project MIF synchronized")
	_check_pixels(expected.pixels, label)
	_check(editor.edit_history.blank_shape_ids == expected.blank, label + " preserves blank-shape state")
	_check(editor.studio.modified == expected.modified and editor.dirty == expected.dirty and editor.edit_history.dirty == expected.history_dirty,
		label + " preserves modified flags")


func _check_pixels(expected: PackedInt32Array, label: String) -> void:
	_check(editor.studio.project.active_pixels(editor.studio.key()) == expected, label + " keeps active layer pixels")
	_check(editor.pixel_canvas.pixels == expected, label + " keeps canvas pixels")


func _check_pending_clear(label: String) -> void:
	_check(not editor.session.has_pending_edit(), label + " clears the pending edit")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)


# Inject invalid targets to check that neither history stack moves on rejection.
func _test_history_rejection(initial: Dictionary, edited: Dictionary) -> void:
	assert(editor.edit_history.undo_stack.size() == 1 and editor.edit_history.redo_stack.is_empty())
	for invalid_project in [false, true]:
		if not _test_rejected_history(false, invalid_project):
			return
	editor.undo()
	_check_artwork(initial, "Undo after rejected history targets")
	_check(editor.edit_history.undo_stack.is_empty() and editor.edit_history.redo_stack.size() == 1, "Valid undo moves the restored record")
	for invalid_project in [false, true]:
		if not _test_rejected_history(true, invalid_project):
			return
	editor.redo()
	_check_artwork(edited, "Redo after rejected history targets")
	_check(editor.edit_history.undo_stack.size() == 1 and editor.edit_history.redo_stack.is_empty(), "Valid redo moves the restored record")
	_check_pending_clear("Restored history")


func _test_rejected_history(redo: bool, invalid_project: bool) -> bool:
	var source := editor.edit_history.redo_stack if redo else editor.edit_history.undo_stack
	assert(not source.is_empty())
	var record: ScurkEditorHistory.Record = source.back()
	var field := "project_after" if redo else "project_before"
	var bytes_field := "after" if redo else "before"
	var saved_project: Dictionary = record.get(field).duplicate(true)
	var saved_bytes: PackedByteArray = record.get(bytes_field).duplicate()
	if invalid_project:
		var invalid := saved_project.duplicate(true)
		invalid.documents[editor.studio.key()].width = 0
		assert(not ScurkProject.new().restore_snapshot(invalid))
		record.set(field, invalid)
	else:
		var invalid := PackedByteArray([0])
		assert(not ScurkMif.new().parse(invalid))
		record.set(bytes_field, invalid)
	var before := _state()
	var label := "Rejected %s %s" % ["redo" if redo else "undo", "project" if invalid_project else "MIF"]
	if redo:
		editor.redo()
	else:
		editor.undo()
	_check_artwork(before, label)
	var undo_unchanged: bool = _history(editor.edit_history.undo_stack) == before.undo
	var redo_unchanged: bool = _history(editor.edit_history.redo_stack) == before.redo
	_check(undo_unchanged and redo_unchanged, label + " keeps both history stacks")
	_check_pending_clear(label)
	# Restore the generated record even if the old implementation moved its stack.
	record.set(field, saved_project)
	record.set(bytes_field, saved_bytes)
	return undo_unchanged and redo_unchanged


func _test_active_stroke_history() -> void:
	editor.error_dialog.hide()
	editor.show()
	var document := ScurkMif.new()
	assert(document.parse(editor.tile_set.to_bytes().bytes))
	assert(editor.load_tile_set(document).ok)
	editor.studio.sync_editor_state()
	editor.studio.update_modified()
	var canvas := editor.pixel_canvas
	var foreground := canvas.selected_color_index
	canvas.selected_color_index = 45
	canvas._begin_stroke(Vector2i(0, 255), MOUSE_BUTTON_LEFT)
	assert(canvas.stroke_changed and editor.session.has_pending_edit())
	var stroke := canvas.pixels.duplicate()
	for forward in [false, true]:
		var key := InputEventKey.new()
		key.keycode = KEY_Z
		key.pressed = true
		key.ctrl_pressed = true
		key.shift_pressed = forward
		_check(editor.handle_shortcut(key), "The active stroke accepts the history shortcut")
		_check(editor.session.has_pending_edit(), "Empty history leaves the active stroke pending")
	_check(canvas.stroke_active and canvas.pixels == stroke, "Empty history leaves the active stroke pixels")
	canvas._finish_stroke()
	_check_pixels(stroke, "Stroke after empty history")
	_check(editor.edit_history.undo_stack.size() == 1, "Stroke after empty history records one action")
	_check_pending_clear("Stroke after empty history")
	if editor.edit_history.undo_stack.is_empty():
		canvas.selected_color_index = foreground
		return

	# Inject a rejected target while another stroke is active.
	var record: ScurkEditorHistory.Record = editor.edit_history.undo_stack.back()
	var saved_bytes := record.before.duplicate()
	record.before = PackedByteArray([0])
	var before := _state()
	canvas.selected_color_index = 46
	canvas._begin_stroke(Vector2i(0, 255), MOUSE_BUTTON_LEFT)
	var next_stroke := canvas.pixels.duplicate()
	editor.undo()
	_check(editor.session.has_pending_edit(), "Rejected history leaves the active stroke pending")
	_check(canvas.stroke_active and canvas.pixels == next_stroke, "Rejected history leaves the active stroke pixels")
	_check(editor.tile_set.to_bytes().bytes == before.mif and editor.studio.project.snapshot() == before.project,
		"Rejected history leaves the stroke document unchanged")
	_check(_history(editor.edit_history.undo_stack) == before.undo and _history(editor.edit_history.redo_stack) == before.redo,
		"Rejected history leaves the active stroke history unchanged")
	record.before = saved_bytes
	editor.error_dialog.hide()
	canvas._finish_stroke()
	_check_pixels(next_stroke, "Stroke after rejected history")
	_check(editor.edit_history.undo_stack.size() == 2, "Stroke after rejected history records one more action")
	_check_pending_clear("Stroke after rejected history")
	canvas.selected_color_index = foreground


func _test_object_revert() -> void:
	var session := ScurkEditSession.new()
	var mif := ScurkMif.from_archives([])
	var original := PackedInt32Array([42, -1])
	for id in [1000, 1001]:
		for view in ScurkSpriteIds.VIEW_COUNT:
			assert(mif.set_shape_indices(ScurkEditorRules.view_sprite_id(id, view), 2, 1, original).ok)
		assert(mif.set_name(ScurkEditorRules.object_tile_id(id), "Initial %d" % id).ok)
	mif.info_payload[23] = 173
	assert(session.load_document(mif).ok)
	var project := session.project
	assert(project.ensure_document("1000:0", original, 2, 1))
	session.capture_object(1000)
	assert(project.ensure_document("1000:1", original, 2, 1))
	session.remember_document_baseline("1000:1")
	_check(not session.can_revert_object(1000), "Viewing another size does not enable Revert")
	assert(session.begin_edit("Rename layer").ok)
	project.documents["1000:0"].layers[0].name = "Windows"
	assert(session.commit_edit().ok)
	_check(session.can_revert_object(1000), "A layer-only edit enables Revert")
	assert(session.revert_object(1000).ok)
	_check(project.documents["1000:0"].layers[0].name == "Root", "Revert restores a layer-only edit")
	_check(not session.can_revert_object(1000), "Revert clears the selected object's changes")
	assert(session.begin_edit("Edit several objects").ok)
	for id in [1000, 1001]:
		for view in ScurkSpriteIds.VIEW_COUNT:
			var key := "%d:%d" % [id, view]
			var changed := PackedInt32Array([99, 99])
			assert(project.ensure_document(key, original, 2, 1))
			assert(project.set_active_pixels(key, changed))
			assert(session.document.set_shape_indices(ScurkEditorRules.view_sprite_id(id, view), 2, 1, changed).ok)
	assert(session.document.remove_name(0).ok)
	assert(session.document.set_name(1, "Keep this name").ok)
	project.metadata.author = "Keep this author"
	project.resources["reference.bin"] = PackedByteArray([0, 1, 255])
	assert(project.add_stamp("Window", 2, 1, original, 3) == 0)
	session.history.blank_shape_ids[1000] = true
	session.history.blank_shape_ids[1001] = true
	project.metadata.editor_state.blank_shape_ids = [1000, 1001]
	project.metadata.editor_state.unclipped_tile_ids = [1000, 1001]
	assert(session.commit_edit().ok)
	session.remember_document_baseline("1000:2")
	var before := project.snapshot()
	assert(session.revert_object(1000).ok)
	for view in ScurkSpriteIds.VIEW_COUNT:
		var entry := session.document.archive.find_sprite(ScurkEditorRules.view_sprite_id(1000, view))
		_check(entry.decode_indices().pixels == original, "Revert restores each selected view")
		var other_key := "1001:%d" % view
		_check(project.documents[other_key] == before.documents[other_key], "Revert preserves each other object's layers")
		var other := session.document.archive.find_sprite(ScurkEditorRules.view_sprite_id(1001, view))
		_check(other.decode_indices().pixels == PackedInt32Array([99, 99]), "Revert preserves each other object's MIF view")
	_check(not project.documents.has("1000:2"), "Revert drops a view first opened after its edit")
	_check(session.document.names[0] == "Initial 1000" and session.document.names[1] == "Keep this name", "Revert restores only the selected name")
	_check(session.document.info_payload[23] == 173, "Revert preserves opaque MIF information")
	_check(project.metadata.author == before.metadata.author and project.resources == before.resources and project.stamps == before.stamps,
		"Revert preserves project metadata, resources, and stamps")
	_check(session.history.blank_shape_ids == {1001: true} and project.metadata.editor_state.unclipped_tile_ids == [1001],
		"Revert restores only the selected object's blank and clip state")
	var after := project.snapshot()
	assert(session.undo().ok)
	_check(project.snapshot() == before, "Undo restores the state before object Revert")
	assert(session.redo().ok)
	_check(project.snapshot() == after, "Redo restores the state after object Revert")
	_check(not session.can_revert_object(1000), "Changes to other objects do not enable Revert")


func _test_layer_names() -> void:
	var studio := editor.studio
	studio.tabs.current_tab = 1
	var document: Dictionary = studio.project.documents[studio.key()]
	var index := int(document.active)
	var original := String(document.layers[index].name)
	var field := studio.get_node(studio.LAYERS + "/Name") as LineEdit
	var list := studio.get_node(studio.LAYERS + "/Row/List") as Tree
	var count := editor.undo_stack.size()
	for value in ["W", "Wa", "Walls"]:
		field.text = value
		field.text_changed.emit(value)
		_check(document.layers[index].name == value, "Typing changes the layer name immediately")
		_check(list.get_selected().get_text(1) == value, "Typing updates the selected layer row")
	_check(editor.undo_stack.size() == count + 1, "A continuous name edit uses one undo action")
	field.focus_exited.emit()
	editor.undo()
	_check(studio.project.documents[studio.key()].layers[index].name == original, "Undo restores the name before typing")
	editor.redo()
	_check(field.text == "Walls", "Redo restores the complete typed name")
	field.text = ""
	field.text_changed.emit("")
	field.focus_exited.emit()
	_check(field.text == "Walls", "An empty name keeps the last valid value")
	field.text = "Windows"
	field.text_changed.emit("Windows")
	field.focus_exited.emit()
	_check(editor.undo_stack.size() == count + 2, "A new name edit gets a separate undo action")
	studio._layer_action("Add")
	var active := int(studio.project.documents[studio.key()].active)
	studio._layer_visible(false, index)
	_check(int(studio.project.documents[studio.key()].active) == active, "Visibility can change without selecting the layer")
	_check(not list.get_root().get_child(1).is_checked(0), "The layer row reflects hidden state")
	editor.undo()
	_check(list.get_root().get_child(1).is_checked(0), "Undo restores layer visibility")
	editor.undo()


func _test_layer_clicks() -> void:
	var was_visible := editor.visible
	editor.show()
	var studio := editor.studio
	studio.tabs.current_tab = 1
	studio._layer_action("Add")
	await process_frame
	var list := studio.get_node(studio.LAYERS + "/Row/List") as Tree
	var key := studio.key()
	var active := int(studio.project.documents[key].active)
	var row := list.get_root().get_child(1)
	var checkbox := list.get_item_area_rect(row, 0).get_center() + list.global_position
	await _click_layer_list(checkbox)
	_check(not studio.project.documents[key].layers[0].visible, "A checkbox click hides its layer")
	_check(int(studio.project.documents[key].active) == active, "A checkbox click keeps the active layer")
	_check(not row.is_checked(0), "A checkbox click updates the existing row")
	await _click_layer_list(checkbox)
	_check(studio.project.documents[key].layers[0].visible and row.is_checked(0), "A second click shows the layer again")
	await _click_layer_list(list.get_item_area_rect(row, 1).get_center() + list.global_position)
	_check(int(studio.project.documents[key].active) == 0, "Clicking a layer name selects that layer")
	editor.undo()
	editor.undo()
	editor.undo()
	editor.visible = was_visible


func _click_layer_list(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)
	await process_frame


func _test_persistence() -> void:
	var studio := editor.studio
	var folder := "user://scurk-edit-session-%d" % OS.get_process_id()
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK)
	studio.recovery_path = folder.path_join("recovery.scurk")
	studio.sync_editor_state()
	studio.project.metadata["palette"] = editor.palette_panel.export_state()
	var invalid_mif := folder.path_join("invalid.mif")
	var invalid_project := folder.path_join("invalid.scurk")
	_store_file(invalid_mif, PackedByteArray([0]))
	_store_file(invalid_project, PackedByteArray([0]))
	for path in [invalid_mif, invalid_project]:
		var before := _persistence_state()
		_check(not editor.load_path(path).ok, "Invalid input rejects the load")
		_check_persistence(before, "Rejected load")
		editor.error_dialog.hide()

	var project_path := folder.path_join("artwork.scurk")
	_store_file(project_path, PackedByteArray([6, 7, 8]))
	_test_failed_project_save(project_path)
	_check(FileAccess.get_file_as_bytes(project_path) == PackedByteArray([6, 7, 8]), "Failed save preserves the existing target bytes")
	assert(studio.save_project(project_path))
	_check_saved_project(project_path, "Project save")
	var earlier := FileAccess.get_file_as_bytes(project_path)
	_store_file(studio.recovery_path, earlier)
	assert(not studio.recovery_owned)

	var pixels := editor.pixel_canvas.pixels.duplicate()
	pixels[255 * 128] = 47
	editor.pixel_canvas._commit_changed_pixels(pixels, "Edit before unrelated recovery save")
	assert(studio.save_project(project_path))
	_check_saved_project(project_path, "Save beside unrelated recovery")
	_check(FileAccess.get_file_as_bytes(studio.recovery_path) == earlier, "Saving leaves unrelated recovery bytes intact")

	pixels[255 * 128] = 48
	editor.pixel_canvas._commit_changed_pixels(pixels, "Edit before autosave")
	assert(studio.autosave())
	_check(studio.recovery_owned and studio.modified, "Autosave owns the recovery file and leaves edits modified")
	var recovery_bytes := FileAccess.get_file_as_bytes(studio.recovery_path)
	var archives := PackedStringArray()
	for name in DirAccess.get_files_at(folder):
		if name.begins_with("recovery-") and name.ends_with(".scurk"):
			archives.append(folder.path_join(name))
	_check(archives.size() == 1 and FileAccess.get_file_as_bytes(archives[0]) == earlier,
		"Autosave preserves the prior unrelated recovery file")

	assert(editor.session.begin_edit("Pending before load").ok)
	assert(studio.load_project(project_path))
	_check_pending_clear("Successful project load")
	_check_saved_project(project_path, "Project load")
	_check(editor.edit_history.undo_stack.is_empty() and editor.edit_history.redo_stack.is_empty(), "Project load resets history")
	_check(not studio.recovery_owned, "Normal project load does not own an older recovery file")
	assert(editor.session.begin_edit("Pending before recovery").ok)
	assert(studio.load_project(studio.recovery_path, true))
	_check_pending_clear("Successful recovery")
	_check_pixels(pixels, "Recovered project")
	_check(studio.modified and editor.dirty and studio.project_path.is_empty(), "Recovery keeps unsaved status and no project path")
	_check(studio.recovery_owned and editor.edit_history.undo_stack.is_empty() and editor.edit_history.redo_stack.is_empty(),
		"Recovery owns its file and resets history")

	var before_cancel := _persistence_state()
	editor.request_close()
	assert(editor.discard_dialog.visible)
	editor.discard_dialog.hide()
	editor.discard_dialog.canceled.emit()
	_check_persistence(before_cancel, "Canceled discard")
	_check(FileAccess.get_file_as_bytes(studio.recovery_path) == recovery_bytes, "Canceled discard keeps owned recovery bytes")
	_test_failed_project_save(folder.path_join("failed.scurk"))
	_check(FileAccess.get_file_as_bytes(studio.recovery_path) == recovery_bytes, "Failed save keeps owned recovery bytes")
	var recovered_path := folder.path_join("recovered.scurk")
	assert(studio.save_project(recovered_path))
	_check_saved_project(recovered_path, "Recovered project save")
	_check(not studio.recovery_owned and studio.recovered_source.is_empty() and not FileAccess.file_exists(studio.recovery_path),
		"Successful save clears only owned recovery state")
	_check(archives.size() == 1 and FileAccess.get_file_as_bytes(archives[0]) == earlier,
		"Owned recovery cleanup leaves unrelated recovery bytes intact")
	_store_file(studio.recovery_path, recovery_bytes)
	studio.recovery_checked = false
	studio.check_recovery()
	_check(studio.get_node("Recovery").visible, "An unhandled recovery opens the prompt")
	var before_ignore := _state()
	studio.get_node("Recovery").custom_action.emit(&"ignore")
	_check(not studio.get_node("Recovery").visible, "Ignore closes the prompt")
	_check(not FileAccess.file_exists(studio.recovery_path), "Ignore removes the automatic recovery candidate")
	_check_artwork(before_ignore, "Ignore keeps the current artwork")
	var ignored_path := ""
	for name in DirAccess.get_files_at(folder):
		if name.begins_with("recovery-ignored-"):
			ignored_path = folder.path_join(name)
	_check(not ignored_path.is_empty() and FileAccess.get_file_as_bytes(ignored_path) == recovery_bytes,
		"Ignored recovery remains byte-exact for manual recovery")
	studio.recovery_checked = false
	studio.check_recovery()
	_check(not studio.get_node("Recovery").visible, "A later startup does not prompt for the ignored file")
	_check(editor.session.ignore_recovery().ok, "Ignoring a missing candidate is harmless")
	_check(ScurkProject.load_path(ignored_path).ok, "The ignored project remains recoverable")
	assert(studio.autosave())
	studio.recovery_checked = false
	studio.check_recovery()
	_check(studio.get_node("Recovery").visible, "A new autosave can still prompt for recovery")
	studio.get_node("Recovery").hide()
	for name in DirAccess.get_files_at(folder):
		assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name))) == OK)
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(folder)) == OK)


func _test_failed_project_save(path: String) -> void:
	editor.studio.sync_editor_state()
	editor.studio.project.metadata["palette"] = editor.palette_panel.export_state()
	# Inject non-JSON metadata so serialization fails before it replaces a file.
	editor.studio.project.metadata["invalid"] = Vector2.ZERO
	var before := _persistence_state()
	_check(not editor.studio.save_project(path), "Invalid project rejects the save")
	_check_persistence(before, "Rejected project save")
	editor.studio.project.metadata.erase("invalid")
	editor.error_dialog.hide()


func _persistence_state() -> Dictionary:
	var studio := editor.studio
	var result := _state()
	result.baselines = [studio.saved_state.duplicate(true), studio.saved_pixels.duplicate(true),
		studio.saved_checkpoints.duplicate(true), editor.edit_history.saved_bytes.duplicate(),
		editor.pixel_canvas.comparison_pixels.duplicate(), studio.project_path, editor.source_path]
	result.recovery = [studio.recovery_owned, studio.recovered_source, studio.recovery_path]
	result.project_context = [studio.project.original_mif.duplicate(), studio.project.checkpoints.duplicate(true),
		studio.project.extra_fields.duplicate(true)]
	return result


func _check_persistence(before: Dictionary, label: String) -> void:
	_check_artwork(before, label)
	var after := _persistence_state()
	_check(after.undo == before.undo and after.redo == before.redo, label + " preserves history")
	_check(after.baselines == before.baselines, label + " preserves saved baselines and paths")
	_check(after.recovery == before.recovery, label + " preserves recovery ownership")
	_check(after.project_context == before.project_context, label + " preserves project context")


func _check_saved_project(path: String, label: String) -> void:
	var studio := editor.studio
	var loaded := ScurkProject.load_path(path)
	_check(loaded.ok and _same_project_state(loaded.project.snapshot(), studio.project.snapshot()), label + " stores the current project")
	_check(studio.saved_state == studio.project.snapshot() and studio.saved_checkpoints == studio.project.checkpoints,
		label + " records project baselines")
	_check(studio.saved_pixels[studio.key()] == editor.pixel_canvas.pixels and editor.pixel_canvas.comparison_pixels == editor.pixel_canvas.pixels,
		label + " records pixel baselines")
	_check(editor.edit_history.saved_bytes == editor.tile_set.to_bytes().bytes, label + " records the MIF baseline")
	_check(not studio.modified and not editor.dirty and studio.project_path == ProjectSettings.globalize_path(path),
		label + " clears modified state and records the path")


func _store_file(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(bytes)
	file.close()


func _same_project_state(left: Dictionary, right: Dictionary) -> bool:
	# JSON normalizes numeric and array types during a project load.
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _test_generation_sampling() -> void:
	# Captured by running WINSCURK.EXE 0x0041435c in an x86 emulator.
	# EXE SHA-256: fb8fdcbe3903f797b5cbb5bf5f3663d2d1337723e8459647f2dee8088f2467fc.
	# Hashes cover little-endian signed 32-bit indices, with transparent pixels as -1.
	var hashes := [
		"0c06f5c11325b4ee9744219d97659b0e3071e304b2a75013ea950f9622bf6406", "ebe84df02e5152b64f0cf2a3d10bb28988c563745ba650bae38622d52b090eaa",
		"c161dc05e749f93951162249b749e32e615e4f31a98c5207cb684ca844e689e5", "1c4fab53e758bbb681445c860cc6d91bc8c2254221f2dc3b1b61fe5732bee712",
		"f8eac3732acd1c65d87db8493f394680e1e27a86a8be67b94b069dbca49ad461", "210ae7ca9020bb6d0bac19612701c1eef060550d887a6049e00b4b24526b5f2d",
		"f45874f5944414b521a6ca9ca085af59df2d2d1ab00b8a378d9d22b421f55e28", "b2102a17962fd8c28b24eea0730047daa044e69ec4b7ff76cf6d7baa4700e184",
	]
	var source := PackedInt32Array()
	source.resize(128 * 256)
	for y in 256:
		for x in 128:
			source[y * 128 + x] = -1 if y < 17 or (x + y) % 11 == 0 else (x * 7 + y * 13) % 240
	var index := 0
	for width in [32, 64, 96, 128]:
		for view in [1, 2]:
			var shape := Workspace.generate_view(source, width, view)
			_check(shape.ok and shape.width == width >> view and shape.height == 240 >> view, "Generated dimensions match the original sampler")
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(shape.pixels.to_byte_array())
			_check(hash.finish().hex_encode() == hashes[index], "Generated pixels match original x86 output for base %d, view %d" % [width, view])
			index += 1
	source.fill(-1)
	for view in [1, 2]:
		var empty := Workspace.generate_view(source, 128, view)
		_check(empty.ok and empty.width == 128 >> view and empty.height == 1 and empty.pixels.count(-1) == empty.width, "Empty generation retains one transparent row")
	source.fill(0)
	for view in [1, 2]:
		var shape := Workspace.generate_view(source, 32, view, false)
		_check(shape.width == 128 >> view and shape.height == 256 >> view, "Unclipped generation uses the whole drawing area")
		_check(shape.pixels[0] == -1 and shape.pixels[1] == 0, "Original left edge omission preserves visible palette index zero")
	_check(not Workspace.generate_view(source, 128, 0).ok, "Generation cannot replace Large")
	_check(not Workspace.generate_view(PackedInt32Array(), 128, 1).ok, "Generation rejects an invalid source")


func _test_size_generation() -> void:
	var mif := ScurkMif.from_archives([])
	for view in 3:
		var pixels := PackedInt32Array()
		pixels.resize(128 >> view)
		pixels.fill(40 + view)
		assert(mif.set_shape_indices(ScurkEditorRules.view_sprite_id(LARGE_ID, view), pixels.size(), 1, pixels).ok)
	assert(editor.load_tile_set(mif).ok)
	editor._set_clipping_enabled(false)
	var project := editor.studio.project
	var large_key := editor.studio.key(0)
	assert(editor._capture_edit_start("Large layers"))
	assert(project.add_layer(large_key, "Visible detail") == 1)
	var layer := project.active_pixels(large_key)
	layer[255 * 128 + 64] = 91
	assert(project.set_active_pixels(large_key, layer))
	assert(project.add_layer(large_key, "Hidden detail") == 2)
	layer[255 * 128 + 64] = 99
	assert(project.set_active_pixels(large_key, layer))
	project.documents[large_key].layers[2].visible = false
	assert(editor._write_pixels(project.flatten(large_key)))
	assert(editor._record_edit())
	assert(editor.studio.ensure_view(1))
	assert(project.add_layer(editor.studio.key(1), "Manual medium") == 1)
	project.documents[editor.studio.key(1)].layers[1].locked = true
	editor._select_view(2)
	var source := project.flatten(large_key)
	var large: PackedByteArray = editor._resolved_view_entry(0).encoded_pixels.duplicate()
	var small: PackedByteArray = editor._resolved_view_entry(2).encoded_pixels.duplicate()
	editor.studio.sync_editor_state()
	var before := _state()
	var dialogs := editor.dialog_registry
	var toolbar := editor.get_node("Panel/Content/Toolbar") as ScurkEditorToolbar
	toolbar.get_node("Actions/Generate").pressed.emit()
	_check(dialogs.generate_options.visible, "Edit action opens the generation dialog")
	dialogs.generate_options.hide()
	dialogs.generate_options.canceled.emit()
	_check_artwork(before, "Cancel generation")
	dialogs.generate_medium.button_pressed = false
	dialogs.generate_small.button_pressed = false
	_check(dialogs.generate_options.get_ok_button().disabled, "No selected sizes disables generation")
	editor._generate_selected_sizes()
	_check_artwork(before, "Skip generation")

	dialogs.generate_medium.button_pressed = true
	_check(not dialogs.generate_options.get_ok_button().disabled, "Selecting a size enables generation")
	dialogs.generate_options.confirmed.emit()
	_check(editor.current_view == 2, "Generation keeps the selected view")
	_check(editor._resolved_view_entry(0).encoded_pixels == large and editor._resolved_view_entry(2).encoded_pixels == small, "Medium-only generation preserves Large and Small")
	var medium: PackedInt32Array = editor._resolved_view_entry(1).decode_indices().pixels
	_check(medium == Workspace.generate_view(source, 128, 1, false).pixels and medium[32] == 91, "Generation uses visible Large layers even while Small is selected")
	_check(project.documents[editor.studio.key(1)].layers.size() == 1 and not project.documents[editor.studio.key(1)].layers[0].locked, "Generated artwork replaces target layers and remains editable")
	_check(editor.undo_stack.size() == before.undo.size() + 1, "Generation records one Undo action")
	var generated := _state()
	editor.undo()
	_check_artwork(before, "Undo generation")
	editor.redo()
	_check_artwork(generated, "Redo generation")

	dialogs.generate_medium.button_pressed = false
	dialogs.generate_small.button_pressed = true
	editor._generate_selected_sizes()
	_check(editor._resolved_view_entry(1).decode_indices().pixels == medium, "Small-only generation preserves Medium")
	_check(editor._resolved_view_entry(2).decode_indices().pixels == Workspace.generate_view(source, 128, 2, false).pixels, "Small is generated directly from Large")
	editor._select_view(1)
	var edited := editor.pixel_canvas.pixels.duplicate()
	edited[255 * 128 + 64] = 73
	editor.pixel_canvas._commit_changed_pixels(edited, "Manual generated Medium edit")
	_check(editor._resolved_view_entry(1).decode_indices().pixels[32] == 73, "Generated Medium accepts manual painting")
	_check(editor._resolved_view_entry(0).encoded_pixels == large, "Manual Medium edits preserve Large")
	editor._select_view(2)
	edited = editor.pixel_canvas.pixels.duplicate()
	edited[255 * 128 + 64] = 74
	editor.pixel_canvas._commit_changed_pixels(edited, "Manual generated Small edit")
	_check(editor._resolved_view_entry(2).decode_indices().pixels[16] == 74, "Generated Small accepts manual painting")
	var small_after: PackedByteArray = editor._resolved_view_entry(2).encoded_pixels.duplicate()
	editor._select_view(0)
	project.documents[large_key].active = 0
	editor._refresh_sprite()
	edited = editor.pixel_canvas.pixels.duplicate()
	edited[255 * 128 + 68] = 72
	editor.pixel_canvas._commit_changed_pixels(edited, "Later Large edit")
	_check(editor._resolved_view_entry(1).decode_indices().pixels[32] == 73 and editor._resolved_view_entry(2).encoded_pixels == small_after, "Later Large edits do not regenerate smaller sizes")

	dialogs.generate_medium.button_pressed = true
	var undo_count := editor.undo_stack.size()
	editor._generate_selected_sizes()
	_check(editor.undo_stack.size() == undo_count + 1, "Generating both sizes records one Undo action")
	var folder := "user://scurk-generation-%d.scurk" % OS.get_process_id()
	assert(editor.studio.save_project(folder))
	var saved := editor.tile_set.to_bytes().bytes
	assert(editor.load_path(folder).ok)
	_check(editor.tile_set.to_bytes().bytes == saved, "Generated artwork survives a project save and reload")
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(folder)) == OK)

	var session := ScurkEditSession.new()
	var large_only := ScurkMif.from_archives([])
	assert(large_only.set_shape_indices(1000, 128, 1, PackedInt32Array(Array(range(128)))).ok)
	assert(session.load_document(large_only).ok)
	var original := session.document.to_bytes().bytes
	assert(session.begin_edit("Invalid generation").ok)
	_check(not session.generate_views(1000, source, 128, [1, 0], false).ok, "Invalid second size rejects generation")
	_check(session.document.to_bytes().bytes == original and session.project.documents.is_empty() and not session.has_pending_edit(), "Failure rolls back all generated sizes and layers")
	assert(session.begin_edit("Missing sizes").ok)
	assert(session.generate_views(1000, source, 128, [1, 2], false).ok)
	assert(session.commit_edit().ok)
	_check(session.document.archive.find_sprite(500) != null and session.document.archive.find_sprite(0) != null, "Generation creates missing smaller sizes")
