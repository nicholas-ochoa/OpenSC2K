class_name DisasterStartPhase
extends RefCounted

const DisasterMapDamage = preload("res://src/simulation/disaster_damage.gd")
const DISASTER_NONE := 0
const DISASTER_FIRE := 1
const DISASTER_FLOOD := 2
const DISASTER_TOXIC_SPILL := 4
const DISASTER_TORNADO := 7
const DISASTER_MONSTER := 8
const TYPE_MONSTER := 5
const TYPE_TORNADO := 15
const TEXT_THING_BASE := 201
const SOUND_SIREN := 520
const SOUND_FLOOD := 511
const MISC_CITY_CENTER_X := 0x1018
const MISC_CITY_CENTER_Y := 0x101c
const FIRE_SPIRAL_X := [0, 1, 0, -1]
const FIRE_SPIRAL_Y := [-1, 0, 1, 0]
const MAP_CHUNK_SIZES := {
	"ALTM": CityState.TILE_COUNT * 2,
	"XBLD": CityState.TILE_COUNT,
	"XTER": CityState.TILE_COUNT,
	"XZON": CityState.TILE_COUNT,
	"XUND": CityState.TILE_COUNT,
	"XBIT": CityState.TILE_COUNT,
	"XTRF": 64 * 64,
	"XTXT": CityState.TILE_COUNT,
	"XLAB": CityState.LABEL_COUNT * CityState.LABEL_RECORD_SIZE,
	"XMIC": CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE,
	"MISC": 4800,
}


static func start(
	city: CityState, disaster_type: int, point: Vector2i, random, lfsr_random = null
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if disaster_type == DISASTER_NONE:
		return _result(disaster_type, point, false, true, 0)
	if disaster_type == DISASTER_FIRE:
		return _start_fire(city, random, lfsr_random)
	if disaster_type == DISASTER_FLOOD:
		return _start_flood(city, point, lfsr_random)
	if disaster_type == DISASTER_TOXIC_SPILL:
		return _start_toxic_spill(city, point)
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


static func _start_fire(city: CityState, random, lfsr_random) -> Dictionary:
	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}
	if (
		lfsr_random == null
		or not lfsr_random.has_method("next_mask")
		or not lfsr_random.has_method("next_mod")
	):
		return {"ok": false, "error": "a compatible LFSR generator is required"}
	var original := _map_payloads(city)
	if original.is_empty():
		return {"ok": false, "error": "fire disaster input chunks are missing or invalid"}
	var payloads := _duplicate_payloads(original)
	var point := Vector2i(
		_read_u32_be(payloads.MISC, MISC_CITY_CENTER_X) - 20 + random.next_u15() % 40,
		_read_u32_be(payloads.MISC, MISC_CITY_CENTER_Y) - 20 + random.next_u15() % 40
	)
	var direction := 0
	var run_length := 1
	var step := 0
	while run_length < 64:
		point.x += FIRE_SPIRAL_X[direction]
		point.y += FIRE_SPIRAL_Y[direction]
		var index := _index(point)
		if (
			index >= 0
			and payloads.XBLD[index] > 0x6f
			and _starts_fire(_apply_fire_damage(city, payloads, point, random, lfsr_random))
		):
			return _store_fire(city, original, payloads, point)
		step += 1
		if step >= run_length:
			step = 0
			if direction & 1 != 0:
				run_length += 1
			direction = (direction + 1) & 3
	for _attempt in 200:
		point = Vector2i(lfsr_random.next_mask(0x7f), lfsr_random.next_mask(0x7f))
		if _starts_fire(_apply_fire_damage(city, payloads, point, random, lfsr_random)):
			return _store_fire(city, original, payloads, point)
	var result := _result(DISASTER_FIRE, point, false, true, 0)
	result["notice_ids"] = [0xf5]
	return result


static func _start_flood(city: CityState, requested_point: Vector2i, lfsr_random) -> Dictionary:
	if lfsr_random == null or not lfsr_random.has_method("next_mask"):
		return {"ok": false, "error": "a compatible LFSR generator is required"}
	var original := _map_payloads(city)
	if original.is_empty():
		return {"ok": false, "error": "flood disaster input chunks are missing or invalid"}
	var payloads := _duplicate_payloads(original)
	for radius in CityState.MAP_SIZE:
		for x_offset in range(-radius, radius + 1):
			for y_offset in range(-radius, radius + 1):
				var point := requested_point + Vector2i(x_offset, y_offset)
				var index := _index(point)
				if index < 0 or payloads.XTER[index] < 0x20 or payloads.XTER[index] >= 0x30:
					continue
				if x_offset > 0:
					_seed_flood_if_dry(payloads, point + Vector2i(-1, 0))
				if y_offset > 0:
					_seed_flood_if_dry(payloads, point + Vector2i(0, -1))
				if x_offset < 127:
					_seed_flood_if_dry(payloads, point + Vector2i(1, 0))
				if y_offset < 127:
					_seed_flood_if_dry(payloads, point + Vector2i(0, 1))
				return _store_flood(city, original, payloads, point)
	for _attempt in 200:
		var point := Vector2i(lfsr_random.next_mask(0x7f), lfsr_random.next_mask(0x7f))
		if payloads.XTER[_index(point)] == 0:
			payloads.XTXT[_index(point)] = 0xfc
			return _store_flood(city, original, payloads, point)
	return _flood_result(requested_point, false)


