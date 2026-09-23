class_name ScurkEditorHistory
extends RefCounted

const Mif = preload("res://src/assets/scurk_mif.gd")
const HISTORY_LIMIT := 24

class Result extends ScurkMif.Result:
	var no_action := false
	var document: ScurkMif


class Record extends RefCounted:
	var description := "Edit artwork"
	var before := PackedByteArray()
	var after := PackedByteArray()
	var project_before: Dictionary = {}
	var project_after: Dictionary = {}
	var blank_before: Dictionary[int, bool] = {}
	var blank_after: Dictionary[int, bool] = {}


var saved_bytes := PackedByteArray()
var undo_stack: Array[Record] = []
var redo_stack: Array[Record] = []
var pending_project_before: Dictionary = {}
var pending_project_after: Dictionary = {}
var pending_description := "Edit artwork"
var pending_edit_before := PackedByteArray()
var pending_blank_shape_ids: Dictionary[int, bool] = {}
var object_start_bytes := PackedByteArray()
var object_start_large_id := -1
var object_start_blank_shape_ids: Dictionary[int, bool] = {}
var blank_shape_ids: Dictionary[int, bool] = {}
var dirty := false


func reset(encoded_bytes: PackedByteArray) -> void:
	saved_bytes = encoded_bytes.duplicate()
	undo_stack.clear()
	redo_stack.clear()
	pending_edit_before.clear()
	pending_blank_shape_ids.clear()
	blank_shape_ids.clear()
	dirty = false


func mark_saved(encoded_bytes: PackedByteArray) -> void:
	saved_bytes = encoded_bytes.duplicate()
	dirty = false


func capture_edit(document: ScurkMif, description := "Edit artwork") -> void:
	if document == null:
		return

	pending_description = description
	var encoded := document.to_bytes()
	pending_edit_before = (
		encoded.bytes.duplicate() if encoded.ok else PackedByteArray()
	)
	pending_blank_shape_ids = blank_shape_ids.duplicate()


func capture_object(document: ScurkMif, large_id: int) -> void:
	object_start_bytes.clear()
	object_start_large_id = large_id
	object_start_blank_shape_ids = blank_shape_ids.duplicate()

	if document == null or large_id < 0:
		return

	var encoded := document.to_bytes()

	if encoded.ok:
		object_start_bytes = encoded.bytes.duplicate()


func capture_blank_state() -> void:
	pending_blank_shape_ids = blank_shape_ids.duplicate()


func cancel_pending_edit() -> void:
	pending_edit_before.clear()


func record(before: PackedByteArray, document: ScurkMif) -> bool:
	if before.is_empty() or document == null:
		return false

	var encoded := document.to_bytes()

	if not encoded.ok or (encoded.bytes == before and pending_project_before == pending_project_after):
		return false

	var action := Record.new()
	action.description = pending_description
	action.project_before = pending_project_before.duplicate(true)
	action.project_after = pending_project_after.duplicate(true)
	action.before = before.duplicate()
	action.after = encoded.bytes.duplicate()
	action.blank_before = pending_blank_shape_ids.duplicate()
	action.blank_after = blank_shape_ids.duplicate()
	undo_stack.append(action)

	if undo_stack.size() > HISTORY_LIMIT:
		undo_stack.pop_front()

	redo_stack.clear()
	pending_edit_before.clear()
	pending_blank_shape_ids.clear()
	_update_dirty_bytes(encoded.bytes)

	return true


func can_undo() -> bool:
	return not undo_stack.is_empty()


func can_redo() -> bool:
	return not redo_stack.is_empty()


func undo() -> Result:
	if not can_undo():
		var result := Result.new()
		result.ok = false
		result.no_action = true
		result.error = ""

		return result

	var action: Record = undo_stack.pop_back()
	var replacement := _decode_document(action.before)

	if not replacement.ok:
		return replacement

	blank_shape_ids = action.blank_before.duplicate()
	redo_stack.append(action)

	var result := Result.new()
	result.ok = true
	result.document = replacement.document
	result.error = ""

	return result


func redo() -> Result:
	if not can_redo():
		var result := Result.new()
		result.ok = false
		result.no_action = true
		result.error = ""

		return result

	var action: Record = redo_stack.pop_back()
	var replacement := _decode_document(action.after)

	if not replacement.ok:
		return replacement

	blank_shape_ids = action.blank_after.duplicate()
	undo_stack.append(action)

	var result := Result.new()
	result.ok = true
	result.document = replacement.document
	result.error = ""

	return result


func revert_object(document: ScurkMif, large_id: int) -> Result:
	if not can_revert_object(document, large_id):
		var result := Result.new()
		result.ok = false
		result.no_action = true
		result.error = ""

		return result

	var encoded := document.to_bytes()
	var before: PackedByteArray = encoded.bytes.duplicate()
	var blank_before := blank_shape_ids.duplicate()
	var replacement := _decode_document(object_start_bytes)

	if not replacement.ok:
		return replacement

	blank_shape_ids = object_start_blank_shape_ids.duplicate()
	pending_blank_shape_ids = blank_before
	record(before, replacement.document)

	var result := Result.new()
	result.ok = true
	result.document = replacement.document
	result.error = ""

	return result


func can_revert_object(document: ScurkMif, large_id: int) -> bool:
	if (
		object_start_bytes.is_empty()
		or large_id < 0
		or object_start_large_id != large_id
		or document == null
	):
		return false

	var encoded := document.to_bytes()

	return encoded.ok and encoded.bytes != object_start_bytes


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


func _decode_document(bytes: PackedByteArray) -> Result:
	var replacement := Mif.new()

	if not replacement.parse(bytes):
		var result := Result.new()
		result.ok = false
		result.error = replacement.parse_error

		return result

	var result := Result.new()
	result.ok = true
	result.document = replacement
	result.error = ""

	return result
