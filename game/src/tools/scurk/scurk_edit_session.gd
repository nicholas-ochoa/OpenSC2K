class_name ScurkEditSession
extends RefCounted
## Owns publication of artwork, its MIF bytes, and its history record.

const Mif = preload("res://src/assets/scurk_mif.gd")
const Project = preload("res://src/tools/scurk/scurk_project.gd")
const History = preload("res://src/tools/scurk/scurk_editor_history.gd")
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
	var view := 0
	var clipped := false


class PendingEdit extends RefCounted:
	var description := "Edit artwork"
	var bytes := PackedByteArray()
	var project_state: Dictionary = {}
	var blank_shape_ids: Dictionary[int, bool] = {}
	var modified := false


var document: ScurkMif
var project: ScurkProject = Project.new()
var history: ScurkEditorHistory = History.new()
var modified := false
var _pending: PendingEdit


func has_pending_edit() -> bool:
	return _pending != null


func begin_edit(description := "Edit artwork") -> Result:
	cancel_edit()
	if document == null:
		return _failure("No SCURK tile set is loaded.")
	var encoded := document.to_bytes()
	if not encoded.ok:
		return _failure(encoded.error)
	_pending = PendingEdit.new()
	_pending.description = description
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
	action.before = _pending.bytes
	action.after = encoded.bytes.duplicate()
	action.project_before = _pending.project_state
	action.project_after = project.snapshot()
	action.blank_before = _pending.blank_shape_ids
	action.blank_after = history.blank_shape_ids.duplicate()
	var changed := history.record(action)
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