static func _start_toxic_spill(city: CityState, point: Vector2i) -> Dictionary:
	var index := _index(point)
	if index < 0:
		return _result(DISASTER_TOXIC_SPILL, point, false, true, 0)
	var text_chunk := city.document.find_chunk("XTXT")
	if text_chunk == null or text_chunk.decoded_payload.size() != CityState.TILE_COUNT:
		return {"ok": false, "error": "toxic-spill map data is missing or invalid"}
	var text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	text[index] = 0xfb
	if not text_chunk.set_decoded_payload(text):
		return {"ok": false, "error": "cannot store the toxic spill"}
	city.text_overlays = text.duplicate()
	return _result(DISASTER_TOXIC_SPILL, point, true, true, 0)


static func _seed_flood_if_dry(payloads: Dictionary, point: Vector2i) -> void:
	var index := _index(point)
	if index >= 0 and payloads.XBIT[index] & 0x04 == 0:
		payloads.XTXT[index] = 0xfc


static func _store_flood(
	city: CityState, original: Dictionary, payloads: Dictionary, point: Vector2i
) -> Dictionary:
	if not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the flood disaster"}
	return _flood_result(point, true)


static func _flood_result(point: Vector2i, started: bool) -> Dictionary:
	var result := _result(DISASTER_FLOOD, point, started, true, 0)
	result["sound_events"] = [SOUND_FLOOD, SOUND_SIREN] if started else []
	result["map_counter"] = 60 if started else 0
	return result


static func _apply_fire_damage(
	city: CityState, payloads: Dictionary, point: Vector2i, random, lfsr_random
) -> int:
	return DisasterMapDamage.apply(
		city,
		payloads.ALTM,
		payloads.XBLD,
		payloads.XTER,
		payloads.XZON,
		payloads.XUND,
		payloads.XBIT,
		payloads.XTRF,
		payloads.XTXT,
		payloads.XLAB,
		payloads.XMIC,
		payloads.MISC,
		point,
		random,
		lfsr_random
	)


static func _starts_fire(result_code: int) -> bool:
	return result_code == 1 or result_code == 3 or result_code == 4


static func _store_fire(
	city: CityState, original: Dictionary, payloads: Dictionary, point: Vector2i
) -> Dictionary:
	if not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the fire disaster"}
	return _result(DISASTER_FIRE, point, true, true, 0)


static func has_active_object(city: CityState, disaster_type: int) -> bool:
	if city == null or not city.is_valid():
		return false
	if disaster_type != DISASTER_TORNADO and disaster_type != DISASTER_MONSTER:
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
		"news_items": [],
		"notice_ids": [],
		"map_counter": 0,
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


static func _map_payloads(city: CityState) -> Dictionary:
	var result := {}
	for chunk_id in MAP_CHUNK_SIZES:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or chunk.decoded_payload.size() != MAP_CHUNK_SIZES[chunk_id]:
			return {}
		result[chunk_id] = chunk.decoded_payload.duplicate()
	return result


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary:
	var result := {}
	for chunk_id in payloads:
		result[chunk_id] = payloads[chunk_id].duplicate()
	return result


static func _apply_map_payloads(
	city: CityState, original: Dictionary, payloads: Dictionary
) -> bool:
	var applied := PackedStringArray()
	for chunk_id in MAP_CHUNK_SIZES:
		if payloads[chunk_id] == original[chunk_id]:
			continue
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or not chunk.set_decoded_payload(payloads[chunk_id]):
			for rollback_id in applied:
				city.document.find_chunk(rollback_id).set_decoded_payload(original[rollback_id])
			_refresh_city_arrays(city)
			return false
		applied.append(chunk_id)
	_refresh_city_arrays(city)
	return true


static func _refresh_city_arrays(city: CityState) -> void:
	city.buildings = city.document.find_chunk("XBLD").decoded_payload.duplicate()
	city.terrain = city.document.find_chunk("XTER").decoded_payload.duplicate()
	city.zones = city.document.find_chunk("XZON").decoded_payload.duplicate()
	city.underground = city.document.find_chunk("XUND").decoded_payload.duplicate()
	city.tile_flags = city.document.find_chunk("XBIT").decoded_payload.duplicate()
	city.text_overlays = city.document.find_chunk("XTXT").decoded_payload.duplicate()
	var altitude: PackedByteArray = city.document.find_chunk("ALTM").decoded_payload
	for index in CityState.TILE_COUNT:
		city.altitude_words[index] = (altitude[index * 2] << 8) | altitude[index * 2 + 1]


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _index(point: Vector2i) -> int:
	if point.x < 0 or point.y < 0 or point.x >= CityState.MAP_SIZE or point.y >= CityState.MAP_SIZE:
		return -1
	return point.x * CityState.MAP_SIZE + point.y
