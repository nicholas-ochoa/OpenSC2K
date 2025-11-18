class_name AirThingTick
extends RefCounted

const MAP_SIZE := CityState.MAP_SIZE
const RECORD_SIZE := CityState.THING_RECORD_SIZE
const TEXT_LABEL_BASE := 201
const TYPE_AIRPLANE := 1
const TYPE_HELICOPTER := 2
const TYPE_EXPLOSION := 6
const SUBTILE_LIMIT := 16
const SOUND_HELICOPTER := 0x1fe
const SOUND_AIR_DISASTER := 0x203
const SOUND_AIRPLANE_TAKEOFF := 0x206
const SOUND_AIRPLANE_LANDING := 0x207
const HELICOPTER_SOUND_DELAY_MSEC := 5000
const EIGHT_DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]
const AIR_ROUTE_DELTAS := [
	Vector2i(0, -3), Vector2i(3, -3), Vector2i(3, 0), Vector2i(3, 3),
	Vector2i(0, 3), Vector2i(-3, 3), Vector2i(-3, 0), Vector2i(-3, -3),
]
const AIR_DIRECTION_OFFSETS := [1, 7, 2, 6, 3, 5, 4]
const THING_SPEEDS := {
	TYPE_AIRPLANE: 16,
	TYPE_HELICOPTER: 8,
}


# final supplied smallmed.dat metadata heights for sprite ids 0x71 through 0xfa
const BUILDING_SPRITE_HEIGHTS := [
	5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 8, 7, 6, 6, 8,
	12, 7, 9, 5, 8, 6, 7, 5, 5, 5, 5, 10, 11, 11, 11, 16,
	14, 20, 20, 9, 11, 11, 12, 12, 14, 19, 17, 19, 22, 11, 11, 11,
	10, 10, 14, 15, 16, 10, 12, 12, 17, 14, 15, 18, 19, 18, 23, 15,
	24, 16, 22, 17, 24, 16, 30, 35, 20, 28, 38, 13, 24, 15, 15, 15,
	13, 21, 17, 18, 24, 9, 9, 11, 23, 29, 21, 20, 24, 18, 28, 18,
	21, 19, 17, 15, 14, 15, 22, 19, 23, 17, 13, 5, 5, 5, 6, 11,
	16, 18, 5, 6, 6, 5, 5, 6, 6, 5, 17, 10, 11, 10, 10, 10,
	14, 9, 10, 10, 14, 10, 13, 14, 13, 16,
]

