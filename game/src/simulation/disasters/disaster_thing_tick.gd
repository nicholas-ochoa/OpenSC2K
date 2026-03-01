class_name DisasterThingTick
extends RefCounted

const NetworkTiles = preload("res://src/tools/city/network_command.gd")
const Demolish = preload("res://src/tools/city/demolish_command.gd")
const Landscape = preload("res://src/tools/landscape/landscape_command.gd")
const Buildings = preload("res://src/tools/city/building_command.gd")
const DisasterMapDamage = preload("res://src/simulation/disasters/disaster_damage.gd")
const MAP_SIZE := CityState.MAP_SIZE
const RECORD_SIZE := CityState.THING_RECORD_SIZE
const FIRST_RECORD := 1
const LAST_RECORD := CityState.THING_COUNT - 1
const TEXT_LABEL_BASE := 201
const TYPE_AIRPLANE := 1
const TYPE_HELICOPTER := 2
const TYPE_MONSTER := 5
const TYPE_EXPLOSION := 6
const TYPE_TORNADO := 15
const SUBTILE_LIMIT := 16
const MISC_PENDING_DISASTER := 0x0070
const SOUND_EXPLOSION := 0x1f8
const SOUND_MONSTER_DAMAGE := 0x202
const EIGHT_DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]
const THING_SPEEDS := {
	TYPE_MONSTER: 8,
	TYPE_TORNADO: 8,
}


static func update_explosion(
	city: CityState,
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	traffic: PackedByteArray,
	text: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	misc: PackedByteArray,
	things: PackedByteArray,
	record: int,
	random,
	lfsr_random,
	allow_disaster_damage: bool,
	counters: Dictionary
) -> void:
	var map_edge: int = city.map_size if city != null else 128
	var offset := record * RECORD_SIZE
	var frame := int(ThingData.read(things, offset + 1))
	var disaster_type := int(ThingData.read(things, offset + 2))

	if frame == 0:
		_queue_thing_sound(counters, SOUND_EXPLOSION, things, record)

	if frame < 2:
		ThingData.write(things, offset + 1, (frame + 1) & 0xff)

		return

	var center := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var center_index := _index(center, map_edge)
	_remove_thing(text, things, record, map_edge)
	counters.removed_explosions += 1

	if center_index < 0:
		counters.malformed_records += 1

		return

	buildings[center_index] = 0

	if ThingData.read(things, offset + 11) == 0 or not allow_disaster_damage:
		return

	var caused_damage := false

	for _attempt in 4:
		var damaged := center + Vector2i(
			lfsr_random.next_mod(5) - 2,
			lfsr_random.next_mod(5) - 2
		)
		var damage_result := DisasterMapDamage.apply(
			city, altitude, buildings, terrain, zones, underground, flags,
			traffic, text, labels, microsims, misc, damaged, random, lfsr_random
		)

		if damage_result == 1:
			caused_damage = true
			counters.spread_explosion_fires += 1
		elif damage_result == 4:
			caused_damage = true
			counters.spread_explosion_fires += 1
			_record_connection_count_change(counters, buildings[_index(damaged, map_edge)], damaged)
		elif damage_result == 2:
			caused_damage = true
			counters.rubble_explosion_hits += 1
		elif damage_result == 3:
			caused_damage = true
			counters.damaged_facilities += 1
			counters.spread_explosion_fires += 1

	if caused_damage and city.city_mode() != 2:
		var requested_type := disaster_type if disaster_type != 0 else 1
		_write_u32_be(misc, MISC_PENDING_DISASTER, requested_type)
		counters.disaster_start_requests.append({
			"type": requested_type,
			"point": center,
		})


