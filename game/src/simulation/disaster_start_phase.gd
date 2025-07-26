class_name DisasterStartPhase
extends RefCounted

const DISASTER_NONE := 0
const DISASTER_TORNADO := 7
const DISASTER_MONSTER := 8
const TYPE_MONSTER := 5
const TYPE_TORNADO := 15
const TEXT_THING_BASE := 201
const SOUND_SIREN := 520


static func start(city: CityState, disaster_type: int, point: Vector2i, random) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if disaster_type == DISASTER_NONE:
		return _result(disaster_type, point, false, true, 0)
	if disaster_type != DISASTER_TORNADO and disaster_type != DISASTER_MONSTER:
		return _result(disaster_type, point, false, false, 0)
	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}
	var thing_chunk := city.document.find_chunk("XTHG")
	var text_chunk := city.document.find_chunk("XTXT")
	if (
		thing_chunk == null
		or thing_chunk.decoded_payload.size() != CityState.THING_COUNT * CityState.THING_RECORD_SIZE
		or text_chunk == null
		or text_chunk.decoded_payload.size() != CityState.TILE_COUNT
	):
		return {"ok": false, "error": "disaster moving-object data is missing or invalid"}
	var things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	if _count_type(things, TYPE_TORNADO if disaster_type == DISASTER_TORNADO else TYPE_MONSTER) > 0:
		return _result(disaster_type, point, false, true, 0)

	var clamped := Vector2i(clampi(point.x, 0, 127), clampi(point.y, 0, 127))
	var index := clamped.x * CityState.MAP_SIZE + clamped.y
	var overlay := int(text[index])
	if overlay > TEXT_THING_BASE - 1 and overlay < TEXT_THING_BASE + CityState.THING_COUNT:
		_remove_thing(things, text, overlay - TEXT_THING_BASE)
	var record := _first_free_record(things)
	if record == 0:
		return _result(disaster_type, clamped, false, false, 0)

	var offset := record * CityState.THING_RECORD_SIZE
	things[offset] = TYPE_TORNADO if disaster_type == DISASTER_TORNADO else TYPE_MONSTER
	things[offset + 1] = random.next_u15() & 7 if disaster_type == DISASTER_TORNADO else 2
	things[offset + 2] = 0
	things[offset + 3] = clamped.x
	things[offset + 4] = clamped.y
	things[offset + 5] = city.land_altitude(clamped.x, clamped.y) if disaster_type == DISASTER_TORNADO else 15
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 8] = random.next_u15() & 0x7f
	things[offset + 9] = random.next_u15() & 0x7f
	things[offset + 10] = text[index]
	if disaster_type == DISASTER_MONSTER:
		things[offset + 11] = 0
		if random.next_u15() & 1 == 0:
			things[offset + 11] = random.next_u15() % 3 + 1
	text[index] = record + TEXT_THING_BASE
	var old_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	if not thing_chunk.set_decoded_payload(things):
		return {"ok": false, "error": "cannot store the disaster moving object"}
	if not text_chunk.set_decoded_payload(text):
		thing_chunk.set_decoded_payload(old_things)
		return {"ok": false, "error": "cannot link the disaster moving object"}
	city.text_overlays = text.duplicate()
	return _result(disaster_type, clamped, true, true, record)


static func has_active_object(city: CityState, disaster_type: int) -> bool:
	if city == null or not city.is_valid():
		return false
	var chunk := city.document.find_chunk("XTHG")
	if chunk == null or chunk.decoded_payload.size() != CityState.THING_COUNT * CityState.THING_RECORD_SIZE:
		return false
	var type := TYPE_TORNADO if disaster_type == DISASTER_TORNADO else TYPE_MONSTER
	return _count_type(chunk.decoded_payload, type) > 0


static func _result(
	disaster_type: int, point: Vector2i, started: bool, complete: bool, record: int
) -> Dictionary:
	return {
		"ok": true,
		"error": "",
		"disaster_type": disaster_type,
		"point": point,
		"started": started,
		"implemented": complete,
		"record": record,
		"sound_events": [SOUND_SIREN] if started else [],
		"view_center_requests": [point] if started else [],
		"complete": complete,
	}


static func _count_type(things: PackedByteArray, thing_type: int) -> int:
	var count := 0
	for record in range(1, CityState.THING_COUNT):
		if things[record * CityState.THING_RECORD_SIZE] == thing_type:
			count += 1
	return count


static func _first_free_record(things: PackedByteArray) -> int:
	for record in range(1, CityState.THING_COUNT):
		if things[record * CityState.THING_RECORD_SIZE] == 0:
			return record
	return 0


static func _remove_thing(things: PackedByteArray, text: PackedByteArray, record: int) -> void:
	if record <= 0 or record >= CityState.THING_COUNT:
		return
	var offset := record * CityState.THING_RECORD_SIZE
	var point := Vector2i(things[offset + 3], things[offset + 4])
	if point.x < 128 and point.y < 128:
		var index := point.x * CityState.MAP_SIZE + point.y
		if text[index] == record + TEXT_THING_BASE:
			text[index] = things[offset + 10]
	for byte_index in CityState.THING_RECORD_SIZE:
		things[offset + byte_index] = 0
