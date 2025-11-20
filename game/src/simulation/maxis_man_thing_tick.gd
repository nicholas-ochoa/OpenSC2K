class_name MaxisManThingTick
extends RefCounted

const MAP_SIZE := CityState.MAP_SIZE
const RECORD_SIZE := CityState.THING_RECORD_SIZE
const FIRST_RECORD := 1
const LAST_RECORD := CityState.THING_COUNT - 1
const TEXT_LABEL_BASE := 201
const TYPE_EXPLOSION := 6
const TYPE_MAXIS_MAN := 16
const SOUND_EXPLOSION := 0x1f8
const SUBTILE_LIMIT := 16
const EIGHT_DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]
const THING_SPEEDS := {
	TYPE_MAXIS_MAN: 16,
}


static func update(
	altitude: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	random,
	counters: Dictionary
) -> void:
	var offset := record * RECORD_SIZE
	var current := Vector2i(things[offset + 3], things[offset + 4])
	var current_index := _index(current)
	var state := int(things[offset + 2])
	var goal := int(things[offset + 11])
	if current_index < 0 or state > 2:
		_remove_thing(text, things, record)
		counters.removed_maxis_men += 1
		counters.malformed_records += 1
		return
	match state:
		0:
			var target_result := _maxis_man_target(text, things, offset, current, goal)
			if not target_result.ok:
				if target_result.get("malformed", false):
					counters.malformed_records += 1
				_update_maxis_man_height(altitude, flags, things, offset)
				return
			var target: Vector2i = target_result.point
			var direction := _direction_quadrant(current, target)
			things[offset + 1] = direction
			var next: Vector2i = current + EIGHT_DIRECTIONS[direction]
			var next_index := _index(next)
			var overlay := int(text[next_index]) if next_index >= 0 else 0
			if overlay > 250:
				if random.next_u15() & 1:
					text[next_index] = 0
					counters.maxis_man_extinguished_fires += 1
					_move_maxis_man(text, things, record, direction, counters)
			elif overlay >= TEXT_LABEL_BASE:
				if overlay == goal + TEXT_LABEL_BASE and random.next_u15() & 3 == 0:
					_remove_thing(text, things, goal)
					counters.maxis_man_destroyed_targets += 1
					_queue_thing_sound(counters, SOUND_EXPLOSION, things, record)
					if _spawn_explosion(text, things, next, things[offset + 5], 0, 1):
						counters.maxis_man_explosions += 1
					things[offset + 2] = 2
				else:
					things[offset + 2] = 1
			else:
				if not _move_maxis_man(text, things, record, direction, counters):
					return
				current = Vector2i(things[offset + 3], things[offset + 4])
				var ahead_index := _index(current + EIGHT_DIRECTIONS[direction])
				if ahead_index < 0 or text[ahead_index] < TEXT_LABEL_BASE:
					if not _move_maxis_man(text, things, record, direction, counters):
						return
		1:
			if random.next_u15() & 3 == 0:
				things[offset + 2] = 0
			else:
				var direction: int = random.next_u15() & 7
				var bugged_check := Vector2i(
					current.x + EIGHT_DIRECTIONS[direction].x,
					current.x + EIGHT_DIRECTIONS[direction].y
				)
				var check_index := _index(bugged_check)
				if check_index >= 0 and text[check_index] < TEXT_LABEL_BASE:
					if _move_maxis_man(text, things, record, direction, counters):
						things[offset + 1] = direction
		2:
			var direction := int(things[offset + 1])
			if direction < 0 or direction >= EIGHT_DIRECTIONS.size():
				_remove_thing(text, things, record)
				counters.malformed_records += 1
				return
			if not _move_maxis_man(text, things, record, direction, counters):
				return
			if not _move_maxis_man(text, things, record, direction, counters):
				return
	if things[offset] == TYPE_MAXIS_MAN:
		_update_maxis_man_height(altitude, flags, things, offset)


static func _maxis_man_target(
	text: PackedByteArray,
	things: PackedByteArray,
	offset: int,
	current: Vector2i,
	goal: int
) -> Dictionary:
	if goal < 241:
		if goal < 0 or goal >= CityState.THING_COUNT:
			return {"ok": false, "malformed": true}
		var target_offset := goal * RECORD_SIZE
		return {
			"ok": true,
			"point": Vector2i(things[target_offset + 3], things[target_offset + 4]),
		}
	var target := Vector2i(things[offset + 8], things[offset + 9])
	var target_index := _index(target)
	if target_index >= 0 and text[target_index] >= 241:
		return {"ok": true, "point": target}
	things[offset + 2] = 2
	for x in range(current.x - 32, current.x + 33):
		for y in range(current.y - 32, current.y + 33):
			var index := _index(Vector2i(x, y))
			if index >= 0 and text[index] >= 241:
				things[offset + 8] = x
				things[offset + 9] = y
				things[offset + 2] = 0
				return {"ok": true, "point": Vector2i(x, y)}
	return {"ok": false}


static func _move_maxis_man(
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int,
	counters: Dictionary
) -> bool:
	if _move_thing_eight_way(TYPE_MAXIS_MAN, text, things, record, direction) < 0:
		counters.removed_maxis_men += 1
		return false
	counters.moved_maxis_men += 1
	return true


static func _update_maxis_man_height(
	altitude: PackedByteArray,
	flags: PackedByteArray,
	things: PackedByteArray,
	offset: int
) -> void:
	var goal := int(things[offset + 11])
	if goal < 241 and goal >= 0 and goal < CityState.THING_COUNT:
		things[offset + 5] = things[goal * RECORD_SIZE + 5]
		return
	var point := Vector2i(things[offset + 3], things[offset + 4])
	var index := _index(point)
	if index < 0:
		return
	var word := (altitude[index * 2] << 8) | altitude[index * 2 + 1]
	var ground := word & 0x1f
	if flags[index] & 0x04:
		ground = (word >> 5) & 0x1f
	things[offset + 5] = (ground + int(things[offset + 2])) & 0xff

static func _spawn_explosion(
	text: PackedByteArray,
	things: PackedByteArray,
	point: Vector2i,
	height: int,
	state: int,
	goal: int
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
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = height
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 10] = text[index]
	things[offset + 11] = goal
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
