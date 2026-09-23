class_name ScurkEditorHistory
extends RefCounted

const HISTORY_LIMIT := 24

class Record extends RefCounted:
	var description := "Edit artwork"
	var merge_key := ""
	var before := PackedByteArray()
	var after := PackedByteArray()
	var project_before: Dictionary = {}
	var project_after: Dictionary = {}
	var blank_before: Dictionary[int, bool] = {}
	var blank_after: Dictionary[int, bool] = {}


var saved_bytes := PackedByteArray()
var undo_stack: Array[Record] = []
var redo_stack: Array[Record] = []
var blank_shape_ids: Dictionary[int, bool] = {}
var dirty := false


func reset(encoded_bytes: PackedByteArray) -> void:
	saved_bytes = encoded_bytes.duplicate()
	undo_stack.clear()
	redo_stack.clear()
	blank_shape_ids.clear()
	dirty = false


func mark_saved(encoded_bytes: PackedByteArray) -> void:
	saved_bytes = encoded_bytes.duplicate()
	dirty = false


func record(action: Record) -> bool:
	if action.before.is_empty() or action.after.is_empty():
		return false
	if action.before == action.after and action.project_before == action.project_after:
		return false
	if not action.merge_key.is_empty() and not undo_stack.is_empty() and redo_stack.is_empty():
		var previous: Record = undo_stack.back()
		if previous.merge_key == action.merge_key and previous.project_after == action.project_before:
			previous.after = action.after
			previous.project_after = action.project_after
			previous.blank_after = action.blank_after
			_update_dirty_bytes(action.after)
			return true
	undo_stack.append(action)
	if undo_stack.size() > HISTORY_LIMIT:
		undo_stack.pop_front()
	redo_stack.clear()
	_update_dirty_bytes(action.after)
	return true


func can_undo() -> bool:
	return not undo_stack.is_empty()


func can_redo() -> bool:
	return not redo_stack.is_empty()


func mark_shape_blank_state(
	sprite_id: int, value_pixels: PackedInt32Array
) -> void:
	for pixel in value_pixels:
		if pixel >= 0:
			blank_shape_ids.erase(sprite_id)

			return

	blank_shape_ids[sprite_id] = true


func update_dirty(document: ScurkMif) -> void:
	if document == null:
		dirty = false

		return

	var encoded := document.to_bytes()
	dirty = encoded.ok and encoded.bytes != saved_bytes


func _update_dirty_bytes(encoded_bytes: PackedByteArray) -> void:
	dirty = encoded_bytes != saved_bytes
