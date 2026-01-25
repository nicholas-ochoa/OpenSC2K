class_name SignCommand
extends RefCounted

const FIRST_USER_LABEL := 1
const LAST_USER_LABEL := 50
const LABEL_RECORD_SIZE := 25


static func set_sign(city: CityState, point: Vector2i, text: String) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	var tile_index := city.index_of(point.x, point.y)
	if tile_index < 0:
		return {"ok": false, "error": "sign position is outside the city"}
	var old_overlay := city.text_overlays[tile_index]
	if old_overlay > LAST_USER_LABEL:
		return {"ok": false, "error": "this tile has a protected simulation label"}
	var label_id := old_overlay
	if label_id == 0 and not text.is_empty():
		label_id = _first_free_label(city)
		if label_id == 0:
			return {"ok": false, "error": "all 50 user sign labels are in use"}
	if label_id == 0:
		return {"ok": false, "error": "this tile does not have a sign"}

	var label_chunk := city.document.find_chunk("XLAB")
	if label_chunk == null:
		return {"ok": false, "error": "XLAB data is missing"}
	var record_offset := label_id * LABEL_RECORD_SIZE
	var old_record := label_chunk.decoded_payload.slice(
		record_offset, record_offset + LABEL_RECORD_SIZE
	)
	var new_overlay := 0 if text.is_empty() else label_id
	if not city.set_label(label_id, text):
		return {"ok": false, "error": "cannot store the sign text"}
	var new_record := label_chunk.decoded_payload.slice(
		record_offset, record_offset + LABEL_RECORD_SIZE
	)
	var changed_overlays := city.text_overlays.duplicate()
	changed_overlays[tile_index] = new_overlay
	if not city.replace_text_overlays(changed_overlays):
		_restore_label_record(label_chunk, record_offset, old_record)
		return {"ok": false, "error": "cannot store the sign position"}
	return {
		"ok": true,
		"command_type": "sign",
		"point": point,
		"tile_index": tile_index,
		"label_id": label_id,
		"old_overlay": old_overlay,
		"new_overlay": new_overlay,
		"old_record": old_record,
		"new_record": new_record,
		"text": text.left(23),
		"error": "",
	}


static func undo(city: CityState, command: Dictionary) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not command.get("ok", false) or command.get("command_type", "") != "sign":
		return {"ok": false, "error": "sign command is invalid"}
	var tile_index: int = command.get("tile_index", -1)
	var label_id: int = command.get("label_id", 0)
	if tile_index < 0 or tile_index >= (map_edge * map_edge):
		return {"ok": false, "error": "sign undo tile is invalid"}
	if label_id < FIRST_USER_LABEL or label_id > LAST_USER_LABEL:
		return {"ok": false, "error": "sign undo label is invalid"}
	var label_chunk := city.document.find_chunk("XLAB")
	if label_chunk == null:
		return {"ok": false, "error": "XLAB data is missing"}
	var record_offset := label_id * LABEL_RECORD_SIZE
	var current_record := label_chunk.decoded_payload.slice(
		record_offset, record_offset + LABEL_RECORD_SIZE
	)
	var expected_record: PackedByteArray = command.get("new_record", PackedByteArray())
	if city.text_overlays[tile_index] != int(command.new_overlay) or current_record != expected_record:
		return {"ok": false, "error": "city changed after this sign command"}
	var old_record: PackedByteArray = command.get("old_record", PackedByteArray())
	if old_record.size() != LABEL_RECORD_SIZE:
		return {"ok": false, "error": "sign undo record has the wrong size"}
	var current_overlays := city.text_overlays.duplicate()
	var restored_overlays := current_overlays.duplicate()
	restored_overlays[tile_index] = int(command.old_overlay)
	if not _restore_label_record(label_chunk, record_offset, old_record):
		return {"ok": false, "error": "cannot restore the sign text"}
	if not city.replace_text_overlays(restored_overlays):
		_restore_label_record(label_chunk, record_offset, current_record)
		return {"ok": false, "error": "cannot restore the sign position"}
	return {"ok": true, "restored_tiles": 1, "error": ""}


static func _first_free_label(city: CityState) -> int:
	for label_id in range(FIRST_USER_LABEL, LAST_USER_LABEL + 1):
		if city.label(label_id).is_empty():
			return label_id
	return 0


static func _restore_label_record(
	label_chunk: Sc2Chunk, record_offset: int, record: PackedByteArray
) -> bool:
	if record.size() != LABEL_RECORD_SIZE:
		return false
	var changed := label_chunk.decoded_payload.duplicate()
	for index in LABEL_RECORD_SIZE:
		changed[record_offset + index] = record[index]
	return label_chunk.set_decoded_payload(changed)
