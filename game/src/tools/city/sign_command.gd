class_name SignCommand
extends RefCounted

const FIRST_USER_LABEL := Sc2OverlayLayout.ORIGINAL_SIGN_FIRST
const LAST_USER_LABEL := Sc2OverlayLayout.ORIGINAL_SIGN_LAST
const LABEL_RECORD_SIZE := Sc2LabelLayout.RECORD_SIZE


static func set_sign(city: CityState, point: Vector2i, text: String) -> SignEditResult:
	if city == null or not city.is_valid():
		return SignEditResult.rejected("city is invalid")

	var tile_index := city.index_of(point.x, point.y)

	if tile_index < 0:
		return SignEditResult.rejected("sign position is outside the city")

	var old_overlay := OverlayData.read(city.text_overlays, tile_index)

	if old_overlay != 0 and not OverlayData.is_sign(old_overlay):
		return SignEditResult.rejected("this tile has a protected simulation label")

	var label_id := old_overlay

	if label_id == 0 and not text.is_empty():
		label_id = _first_free_label(city)

		if label_id == 0:
			return SignEditResult.rejected("all user sign labels are in use")

	if label_id == 0:
		return SignEditResult.rejected("this tile does not have a sign")

	var label_chunk := city.document.find_chunk("XLAB")

	if label_chunk == null:
		return SignEditResult.rejected("XLAB data is missing")

	var record_offset := label_id * LABEL_RECORD_SIZE
	var old_record := label_chunk.decoded_payload.slice(
		record_offset, record_offset + LABEL_RECORD_SIZE
	)
	var new_overlay := 0 if text.is_empty() else label_id

	if not city.set_label(label_id, text):
		return SignEditResult.rejected("cannot store the sign text")

	var new_record := label_chunk.decoded_payload.slice(
		record_offset, record_offset + LABEL_RECORD_SIZE
	)
	var changed_overlays := city.text_overlays.duplicate()
	OverlayData.write(changed_overlays, tile_index, new_overlay)

	if not city.replace_text_overlays(changed_overlays):
		_restore_label_record(label_chunk, record_offset, old_record)

		return SignEditResult.rejected("cannot store the sign position")

	var result := SignEditResult.new()
	result.ok = true
	result.command_type = "sign"
	result.point = point
	result.tile_index = tile_index
	result.label_id = label_id
	result.old_overlay = old_overlay
	result.new_overlay = new_overlay
	result.old_record = old_record
	result.new_record = new_record
	result.text = text.left(Sc2LabelLayout.MAX_TEXT_BYTES)

	return result


static func undo(city: CityState, command: SignEditResult) -> EditCommandResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != "sign":
		return EditCommandResult.failure("sign command is invalid")

	var tile_index := command.tile_index
	var label_id := command.label_id

	if tile_index < 0 or tile_index >= (map_edge * map_edge):
		return EditCommandResult.failure("sign undo tile is invalid")

	if not OverlayData.is_sign(label_id):
		return EditCommandResult.failure("sign undo label is invalid")

	var label_chunk := city.document.find_chunk("XLAB")

	if label_chunk == null:
		return EditCommandResult.failure("XLAB data is missing")

	var record_offset := label_id * LABEL_RECORD_SIZE
	var current_record := label_chunk.decoded_payload.slice(
		record_offset, record_offset + LABEL_RECORD_SIZE
	)
	var expected_record := command.new_record

	if OverlayData.read(city.text_overlays, tile_index) != command.new_overlay or current_record != expected_record:
		return EditCommandResult.failure("city changed after this sign command")

	var old_record := command.old_record

	if old_record.size() != LABEL_RECORD_SIZE:
		return EditCommandResult.failure("sign undo record has the wrong size")

	var current_overlays := city.text_overlays.duplicate()
	var restored_overlays := current_overlays.duplicate()
	OverlayData.write(restored_overlays, tile_index, command.old_overlay)

	if not _restore_label_record(label_chunk, record_offset, old_record):
		return EditCommandResult.failure("cannot restore the sign text")

	if not city.replace_text_overlays(restored_overlays):
		_restore_label_record(label_chunk, record_offset, current_record)

		return EditCommandResult.failure("cannot restore the sign position")

	return EditCommandResult.undone(1)


static func _first_free_label(city: CityState) -> int:
	for label_id in OverlayData.sign_ids(city.document.decoded_size("XLAB")):
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
