class_name MovingThingSpawner
extends RefCounted

const MAP_SIZE := 128
const RECORD_SIZE := 12
const FIRST_RECORD := 1
const LAST_RECORD := 39
const TEXT_LABEL_BASE := 201
const TYPE_AIRPLANE := 1
const TYPE_HELICOPTER := 2
const TYPE_SHIP := 3
const TYPE_MONSTER := 5
const TYPE_SAILBOAT := 9
const TYPE_TRAIN_ENGINE := 10
const TYPE_TRAIN_CAR := 11
const CARDINAL_DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]
const TRAIN_SEARCH_OFFSETS := [
	Vector2i(0, -2), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0),
]
const TRAIN_DIRECTION_ORDERS := [
	[0, 3, 1, 2],
	[0, 1, 3, 2],
]


static func count_type(things: PackedByteArray, thing_type: int) -> int:
	var count := 0
	for record in range(FIRST_RECORD, LAST_RECORD + 1):
		if things[record * RECORD_SIZE] == thing_type:
			count += 1
	return count


static func spawn_helicopter(
	things: PackedByteArray, text: PackedByteArray, point: Vector2i, random
) -> Dictionary:
	var index := _index(point)
	if (
		index < 0
		or text[index] >= TEXT_LABEL_BASE
		or count_type(things, TYPE_MONSTER) != 0
		or count_type(things, TYPE_HELICOPTER) >= 1
	):
		return {"spawned": false}
	var record := _first_free_record(things)
	if record == 0:
		return {"spawned": false}
	var offset := record * RECORD_SIZE
	things[offset] = TYPE_HELICOPTER
	things[offset + 1] = 2
	things[offset + 2] = 0
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = 0
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 8] = random.next_u15() & 0x7f
	things[offset + 9] = random.next_u15() & 0x7f
	things[offset + 10] = text[index]
	text[index] = record + TEXT_LABEL_BASE
	return {"spawned": true, "record": record, "point": point}


static func spawn_airplane(
	things: PackedByteArray,
	text: PackedByteArray,
	point: Vector2i,
	runway_axis: int,
	random
) -> Dictionary:
	var source_index := _index(point)
	if (
		source_index < 0
		or text[source_index] >= TEXT_LABEL_BASE
		or count_type(things, TYPE_MONSTER) != 0
		or count_type(things, TYPE_AIRPLANE) >= 2
	):
		return {"spawned": false}
	var record := _first_free_record(things)
	if record == 0:
		return {"spawned": false}
	var offset := record * RECORD_SIZE
	things[offset] = TYPE_AIRPLANE
	things[offset + 6] = 8
	things[offset + 7] = 8
	var attached := point
	if random.next_u15() % 10 < 5:
		match random.next_u15() & 3:
			0:
				attached = Vector2i(0, random.next_u15() % 100 + 10)
				things[offset + 1] = 3
			1:
				attached = Vector2i(random.next_u15() % 100 + 10, 0)
				things[offset + 1] = 5
			2:
				attached = Vector2i(127, random.next_u15() % 100 + 10)
				things[offset + 1] = 7
			3:
				attached = Vector2i(random.next_u15() % 100 + 10, 127)
				things[offset + 1] = 1
		things[offset + 2] = runway_axis * 0x10 + 3
		things[offset + 5] = 0x10
		if runway_axis == 0:
			things[offset + 8] = point.x
			things[offset + 9] = point.y + 0x10
		else:
			things[offset + 8] = (point.x - 0x10) & 0xff
			things[offset + 9] = point.y
	else:
		things[offset + 1] = runway_axis
		things[offset + 2] = 0
		things[offset + 5] = 0
		things[offset + 8] = 0x14
		things[offset + 9] = 0x14
	things[offset + 3] = attached.x
	things[offset + 4] = attached.y
	var attached_index := _index(attached)
	things[offset + 10] = text[attached_index]
	text[attached_index] = record + TEXT_LABEL_BASE
	return {"spawned": true, "record": record, "point": attached}


static func spawn_ship(
	terrain: PackedByteArray,
	things: PackedByteArray,
	text: PackedByteArray,
	target: Vector2i,
	random
) -> Dictionary:
	if count_type(things, TYPE_SHIP) >= 1:
		return {"spawned": false}
	var start := Vector2i(-1, -1)
	match random.next_u15() & 3:
		0:
			for y in MAP_SIZE:
				if terrain[2 * MAP_SIZE + y] == 0x10:
					start = Vector2i(2, y)
		1:
			for y in MAP_SIZE:
				if terrain[126 * MAP_SIZE + y] == 0x10:
					start = Vector2i(126, y)
		2:
			for x in MAP_SIZE:
				if terrain[x * MAP_SIZE + 2] == 0x10:
					start = Vector2i(x, 2)
		3:
			for x in MAP_SIZE:
				if terrain[x * MAP_SIZE + 126] == 0x10:
					start = Vector2i(x, 126)
	if start.x < 0:
		return {"spawned": false}
	var start_index := _index(start)
	if text[start_index] >= TEXT_LABEL_BASE:
		return {"spawned": false}
	var record := _first_free_record(things)
	if record == 0:
		return {"spawned": false}
	var offset := record * RECORD_SIZE
	things[offset] = TYPE_SHIP
	things[offset + 1] = _direction_between(start, target)
	things[offset + 2] = 0
	things[offset + 3] = start.x
	things[offset + 4] = start.y
	things[offset + 5] = 1
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 10] = text[start_index]
	text[start_index] = record + TEXT_LABEL_BASE
	return {"spawned": true, "record": record, "point": start, "target": target}


