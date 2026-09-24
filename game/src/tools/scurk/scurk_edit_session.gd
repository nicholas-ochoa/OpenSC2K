class_name ScurkEditSession
extends RefCounted
## Owns publication of artwork, its MIF bytes, and its history record.

const Mif = preload("res://src/assets/scurk_mif.gd")
const Project = preload("res://src/tools/scurk/scurk_project.gd")
const History = preload("res://src/tools/scurk/scurk_editor_history.gd")
const ObjectState = preload("res://src/tools/scurk/scurk_object_state.gd")
const Workspace = preload("res://src/tools/scurk/scurk_drawing_workspace.gd")

class Result extends RefCounted:
	var ok := false
	var error := ""
	var changed := false


class PixelTarget extends RefCounted:
	var key := ""
	var sprite_id := -1
	var width := 0
	var height := 0
	var workspace := false
	var base_width := 0
	var view := ScurkSpriteIds.View.LARGE
	var clipped := false


class PendingEdit extends RefCounted:
	var description := "Edit artwork"
	var merge_key := ""
	var bytes := PackedByteArray()
	var project_state: Dictionary = {}
	var blank_shape_ids: Dictionary[int, bool] = {}
	var modified := false


var document: ScurkMif
var project: ScurkProject = Project.new()
var history: ScurkEditorHistory = History.new()
var modified := false
var project_path := ""
var recovery_path := "user://scurk/recovery.scurk"
var recovery_owned := false
var recovered_source := ""
var saved_pixels: Dictionary = {}
var saved_state: Dictionary = {}
var saved_checkpoints: Array = []
var object_start: ScurkObjectState
var _pending: PendingEdit


func load_document(value: ScurkMif) -> Result:
	if value == null or not value.is_valid():
		return _failure("The SCURK tile set is invalid.")
	var encoded := value.to_bytes()
	if not encoded.ok:
		return _failure(encoded.error)
	var fresh := Project.new()
	var initialized := fresh.initialize(encoded.bytes)
	if not initialized.ok:
		return _failure(initialized.error)
	fresh.metadata["editor_state"] = {"blank_shape_ids": [], "unclipped_tile_ids": []}
	document = value
	project = fresh
	history.reset(encoded.bytes)
	cancel_edit()
	project_path = ""
	recovery_owned = false
	recovered_source = ""
	modified = false
	object_start = null
	_capture_saved_state()
	return _success()


func load_project(path: String, recovered := false) -> Result:
	var loaded := Project.load_path(path)
	if not loaded.ok:
		return _failure(loaded.error)
	var replacement := Mif.new()
	if not replacement.parse(loaded.project.current_mif):
		return _failure(replacement.parse_error)
	document = replacement
	project = loaded.project
	history.reset(project.current_mif)
	cancel_edit()
	object_start = null
	project_path = "" if recovered else ProjectSettings.globalize_path(path)
	recovery_owned = recovered and ProjectSettings.globalize_path(path) == ProjectSettings.globalize_path(recovery_path)
	recovered_source = path if recovered else ""
	_capture_saved_state()
	modified = recovered
	return _success()


func save_project(path: String) -> Result:
	var synchronized := _synchronize_document()
	if not synchronized.ok:
		return synchronized
	var written := project.save_path(path)
	if not written.ok:
		return _failure(written.error)
	project_path = ProjectSettings.globalize_path(path)
	_capture_saved_state()
	history.mark_saved(project.current_mif)
	modified = false
	if recovery_owned and FileAccess.file_exists(recovery_path) and ProjectSettings.globalize_path(recovery_path).simplify_path() != project_path.simplify_path():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(recovery_path))
	if not recovered_source.is_empty() and FileAccess.file_exists(recovered_source) and ProjectSettings.globalize_path(recovered_source).simplify_path() != project_path.simplify_path():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(recovered_source))
	recovery_owned = false
	recovered_source = ""
	return _success()


func autosave() -> Result:
	var synchronized := _synchronize_document()
	if not synchronized.ok:
		return synchronized
	if FileAccess.file_exists(recovery_path) and not recovery_owned:
		var archived := "%s/recovery-%d-%d.scurk" % [recovery_path.get_base_dir(), Time.get_unix_time_from_system(), Time.get_ticks_usec()]
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(recovery_path), ProjectSettings.globalize_path(archived)) != OK:
			return _failure("Cannot preserve the previous recovery file.")
	var written := project.autosave_path(recovery_path)
	if not written.ok:
		return _failure(written.error)
	recovery_owned = true
	return _success()