static func update_airplane(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	var offset := record * RECORD_SIZE
	var current := Vector2i(things[offset + 3], things[offset + 4])
	var current_index := _index(current)
	var direction := int(things[offset + 1])
	if current_index < 0 or direction < 0 or direction >= EIGHT_DIRECTIONS.size():
		_remove_thing(text, things, record)
		counters.removed_airplanes += 1
		counters.malformed_records += 1
		return
	var building := int(buildings[current_index])
	if building > 0x70 and zones[current_index] & 0x0f != 8:
		if building > 0xfa:
			_convert_to_explosion(
				things, record, 5, 1 if lfsr_random.next_mod(16) == 0 else 0
			)
			counters.crashed_airplanes += 1
			return
		# building artwork height is part of aircraft physics
		var sprite_height: int = BUILDING_SPRITE_HEIGHTS[building - 0x71]
		if things[offset + 5] < int(sprite_height / 3):
			_convert_to_explosion(things, record, 5, 1)
			counters.crashed_airplanes += 1
			return
	var state: int = int(things[offset + 2]) & 0x0f
	match state:
		0:
			if _move_thing_eight_way(TYPE_AIRPLANE, text, things, record, direction) < 0:
				counters.removed_airplanes += 1
				return
			counters.moved_airplanes += 1
			if things[offset + 5] == 0:
				_queue_thing_sound(counters, SOUND_AIRPLANE_TAKEOFF, things, record)
			if things[offset + 5] < 14:
				things[offset + 5] += 1
			else:
				things[offset + 2] = 2
		1:
			if _move_thing_eight_way(TYPE_AIRPLANE, text, things, record, direction) < 0:
				counters.removed_airplanes += 1
				return
			counters.moved_airplanes += 1
			things[offset + 5] = (int(things[offset + 5]) - 1) & 0xff
			if things[offset + 5] == 0:
				_queue_thing_sound(counters, SOUND_AIRPLANE_LANDING, things, record)
				current = Vector2i(things[offset + 3], things[offset + 4])
				current_index = _index(current)
				if current_index >= 0:
					text[current_index] = things[offset + 10]
				if current_index < 0 or buildings[current_index] != 0xdd:
					_convert_to_explosion(things, record, 5, 1)
					counters.crashed_airplanes += 1
				else:
					_remove_thing(text, things, record)
					counters.removed_airplanes += 1
					counters.landed_airplanes += 1
		2:
			direction = _random_direction_step(direction, 5, random)
			things[offset + 1] = direction
			_advance_air_direction(buildings, things, record)
			direction = int(things[offset + 1])
			if _move_thing_eight_way(TYPE_AIRPLANE, text, things, record, direction) < 0:
				counters.removed_airplanes += 1
				return
			counters.moved_airplanes += 1
		3:
			var target := Vector2i(things[offset + 8], things[offset + 9])
			var planned_direction := _direction_quadrant(current, target)
			things[offset + 1] = planned_direction
			_advance_air_direction(buildings, things, record)
			direction = int(things[offset + 1])
			if _move_thing_eight_way(TYPE_AIRPLANE, text, things, record, direction) < 0:
				counters.removed_airplanes += 1
				return
			counters.moved_airplanes += 1
			current = Vector2i(things[offset + 3], things[offset + 4])
			if _thing_distance(current, target) < 2:
				var runway_axis: int = int(things[offset + 2]) >> 4
				things[offset + 1] = _turn_one_step(planned_direction, runway_axis)
				things[offset + 2] = runway_axis * 0x10 + 4
				_adjust_airplane_target(things, offset, runway_axis)
		4:
			var target := Vector2i(things[offset + 8], things[offset + 9])
			direction = _steer_direction(direction, current, target)
			things[offset + 1] = direction
			if _move_thing_eight_way(TYPE_AIRPLANE, text, things, record, direction) < 0:
				counters.removed_airplanes += 1
				return
			counters.moved_airplanes += 1
			current = Vector2i(things[offset + 3], things[offset + 4])
			if _thing_distance(current, target) < 2:
				var runway_axis: int = int(things[offset + 2]) >> 4
				things[offset + 1] = runway_axis
				things[offset + 2] = 1
				match runway_axis:
					1, 5:
						things[offset + 3] = things[offset + 8]
					3, 7:
						things[offset + 4] = things[offset + 9]
		7:
			if things[offset + 5] != 0:
				things[offset + 5] -= 1
				if things[offset + 5] == 8:
					_queue_thing_sound(counters, SOUND_AIR_DISASTER, things, record)
				var old_direction := direction
				things[offset + 1] = (direction + 1) & 7
				if _move_thing_eight_way(
					TYPE_AIRPLANE, text, things, record, old_direction
				) < 0:
					counters.removed_airplanes += 1
					return
				counters.moved_airplanes += 1
			else:
				_convert_to_explosion(things, record, 5, 1)
				counters.crashed_airplanes += 1


static func _adjust_airplane_target(
	things: PackedByteArray, offset: int, runway_axis: int
) -> void:
	match runway_axis:
		1:
			things[offset + 9] = (int(things[offset + 9]) - 6) & 0xff
		3:
			things[offset + 8] = (int(things[offset + 8]) + 6) & 0xff
		5:
			things[offset + 9] = (int(things[offset + 9]) + 6) & 0xff
		7:
			things[offset + 8] = (int(things[offset + 8]) - 6) & 0xff


static func update_helicopter(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	traffic: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	city_center: Vector2i,
	random,
	counters: Dictionary
) -> void:
	var offset := record * RECORD_SIZE
	var current := Vector2i(things[offset + 3], things[offset + 4])
	var current_index := _index(current)
	var direction := int(things[offset + 1])
	if current_index < 0 or direction < 0 or direction >= EIGHT_DIRECTIONS.size():
		_remove_thing(text, things, record)
		counters.removed_helicopters += 1
		counters.malformed_records += 1
		return
	if buildings[current_index] > 0xfa:
		_convert_to_explosion(things, record, 5, 0)
		counters.crashed_helicopters += 1
		return
	match int(things[offset + 2]):
		0:
			things[offset + 1] = (direction + 1) & 7
			if things[offset + 5] < 10:
				things[offset + 5] += 1
			else:
				things[offset + 2] = 2
		2:
			var target := Vector2i(things[offset + 8], things[offset + 9])
			direction = _steer_direction(direction, current, target)
			things[offset + 1] = direction
			_advance_air_direction(buildings, things, record)
			direction = int(things[offset + 1])
			var motion := _move_thing_eight_way(
				TYPE_HELICOPTER, text, things, record, direction
			)
			if motion < 0:
				counters.removed_helicopters += 1
				return
			counters.moved_helicopters += 1
			current = Vector2i(things[offset + 3], things[offset + 4])
			var traffic_index := int(current.x / 2) * 64 + int(current.y / 2)
			if traffic[traffic_index] > 0xa9:
				counters.traffic_news_checks += 1
				if counters.traffic_news_deadline_msec < counters.traffic_news_time_msec:
					counters.traffic_news_deadline_msec = (
						counters.traffic_news_time_msec + HELICOPTER_SOUND_DELAY_MSEC
					)
					_queue_thing_sound(counters, SOUND_HELICOPTER, things, record)
			if _thing_distance(current, target) < 2:
				var target_x: int = (random.next_u15() & 0x3f) - 0x20 + city_center.x
				var target_y: int = (random.next_u15() & 0x3f) - 0x20 + city_center.y
				if target_x < 0 or target_x >= MAP_SIZE:
					target_x = (random.next_u15() & 0x3f) + 0x20
				if target_y < 0 or target_y >= MAP_SIZE:
					target_y = (random.next_u15() & 0x3f) + 0x20
				things[offset + 8] = target_x
				things[offset + 9] = target_y
				if (
					random.next_u15() & 1
					and buildings[_index(current)] == 0
					and underground[_index(current)] == 0
				):
					things[offset + 2] = 3
		3:
			things[offset + 1] = (direction + 1) & 7
			if things[offset + 5] > 2:
				things[offset + 5] -= 1
			else:
				things[offset + 2] = 4
		4:
			if random.next_u15() % 20 == 0:
				things[offset + 2] = 0
		5:
			things[offset + 1] = (direction + 2) & 7
			if things[offset + 5] == 4:
				_queue_thing_sound(counters, SOUND_AIR_DISASTER, things, record)
			if things[offset + 5] > 2:
				things[offset + 5] -= 1
			else:
				_convert_to_explosion(things, record, 0x11, 1)
				counters.crashed_helicopters += 1

static func _remove_thing(
	text: PackedByteArray, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	things[offset] = 0
	var point := Vector2i(things[offset + 3], things[offset + 4])
	var index := _index(point)
	if index >= 0:
		text[index] = 0

static func _convert_to_explosion(
	things: PackedByteArray, record: int, state: int, goal: int
) -> void:
	var offset := record * RECORD_SIZE
	things[offset] = TYPE_EXPLOSION
	things[offset + 1] = 0
	things[offset + 2] = state
	things[offset + 11] = goal

static func _move_thing_eight_way(
	thing_type: int,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int
) -> int:
	if not THING_SPEEDS.has(thing_type) or direction < 0 or direction >= EIGHT_DIRECTIONS.size():
		_remove_thing(text, things, record)
		return -1
	var offset := record * RECORD_SIZE
	var speed: int = THING_SPEEDS[thing_type]
	var subtile_x: int = int(things[offset + 6]) + EIGHT_DIRECTIONS[direction].x * speed
	var subtile_y: int = int(things[offset + 7]) + EIGHT_DIRECTIONS[direction].y * speed
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
	if tile_delta == Vector2i.ZERO:
		return 0
	var current := Vector2i(things[offset + 3], things[offset + 4])
	var current_index := _index(current)
	if current_index < 0:
		_remove_thing(text, things, record)
		return -1
	text[current_index] = things[offset + 10]
	var next := current + tile_delta
	var next_index := _index(next)
	while next_index >= 0 and text[next_index] >= TEXT_LABEL_BASE:
		things[offset + 3] = next.x
		things[offset + 4] = next.y
		next += tile_delta
		next_index = _index(next)
	if next_index < 0:
		_remove_thing(text, things, record)
		return -1
	things[offset + 3] = next.x
	things[offset + 4] = next.y
	things[offset + 10] = text[next_index]
	text[next_index] = record + TEXT_LABEL_BASE
	return 1


static func _advance_air_direction(
	buildings: PackedByteArray, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	var direction := int(things[offset + 1]) & 7
	var current := Vector2i(things[offset + 3], things[offset + 4])
	if not _air_route_blocked(buildings, current, direction):
		return
	for direction_offset in AIR_DIRECTION_OFFSETS:
		direction = (int(things[offset + 1]) + int(direction_offset)) & 7
		if not _air_route_blocked(buildings, current, direction):
			break
	things[offset + 1] = direction


static func _air_route_blocked(
	buildings: PackedByteArray, current: Vector2i, direction: int
) -> bool:
	var checked_index := _index(current + AIR_ROUTE_DELTAS[direction])
	return checked_index >= 0 and buildings[checked_index] >= 0xfb


static func _turn_one_step(direction: int, target: int) -> int:
	if direction <= target:
		return (direction - 1) & 7 if target - direction > 4 else (direction + 1) & 7
	return (direction + 1) & 7 if direction - target > 4 else (direction - 1) & 7


static func _random_direction_step(direction: int, divisor: int, random) -> int:
	if random.next_u15() % divisor == 0:
		return (direction + random.next_u15() % 3 - 1) & 7
	return direction


static func _direction_quadrant(start: Vector2i, target: Vector2i) -> int:
	var difference := target - start
	if difference.x < 0:
		if difference.y < 0:
			return 7
		return 6 if difference.y == 0 else 5
	if difference.x == 0:
		return 0 if difference.y < 0 else 4
	if difference.y < 0:
		return 1
	return 2 if difference.y == 0 else 3


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


static func _steer_direction(direction: int, start: Vector2i, target: Vector2i) -> int:
	var desired := _direction_between(start, target)
	return direction if desired == direction else _turn_one_step(direction, desired)


static func _thing_distance(start: Vector2i, target: Vector2i) -> int:
	return absi(target.x - start.x) + absi(target.y - start.y)


static func _queue_thing_sound(
	counters: Dictionary, sound_id: int, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	counters.sound_events.append({
		"sound_id": sound_id,
		"thing_type": int(things[offset]),
		"record": record,
		"point": Vector2i(things[offset + 3], things[offset + 4]),
	})

static func _index(point: Vector2i) -> int:
	if point.x < 0 or point.x >= MAP_SIZE or point.y < 0 or point.y >= MAP_SIZE:
		return -1
	return point.x * MAP_SIZE + point.y
