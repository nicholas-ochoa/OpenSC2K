class_name BuildingState
extends BuildingConstants
## The building chunk payloads of a city, for the stadium team and SCURK history.

const ChunkCommit = preload("res://src/model/city/ordered_chunk_commit.gd")


static func _city_payloads(city: CityState) -> Dictionary[String, PackedByteArray]:
	var map_edge: int = city.map_size if city != null else 128
	var result: Dictionary[String, PackedByteArray] = {}

	for checked in [
		["XBLD", (map_edge * map_edge)],
		["XTER", (map_edge * map_edge)],
		["XZON", (map_edge * map_edge)],
		["XUND", (map_edge * map_edge)],
		["XBIT", (map_edge * map_edge)],
		["XTXT", (map_edge * map_edge)],
		["XLAB", CityState.LABEL_COUNT * CityState.LABEL_RECORD_SIZE],
		["XMIC", CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE],
		["MISC", Sc2MiscLayout.SIZE],
	]:
		var chunk := city.document.find_chunk(checked[0])

		if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size(str(checked[0])):
			return {}

		result[checked[0]] = chunk.decoded_payload.duplicate()

	return result


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary[String, PackedByteArray]:
	var result: Dictionary[String, PackedByteArray] = {}

	for chunk_id in payloads:
		result[chunk_id] = payloads[chunk_id].duplicate()

	return result


static func _restore_payloads(city: CityState, old_payloads: Dictionary) -> bool:
	var current_payloads := _city_payloads(city)

	if current_payloads.is_empty():
		return false

	var changed_ids := PackedStringArray()

	for chunk_id in old_payloads:
		if current_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	return _apply_payloads(city, changed_ids, old_payloads, current_payloads)


static func _apply_payloads(
	city: CityState, chunk_ids: PackedStringArray, payloads: Dictionary, rollback: Dictionary
) -> bool:
	return ChunkCommit.apply(city, chunk_ids, payloads, rollback)
