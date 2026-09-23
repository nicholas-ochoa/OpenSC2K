class_name ScurkObjectState
extends RefCounted
## Keeps the selected object's baseline without retaining the whole project.

var large_id := -1
var pieces: Array[Dictionary] = []
var documents: Dictionary = {}
var blank_shape_ids: Array[int] = []
var unclipped := false


static func capture(document: ScurkMif, project: ScurkProject, id: int, blank_ids: Dictionary[int, bool]) -> ScurkObjectState:
	var state := ScurkObjectState.new()
	state.large_id = id
	for index in document.piece_records.size():
		var piece := document.piece_records[index]
		if state._contains_piece(piece):
			state.pieces.append({"tag": piece.tag, "id": piece.sprite_id, "payload": piece.raw_payload.duplicate(), "position": index})
	for view in ScurkSpriteIds.VIEW_COUNT:
		state.remember_document(project, "%d:%d" % [id, view])
		var sprite_id := ScurkEditorRules.view_sprite_id(id, view)
		if blank_ids.has(sprite_id):
			state.blank_shape_ids.append(sprite_id)
	return state


func remember_document(project: ScurkProject, key: String) -> void:
	if key.begins_with("%d:" % large_id) and project.documents.has(key) and not documents.has(key):
		documents[key] = project.documents[key].duplicate(true)


func remember_unedited_document(document: ScurkMif, project: ScurkProject, key: String) -> void:
	if not key.begins_with("%d:" % large_id) or documents.has(key):
		return
	var sprite_id := ScurkEditorRules.view_sprite_id(large_id, int(key.get_slice(":", 1)))
	var original: Array[PackedByteArray] = []
	var current: Array[PackedByteArray] = []
	for piece in pieces:
		if piece.tag == "SHAP" and piece.id == sprite_id:
			original.append(piece.payload)
	for piece in document.piece_records:
		if piece.tag == "SHAP" and piece.sprite_id == sprite_id:
			current.append(piece.raw_payload)
	if original == current:
		remember_document(project, key)


func matches(document: ScurkMif, project: ScurkProject, blank_ids: Dictionary[int, bool]) -> bool:
	var current := capture(document, project, large_id, blank_ids)
	# Selection of a layer or insertion of another object's record is not an edit.
	for key: String in current.documents:
		if documents.has(key):
			current.documents[key].active = documents[key].active
	for piece in current.pieces:
		piece.erase("position")
	var baseline := pieces.duplicate(true)
	for piece in baseline:
		piece.erase("position")
	return current.pieces == baseline and current.documents == documents and current.blank_shape_ids == blank_shape_ids


func restored_project(document: ScurkMif, project: ScurkProject) -> Dictionary:
	var replacement := ScurkMif.new()
	replacement.info_payload = document.info_payload.duplicate()
	var remaining := pieces.duplicate(true)
	for piece in document.piece_records:
		if not _contains_piece(piece):
			replacement.piece_records.append(piece)
			continue
		for index in remaining.size():
			var original: Dictionary = remaining[index]
			if piece.tag == original.tag and piece.sprite_id == original.id:
				replacement.piece_records.append(ScurkMif.Piece.new(original.tag, original.id, original.payload))
				remaining.remove_at(index)
				break
	for original in remaining:
		replacement.piece_records.insert(mini(original.position, replacement.piece_records.size()),
			ScurkMif.Piece.new(original.tag, original.id, original.payload))
	var encoded := replacement.to_bytes()
	if not encoded.ok:
		return {}
	var state := project.snapshot()
	state.current_mif = encoded.bytes
	for view in ScurkSpriteIds.VIEW_COUNT:
		var key := "%d:%d" % [large_id, view]
		state.documents.erase(key)
		if documents.has(key):
			state.documents[key] = documents[key].duplicate(true)
	var editor_state: Dictionary = state.metadata.get("editor_state", {}).duplicate(true)
	var blank: Array = editor_state.get("blank_shape_ids", [])
	for view in ScurkSpriteIds.VIEW_COUNT:
		blank.erase(ScurkEditorRules.view_sprite_id(large_id, view))
	blank.append_array(blank_shape_ids)
	editor_state.blank_shape_ids = blank
	var unclipped_ids: Array = editor_state.get("unclipped_tile_ids", [])
	unclipped_ids.erase(large_id)
	if unclipped:
		unclipped_ids.append(large_id)
	editor_state.unclipped_tile_ids = unclipped_ids
	state.metadata.editor_state = editor_state
	return state


func _contains_piece(piece: ScurkMif.Piece) -> bool:
	if piece.tag == "NAME":
		return piece.sprite_id == ScurkEditorRules.object_tile_id(large_id)
	if piece.tag == "SHAP":
		for view in ScurkSpriteIds.VIEW_COUNT:
			if piece.sprite_id == ScurkEditorRules.view_sprite_id(large_id, view):
				return true
	return false
