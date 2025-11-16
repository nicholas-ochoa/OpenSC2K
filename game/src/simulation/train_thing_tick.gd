class_name TrainThingTick
extends RefCounted

const RECORD_SIZE := CityState.THING_RECORD_SIZE
const FIRST_RECORD := 1
const LAST_RECORD := CityState.THING_COUNT - 1
const TEXT_LABEL_BASE := 201
const TYPE_EXPLOSION := 6
const TYPE_TRAIN_ENGINE := 10
const TYPE_TRAIN_CAR := 11
const TYPE_SUBWAY_ENGINE := 12
const TYPE_SUBWAY_CAR := 13
const TILE_RAIL_STATION := 0xed
const SOUND_TRAIN := 0x20c
const CARDINAL_DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]
const DIRECTION_ORDERS := [
	[0, 3, 1, 2],
	[0, 1, 3, 2],
]
const TRANSITIONS := [
	0, 1, 2, 7,
	1, 2, 3, 4,
	2, 3, 4, 5,
	7, 4, 5, 6,
]


static func update(
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
	if not _current_route_is_valid(buildings, underground, current):
		_remove_train(text, things, record, first_car, second_car)
		counters.active_trains -= 1
		counters.removed_trains += 1
		if _spawn_explosion(text, things, current):
			counters.created_train_crash_explosions += 1
		return
	var destination := Vector2i(things[offset + 6], things[offset + 7])
	var destination_index := _index(destination)
	if destination_index < 0:
		_remove_train(text, things, record, first_car, second_car)
		counters.removed_trains += 1
		counters.malformed_records += 1
		return
	var destination_overlay := int(text[destination_index])
	if (
		destination_overlay >= TEXT_LABEL_BASE
		and destination_overlay != second_car + TEXT_LABEL_BASE
	):
		return
	if not _record_points_are_valid(things, [record, first_car, second_car]):
		_remove_train(text, things, record, first_car, second_car)
		counters.removed_trains += 1
		counters.malformed_records += 1
		return
	if current != destination:
		text[_record_index(things, record)] = first_car + TEXT_LABEL_BASE
		text[_record_index(things, first_car)] = second_car + TEXT_LABEL_BASE
		text[_record_index(things, second_car)] = things[second_car_offset + 10]
		_copy_record(things, first_car, second_car)
		_copy_record(things, record, first_car)
		things[offset + 10] = text[destination_index]
		text[destination_index] = record + TEXT_LABEL_BASE
		counters.moved_trains += 1
	things[offset + 3] = destination.x
	things[offset + 4] = destination.y
	current = destination
	var current_index := _index(current)
	if buildings[current_index] >= 0x6c and buildings[current_index] <= 0x70:
		things[offset] = (
			TYPE_SUBWAY_ENGINE if engine_type == TYPE_TRAIN_ENGINE else TYPE_TRAIN_ENGINE
		)
		engine_type = int(things[offset])
	direction = int(things[offset + 1]) & 0x0f
	if lfsr_random.next_mod(4) == 0:
		var turn_direction := (
			(direction - 1) & 3
			if lfsr_random.next_mod(2) == 0
			else (direction + 1) & 3
		)
		if _route_is_valid(
			buildings,
			underground,
			text,
			current + CARDINAL_DIRECTIONS[turn_direction],
			engine_type
		):
			direction = turn_direction
			counters.turned_trains += 1
		if random.next_u15() & 0xff == 0:
			_queue_sound(counters, things, record)
	var next: Vector2i = current + CARDINAL_DIRECTIONS[direction]
	if not _route_is_valid(buildings, underground, text, next, engine_type):
		var selected := _select_direction(
			buildings,
			underground,
			text,
			current,
			direction,
			engine_type,
			game_random
		)
		if selected < 0:
			_reverse(things, record, second_car)
			counters.reversed_trains += 1
			return
		things[offset + 1] = selected
		things[offset + 8] = TRANSITIONS[direction * 4 + selected]
		next = current + CARDINAL_DIRECTIONS[selected]
	else:
		things[offset + 1] = int(things[offset + 1]) & 0x0f
		things[offset + 8] = direction * 2
	things[offset + 6] = next.x
	things[offset + 7] = next.y


static func _current_route_is_valid(
	buildings: PackedByteArray, underground: PackedByteArray, point: Vector2i
) -> bool:
	var index := _index(point)
	if index < 0:
		return false
	var surface := int(buildings[index])
	if _is_surface_route(surface) or (surface >= 0x6c and surface <= 0x70):
		return true
	return _is_underground_route(underground[index])


static func _route_is_valid(
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
		return _is_surface_route(buildings[index])
	return (
		_is_underground_route(underground[index])
		or (buildings[index] >= 0x6c and buildings[index] <= 0x70)
	)


static func _is_surface_route(tile_value: int) -> bool:
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


static func _is_underground_route(tile_value: int) -> bool:
	var tile := int(tile_value)
	return (
		(tile > 0 and tile < 0x10)
		or tile == 0x1f
		or tile == 0x20
		or tile == 0x22
		or tile == 0x23
	)


static func _select_direction(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	text: PackedByteArray,
	point: Vector2i,
	initial_direction: int,
	engine_type: int,
	game_random
) -> int:
	var order_index: int = game_random.next_mod(2)
	for direction_offset in DIRECTION_ORDERS[order_index]:
		var direction := (initial_direction + int(direction_offset)) & 3
		if _route_is_valid(
			buildings,
			underground,
			text,
			point + CARDINAL_DIRECTIONS[direction],
			engine_type
		):
			return direction
	return -1


static func _copy_record(
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


static func _reverse(
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


static func _record_points_are_valid(
	things: PackedByteArray, records: Array
) -> bool:
	for record_value in records:
		if _record_index(things, int(record_value)) < 0:
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


static func _spawn_explosion(
	text: PackedByteArray, things: PackedByteArray, point: Vector2i
) -> bool:
	var index := _index(point)
	if index < 0 or text[index] >= TEXT_LABEL_BASE:
		return false
	var record := 0
	for checked_record in range(FIRST_RECORD, LAST_RECORD + 1):
		if things[checked_record * RECORD_SIZE] == 0:
			record = checked_record
			break
	if record == 0:
		return false
	var offset := record * RECORD_SIZE
	things[offset] = TYPE_EXPLOSION
	things[offset + 1] = 0
	things[offset + 2] = 0
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = 0
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 10] = text[index]
	things[offset + 11] = 0
	text[index] = record + TEXT_LABEL_BASE
	return true


static func _remove_thing(
	text: PackedByteArray, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	things[offset] = 0
	var point := Vector2i(things[offset + 3], things[offset + 4])
	var index := _index(point)
	if index >= 0:
		text[index] = 0


static func _queue_sound(
	counters: Dictionary, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	counters.sound_events.append({
		"sound_id": SOUND_TRAIN,
		"thing_type": int(things[offset]),
		"record": record,
		"point": Vector2i(things[offset + 3], things[offset + 4]),
	})


static func _index(point: Vector2i) -> int:
	if (
		point.x < 0
		or point.x >= CityState.MAP_SIZE
		or point.y < 0
		or point.y >= CityState.MAP_SIZE
	):
		return -1
	return point.x * CityState.MAP_SIZE + point.y
