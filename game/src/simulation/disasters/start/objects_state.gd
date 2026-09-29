class_name DisasterStartObjectsState
extends DisasterStartConstants

@warning_ignore_start("integer_division")


static func has_active_object(city: CityState, _disaster_type: int) -> bool:
	if city == null or not city.is_valid():
		return false

	var chunk := city.document.find_chunk("XTHG")

	if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size("XTHG"):
		return false

	var things: PackedByteArray = chunk.decoded_payload

	for record in range(1, ThingData.count(things)):
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var offset := record * CityState.THING_RECORD_SIZE
		var type := int(ThingData.read(things, offset))

		if type == TYPE_MONSTER or type == TYPE_TORNADO or type == TYPE_EXPLOSION:
			return true

		if type == TYPE_AIRPLANE and ThingData.read(things, offset + 2) == 7:
			return true

	return false


static func _result(
	disaster_type: int, point: Vector2i, started: bool, complete: bool, record: int
) -> DisasterStartResult:
	var result := DisasterStartResult.new()
	result.ok = true
	result.disaster_type = disaster_type
	result.point = point
	result.started = started
	result.implemented = complete
	result.record = record
	if started:
		result.sound_events = [SoundEvent.new(SOUND_SIREN)]
		result.view_center_requests.append(point)
	result.complete = complete

	return result


static func _map_payloads(city: CityState) -> Dictionary[String, PackedByteArray]:
	var result: Dictionary[String, PackedByteArray] = {}

	for chunk_id in MAP_CHUNK_SIZES:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size(chunk_id):
			return {}

		result[chunk_id] = chunk.decoded_payload.duplicate()

	return result


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary[String, PackedByteArray]:
	var result: Dictionary[String, PackedByteArray] = {}

	for chunk_id in payloads:
		result[chunk_id] = payloads[chunk_id].duplicate()

	return result


static func _payloads_changed(original: Dictionary, payloads: Dictionary) -> bool:
	for chunk_id in MAP_CHUNK_SIZES:
		if payloads[chunk_id] != original[chunk_id]:
			return true

	return false


static func _apply_map_payloads(
	city: CityState, original: Dictionary, payloads: Dictionary
) -> bool:
	var applied := PackedStringArray()

	for chunk_id in MAP_CHUNK_SIZES:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		if payloads[chunk_id] == original[chunk_id]:
			continue

		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not chunk.set_decoded_payload(payloads[chunk_id]):
			for rollback_id in applied:
				city.document.find_chunk(rollback_id).set_decoded_payload(original[rollback_id])

			city.resync_mirrors(CityState.MIRRORED_CHUNKS)

			return false

		applied.append(chunk_id)

	city.resync_mirrors(CityState.MIRRORED_CHUNKS)

	return true


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.y < 0 or point.x >= map_edge or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y
