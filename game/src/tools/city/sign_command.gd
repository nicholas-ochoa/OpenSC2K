class_name SignCommand
extends RefCounted
## User signs. The native simulation library edits XLAB and XTXT of original
## and SCLG cities, and XSGN of SC2X version 4 cities; see
## native/core/sim/src/sim/tools/commands/sign.rs.

const LABEL_RECORD_SIZE := Sc2LabelLayout.RECORD_SIZE
# commit order: the label text, then its tile link
const PAYLOAD_IDS: PackedStringArray = ["XLAB", "XTXT"]


static func set_sign(city: CityState, point: Vector2i, text: String) -> SignEditResult:
	if city == null or not city.is_valid():
		return SignEditResult.rejected("city is invalid")

	var tile_index := city.index_of(point.x, point.y)

	if tile_index < 0:
		return SignEditResult.rejected("sign position is outside the city")

	if CitySignTable.uses_table(city):
		return _set_table_sign(city, point, tile_index, text)

	return NativeSimulationBridge.run("tool.sign", city, null, null, null, {"point": point, "text": text}, PAYLOAD_IDS).result


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

	if CitySignTable.uses_table(city):
		return _undo_table_sign(city, command)

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


static func _restore_label_record(
	label_chunk: Sc2Chunk, record_offset: int, record: PackedByteArray
) -> bool:
	if record.size() != LABEL_RECORD_SIZE:
		return false

	var changed := label_chunk.decoded_payload.duplicate()

	for index in LABEL_RECORD_SIZE:
		changed[record_offset + index] = record[index]

	return label_chunk.set_decoded_payload(changed)


# An SC2X version 4 sign shares its tile with any facility, object, or marker.
# The command swaps the whole XSGN payload.
static func _set_table_sign(city: CityState, point: Vector2i, tile_index: int, text: String) -> SignEditResult:
	var chunk := city.document.find_chunk(CitySignTable.CHUNK_ID)

	if chunk == null:
		return SignEditResult.rejected("XSGN data is missing")

	var changed := CitySignTable.with_text(city, point, text)

	if not changed.ok:
		return SignEditResult.rejected(changed.error)

	var old_payload := chunk.decoded_payload

	if not chunk.set_decoded_payload(changed.payload):
		return SignEditResult.rejected("cannot store the sign")

	var metadata := city.document.sc2x_metadata

	if int(changed.sign_id) >= metadata.next_sign_id:
		metadata.next_sign_id = int(changed.sign_id) + 1

	var result := SignEditResult.new()
	result.ok = true
	result.command_type = "sign"
	result.point = point
	result.tile_index = tile_index
	result.label_id = int(changed.sign_id)
	result.old_record = old_payload
	result.new_record = chunk.decoded_payload
	result.text = text

	return result


static func _undo_table_sign(city: CityState, command: SignEditResult) -> EditCommandResult:
	var chunk := city.document.find_chunk(CitySignTable.CHUNK_ID)

	if chunk == null:
		return EditCommandResult.failure("XSGN data is missing")

	if chunk.decoded_payload != command.new_record:
		return EditCommandResult.failure("city changed after this sign command")

	if not chunk.set_decoded_payload(command.old_record):
		return EditCommandResult.failure("cannot restore the signs")

	return EditCommandResult.undone(1)
