class_name ScurkEditorHistory
extends RefCounted

const Mif = preload("res://src/assets/scurk_mif.gd")
const HISTORY_LIMIT := 24

var saved_bytes := PackedByteArray()
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var pending_edit_before := PackedByteArray()
var pending_blank_shape_ids: Dictionary = {}
var object_start_bytes := PackedByteArray()
var object_start_large_id := -1
var object_start_blank_shape_ids: Dictionary = {}
var blank_shape_ids: Dictionary = {}
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


func capture_edit(document: ScurkMif) -> void:
	if document == null:
		return

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

	if not encoded.ok or encoded.bytes == before:
		return false

	undo_stack.append({
		"before": before.duplicate(),
		"after": encoded.bytes.duplicate(),
		"blank_before": pending_blank_shape_ids.duplicate(),
		"blank_after": blank_shape_ids.duplicate(),
	})

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


func undo() -> Dictionary:
	if not can_undo():
		return {"ok": false, "no_action": true, "error": ""}

	var action: Dictionary = undo_stack.pop_back()
	var replacement := _decode_document(action.before)

	if not replacement.ok:
		return replacement

	blank_shape_ids = action.get("blank_before", {}).duplicate()
	redo_stack.append(action)

	return {"ok": true, "document": replacement.document, "error": ""}


func redo() -> Dictionary:
	if not can_redo():
		return {"ok": false, "no_action": true, "error": ""}

	var action: Dictionary = redo_stack.pop_back()
	var replacement := _decode_document(action.after)

	if not replacement.ok:
		return replacement

	blank_shape_ids = action.get("blank_after", {}).duplicate()
	undo_stack.append(action)

	return {"ok": true, "document": replacement.document, "error": ""}


func revert_object(document: ScurkMif, large_id: int) -> Dictionary:
	if not can_revert_object(document, large_id):
		return {"ok": false, "no_action": true, "error": ""}

	var encoded := document.to_bytes()
	var before: PackedByteArray = encoded.bytes.duplicate()
	var blank_before := blank_shape_ids.duplicate()
	var replacement := _decode_document(object_start_bytes)

	if not replacement.ok:
		return replacement

	blank_shape_ids = object_start_blank_shape_ids.duplicate()
	pending_blank_shape_ids = blank_before
	record(before, replacement.document)

	return {"ok": true, "document": replacement.document, "error": ""}


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


func _decode_document(bytes: PackedByteArray) -> Dictionary:
	var replacement := Mif.new()

	if not replacement.parse(bytes):
		return {"ok": false, "error": replacement.parse_error}

	return {"ok": true, "document": replacement, "error": ""}
