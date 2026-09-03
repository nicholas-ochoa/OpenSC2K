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


class TargetResult extends RefCounted:
	var ok := false
	var malformed := false
	var point := Vector2i.ZERO


static func update(
	altitude: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	random: SimRandom,
	counters: MovingThingResult,
	map_edge: int = 128,
) -> void:
	var offset := record * RECORD_SIZE
	var current := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var current_index := _index(current, map_edge)
	var state := int(ThingData.read(things, offset + 2))
	var goal := int(ThingData.read(things, offset + 11))

	if current_index < 0 or state > 2:
		_remove_thing(text, things, record, map_edge)
		counters.removed_maxis_men += 1
		counters.malformed_records += 1

		return

	match state:
		0:
			var target_result := _maxis_man_target(text, things, offset, current, goal, map_edge)

			if not target_result.ok:
				if target_result.malformed:
					counters.malformed_records += 1

				_update_maxis_man_height(altitude, flags, things, offset, map_edge)

				return

			var target: Vector2i = target_result.point
			var direction := _direction_quadrant(current, target)
			ThingData.write(things, offset + 1, direction)
			var next: Vector2i = current + EIGHT_DIRECTIONS[direction]
			var next_index := _index(next, map_edge)
			var overlay := int(OverlayData.read(text, next_index)) if next_index >= 0 else 0

			if (overlay > 250 and overlay <= 255):
				if random.next_u15() & 1:
					OverlayData.write(text, next_index, 0)
					counters.maxis_man_extinguished_fires += 1
					_move_maxis_man(text, things, record, direction, counters, map_edge)
			elif OverlayData.is_thing(overlay):
				if overlay == OverlayData.thing_id(ThingData.target_record(goal)) and random.next_u15() & 3 == 0:
					_remove_thing(text, things, ThingData.target_record(goal), map_edge)
					counters.maxis_man_destroyed_targets += 1
					_queue_thing_sound(counters, SOUND_EXPLOSION, things, record)

					if _spawn_explosion(text, things, next, ThingData.read(things, offset + 5), 0, 1, map_edge):
						counters.maxis_man_explosions += 1

					ThingData.write(things, offset + 2, 2)
				else:
					ThingData.write(things, offset + 2, 1)
			else:
				if not _move_maxis_man(text, things, record, direction, counters, map_edge):
					return

				current = Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
				var ahead_index := _index(current + EIGHT_DIRECTIONS[direction], map_edge)

				if ahead_index < 0 or not OverlayData.blocks_thing(OverlayData.read(text, ahead_index)):
					if not _move_maxis_man(text, things, record, direction, counters, map_edge):
						return
		1:
			if random.next_u15() & 3 == 0:
				ThingData.write(things, offset + 2, 0)
			else:
				var direction: int = random.next_u15() & 7
				var bugged_check := Vector2i(
					current.x + EIGHT_DIRECTIONS[direction].x,
					current.x + EIGHT_DIRECTIONS[direction].y
				)
				var check_index := _index(bugged_check, map_edge)

				if check_index >= 0 and not OverlayData.blocks_thing(OverlayData.read(text, check_index)):
					if _move_maxis_man(text, things, record, direction, counters, map_edge):
						ThingData.write(things, offset + 1, direction)
		2:
			var direction := int(ThingData.read(things, offset + 1))

			if direction < 0 or direction >= EIGHT_DIRECTIONS.size():
				_remove_thing(text, things, record, map_edge)
				counters.malformed_records += 1

				return

			if not _move_maxis_man(text, things, record, direction, counters, map_edge):
				return

			if not _move_maxis_man(text, things, record, direction, counters, map_edge):
				return

	if ThingData.read(things, offset) == TYPE_MAXIS_MAN:
		_update_maxis_man_height(altitude, flags, things, offset, map_edge)


static func _maxis_man_target(
	text: PackedByteArray,
	things: PackedByteArray,
	offset: int,
	current: Vector2i,
	goal: int,
	map_edge: int = 128,
) -> TargetResult:
	if ThingData.is_record_target(goal):
		if goal < 0 or ThingData.target_record(goal) >= ThingData.count(things):
			var result := TargetResult.new()
			result.ok = false
			result.malformed = true

			return result

		var target_offset := ThingData.target_record(goal) * RECORD_SIZE

		var result := TargetResult.new()
		result.ok = true
		result.point = Vector2i(ThingData.read(things, target_offset + 3), ThingData.read(things, target_offset + 4))

		return result

	var target := Vector2i(ThingData.read(things, offset + 8), ThingData.read(things, offset + 9))
	var target_index := _index(target, map_edge)

	if target_index >= 0 and (OverlayData.read(text, target_index) >= 241 and OverlayData.read(text, target_index) <= 255):
		var result := TargetResult.new()
		result.ok = true
		result.point = target

		return result

	ThingData.write(things, offset + 2, 2)

	for x in range(current.x - 32, current.x + 33):
		for y in range(current.y - 32, current.y + 33):
			var index := _index(Vector2i(x, y), map_edge)

			if index >= 0 and (OverlayData.read(text, index) >= 241 and OverlayData.read(text, index) <= 255):
				ThingData.write(things, offset + 8, x)
				ThingData.write(things, offset + 9, y)
				ThingData.write(things, offset + 2, 0)

				var result := TargetResult.new()
				result.ok = true
				result.point = Vector2i(x, y)

				return result

	var result := TargetResult.new()
	result.ok = false

	return result