static func spawn_sailboats(
	buildings: PackedByteArray,
	flags: PackedByteArray,
	things: PackedByteArray,
	text: PackedByteArray,
	point: Vector2i,
	lfsr_random
) -> int:
	if count_type(things, TYPE_SAILBOAT) >= 4:
		return 0
	var spawned := 0
	for direction in CARDINAL_DIRECTIONS:
		var start: Vector2i = point + direction
		var index := _index(start)
		var record := _first_free_record(things)
		if (
			record == 0
			or index < 0
			or flags[index] & 0x04 == 0
			or buildings[index] != 0
			or text[index] != 0
		):
			continue
		var offset := record * RECORD_SIZE
		things[offset] = TYPE_SAILBOAT
		things[offset + 1] = lfsr_random.next_mod(3)
		things[offset + 2] = 0
		things[offset + 3] = start.x
		things[offset + 4] = start.y
		things[offset + 5] = 0
		things[offset + 6] = 4
		things[offset + 7] = 4
		things[offset + 10] = 0
		text[index] = record + TEXT_LABEL_BASE
		spawned += 1
	return spawned


static func spawn_train(
	buildings: PackedByteArray,
	things: PackedByteArray,
	text: PackedByteArray,
	station: Vector2i,
	random,
	lfsr_random
) -> bool:
	for search_offset in TRAIN_SEARCH_OFFSETS:
		var start: Vector2i = station + search_offset
		if _spawn_train_record(buildings, things, text, start, random, lfsr_random):
			return true
	return false


static func _spawn_train_record(
	buildings: PackedByteArray,
	things: PackedByteArray,
	text: PackedByteArray,
	start: Vector2i,
	random,
	lfsr_random
) -> bool:
	if count_type(things, TYPE_TRAIN_ENGINE) > 4:
		return false
	if start.x < 2 or start.x > 124 or start.y < 2 or start.y > 124:
		return false
	var index := _index(start)
	var tile := int(buildings[index])
	if tile < 0x2c or tile > 0x35 or text[index] != 0:
		return false
	var initial_direction: int = lfsr_random.next_mod(4)
	var direction := _train_direction(
		buildings, text, start, initial_direction, random.next_u15() % 2
	)
	if direction < 0:
		return false

	# The original skips all three allocation checks. If no slot is free,
	# it writes the train into reserved record 0.
	var engine_record := _first_free_record(things)
	things[engine_record * RECORD_SIZE] = TYPE_TRAIN_ENGINE
	var first_car_record := _first_free_record(things)
	things[first_car_record * RECORD_SIZE] = TYPE_TRAIN_CAR
	var second_car_record := _first_free_record(things)
	things[second_car_record * RECORD_SIZE] = TYPE_TRAIN_CAR
	var records: Array[int] = [engine_record, first_car_record, second_car_record]
	for record in records:
		var offset: int = record * RECORD_SIZE
		things[offset + 1] = direction
		things[offset + 3] = start.x
		things[offset + 4] = start.y
		things[offset + 5] = 0
	var engine_offset := engine_record * RECORD_SIZE
	var first_car_offset := first_car_record * RECORD_SIZE
	var second_car_offset := second_car_record * RECORD_SIZE
	things[engine_offset + 6] = start.x + CARDINAL_DIRECTIONS[direction].x
	things[engine_offset + 7] = start.y + CARDINAL_DIRECTIONS[direction].y
	things[first_car_offset + 6] = start.x
	things[first_car_offset + 7] = start.y
	things[second_car_offset + 6] = start.x
	things[second_car_offset + 7] = start.y
	things[engine_offset + 10] = text[index]
	things[first_car_offset + 10] = 0
	things[second_car_offset + 10] = 0
	things[engine_offset + 2] = first_car_record
	things[first_car_offset + 2] = second_car_record
	text[index] = engine_record + TEXT_LABEL_BASE
	return true


static func _train_direction(
	buildings: PackedByteArray,
	text: PackedByteArray,
	point: Vector2i,
	initial_direction: int,
	order_index: int
) -> int:
	for offset in TRAIN_DIRECTION_ORDERS[order_index & 1]:
		var direction: int = (initial_direction + int(offset)) & 3
		var neighbor: Vector2i = point + CARDINAL_DIRECTIONS[direction]
		var index := _index(neighbor)
		if index >= 0 and text[index] < TEXT_LABEL_BASE and _train_route_tile(buildings[index]):
			return direction
	return -1


static func _train_route_tile(tile_value: int) -> bool:
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


static func _first_free_record(things: PackedByteArray) -> int:
	for record in range(FIRST_RECORD, LAST_RECORD + 1):
		if things[record * RECORD_SIZE] == 0:
			return record
	return 0


static func _direction_between(start: Vector2i, target: Vector2i) -> int:
	var difference := target - start
	var absolute_x := absi(difference.x)
	var absolute_y := absi(difference.y)
	if absolute_x < int((absolute_y + 1) / 2):
		return 0 if difference.y < 0 else 4
	if absolute_y < int((absolute_x + 1) / 2):
		return 6 if difference.x < 0 else 2
	if difference.x < 0:
		return 7 if difference.y < 0 else 5
	return 1 if difference.y < 0 else 3


static func _index(point: Vector2i) -> int:
	if point.x < 0 or point.x >= MAP_SIZE or point.y < 0 or point.y >= MAP_SIZE:
		return -1
	return point.x * MAP_SIZE + point.y
