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
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	game_random: GameLcgRandom,
	counters: MovingThingResult,
	map_edge: int = 128,
) -> void:
	var offset := record * RECORD_SIZE
	var engine_type := int(ThingData.read(things, offset))
	var first_car := int(ThingData.read(things, offset + 2))

	if first_car < 0 or first_car >= ThingData.count(things):
		_remove_thing(text, things, record, map_edge)
		counters.removed_trains += 1
		counters.malformed_records += 1

		return

	var first_car_offset := first_car * RECORD_SIZE
	var second_car := int(ThingData.read(things, first_car_offset + 2))

	if second_car < 0 or second_car >= ThingData.count(things):
		_remove_thing(text, things, record, map_edge)
		_remove_thing(text, things, first_car, map_edge)
		counters.removed_trains += 1
		counters.malformed_records += 1

		return

	var second_car_offset := second_car * RECORD_SIZE
	var current := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var direction := int(ThingData.read(things, offset + 1)) & 0x0f

	if direction >= CARDINAL_DIRECTIONS.size():
		_remove_train(text, things, record, first_car, second_car, map_edge)
		counters.removed_trains += 1
		counters.malformed_records += 1

		return

	if engine_type == TYPE_TRAIN_ENGINE and lfsr_random.next_mask(1) != 0:
		var station_offset := Vector2i.ZERO

		if direction & 1 == 0:
			station_offset.x = -1 if game_random.next_mod(2) == 0 else 1
		else:
			station_offset.y = -1 if game_random.next_mod(2) == 0 else 1

		var station_index := _index(current + station_offset, map_edge)

		if station_index >= 0 and buildings[station_index] == TILE_RAIL_STATION:
			counters.paused_trains += 1

			return

	if not _current_route_is_valid(buildings, underground, current, map_edge):
		_remove_train(text, things, record, first_car, second_car, map_edge)
		counters.active_trains -= 1
		counters.removed_trains += 1

		if _spawn_explosion(text, things, current, map_edge):
			counters.created_train_crash_explosions += 1

		return

	var destination := Vector2i(ThingData.read(things, offset + 6), ThingData.read(things, offset + 7))
	var destination_index := _index(destination, map_edge)

	if destination_index < 0:
		_remove_train(text, things, record, first_car, second_car, map_edge)
		counters.removed_trains += 1
		counters.malformed_records += 1

		return

	var destination_overlay := int(OverlayData.read(text, destination_index))

	if (
		OverlayData.blocks_thing(destination_overlay)
		and destination_overlay != OverlayData.thing_id(second_car)
	):
		return

	if not _record_points_are_valid(things, [record, first_car, second_car], map_edge):
		_remove_train(text, things, record, first_car, second_car, map_edge)
		counters.removed_trains += 1
		counters.malformed_records += 1

		return

	if current != destination:
		OverlayData.write(text, _record_index(things, record, map_edge), OverlayData.thing_id(first_car))
		OverlayData.write(text, _record_index(things, first_car, map_edge), OverlayData.thing_id(second_car))
		OverlayData.write(text, _record_index(things, second_car, map_edge), ThingData.read(things, second_car_offset + 10))
		_copy_record(things, first_car, second_car)
		_copy_record(things, record, first_car)
		ThingData.write(things, offset + 10, OverlayData.read(text, destination_index))
		OverlayData.write(text, destination_index, OverlayData.thing_id(record))
		counters.moved_trains += 1

	ThingData.write(things, offset + 3, destination.x)
	ThingData.write(things, offset + 4, destination.y)
	current = destination
	var current_index := _index(current, map_edge)

	if buildings[current_index] >= 0x6c and buildings[current_index] <= 0x70:
		ThingData.write(things, offset, (
			TYPE_SUBWAY_ENGINE if engine_type == TYPE_TRAIN_ENGINE else TYPE_TRAIN_ENGINE
		))
		engine_type = int(ThingData.read(things, offset))

	direction = int(ThingData.read(things, offset + 1)) & 0x0f

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
			engine_type, map_edge
		):
			direction = turn_direction
			counters.turned_trains += 1

		if random.next_u15() & 0xff == 0:
			_queue_sound(counters, things, record)

	var next: Vector2i = current + CARDINAL_DIRECTIONS[direction]

	if not _route_is_valid(buildings, underground, text, next, engine_type, map_edge):
		var selected := _select_direction(
			buildings,
			underground,
			text,
			current,
			direction,
			engine_type,
			game_random, map_edge
		)

		if selected < 0:
			_reverse(things, record, second_car)
			counters.reversed_trains += 1

			return

		ThingData.write(things, offset + 1, selected)
		ThingData.write(things, offset + 8, TRANSITIONS[direction * 4 + selected])
		next = current + CARDINAL_DIRECTIONS[selected]
	else:
		ThingData.write(things, offset + 1, int(ThingData.read(things, offset + 1)) & 0x0f)
		ThingData.write(things, offset + 8, direction * 2)

	ThingData.write(things, offset + 6, next.x)
	ThingData.write(things, offset + 7, next.y)