static func _move_maxis_man(
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int,
	counters: MovingThingResult,
	map_edge: int = 128,
) -> bool:
	if _move_thing_eight_way(TYPE_MAXIS_MAN, text, things, record, direction, map_edge) < 0:
		counters.removed_maxis_men += 1

		return false

	counters.moved_maxis_men += 1

	return true


static func _update_maxis_man_height(
	altitude: PackedByteArray,
	flags: PackedByteArray,
	things: PackedByteArray,
	offset: int,
	map_edge: int = 128,
) -> void:
	var goal := int(ThingData.read(things, offset + 11))

	if ThingData.is_record_target(goal) and goal >= 0 and ThingData.target_record(goal) < ThingData.count(things):
		ThingData.write(things, offset + 5, ThingData.read(things, ThingData.target_record(goal) * RECORD_SIZE + 5))

		return

	var point := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var index := _index(point, map_edge)

	if index < 0:
		return

	var word := (altitude[index * 2] << 8) | altitude[index * 2 + 1]
	var ground := word & 0x1f

	if flags[index] & 0x04:
		ground = (word >> 5) & 0x1f

	ThingData.write(things, offset + 5, (ground + int(ThingData.read(things, offset + 2))) & 0xff)


static func _spawn_explosion(
	text: PackedByteArray,
	things: PackedByteArray,
	point: Vector2i,
	height: int,
	state: int,
	goal: int,
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
	ThingData.write(things, offset + 2, state)
	ThingData.write(things, offset + 3, point.x)
	ThingData.write(things, offset + 4, point.y)
	ThingData.write(things, offset + 5, height)
	ThingData.write(things, offset + 6, 8)
	ThingData.write(things, offset + 7, 8)
	ThingData.write(things, offset + 10, OverlayData.read(text, index))
	ThingData.write(things, offset + 11, goal)
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


static func _move_thing_eight_way(
	thing_type: int,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int,
	map_edge: int = 128,
) -> int:
	if not THING_SPEEDS.has(thing_type) or direction < 0 or direction >= EIGHT_DIRECTIONS.size():
		_remove_thing(text, things, record, map_edge)

		return -1

	var offset := record * RECORD_SIZE
	var speed: int = THING_SPEEDS[thing_type]
	var subtile_x: int = int(ThingData.read(things, offset + 6)) + EIGHT_DIRECTIONS[direction].x * speed
	var subtile_y: int = int(ThingData.read(things, offset + 7)) + EIGHT_DIRECTIONS[direction].y * speed
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

	ThingData.write(things, offset + 6, subtile_x)
	ThingData.write(things, offset + 7, subtile_y)

	if tile_delta == Vector2i.ZERO:
		return 0

	var current := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var current_index := _index(current, map_edge)

	if current_index < 0:
		_remove_thing(text, things, record, map_edge)

		return -1

	OverlayData.write(text, current_index, ThingData.read(things, offset + 10))
	var next := current + tile_delta
	var next_index := _index(next, map_edge)

	while next_index >= 0 and OverlayData.blocks_thing(OverlayData.read(text, next_index)):
		ThingData.write(things, offset + 3, next.x)
		ThingData.write(things, offset + 4, next.y)
		next += tile_delta
		next_index = _index(next, map_edge)

	if next_index < 0:
		_remove_thing(text, things, record, map_edge)

		return -1

	ThingData.write(things, offset + 3, next.x)
	ThingData.write(things, offset + 4, next.y)
	ThingData.write(things, offset + 10, OverlayData.read(text, next_index))
	OverlayData.write(text, next_index, OverlayData.thing_id(record))

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
	counters: MovingThingResult, sound_id: int, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	counters.sound_events.append({
		"sound_id": sound_id,
		"thing_type": int(ThingData.read(things, offset)),
		"record": record,
		"point": Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4)),
	})


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.x >= map_edge or point.y < 0 or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y
