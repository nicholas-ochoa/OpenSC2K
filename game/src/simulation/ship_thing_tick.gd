class_name ShipThingTick
extends RefCounted

const RECORD_SIZE := CityState.THING_RECORD_SIZE
const TEXT_LABEL_BASE := 201
const TYPE_EXPLOSION := 6
const TILE_PIER := 0xdf
const TILE_MARINA := 0xf8
const SOUND_SHIP := 0x205
const DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]
const ROUTE_DELTAS := [
	Vector2i(0, -4), Vector2i(3, -3), Vector2i(4, 0), Vector2i(3, 3),
	Vector2i(0, 4), Vector2i(-3, 3), Vector2i(-4, 0), Vector2i(-3, -3),
]
const DIRECTION_OFFSETS := [0, 1, 2, 3, 4, 5, 6, 7, 0]
const REVERSE_OFFSETS := [0, 7, 6, 5, 4, 3, 2, 1]
const PIER_DELTAS := [
	Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(0, -2),
]
const ROUTE_BUILDINGS := {
	0x51: true, 0x52: true, 0x54: true, 0x55: true, 0x58: true,
	0x59: true, 0x5b: true, 0x5c: true, 0x6b: true,
}


static func update(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	ship_home: Vector2i,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	var offset := record * RECORD_SIZE
	if random.next_u15() & 0xff == 0:
		_queue_sound(counters, things, record)
	var current := Vector2i(things[offset + 3], things[offset + 4])
	var current_index := _index(current)
	var direction := int(things[offset + 1])
	if current_index < 0 or direction < 0 or direction >= DIRECTIONS.size():
		_convert_to_explosion(things, record)
		counters.crashed_ships += 1
		counters.malformed_records += 1
		return
	if flags[current_index] & 0x04 == 0:
		_convert_to_explosion(things, record)
		counters.crashed_ships += 1
		return
	var target := Vector2i(things[offset + 8], things[offset + 9])
	match int(things[offset + 2]):
		0:
			if lfsr_random.next_mod(10) == 0:
				var turned := _steer_direction(direction, current, target)
				if _route_is_valid(
					buildings, underground, flags, text, current, turned
				):
					direction = turned
					things[offset + 1] = direction
			if _route_is_valid(
				buildings, underground, flags, text, current, direction
			):
				if not _move(text, things, record, direction):
					counters.removed_ships += 1
					return
				counters.moved_ships += 1
			else:
				things[offset + 2] = 1
			for pier_delta in PIER_DELTAS:
				var pier_index := _index(current + pier_delta)
				if pier_index >= 0 and buildings[pier_index] == TILE_PIER:
					things[offset + 2] = 3
					counters.docked_ships += 1
		1:
			var desired := _direction_between(current, target)
			direction = _turn_one_step(direction, desired)
			things[offset + 1] = direction
			if direction == desired:
				things[offset + 2] = (
					0
					if _route_is_valid(
						buildings, underground, flags, text, current, desired
					)
					else 2
				)
		2:
			var offsets = (
				REVERSE_OFFSETS
				if lfsr_random.next_mod(2) == 0
				else DIRECTION_OFFSETS
			)
			var found := false
			for direction_offset in offsets.slice(0, 8):
				direction = (int(things[offset + 1]) + int(direction_offset)) & 7
				if _route_is_valid(
					buildings, underground, flags, text, current, direction
				):
					found = true
					break
			if not found:
				_remove(text, things, record)
				counters.removed_ships += 1
				direction = (
					(int(things[offset + 1]) + 2) & 7
					if offsets == REVERSE_OFFSETS
					else int(things[offset + 1]) & 7
				)
			things[offset + 1] = direction
			things[offset + 2] = 0
		3:
			if lfsr_random.next_mod(30) == 0:
				things[offset + 2] = 4
				_queue_sound(counters, things, record)
				counters.departing_ships += 1
				var home := ship_home if _index(ship_home) >= 0 else current
				things[offset + 8] = home.x
				things[offset + 9] = home.y
		4:
			if _route_is_valid(
				buildings, underground, flags, text, current, direction
			):
				if not _move(text, things, record, direction):
					counters.removed_ships += 1
					return
				counters.moved_ships += 1
				return
			var start_offset: int = lfsr_random.next_mod(2)
			for order_index in range(start_offset, DIRECTION_OFFSETS.size()):
				direction = (
					int(things[offset + 1]) + DIRECTION_OFFSETS[order_index]
				) & 7
				if _route_is_valid(
					buildings, underground, flags, text, current, direction
				):
					break
			things[offset + 1] = direction


static func _route_is_valid(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	current: Vector2i,
	direction: int
) -> bool:
	var route_point: Vector2i = current + ROUTE_DELTAS[direction]
	var route_index := _index(route_point)
	if route_index < 0:
		return true
	return (
		_is_water_route(buildings, underground, flags, route_index)
		and text[route_index] < TEXT_LABEL_BASE
	)


static func _is_water_route(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	index: int
) -> bool:
	if flags[index] & 0x04 == 0:
		return false
	var underground_tile := int(underground[index])
	if underground_tile >= 0x10 and underground_tile <= 0x1f:
		return false
	var building := int(buildings[index])
	if building == TILE_MARINA:
		return false
	return building == 0 or ROUTE_BUILDINGS.has(building)


static func _move(
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int
) -> bool:
	var offset := record * RECORD_SIZE
	var subtile_x: int = int(things[offset + 6]) + ROUTE_DELTAS[direction].x
	var subtile_y: int = int(things[offset + 7]) + ROUTE_DELTAS[direction].y
	var tile_delta := Vector2i.ZERO
	if subtile_x > 12:
		subtile_x -= 12
		tile_delta.x = 1
	elif subtile_x < 0:
		subtile_x += 12
		tile_delta.x = -1
	if subtile_y > 12:
		subtile_y -= 12
		tile_delta.y = 1
	elif subtile_y < 0:
		subtile_y += 12
		tile_delta.y = -1
	things[offset + 6] = subtile_x
	things[offset + 7] = subtile_y
	if tile_delta == Vector2i.ZERO:
		return true
	var current := Vector2i(things[offset + 3], things[offset + 4])
	var current_index := _index(current)
	if current_index >= 0:
		text[current_index] = things[offset + 10]
	var next := current + tile_delta
	var next_index := _index(next)
	if next_index < 0:
		things[offset] = 0
		return false
	things[offset + 3] = next.x
	things[offset + 4] = next.y
	things[offset + 10] = text[next_index]
	text[next_index] = record + TEXT_LABEL_BASE
	return true


static func _convert_to_explosion(things: PackedByteArray, record: int) -> void:
	var offset := record * RECORD_SIZE
	things[offset] = TYPE_EXPLOSION
	things[offset + 1] = 0
	things[offset + 2] = 0
	things[offset + 11] = 0


static func _remove(
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
		"sound_id": SOUND_SHIP,
		"thing_type": int(things[offset]),
		"record": record,
		"point": Vector2i(things[offset + 3], things[offset + 4]),
	})


static func _steer_direction(
	direction: int, start: Vector2i, target: Vector2i
) -> int:
	var desired := _direction_between(start, target)
	return direction if desired == direction else _turn_one_step(direction, desired)


static func _turn_one_step(direction: int, target: int) -> int:
	if direction <= target:
		return (
			(direction - 1) & 7 if target - direction > 4 else (direction + 1) & 7
		)
	return (direction + 1) & 7 if direction - target > 4 else (direction - 1) & 7


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
	if (
		point.x < 0
		or point.x >= CityState.MAP_SIZE
		or point.y < 0
		or point.y >= CityState.MAP_SIZE
	):
		return -1
	return point.x * CityState.MAP_SIZE + point.y