func discard_recovery() -> void:
	if recovery_owned:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(recovery_path))
		recovery_owned = false


func ignore_recovery() -> Result:
	if not FileAccess.file_exists(recovery_path):
		return _success()
	var archived := "%s/recovery-ignored-%d-%d.scurk" % [recovery_path.get_base_dir(), Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(recovery_path), ProjectSettings.globalize_path(archived)) != OK:
		return _failure("Cannot archive the ignored recovery file.")
	if recovered_source == recovery_path:
		recovered_source = archived
	recovery_owned = false
	return _success()


func capture_object(large_id: int, unclipped := false) -> void:
	object_start = ObjectState.capture(document, project, large_id, history.blank_shape_ids) if document != null and large_id >= 0 else null
	if object_start != null:
		object_start.unclipped = unclipped


func can_revert_object(large_id: int) -> bool:
	return object_start != null and object_start.large_id == large_id and document != null and not object_start.matches(document, project, history.blank_shape_ids)


func revert_object(large_id: int) -> Result:
	if not can_revert_object(large_id):
		return _success()
	var state := object_start.restored_project(document, project)
	if state.is_empty():
		return _failure("Cannot restore the selected object.")
	var replacement := Mif.new()
	if not replacement.parse(state.current_mif):
		return _failure(replacement.parse_error)
	var started := begin_edit("Revert object")
	if not started.ok:
		return started
	if not project.restore_snapshot(state):
		return _reject_edit("Cannot restore the selected object.")
	document = replacement
	for view in ScurkSpriteIds.VIEW_COUNT:
		history.blank_shape_ids.erase(ScurkEditorRules.view_sprite_id(large_id, view))
	for sprite_id in object_start.blank_shape_ids:
		history.blank_shape_ids[sprite_id] = true
	return commit_edit()


func remember_document_baseline(key: String) -> void:
	if not project.documents.has(key):
		return
	if object_start != null:
		object_start.remember_unedited_document(document, project, key)
	var current: Dictionary = project.documents[key]
	if saved_state.has("documents") and not saved_state.documents.has(key):
		saved_state.documents[key] = current.duplicate(true)
	if not saved_pixels.has(key):
		saved_pixels[key] = current.original_pixels.duplicate()


func update_modified() -> void:
	var current := project.snapshot()
	current.metadata.erase("editor_state")
	var saved := saved_state.duplicate(true)
	if saved.has("metadata"):
		saved.metadata.erase("editor_state")
	for name: String in current.documents:
		if saved.has("documents") and saved.documents.has(name):
			saved.documents[name].active = current.documents[name].active
	modified = current != saved or project.checkpoints != saved_checkpoints


func _capture_saved_state() -> void:
	saved_state = project.snapshot()
	saved_checkpoints = project.checkpoints.duplicate(true)
	saved_pixels.clear()
	for name: String in project.documents:
		saved_pixels[name] = project.flatten(name)


func _synchronize_document() -> Result:
	if document == null:
		return _failure("No SCURK tile set is loaded.")
	var encoded := document.to_bytes()
	if not encoded.ok:
		return _failure(encoded.error)
	if not project.set_current_mif(encoded.bytes):
		return _failure("The project tile set is invalid.")
	return _success()


func has_pending_edit() -> bool:
	return _pending != null


func begin_edit(description := "Edit artwork", merge_key := "") -> Result:
	cancel_edit()
	if document == null:
		return _failure("No SCURK tile set is loaded.")
	var encoded := document.to_bytes()
	if not encoded.ok:
		return _failure(encoded.error)
	_pending = PendingEdit.new()
	_pending.description = description
	_pending.merge_key = merge_key
	_pending.bytes = encoded.bytes.duplicate()
	_pending.project_state = project.snapshot()
	_pending.blank_shape_ids = history.blank_shape_ids.duplicate()
	_pending.modified = modified
	return _success()


func cancel_edit() -> void:
	_pending = null


