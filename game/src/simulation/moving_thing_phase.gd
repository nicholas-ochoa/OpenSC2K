class_name MovingThingPhase
extends RefCounted

const MAP_SIZE := 128
const RECORD_SIZE := 12
const FIRST_RECORD := 1
const LAST_RECORD := 39
const TEXT_LABEL_BASE := 201
const TYPE_SAILBOAT := 9
const TILE_PIER := 0xdf
const TILE_MARINA := 0xf8
const SUBTILE_LIMIT := 16
const SAIL_SUBTILE_X := [0, 16, 0, -16]
const SAIL_SUBTILE_Y := [-16, 0, 16, 0]
const CARDINAL_DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]


static func run(city: CityState, random, lfsr_random) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible random generator is required"}
	if lfsr_random == null or not lfsr_random.has_method("next_mod"):
		return {"ok": false, "error": "a compatible LFSR generator is required"}
	var building_chunk := city.document.find_chunk("XBLD")
	var text_chunk := city.document.find_chunk("XTXT")
	var thing_chunk := city.document.find_chunk("XTHG")
	var flag_chunk := city.document.find_chunk("XBIT")
	if (
		building_chunk == null
		or building_chunk.decoded_payload.size() != CityState.TILE_COUNT
		or text_chunk == null
		or text_chunk.decoded_payload.size() != CityState.TILE_COUNT
		or thing_chunk == null
		or thing_chunk.decoded_payload.size() != CityState.THING_COUNT * RECORD_SIZE
		or flag_chunk == null
		or flag_chunk.decoded_payload.size() != CityState.TILE_COUNT
	):
		return {"ok": false, "error": "moving-thing input chunks are missing or have the wrong size"}

	var buildings: PackedByteArray = building_chunk.decoded_payload
	var flags: PackedByteArray = flag_chunk.decoded_payload
	var original_text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	var original_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var text: PackedByteArray = original_text.duplicate()
	var things: PackedByteArray = original_things.duplicate()
	var counters := {
		"scanned_records": LAST_RECORD,
		"active_sailboats": 0,
		"moved_sailboats": 0,
		"turned_sailboats": 0,
		"distressed_sailboats": 0,
		"removed_sailboats": 0,
		"malformed_records": 0,
		"deferred_news": 0,
	}

	for record in range(FIRST_RECORD, LAST_RECORD + 1):
		var offset := record * RECORD_SIZE
		if things[offset] != TYPE_SAILBOAT:
			continue
		counters.active_sailboats += 1
		_update_sailboat(
			buildings, flags, text, things, record, random, lfsr_random, counters
		)

	if things != original_things and not thing_chunk.set_decoded_payload(things):
		return {"ok": false, "error": "cannot store XTHG after the moving-thing tick"}
	if text != original_text and not text_chunk.set_decoded_payload(text):
		if things != original_things:
			thing_chunk.set_decoded_payload(original_things)
		return {"ok": false, "error": "cannot store XTXT after the moving-thing tick"}
	city.text_overlays = text.duplicate()
	counters["ok"] = true
	counters["sailboats_complete"] = true
	counters["complete"] = false
	counters["error"] = ""
	return counters


static func _update_sailboat(
	buildings: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	var offset := record * RECORD_SIZE
	if counters.active_sailboats > 4:
		_remove_thing(text, things, record)
		counters.removed_sailboats += 1
		return
	var direction := int(things[offset + 1])
	if direction < 0 or direction >= CARDINAL_DIRECTIONS.size():
		_remove_thing(text, things, record)
		counters.removed_sailboats += 1
		counters.malformed_records += 1
		return
	if things[offset + 2] != 0:
		if lfsr_random.next_mod(5) == 0:
			_remove_thing(text, things, record)
			counters.removed_sailboats += 1
		return
	if lfsr_random.next_mod(4) == 0:
		var current := Vector2i(things[offset + 3], things[offset + 4])
		var current_index := _index(current)
		if current_index < 0 or flags[current_index] & 0x04 == 0:
			_remove_thing(text, things, record)
			counters.removed_sailboats += 1
			return
		if lfsr_random.next_mod(4000) == 0:
			things[offset + 2] = 1
			counters.distressed_sailboats += 1
			counters.deferred_news += 1
		things[offset + 1] = (direction + random.next_u15() % 3 - 1) & 3
		counters.turned_sailboats += 1
		return
	var route_state := _sailboat_route_state(buildings, flags, text, things, record, direction)
	if route_state < 0:
		counters.removed_sailboats += 1
	elif route_state > 0:
		_move_sailboat(text, things, record, direction, counters)


static func _sailboat_route_state(
	buildings: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int
) -> int:
	var offset := record * RECORD_SIZE
	var next: Vector2i = (
		Vector2i(things[offset + 3], things[offset + 4]) + CARDINAL_DIRECTIONS[direction]
	)
	var next_index := _index(next)
	if next_index < 0:
		return 1
	if buildings[next_index] == TILE_MARINA:
		_remove_thing(text, things, record)
		return -1
	if buildings[next_index] == TILE_PIER or text[next_index] != 0:
		return 0
	return 1 if flags[next_index] & 0x04 != 0 else 0


static func _move_sailboat(
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int,
	counters: Dictionary
) -> void:
	var offset := record * RECORD_SIZE
	var subtile_x: int = int(things[offset + 6]) + SAIL_SUBTILE_X[direction]
	var subtile_y: int = int(things[offset + 7]) + SAIL_SUBTILE_Y[direction]
	var tile_delta := Vector2i.ZERO
	if subtile_x > SUBTILE_LIMIT:
		subtile_x -= SUBTILE_LIMIT
		tile_delta.x = 1
	elif subtile_x < 0:
		subtile_x += SUBTILE_LIMIT
		tile_delta.x = -1
	if subtile_y > SUBTILE_LIMIT:
		subtile_y -= SUBTILE_LIMIT
		tile_delta.y = 1
	elif subtile_y < 0:
		subtile_y += SUBTILE_LIMIT
		tile_delta.y = -1
	things[offset + 6] = subtile_x
	things[offset + 7] = subtile_y
	if tile_delta != Vector2i.ZERO:
		var old_point := Vector2i(things[offset + 3], things[offset + 4])
		var old_index := _index(old_point)
		if old_index >= 0:
			text[old_index] = 0
		var next := old_point + tile_delta
		if next.x < 0 or next.x > 126 or next.y < 0 or next.y > 126:
			_remove_thing(text, things, record)
			counters.removed_sailboats += 1
			return
		things[offset + 3] = next.x
		things[offset + 4] = next.y
		text[_index(next)] = record + TEXT_LABEL_BASE
	counters.moved_sailboats += 1


static func _remove_thing(
	text: PackedByteArray, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	things[offset] = 0
	var point := Vector2i(things[offset + 3], things[offset + 4])
	var index := _index(point)
	if index >= 0:
		text[index] = 0


static func _index(point: Vector2i) -> int:
	if point.x < 0 or point.x >= MAP_SIZE or point.y < 0 or point.y >= MAP_SIZE:
		return -1
	return point.x * MAP_SIZE + point.y
