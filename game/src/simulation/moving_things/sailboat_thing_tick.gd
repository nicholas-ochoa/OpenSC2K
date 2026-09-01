class_name SailboatThingTick
extends RefCounted

@warning_ignore_start("integer_division")

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
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	counters: MovingThingResult,
	map_edge: int = 128,
) -> void:
	var offset := record * RECORD_SIZE

	if counters.active_sailboats > 4 * maxi(1, (map_edge * map_edge) / 16384):
		_remove(text, things, record, map_edge)
		counters.removed_sailboats += 1

		return

	var direction := int(ThingData.read(things, offset + 1))

	if direction < 0 or direction >= DIRECTIONS.size():
		_remove(text, things, record, map_edge)
		counters.removed_sailboats += 1
		counters.malformed_records += 1

		return

	if ThingData.read(things, offset + 2) != 0:
		if lfsr_random.next_mod(5) == 0:
			_remove(text, things, record, map_edge)
			counters.removed_sailboats += 1

		return

	if lfsr_random.next_mod(4) == 0:
		var current := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
		var current_index := _index(current, map_edge)

		if current_index < 0 or flags[current_index] & 0x04 == 0:
			_remove(text, things, record, map_edge)
			counters.removed_sailboats += 1

			return

		if lfsr_random.next_mod(4000) == 0:
			ThingData.write(things, offset + 2, 1)
			counters.distressed_sailboats += 1
			_queue_distress_sound(counters, things, record)

		ThingData.write(things, offset + 1, (direction + random.next_u15() % 3 - 1) & 3)
		counters.turned_sailboats += 1

		return

	var route_state := _route_state(
		buildings, flags, text, things, record, direction, map_edge
	)

	if route_state < 0:
		counters.removed_sailboats += 1
	elif route_state > 0:
		_move(text, things, record, direction, counters, map_edge)


static func _route_state(
	buildings: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int,
	map_edge: int = 128,
) -> int:
	var offset := record * RECORD_SIZE
	var next: Vector2i = (
		Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4)) + DIRECTIONS[direction]
	)
	var next_index := _index(next, map_edge)

	if next_index < 0:
		return 1

	if buildings[next_index] == TILE_MARINA:
		_remove(text, things, record, map_edge)

		return -1

	if buildings[next_index] == TILE_PIER or OverlayData.read(text, next_index) != 0:
		return 0

	return 1 if flags[next_index] & 0x04 != 0 else 0


static func _move(
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int,
	counters: MovingThingResult,
	map_edge: int = 128,
) -> void:
	var offset := record * RECORD_SIZE
	var subtile_x: int = int(ThingData.read(things, offset + 6)) + SUBTILE_X[direction]
	var subtile_y: int = int(ThingData.read(things, offset + 7)) + SUBTILE_Y[direction]
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

	if tile_delta != Vector2i.ZERO:
		var old_point := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
		var old_index := _index(old_point, map_edge)

		if old_index >= 0:
			OverlayData.write(text, old_index, 0)

		var next := old_point + tile_delta

		if next.x < 0 or next.x > map_edge - 2 or next.y < 0 or next.y > map_edge - 2:
			_remove(text, things, record, map_edge)
			counters.removed_sailboats += 1

			return

		ThingData.write(things, offset + 3, next.x)
		ThingData.write(things, offset + 4, next.y)
		OverlayData.write(text, _index(next, map_edge), OverlayData.thing_id(record))

	counters.moved_sailboats += 1


static func _remove(
	text: PackedByteArray, things: PackedByteArray, record: int,
	map_edge: int = 128,
) -> void:
	var offset := record * RECORD_SIZE
	ThingData.write(things, offset, 0)
	var point := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var index := _index(point, map_edge)

	if index >= 0:
		OverlayData.write(text, index, 0)


static func _queue_distress_sound(
	counters: MovingThingResult, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	counters.sound_events.append({
		"sound_id": SOUND_DISTRESS,
		"thing_type": int(ThingData.read(things, offset)),
		"record": record,
		"point": Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4)),
	})


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if (
		point.x < 0
		or point.x >= map_edge
		or point.y < 0
		or point.y >= map_edge
	):
		return -1

	return point.x * map_edge + point.y
