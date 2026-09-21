class_name ShipThingTick
extends RefCounted

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const RECORD_SIZE := CityState.THING_RECORD_SIZE
const TEXT_LABEL_BASE := 201
const TYPE_EXPLOSION := 6
const TILE_PIER := Tiles.PIER
const TILE_MARINA := Tiles.MARINA
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
	Tiles.SUSPENSION_BRIDGE_ONE: true, Tiles.SUSPENSION_BRIDGE_TWO: true, Tiles.SUSPENSION_BRIDGE_FOUR: true, Tiles.SUSPENSION_BRIDGE_FIVE: true, Tiles.RAISING_BRIDGE_CLOSED: true,
	Tiles.RAISING_BRIDGE_OPEN: true, Tiles.RAIL_BRIDGE_PYLON: true, Tiles.POWER_BRIDGE: true, Tiles.REINFORCED_HIGHWAY_BRIDGE: true,
}


static func update(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	ship_home: Vector2i,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	counters: MovingThingResult,
	map_edge: int = 128,
) -> void:
	var offset := record * RECORD_SIZE

	if random.next_u15() & 0xff == 0:
		_queue_sound(counters, things, record)

	var current := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var current_index := _index(current, map_edge)
	var direction := int(ThingData.read(things, offset + 1))

	if current_index < 0 or direction < 0 or direction >= DIRECTIONS.size():
		_convert_to_explosion(things, record)
		counters.crashed_ships += 1
		counters.malformed_records += 1

		return

	if flags[current_index] & 0x04 == 0:
		_convert_to_explosion(things, record)
		counters.crashed_ships += 1

		return

	var target := Vector2i(ThingData.read(things, offset + 8), ThingData.read(things, offset + 9))

	match int(ThingData.read(things, offset + 2)):
		0:
			if lfsr_random.next_mod(10) == 0:
				var turned := _steer_direction(direction, current, target)

				if _route_is_valid(
					buildings, underground, flags, text, current, turned, map_edge
				):
					direction = turned
					ThingData.write(things, offset + 1, direction)

			if _route_is_valid(
				buildings, underground, flags, text, current, direction, map_edge
			):
				if not _move(text, things, record, direction, map_edge):
					counters.removed_ships += 1

					return

				counters.moved_ships += 1
			else:
				ThingData.write(things, offset + 2, 1)

			for pier_delta in PIER_DELTAS:
				var pier_index := _index(current + pier_delta, map_edge)

				if pier_index >= 0 and buildings[pier_index] == TILE_PIER:
					ThingData.write(things, offset + 2, 3)
					counters.docked_ships += 1
		1:
			var desired := _direction_between(current, target)
			direction = _turn_one_step(direction, desired)
			ThingData.write(things, offset + 1, direction)

			if direction == desired:
				ThingData.write(things, offset + 2, (
					0
					if _route_is_valid(
						buildings, underground, flags, text, current, desired, map_edge
					)
					else 2
				))
		2:
			var offsets = (
				REVERSE_OFFSETS
				if lfsr_random.next_mod(2) == 0
				else DIRECTION_OFFSETS
			)
			var found := false

			for direction_offset in offsets.slice(0, 8):
				direction = (int(ThingData.read(things, offset + 1)) + int(direction_offset)) & 7

				if _route_is_valid(
					buildings, underground, flags, text, current, direction, map_edge
				):
					found = true
					break

			if not found:
				_remove(text, things, record, map_edge)
				counters.removed_ships += 1
				direction = (
					(int(ThingData.read(things, offset + 1)) + 2) & 7
					if offsets == REVERSE_OFFSETS
					else int(ThingData.read(things, offset + 1)) & 7
				)

			ThingData.write(things, offset + 1, direction)
			ThingData.write(things, offset + 2, 0)
		3:
			if lfsr_random.next_mod(30) == 0:
				ThingData.write(things, offset + 2, 4)
				_queue_sound(counters, things, record)
				counters.departing_ships += 1
				var home := ship_home if _index(ship_home, map_edge) >= 0 else current
				ThingData.write(things, offset + 8, home.x)
				ThingData.write(things, offset + 9, home.y)
		4:
			if _route_is_valid(
				buildings, underground, flags, text, current, direction, map_edge
			):
				if not _move(text, things, record, direction, map_edge):
					counters.removed_ships += 1

					return

				counters.moved_ships += 1

				return

			var start_offset: int = lfsr_random.next_mod(2)

			for order_index in range(start_offset, DIRECTION_OFFSETS.size()):
				direction = (
					int(ThingData.read(things, offset + 1)) + DIRECTION_OFFSETS[order_index]
				) & 7

				if _route_is_valid(
					buildings, underground, flags, text, current, direction, map_edge
				):
					break

			ThingData.write(things, offset + 1, direction)


static func _route_is_valid(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	current: Vector2i,
	direction: int,
	map_edge: int = 128,
) -> bool:
	var route_point: Vector2i = current + ROUTE_DELTAS[direction]
	var route_index := _index(route_point, map_edge)

	if route_index < 0:
		return true

	return (
		_is_water_route(buildings, underground, flags, route_index)
		and not OverlayData.blocks_thing(OverlayData.read(text, route_index))
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

	if underground_tile >= UndergroundTileIds.PIPE_FIRST and underground_tile <= UndergroundTileIds.PIPE_SUBWAY_ONE:
		return false

	var building := int(buildings[index])

	if building == TILE_MARINA:
		return false

	return building == 0 or ROUTE_BUILDINGS.has(building)


static func _move(
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int,
	map_edge: int = 128,
) -> bool:
	var offset := record * RECORD_SIZE
	var subtile_x: int = int(ThingData.read(things, offset + 6)) + ROUTE_DELTAS[direction].x
	var subtile_y: int = int(ThingData.read(things, offset + 7)) + ROUTE_DELTAS[direction].y
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

	ThingData.write(things, offset + 6, subtile_x)
	ThingData.write(things, offset + 7, subtile_y)

	if tile_delta == Vector2i.ZERO:
		return true

	var current := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var current_index := _index(current, map_edge)

	if current_index >= 0:
		OverlayData.write(text, current_index, ThingData.read(things, offset + 10))

	var next := current + tile_delta
	var next_index := _index(next, map_edge)

	if next_index < 0:
		ThingData.write(things, offset, 0)

		return false

	ThingData.write(things, offset + 3, next.x)
	ThingData.write(things, offset + 4, next.y)
	ThingData.write(things, offset + 10, OverlayData.read(text, next_index))
	OverlayData.write(text, next_index, OverlayData.thing_id(record))

	return true


static func _convert_to_explosion(things: PackedByteArray, record: int) -> void:
	var offset := record * RECORD_SIZE
	ThingData.write(things, offset, TYPE_EXPLOSION)
	ThingData.write(things, offset + 1, 0)
	ThingData.write(things, offset + 2, 0)
	ThingData.write(things, offset + 11, 0)


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


static func _queue_sound(
	counters: MovingThingResult, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	counters.sound_events.append(SoundEvent.for_thing(SOUND_SHIP, int(ThingData.read(things, offset)), record,
		Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))))


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


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if (
		point.x < 0
		or point.x >= map_edge
		or point.y < 0
		or point.y >= map_edge
	):
		return -1

	return point.x * map_edge + point.y