func write_pixels(target: PixelTarget, pixels: PackedInt32Array, replace_active_layer := false) -> Result:
	if not has_pending_edit():
		return _failure("No SCURK edit is pending.")
	if document == null or target.sprite_id < 0:
		return _reject_edit("No SCURK tile is selected.")
	var flattened := pixels
	if replace_active_layer and project.documents.has(target.key):
		if not project.set_active_pixels(target.key, pixels):
			return _reject_edit("The active layer cannot accept these pixels.")
		flattened = project.flatten(target.key)
	var width := target.width
	var height := target.height
	var output := flattened
	if target.workspace:
		var shape := Workspace.shape_from_workspace(flattened, target.base_width, target.view, target.clipped)
		if not shape.ok:
			return _reject_edit(shape.error)
		width = shape.width
		height = shape.height
		output = shape.pixels
	var written := document.set_shape_indices(target.sprite_id, width, height, output)
	if not written.ok:
		return _reject_edit(written.error)
	history.mark_shape_blank_state(target.sprite_id, output)
	return _success()


func generate_views(
	large_id: int, source: PackedInt32Array, base_width: int, views: Array[int], clipped: bool
) -> Result:
	if not has_pending_edit():
		return _failure("No SCURK edit is pending.")
	if views.is_empty():
		return _reject_edit("Select at least one size to generate.")
	for view in views:
		var shape := Workspace.generate_view(source, base_width, view, clipped)
		if not shape.ok:
			return _reject_edit(shape.error)
		var sprite_id := ScurkEditorRules.view_sprite_id(large_id, view)
		var written := document.set_shape_indices(sprite_id, shape.width, shape.height, shape.pixels)
		if not written.ok:
			return _reject_edit(written.error)
		var key := "%d:%d" % [large_id, view]
		var pixels := Workspace.from_shape(shape.width, shape.height, shape.pixels, view, base_width, clipped)
		if not project.ensure_document(key, pixels, Workspace.WIDTH, Workspace.HEIGHT):
			return _reject_edit("Cannot create the generated artwork document.")
		var target: Dictionary = project.documents[key]
		target.layers = [{"name": "Root", "visible": true, "locked": false, "pixels": pixels}]
		target.active = 0
		history.mark_shape_blank_state(sprite_id, shape.pixels)
	return _success()


func commit_edit() -> Result:
	if not has_pending_edit():
		return _failure("No SCURK edit is pending.")
	var encoded := document.to_bytes()
	if not encoded.ok:
		return _reject_edit(encoded.error)
	if not project.set_current_mif(encoded.bytes):
		return _reject_edit("The project tile set is invalid.")
	var action := History.Record.new()
	action.description = _pending.description
	action.merge_key = _pending.merge_key
	action.before = _pending.bytes
	action.after = encoded.bytes.duplicate()
	action.project_before = _pending.project_state
	action.project_after = project.snapshot()
	action.blank_before = _pending.blank_shape_ids
	action.blank_after = history.blank_shape_ids.duplicate()
	var changed := history.record(action)
	update_modified()
	cancel_edit()
	return _success(changed)


func rollback_edit() -> Result:
	if not has_pending_edit():
		return _success()
	var replacement := Mif.new()
	if not replacement.parse(_pending.bytes):
		return _failure(replacement.parse_error)
	if not project.restore_snapshot(_pending.project_state):
		return _failure("Cannot restore the project before this edit.")
	document = replacement
	history.blank_shape_ids = _pending.blank_shape_ids.duplicate()
	modified = _pending.modified
	cancel_edit()
	return _success()


func undo() -> Result:
	return _step_history(false)


func redo() -> Result:
	return _step_history(true)


func _step_history(forward: bool) -> Result:
	var source := history.redo_stack if forward else history.undo_stack
	if source.is_empty():
		return _success()
	var action: ScurkEditorHistory.Record = source.back()
	var bytes := action.after if forward else action.before
	var state := action.project_after if forward else action.project_before
	var replacement := Mif.new()
	if not replacement.parse(bytes):
		return _failure(replacement.parse_error)
	if state.get("current_mif") != bytes or not project.restore_snapshot(state):
		return _failure("Cannot restore the project for this history action.")
	cancel_edit()
	# Both representations are valid before either history stack moves.
	document = replacement
	history.blank_shape_ids = (action.blank_after if forward else action.blank_before).duplicate()
	source.pop_back()
	var destination := history.undo_stack if forward else history.redo_stack
	destination.append(action)
	history.update_dirty(document)
	update_modified()
	return _success(true)


func _reject_edit(message: String) -> Result:
	var restored := rollback_edit()
	return _failure(message if restored.ok else message + " " + restored.error)


static func _success(changed := false) -> Result:
	var result := Result.new()
	result.ok = true
	result.changed = changed
	return result


static func _failure(message: String) -> Result:
	var result := Result.new()
	result.error = message
	return result
