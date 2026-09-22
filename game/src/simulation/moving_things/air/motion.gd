class_name AirThingMotion
extends AirThingConstants


@warning_ignore_start("integer_division")


static func _remove_without_crash(
	text: PackedByteArray, things: PackedByteArray, record: int, map_edge: int
) -> void:
	var offset := record * RECORD_SIZE
	var point := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var index := _index(point, map_edge)

	if index >= 0 and OverlayData.read(text, index) == OverlayData.thing_id(record):
		OverlayData.write(text, index, ThingData.read(things, offset + 10))

	ThingData.write(things, offset, 0)


static func _convert_to_explosion(
	things: PackedByteArray, record: int, state: int, goal: int
) -> void:
	var offset := record * RECORD_SIZE
	ThingData.write(things, offset, TYPE_EXPLOSION)
	ThingData.write(things, offset + 1, 0)
	ThingData.write(things, offset + 2, state)
	ThingData.write(things, offset + 11, goal)


static func _move_thing_eight_way(
	thing_type: int,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int,
	map_edge: int = 128,
) -> int:
	return MovingThingMotion.move(int(THING_SPEEDS.get(thing_type, -1)), text, things, record, direction, map_edge)


static func _advance_air_direction(
	buildings: PackedByteArray, things: PackedByteArray, record: int,
	map_edge: int = 128,
) -> void:
	var offset := record * RECORD_SIZE
	var direction := int(ThingData.read(things, offset + 1)) & 7
	var current := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))

	if not _air_route_blocked(buildings, current, direction, map_edge):
		return

	for direction_offset in AIR_DIRECTION_OFFSETS:
		direction = (int(ThingData.read(things, offset + 1)) + int(direction_offset)) & 7

		if not _air_route_blocked(buildings, current, direction, map_edge):
			break

	ThingData.write(things, offset + 1, direction)


static func _air_route_blocked(
	buildings: PackedByteArray, current: Vector2i, direction: int,
	map_edge: int = 128,
) -> bool:
	var checked_index := _index(current + AIR_ROUTE_DELTAS[direction], map_edge)

	return checked_index >= 0 and buildings[checked_index] >= BuildingTileIds.PLYMOUTH_ARCOLOGY


static func _turn_one_step(direction: int, target: int) -> int:
	if direction <= target:
		return (direction - 1) & 7 if target - direction > 4 else (direction + 1) & 7

	return (direction + 1) & 7 if direction - target > 4 else (direction - 1) & 7


static func _random_direction_step(direction: int, divisor: int, random: SimRandom) -> int:
	if random.next_u15() % divisor == 0:
		return (direction + random.next_u15() % 3 - 1) & 7

	return direction


static func _steer_direction(direction: int, start: Vector2i, target: Vector2i) -> int:
	var desired := MovingThingMotion.direction_between(start, target)

	return direction if desired == direction else _turn_one_step(direction, desired)


static func _thing_distance(start: Vector2i, target: Vector2i) -> int:
	return absi(target.x - start.x) + absi(target.y - start.y)


static func _queue_thing_sound(
	counters: MovingThingResult, sound_id: int, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	counters.sound_events.append(SoundEvent.for_thing(sound_id, int(ThingData.read(things, offset)), record,
		Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))))


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.x >= map_edge or point.y < 0 or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y
