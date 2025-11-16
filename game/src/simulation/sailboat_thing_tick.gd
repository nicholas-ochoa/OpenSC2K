class_name SailboatThingTick
extends RefCounted

const RECORD_SIZE := CityState.THING_RECORD_SIZE
const TEXT_LABEL_BASE := 201
const TILE_PIER := 0xdf
const TILE_MARINA := 0xf8
const SOUND_DISTRESS := 0x20f
const SUBTILE_LIMIT := 16
const SUBTILE_X := [0, 16, 0, -16]
const SUBTILE_Y := [-16, 0, 16, 0]
const DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]


static func update(
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
		_remove(text, things, record)
		counters.removed_sailboats += 1
		return
	var direction := int(things[offset + 1])
	if direction < 0 or direction >= DIRECTIONS.size():
		_remove(text, things, record)
		counters.removed_sailboats += 1
		counters.malformed_records += 1
		return
	if things[offset + 2] != 0:
		if lfsr_random.next_mod(5) == 0:
			_remove(text, things, record)
			counters.removed_sailboats += 1
		return
	if lfsr_random.next_mod(4) == 0:
		var current := Vector2i(things[offset + 3], things[offset + 4])
		var current_index := _index(current)
		if current_index < 0 or flags[current_index] & 0x04 == 0:
			_remove(text, things, record)
			counters.removed_sailboats += 1
			return
		if lfsr_random.next_mod(4000) == 0:
			things[offset + 2] = 1
			counters.distressed_sailboats += 1
			_queue_distress_sound(counters, things, record)
		things[offset + 1] = (direction + random.next_u15() % 3 - 1) & 3
		counters.turned_sailboats += 1
		return
	var route_state := _route_state(
		buildings, flags, text, things, record, direction
	)
	if route_state < 0:
		counters.removed_sailboats += 1
	elif route_state > 0:
		_move(text, things, record, direction, counters)


static func _route_state(
	buildings: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int
) -> int:
	var offset := record * RECORD_SIZE
	var next: Vector2i = (
		Vector2i(things[offset + 3], things[offset + 4]) + DIRECTIONS[direction]
	)
	var next_index := _index(next)
	if next_index < 0:
		return 1
	if buildings[next_index] == TILE_MARINA:
		_remove(text, things, record)
		return -1
	if buildings[next_index] == TILE_PIER or text[next_index] != 0:
		return 0
	return 1 if flags[next_index] & 0x04 != 0 else 0


static func _move(
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int,
	counters: Dictionary
) -> void:
	var offset := record * RECORD_SIZE
	var subtile_x: int = int(things[offset + 6]) + SUBTILE_X[direction]
	var subtile_y: int = int(things[offset + 7]) + SUBTILE_Y[direction]
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
			_remove(text, things, record)
			counters.removed_sailboats += 1
			return
		things[offset + 3] = next.x
		things[offset + 4] = next.y
		text[_index(next)] = record + TEXT_LABEL_BASE
	counters.moved_sailboats += 1


static func _remove(
	text: PackedByteArray, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	things[offset] = 0
	var point := Vector2i(things[offset + 3], things[offset + 4])
	var index := _index(point)
	if index >= 0:
		text[index] = 0


static func _queue_distress_sound(
	counters: Dictionary, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	counters.sound_events.append({
		"sound_id": SOUND_DISTRESS,
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
