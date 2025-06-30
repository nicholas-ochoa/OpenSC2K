class_name MovingThingPhase
extends RefCounted

const MAP_SIZE := 128
const RECORD_SIZE := 12
const FIRST_RECORD := 1
const LAST_RECORD := 39
const TEXT_LABEL_BASE := 201
const TYPE_SAILBOAT := 9
const TYPE_TRAIN_ENGINE := 10
const TYPE_TRAIN_CAR := 11
const TYPE_SUBWAY_ENGINE := 12
const TYPE_SUBWAY_CAR := 13
const TILE_PIER := 0xdf
const TILE_MARINA := 0xf8
const TILE_RAIL_STATION := 0xed
const SUBTILE_LIMIT := 16
const SAIL_SUBTILE_X := [0, 16, 0, -16]
const SAIL_SUBTILE_Y := [-16, 0, 16, 0]
const CARDINAL_DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]
const TRAIN_DIRECTION_ORDERS := [
	[0, 3, 1, 2],
	[0, 1, 3, 2],
]
const TRAIN_TRANSITIONS := [
	0, 1, 2, 7,
	1, 2, 3, 4,
	2, 3, 4, 5,
	7, 4, 5, 6,
]


static func run(city: CityState, random, lfsr_random, game_random = null) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible random generator is required"}
	if (
		lfsr_random == null
		or not lfsr_random.has_method("next_mod")
		or not lfsr_random.has_method("next_mask")
	):
		return {"ok": false, "error": "a compatible LFSR generator is required"}
	if game_random == null:
		game_random = GameLcgRandom.new(1)
	if not game_random.has_method("next_mod"):
		return {"ok": false, "error": "a compatible game random generator is required"}
	var building_chunk := city.document.find_chunk("XBLD")
	var underground_chunk := city.document.find_chunk("XUND")
	var text_chunk := city.document.find_chunk("XTXT")
	var thing_chunk := city.document.find_chunk("XTHG")
	var flag_chunk := city.document.find_chunk("XBIT")
	if (
		building_chunk == null
		or building_chunk.decoded_payload.size() != CityState.TILE_COUNT
		or underground_chunk == null
		or underground_chunk.decoded_payload.size() != CityState.TILE_COUNT
		or text_chunk == null
		or text_chunk.decoded_payload.size() != CityState.TILE_COUNT
		or thing_chunk == null
		or thing_chunk.decoded_payload.size() != CityState.THING_COUNT * RECORD_SIZE
		or flag_chunk == null
		or flag_chunk.decoded_payload.size() != CityState.TILE_COUNT
	):
		return {"ok": false, "error": "moving-thing input chunks are missing or have the wrong size"}

	var buildings: PackedByteArray = building_chunk.decoded_payload
	var underground: PackedByteArray = underground_chunk.decoded_payload
	var flags: PackedByteArray = flag_chunk.decoded_payload
	var original_text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	var original_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var text: PackedByteArray = original_text.duplicate()
	var things: PackedByteArray = original_things.duplicate()
	var counters := {
		"scanned_records": LAST_RECORD,
		"active_sailboats": 0,
		"active_trains": 0,
		"moved_sailboats": 0,
		"moved_trains": 0,
		"turned_sailboats": 0,
		"turned_trains": 0,
		"paused_trains": 0,
		"reversed_trains": 0,
		"distressed_sailboats": 0,
		"removed_sailboats": 0,
		"removed_trains": 0,
		"malformed_records": 0,
		"deferred_news": 0,
		"deferred_train_crashes": 0,
	}

	for record in range(FIRST_RECORD, LAST_RECORD + 1):
		var offset := record * RECORD_SIZE
		match int(things[offset]):
			TYPE_SAILBOAT:
				counters.active_sailboats += 1
				_update_sailboat(
					buildings, flags, text, things, record, random, lfsr_random, counters
				)
			TYPE_TRAIN_ENGINE, TYPE_SUBWAY_ENGINE:
				counters.active_trains += 1
				_update_train(
					buildings, underground, text, things, record,
					random, lfsr_random, game_random, counters
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
	counters["train_routes_complete"] = true
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


static func _update_train(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	random,
	lfsr_random,
	game_random,
	counters: Dictionary
) -> void:
	var offset := record * RECORD_SIZE
	var engine_type := int(things[offset])
	var first_car := int(things[offset + 2])
	if first_car < 0 or first_car > LAST_RECORD:
		_remove_thing(text, things, record)
		counters.removed_trains += 1
		counters.malformed_records += 1
		return
	var first_car_offset := first_car * RECORD_SIZE
	var second_car := int(things[first_car_offset + 2])
	if second_car < 0 or second_car > LAST_RECORD:
		_remove_thing(text, things, record)
		_remove_thing(text, things, first_car)
		counters.removed_trains += 1
		counters.malformed_records += 1
		return
	var second_car_offset := second_car * RECORD_SIZE
	var current := Vector2i(things[offset + 3], things[offset + 4])
	var direction := int(things[offset + 1]) & 0x0f
	if direction >= CARDINAL_DIRECTIONS.size():
		_remove_train(text, things, record, first_car, second_car)
		counters.removed_trains += 1
		counters.malformed_records += 1
		return
	if engine_type == TYPE_TRAIN_ENGINE and lfsr_random.next_mask(1) != 0:
		var station_offset := Vector2i.ZERO
		if direction & 1 == 0:
			station_offset.x = -1 if game_random.next_mod(2) == 0 else 1
		else:
			station_offset.y = -1 if game_random.next_mod(2) == 0 else 1
		var station_index := _index(current + station_offset)
		if station_index >= 0 and buildings[station_index] == TILE_RAIL_STATION:
			counters.paused_trains += 1
			return
	if not _train_current_route(buildings, underground, current):
		_remove_train(text, things, record, first_car, second_car)
		counters.active_trains -= 1
		counters.removed_trains += 1
		counters.deferred_train_crashes += 1
		return
	var destination := Vector2i(things[offset + 6], things[offset + 7])
	var destination_index := _index(destination)
	if destination_index < 0:
		_remove_train(text, things, record, first_car, second_car)
		counters.removed_trains += 1
		counters.malformed_records += 1
		return
	var destination_overlay := int(text[destination_index])
	if destination_overlay >= TEXT_LABEL_BASE and destination_overlay != second_car + TEXT_LABEL_BASE:
		return
	if not _train_record_points_are_valid(things, [record, first_car, second_car]):
		_remove_train(text, things, record, first_car, second_car)
		counters.removed_trains += 1
		counters.malformed_records += 1
		return
	if current != destination:
		text[_record_index(things, record)] = first_car + TEXT_LABEL_BASE
		text[_record_index(things, first_car)] = second_car + TEXT_LABEL_BASE
		text[_record_index(things, second_car)] = things[second_car_offset + 10]
		_copy_train_record(things, first_car, second_car)
		_copy_train_record(things, record, first_car)
		things[offset + 10] = text[destination_index]
		text[destination_index] = record + TEXT_LABEL_BASE
		counters.moved_trains += 1
	things[offset + 3] = destination.x
	things[offset + 4] = destination.y
	current = destination
	var current_index := _index(current)
	if buildings[current_index] >= 0x6c and buildings[current_index] <= 0x70:
		things[offset] = TYPE_SUBWAY_ENGINE if engine_type == TYPE_TRAIN_ENGINE else TYPE_TRAIN_ENGINE
		engine_type = int(things[offset])
	direction = int(things[offset + 1]) & 0x0f
	if lfsr_random.next_mod(4) == 0:
		var turn_direction := (
			(direction - 1) & 3 if lfsr_random.next_mod(2) == 0 else (direction + 1) & 3
		)
		if _train_route_valid(
			buildings, underground, text, current + CARDINAL_DIRECTIONS[turn_direction],
			engine_type
		):
			direction = turn_direction
			counters.turned_trains += 1
		if random.next_u15() & 0xff == 0:
			counters.deferred_news += 1
	var next: Vector2i = current + CARDINAL_DIRECTIONS[direction]
	if not _train_route_valid(buildings, underground, text, next, engine_type):
		var selected := _select_train_direction(
			buildings, underground, text, current, direction, engine_type, game_random
		)
		if selected < 0:
			_reverse_train(things, record, second_car)
			counters.reversed_trains += 1
			return
		things[offset + 1] = selected
		things[offset + 8] = TRAIN_TRANSITIONS[direction * 4 + selected]
		next = current + CARDINAL_DIRECTIONS[selected]
	else:
		things[offset + 1] = int(things[offset + 1]) & 0x0f
		things[offset + 8] = direction * 2
	things[offset + 6] = next.x
	things[offset + 7] = next.y


static func _train_current_route(
	buildings: PackedByteArray, underground: PackedByteArray, point: Vector2i
) -> bool:
	var index := _index(point)
	if index < 0:
		return false
	var surface := int(buildings[index])
	if _surface_train_route(surface) or (surface >= 0x6c and surface <= 0x70):
		return true
	return _underground_train_route(underground[index])


static func _train_route_valid(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	text: PackedByteArray,
	point: Vector2i,
	engine_type: int
) -> bool:
	var index := _index(point)
	if index < 0 or text[index] >= TEXT_LABEL_BASE:
		return false
	if engine_type == TYPE_TRAIN_ENGINE:
		return _surface_train_route(buildings[index])
	return (
		_underground_train_route(underground[index])
		or (buildings[index] >= 0x6c and buildings[index] <= 0x70)
	)


static func _surface_train_route(tile_value: int) -> bool:
	var tile := int(tile_value)
	return (
		(tile >= 0x2c and tile <= 0x3e)
		or (tile >= 0x45 and tile <= 0x48)
		or (tile >= 0x6c and tile <= 0x6f)
		or tile == 0x4d
		or tile == 0x4e
		or tile == 0x5a
		or tile == 0x5b
	)


static func _underground_train_route(tile_value: int) -> bool:
	var tile := int(tile_value)
	return (
		(tile > 0 and tile < 0x10)
		or tile == 0x1f
		or tile == 0x20
		or tile == 0x22
		or tile == 0x23
	)


static func _select_train_direction(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	text: PackedByteArray,
	point: Vector2i,
	initial_direction: int,
	engine_type: int,
	game_random
) -> int:
	var order_index: int = game_random.next_mod(2)
	for direction_offset in TRAIN_DIRECTION_ORDERS[order_index]:
		var direction := (initial_direction + int(direction_offset)) & 3
		if _train_route_valid(
			buildings, underground, text, point + CARDINAL_DIRECTIONS[direction], engine_type
		):
			return direction
	return -1


static func _copy_train_record(
	things: PackedByteArray, source_record: int, destination_record: int
) -> void:
	var source := source_record * RECORD_SIZE
	var destination := destination_record * RECORD_SIZE
	for field in [3, 4, 6, 7, 10, 1, 8, 0]:
		things[destination + field] = things[source + field]
	if things[destination] == TYPE_TRAIN_ENGINE:
		things[destination] = TYPE_TRAIN_CAR
	elif things[destination] == TYPE_SUBWAY_ENGINE:
		things[destination] = TYPE_SUBWAY_CAR


static func _reverse_train(
	things: PackedByteArray, engine_record: int, second_car_record: int
) -> void:
	var engine := engine_record * RECORD_SIZE
	var second_car := second_car_record * RECORD_SIZE
	var tail_x := things[second_car + 3]
	var tail_y := things[second_car + 4]
	var tail_label := things[second_car + 10]
	var reverse_direction := (int(things[second_car + 1]) + 2) & 3
	for field in [3, 4, 6, 7, 10]:
		things[second_car + field] = things[engine + field]
	things[engine + 3] = tail_x
	things[engine + 4] = tail_y
	things[engine + 6] = tail_x
	things[engine + 7] = tail_y
	things[engine + 10] = tail_label
	things[engine + 8] = reverse_direction + 4
	things[engine + 1] = reverse_direction


static func _train_record_points_are_valid(
	things: PackedByteArray, records: Array
) -> bool:
	for record_value in records:
		var record := int(record_value)
		if _record_index(things, record) < 0:
			return false
	return true


static func _record_index(things: PackedByteArray, record: int) -> int:
	var offset := record * RECORD_SIZE
	return _index(Vector2i(things[offset + 3], things[offset + 4]))


static func _remove_train(
	text: PackedByteArray,
	things: PackedByteArray,
	engine_record: int,
	first_car_record: int,
	second_car_record: int
) -> void:
	_remove_thing(text, things, engine_record)
	_remove_thing(text, things, first_car_record)
	_remove_thing(text, things, second_car_record)


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
