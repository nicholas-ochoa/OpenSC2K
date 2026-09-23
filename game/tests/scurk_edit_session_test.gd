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
	_test_persistence()
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
	var foreground := canvas.foreground_index
	canvas.foreground_index = 43
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
	canvas.foreground_index = foreground
	assert(editor.studio.project.set_layer_locked(key, 0, false))
	editor.studio.bind_canvas()
	editor.studio.update_modified()
	_check_artwork(initial, "Unlocked fixture")


func _test_unchanged_stroke(before: Dictionary) -> void:
	var canvas := editor.pixel_canvas
	var foreground := canvas.foreground_index
	canvas.foreground_index = 42
	canvas._begin_stroke(Vector2i(0, 255), MOUSE_BUTTON_LEFT)
	_check(editor.session.has_pending_edit(), "A stroke captures its starting state")
	canvas._finish_stroke()
	_check_artwork(before, "Same-color stroke")
	_check(editor.edit_history.undo_stack.is_empty() and editor.edit_history.redo_stack.is_empty(), "Same-color stroke adds no history")
	_check_pending_clear("Same-color stroke")
	canvas.foreground_index = foreground


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
	var foreground := canvas.foreground_index
	canvas.foreground_index = 45
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
		canvas.foreground_index = foreground
		return

	# Inject a rejected target while another stroke is active.
	var record: ScurkEditorHistory.Record = editor.edit_history.undo_stack.back()
	var saved_bytes := record.before.duplicate()
	record.before = PackedByteArray([0])
	var before := _state()
	canvas.foreground_index = 46
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
	canvas.foreground_index = foreground


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
