class_name DisasterStartObjectsState
extends DisasterStartConstants

@warning_ignore_start("integer_division")


static func _start_crash_wrapper(disaster_type: int, point: Vector2i) -> DisasterStartResult:
	var result := _result(disaster_type, point, true, true, 0)
	result.view_center_requests = []

	return result


static func _start_plane_crash(city: CityState, lfsr_random: SimLfsrRandom) -> DisasterStartResult:
	var map_edge: int = city.map_size if city != null else 128

	if lfsr_random == null:
		return DisasterStartResult.failed("a compatible LFSR generator is required")

	var thing_chunk := city.document.find_chunk("XTHG")
	var text_chunk := city.document.find_chunk("XTXT")

	if (
		thing_chunk == null
		or thing_chunk.decoded_payload.size()
		!= city.document.decoded_size("XTHG")
		or text_chunk == null
		or text_chunk.decoded_payload.size() != city.document.decoded_size("XTXT")
	):
		return DisasterStartResult.failed("plane-crash moving-object data is missing or invalid")

	var things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	var point := Vector2i.ZERO

	while true:
		point = Vector2i(
			lfsr_random.next_mask(0xffff) % (map_edge / 2) + (map_edge / 4),
			lfsr_random.next_mask(0xffff) % (map_edge / 2) + (map_edge / 4)
		)

		if OverlayData.read(text, _index(point, map_edge)) == 0:
			break

	var record := _first_free_record(things)

	if record == 0:
		return _result(DISASTER_PLANE_CRASH, point, false, true, 0)

	var offset := record * CityState.THING_RECORD_SIZE
	ThingData.write(things, offset, TYPE_AIRPLANE)
	ThingData.write(things, offset + 2, 7)
	ThingData.write(things, offset + 3, point.x)
	ThingData.write(things, offset + 4, point.y)
	ThingData.write(things, offset + 5, 16)
	ThingData.write(things, offset + 6, 8)
	ThingData.write(things, offset + 7, 8)
	ThingData.write(things, offset + 10, 0)
	OverlayData.write(text, _index(point, map_edge), OverlayData.thing_id(record))
	var old_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()

	if not thing_chunk.set_decoded_payload(things):
		return DisasterStartResult.failed("cannot store the crashing plane")

	if not text_chunk.set_decoded_payload(text):
		thing_chunk.set_decoded_payload(old_things)

		return DisasterStartResult.failed("cannot link the crashing plane")

	city.resync_mirrors(["XTXT"])

	return _result(DISASTER_PLANE_CRASH, point, true, true, record)


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


static func _count_type(things: PackedByteArray, thing_type: int) -> int:
	var count := 0

	for record in range(1, ThingData.count(things)):
		if ThingData.read(things, record * CityState.THING_RECORD_SIZE) == thing_type:
			count += 1

	return count


static func _first_free_record(things: PackedByteArray) -> int:
	for record in range(1, ThingData.count(things)):
		if ThingData.read(things, record * CityState.THING_RECORD_SIZE) == 0:
			return record

	return 0


static func _remove_thing(things: PackedByteArray, text: PackedByteArray, record: int, map_edge: int = 128) -> void:
	if record <= 0 or record >= ThingData.count(things):
		return

	var offset := record * CityState.THING_RECORD_SIZE
	var point := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))

	if point.x < map_edge and point.y < map_edge:
		var index := point.x * map_edge + point.y

		if OverlayData.read(text, index) == OverlayData.thing_id(record):
			OverlayData.write(text, index, ThingData.read(things, offset + 10))

	for byte_index in CityState.THING_RECORD_SIZE:
		ThingData.write(things, offset + byte_index, 0)


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


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.y < 0 or point.x >= map_edge or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y