static func update_monster(
	city: CityState,
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	traffic: PackedByteArray,
	text: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	misc: PackedByteArray,
	things: PackedByteArray,
	record: int,
	city_center: Vector2i,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	var map_edge: int = city.map_size if city != null else 128
	var offset := record * RECORD_SIZE
	var current := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var current_index := _index(current, map_edge)
	var direction := int(ThingData.read(things, offset + 1))

	if current_index < 0 or direction < 0 or direction >= EIGHT_DIRECTIONS.size():
		_remove_thing(text, things, record, map_edge)
		counters.removed_monsters += 1
		counters.malformed_records += 1

		return

	if counters.active_airplanes > 0:
		for checked_record in range(FIRST_RECORD, ThingData.count(things)):
			var checked_offset := checked_record * RECORD_SIZE

			if ThingData.read(things, checked_offset) == TYPE_AIRPLANE:
				ThingData.write(things, checked_offset + 2, 7)
				counters.monster_forced_airplanes += 1

	if counters.active_helicopters > 0:
		for checked_record in range(FIRST_RECORD, ThingData.count(things)):
			var checked_offset := checked_record * RECORD_SIZE

			if ThingData.read(things, checked_offset) == TYPE_HELICOPTER:
				ThingData.write(things, checked_offset + 2, 5)
				counters.monster_forced_helicopters += 1

	var state := int(ThingData.read(things, offset + 2))
	var move_direction := direction

	match state:
		0:
			if ThingData.read(things, offset + 5) < 9:
				ThingData.write(things, offset + 2, 1)
			else:
				ThingData.write(things, offset + 5, ThingData.read(things, offset + 5) - (1))

			ThingData.write(things, offset + 8, 0)
			ThingData.write(things, offset + 9, 0)
			move_direction = _direction_quadrant(current, city_center)
		1:
			if random.next_u15() % 25 == 0:
				ThingData.write(things, offset + 2, 2)

			ThingData.write(things, offset + 8, random.next_u15() & 0x7f)
			ThingData.write(things, offset + 9, random.next_u15() & 0x7f)
			move_direction = _random_direction_step(direction, 5, random)
			_monster_damage(
				city, altitude, buildings, terrain, zones, underground,
				flags, traffic, text, labels, microsims, misc, things,
				offset, current, random, lfsr_random, counters
			)
		2:
			if ThingData.read(things, offset + 5) < 15:
				ThingData.write(things, offset + 5, ThingData.read(things, offset + 5) + (1))
			else:
				ThingData.write(things, offset + 2, 3 if random.next_u15() % 3 == 0 else 0)

			var animation: int = (random.next_u15() & 7) * 9
			ThingData.write(things, offset + 8, animation)
			ThingData.write(things, offset + 9, animation)
			move_direction = _random_direction_step(direction, 5, random)
		3:
			ThingData.write(things, offset + 8, 0)
			ThingData.write(things, offset + 9, 0)

			if random.next_u15() & 1:
				ThingData.write(things, offset + 8, 36)
				ThingData.write(things, offset + 9, 36)

			if lfsr_random.next_mod(100) == 0:
				_remove_thing(text, things, record, map_edge)
				counters.removed_monsters += 1

				return
		_:
			_remove_thing(text, things, record, map_edge)
			counters.removed_monsters += 1
			counters.malformed_records += 1

			return

	if ThingData.read(things, offset + 2) != 3:
		var military_point: Vector2i = current + EIGHT_DIRECTIONS[move_direction]
		var military_index := _index(military_point, map_edge)

		if military_index >= 0:
			var overlay := int(OverlayData.read(text, military_index))

			if OverlayData.is_thing(overlay):
				var target_record := OverlayData.thing_record(overlay)

				if ThingData.read(things, target_record * RECORD_SIZE) == 14:
					ThingData.write(things, offset + 2, 3)
					counters.monster_military_collisions += 1

					return

	ThingData.write(things, offset + 1, move_direction)

	if _move_thing_eight_way(TYPE_MONSTER, text, things, record, move_direction, map_edge) < 0:
		counters.removed_monsters += 1

		return

	counters.moved_monsters += 1

	if ThingData.read(things, offset + 8) & 0x80:
		_queue_thing_sound(counters, SOUND_MONSTER_DAMAGE, things, record)


static func update_tornado(
	city: CityState,
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	misc: PackedByteArray,
	things: PackedByteArray,
	record: int,
	random,
	counters: Dictionary
) -> void:
	var map_edge: int = city.map_size if city != null else 128
	var offset := record * RECORD_SIZE
	var current := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var index := _index(current, map_edge)
	var direction := int(ThingData.read(things, offset + 1))

	if index < 0 or direction < 0 or direction >= EIGHT_DIRECTIONS.size():
		_remove_thing(text, things, record, map_edge)
		counters.removed_tornadoes += 1
		counters.malformed_records += 1

		return

	var building := int(buildings[index])

	if building > 5:
		var demolition := Demolish._demolish_point(
			city, altitude, buildings, terrain, zones, underground,
			flags, text, labels, microsims, misc, current, random, true, true, false
		)

		if demolition.get("changed", false):
			counters.tornado_demolitions += 1

	var first_direction: int = (
		direction + random.next_u15() % 3 - random.next_u15() % 3
	) & 7

	if _move_thing_eight_way(TYPE_TORNADO, text, things, record, first_direction, map_edge) < 0:
		counters.removed_tornadoes += 1

		return

	counters.moved_tornadoes += 1

	if random.next_u15() & 0xff == 0:
		_remove_thing(text, things, record, map_edge)
		counters.removed_tornadoes += 1

		return

	if building >= 0x0d:
		return

	var second_direction: int = (
		direction + (random.next_u15() & 1) - (random.next_u15() & 1)
	) & 7

	if _move_thing_eight_way(TYPE_TORNADO, text, things, record, second_direction, map_edge) < 0:
		counters.removed_tornadoes += 1

		return

	counters.moved_tornadoes += 1

	if random.next_u15() & 0xff == 0:
		_remove_thing(text, things, record, map_edge)
		counters.removed_tornadoes += 1


static func _monster_damage(
	city: CityState,
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	traffic: PackedByteArray,
	text: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	misc: PackedByteArray,
	things: PackedByteArray,
	offset: int,
	current: Vector2i,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	var map_edge: int = city.map_size if city != null else 128
	var point := current + Vector2i.ONE
	var index := _index(point, map_edge)

	if index < 0:
		return

	var building := int(buildings[index])
	var goal := int(ThingData.read(things, offset + 11))

	if goal == 0:
		if building <= 5:
			return

		var damage_result := DisasterMapDamage.apply(
			city, altitude, buildings, terrain, zones, underground, flags,
			traffic, text, labels, microsims, misc, point, random, lfsr_random
		)

		if damage_result == 1:
			counters.spread_explosion_fires += 1
		elif damage_result == 3:
			counters.damaged_facilities += 1
			counters.spread_explosion_fires += 1
		elif damage_result == 4:
			counters.spread_explosion_fires += 1
			_record_connection_count_change(counters, buildings[index], point)

		if damage_result != 0 and damage_result != 2:
			ThingData.write(things, offset + 8, ThingData.read(things, offset + 8) | (0x80))
			counters.monster_damage_hits += 1

		return

	if flags[index] & 0x04 or building <= 0x0d or building == 200:
		return

	var demolition := Demolish._demolish_point(
		city, altitude, buildings, terrain, zones, underground,
		flags, text, labels, microsims, misc, point, random, true, true, false
	)

	if not demolition.get("changed", false):
		return

	match goal:
		1:
			NetworkTiles._replace_building(
				buildings, zones, misc, index, (random.next_u15() & 3) + 9
			)
		2:
			Landscape._place_water(
				buildings, terrain, zones, flags, altitude, text, misc, point, map_edge
			)
		3:
			var overlay_id := Buildings._provision_microsim(
				microsims, labels, text, 200, city.current_year(), random
			)
			NetworkTiles._replace_building(buildings, zones, misc, index, 200)
			zones[index] = 0xf0
			flags[index] = (flags[index] & 0x1f) | 0xe0

			if overlay_id != 0:
				OverlayData.write(text, index, overlay_id)
		_:
			pass

	ThingData.write(things, offset + 8, ThingData.read(things, offset + 8) | (0x80))
	counters.monster_damage_hits += 1


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


static func _queue_thing_sound(
	counters: Dictionary, sound_id: int, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	counters.sound_events.append({
		"sound_id": sound_id,
		"thing_type": int(ThingData.read(things, offset)),
		"record": record,
		"point": Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4)),
	})


static func _write_u32_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff


static func _record_connection_count_change(
	counters: Dictionary, tile_id: int, point: Vector2i
) -> void:
	var is_commerce := (
		(tile_id >= 0x1d and tile_id <= 0x2b)
		or (tile_id >= 0x3f and tile_id <= 0x46)
		or tile_id == 0x4b
		or tile_id == 0x4c
		or (tile_id >= 0x5d and tile_id <= 0x60)
	)
	counters.connection_count_changes.append({
		"kind": "commerce" if is_commerce else "industry",
		"delta": -1,
		"point": point,
	})


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.x >= map_edge or point.y < 0 or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y
