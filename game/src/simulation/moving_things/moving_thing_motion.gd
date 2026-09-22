class_name MovingThingMotion
extends RefCounted

@warning_ignore_start("integer_division")

const RECORD_SIZE := CityState.THING_RECORD_SIZE
const SUBTILE_LIMIT := 16
const DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]


static func direction_between(start: Vector2i, target: Vector2i) -> int:
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


static func direction_quadrant(start: Vector2i, target: Vector2i) -> int:
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


static func remove(
	text: PackedByteArray, things: PackedByteArray, record: int,
	map_edge: int = 128,
) -> void:
	var offset := record * RECORD_SIZE
	ThingData.write(things, offset, 0)
	var point := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var index := _index(point, map_edge)

	if index >= 0:
		OverlayData.write(text, index, 0)


static func move(
	speed: int,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int,
	map_edge: int = 128,
) -> int:
	if speed < 0 or direction < 0 or direction >= DIRECTIONS.size():
		remove(text, things, record, map_edge)

		return -1

	var offset := record * RECORD_SIZE
	var subtile_x: int = int(ThingData.read(things, offset + 6)) + DIRECTIONS[direction].x * speed
	var subtile_y: int = int(ThingData.read(things, offset + 7)) + DIRECTIONS[direction].y * speed
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
		remove(text, things, record, map_edge)

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
		remove(text, things, record, map_edge)

		return -1

	ThingData.write(things, offset + 3, next.x)
	ThingData.write(things, offset + 4, next.y)
	ThingData.write(things, offset + 10, OverlayData.read(text, next_index))
	OverlayData.write(text, next_index, OverlayData.thing_id(record))

	return 1


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.x >= map_edge or point.y < 0 or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y