static func _current_route_is_valid(
	buildings: PackedByteArray, underground: PackedByteArray, point: Vector2i,
	map_edge: int = 128,
) -> bool:
	var index := _index(point, map_edge)

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
	engine_type: int,
	map_edge: int = 128,
) -> bool:
	var index := _index(point, map_edge)

	if index < 0 or OverlayData.blocks_thing(OverlayData.read(text, index)):
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
	game_random: GameLcgRandom,
	map_edge: int = 128,
) -> int:
	var order_index: int = game_random.next_mod(2)

	for direction_offset in DIRECTION_ORDERS[order_index]:
		var direction := (initial_direction + int(direction_offset)) & 3

		if _route_is_valid(
			buildings,
			underground,
			text,
			point + CARDINAL_DIRECTIONS[direction],
			engine_type, map_edge
		):
			return direction

	return -1


static func _copy_record(
	things: PackedByteArray, source_record: int, destination_record: int
) -> void:
	var source := source_record * RECORD_SIZE
	var destination := destination_record * RECORD_SIZE

	for field in [0, 3, 4, 6, 7, 10, 1, 8]:
		ThingData.write(things, destination + field, ThingData.read(things, source + field))

	if ThingData.read(things, destination) == TYPE_TRAIN_ENGINE:
		ThingData.write(things, destination, TYPE_TRAIN_CAR)
	elif ThingData.read(things, destination) == TYPE_SUBWAY_ENGINE:
		ThingData.write(things, destination, TYPE_SUBWAY_CAR)


static func _reverse(
	things: PackedByteArray, engine_record: int, second_car_record: int
) -> void:
	var engine := engine_record * RECORD_SIZE
	var second_car := second_car_record * RECORD_SIZE
	var tail_x := ThingData.read(things, second_car + 3)
	var tail_y := ThingData.read(things, second_car + 4)
	var tail_label := ThingData.read(things, second_car + 10)
	var reverse_direction := (int(ThingData.read(things, second_car + 1)) + 2) & 3

	for field in [3, 4, 6, 7, 10]:
		ThingData.write(things, second_car + field, ThingData.read(things, engine + field))

	ThingData.write(things, engine + 3, tail_x)
	ThingData.write(things, engine + 4, tail_y)
	ThingData.write(things, engine + 6, tail_x)
	ThingData.write(things, engine + 7, tail_y)
	ThingData.write(things, engine + 10, tail_label)
	ThingData.write(things, engine + 8, reverse_direction + 4)
	ThingData.write(things, engine + 1, reverse_direction)


static func _record_points_are_valid(
	things: PackedByteArray, records: Array,
	map_edge: int = 128,
) -> bool:
	for record_value in records:
		if _record_index(things, int(record_value), map_edge) < 0:
			return false

	return true


static func _record_index(things: PackedByteArray, record: int, map_edge: int = 128) -> int:
	var offset := record * RECORD_SIZE

	return _index(Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4)), map_edge)


static func _remove_train(
	text: PackedByteArray,
	things: PackedByteArray,
	engine_record: int,
	first_car_record: int,
	second_car_record: int,
	map_edge: int = 128,
) -> void:
	_remove_thing(text, things, engine_record, map_edge)
	_remove_thing(text, things, first_car_record, map_edge)
	_remove_thing(text, things, second_car_record, map_edge)


static func _spawn_explosion(
	text: PackedByteArray, things: PackedByteArray, point: Vector2i,
	map_edge: int = 128,
) -> bool:
	var index := _index(point, map_edge)

	if index < 0 or OverlayData.blocks_thing(OverlayData.read(text, index)):
		return false

	var record := 0

	for checked_record in range(FIRST_RECORD, ThingData.count(things)):
		if ThingData.read(things, checked_record * RECORD_SIZE) == 0:
			record = checked_record
			break

	if record == 0:
		return false

	var offset := record * RECORD_SIZE
	ThingData.write(things, offset, TYPE_EXPLOSION)
	ThingData.write(things, offset + 1, 0)
	ThingData.write(things, offset + 2, 0)
	ThingData.write(things, offset + 3, point.x)
	ThingData.write(things, offset + 4, point.y)
	ThingData.write(things, offset + 5, 0)
	ThingData.write(things, offset + 6, 8)
	ThingData.write(things, offset + 7, 8)
	ThingData.write(things, offset + 10, OverlayData.read(text, index))
	ThingData.write(things, offset + 11, 0)
	OverlayData.write(text, index, OverlayData.thing_id(record))

	return true


static func _remove_thing(
	text: PackedByteArray, things: PackedByteArray, record: int,
	map_edge: int = 128,
) -> void:
	var offset := record * RECORD_SIZE
	ThingData.write(things, offset, 0)
	var point := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var index := _index(point, map_edge)

	if index >= 0:
		OverlayData.write(text, index, 0)


static func _queue_sound(
	counters: MovingThingResult, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	counters.sound_events.append(SoundEvent.for_thing(SOUND_TRAIN, int(ThingData.read(things, offset)), record,
		Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))))


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if (
		point.x < 0
		or point.x >= map_edge
		or point.y < 0
		or point.y >= map_edge
	):
		return -1

	return point.x * map_edge + point.y
