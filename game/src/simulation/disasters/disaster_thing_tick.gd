class_name DisasterThingTick
extends DisasterThingConstants



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
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	allow_disaster_damage: bool,
	counters: Dictionary
) -> void:
	var map_edge: int = city.map_size if city != null else 128
	var offset := record * RECORD_SIZE
	var frame := int(ThingData.read(things, offset + 1))
	var disaster_type := int(ThingData.read(things, offset + 2))

	if frame == 0:
		DisasterThingActions._queue_thing_sound(counters, SOUND_EXPLOSION, things, record)

	if frame < 2:
		ThingData.write(things, offset + 1, (frame + 1) & 0xff)

		return

	var center := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var center_index := DisasterThingActions._index(center, map_edge)
	DisasterThingActions._remove_thing(text, things, record, map_edge)
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
			DisasterThingActions._record_connection_count_change(counters, buildings[DisasterThingActions._index(damaged, map_edge)], damaged)
		elif damage_result == 2:
			caused_damage = true
			counters.rubble_explosion_hits += 1
		elif damage_result == 3:
			caused_damage = true
			counters.damaged_facilities += 1
			counters.spread_explosion_fires += 1

	if caused_damage and city.city_mode() != 2:
		var requested_type := disaster_type if disaster_type != 0 else 1
		DisasterThingActions._write_u32_be(misc, MISC_PENDING_DISASTER, requested_type)
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
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	counters: Dictionary
) -> void:
	var map_edge: int = city.map_size if city != null else 128
	var offset := record * RECORD_SIZE
	var current := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var current_index := DisasterThingActions._index(current, map_edge)
	var direction := int(ThingData.read(things, offset + 1))

	if current_index < 0 or direction < 0 or direction >= EIGHT_DIRECTIONS.size():
		DisasterThingActions._remove_thing(text, things, record, map_edge)
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
			move_direction = DisasterThingActions._direction_quadrant(current, city_center)
		1:
			if random.next_u15() % 25 == 0:
				ThingData.write(things, offset + 2, 2)

			ThingData.write(things, offset + 8, random.next_u15() & 0x7f)
			ThingData.write(things, offset + 9, random.next_u15() & 0x7f)
			move_direction = DisasterThingActions._random_direction_step(direction, 5, random)
			DisasterThingActions._monster_damage(
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
			move_direction = DisasterThingActions._random_direction_step(direction, 5, random)
		3:
			ThingData.write(things, offset + 8, 0)
			ThingData.write(things, offset + 9, 0)

			if random.next_u15() & 1:
				ThingData.write(things, offset + 8, 36)
				ThingData.write(things, offset + 9, 36)

			if lfsr_random.next_mod(100) == 0:
				DisasterThingActions._remove_thing(text, things, record, map_edge)
				counters.removed_monsters += 1

				return
		_:
			DisasterThingActions._remove_thing(text, things, record, map_edge)
			counters.removed_monsters += 1
			counters.malformed_records += 1

			return

	if ThingData.read(things, offset + 2) != 3:
		var military_point: Vector2i = current + EIGHT_DIRECTIONS[move_direction]
		var military_index := DisasterThingActions._index(military_point, map_edge)

		if military_index >= 0:
			var overlay := int(OverlayData.read(text, military_index))

			if OverlayData.is_thing(overlay):
				var target_record := OverlayData.thing_record(overlay)

				if ThingData.read(things, target_record * RECORD_SIZE) == 14:
					ThingData.write(things, offset + 2, 3)
					counters.monster_military_collisions += 1

					return

	ThingData.write(things, offset + 1, move_direction)

	if DisasterThingActions._move_thing_eight_way(TYPE_MONSTER, text, things, record, move_direction, map_edge) < 0:
		counters.removed_monsters += 1

		return

	counters.moved_monsters += 1

	if ThingData.read(things, offset + 8) & 0x80:
		DisasterThingActions._queue_thing_sound(counters, SOUND_MONSTER_DAMAGE, things, record)


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
	random: SimRandom,
	counters: Dictionary
) -> void:
	var map_edge: int = city.map_size if city != null else 128
	var offset := record * RECORD_SIZE
	var current := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var index := DisasterThingActions._index(current, map_edge)
	var direction := int(ThingData.read(things, offset + 1))

	if index < 0 or direction < 0 or direction >= EIGHT_DIRECTIONS.size():
		DisasterThingActions._remove_thing(text, things, record, map_edge)
		counters.removed_tornadoes += 1
		counters.malformed_records += 1

		return

	var building := int(buildings[index])

	if building > 5:
		var demolition := DemolishStructures._demolish_point(
			city, altitude, buildings, terrain, zones, underground,
			flags, text, labels, microsims, misc, current, random, true, true, false
		)

		if demolition.get("changed", false):
			counters.tornado_demolitions += 1

	var first_direction: int = (
		direction + random.next_u15() % 3 - random.next_u15() % 3
	) & 7

	if DisasterThingActions._move_thing_eight_way(TYPE_TORNADO, text, things, record, first_direction, map_edge) < 0:
		counters.removed_tornadoes += 1

		return

	counters.moved_tornadoes += 1

	if random.next_u15() & 0xff == 0:
		DisasterThingActions._remove_thing(text, things, record, map_edge)
		counters.removed_tornadoes += 1

		return

	if building >= 0x0d:
		return

	var second_direction: int = (
		direction + (random.next_u15() & 1) - (random.next_u15() & 1)
	) & 7

	if DisasterThingActions._move_thing_eight_way(TYPE_TORNADO, text, things, record, second_direction, map_edge) < 0:
		counters.removed_tornadoes += 1

		return

	counters.moved_tornadoes += 1

	if random.next_u15() & 0xff == 0:
		DisasterThingActions._remove_thing(text, things, record, map_edge)
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
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	counters: Dictionary
) -> void:
	DisasterThingActions._monster_damage(
		city, altitude, buildings, terrain, zones, underground, flags, traffic, text, labels, microsims, misc,
		things, offset, current, random, lfsr_random, counters
	)


static func _remove_thing(
	text: PackedByteArray, things: PackedByteArray, record: int,
	map_edge: int = 128,
) -> void:
	DisasterThingActions._remove_thing(text, things, record, map_edge)


static func _move_thing_eight_way(
	thing_type: int,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int,
	map_edge: int = 128,
) -> int:
	return DisasterThingActions._move_thing_eight_way(thing_type, text, things, record, direction, map_edge)


static func _random_direction_step(direction: int, divisor: int, random: SimRandom) -> int:
	return DisasterThingActions._random_direction_step(direction, divisor, random)


static func _direction_quadrant(start: Vector2i, target: Vector2i) -> int:
	return DisasterThingActions._direction_quadrant(start, target)


static func _queue_thing_sound(
	counters: Dictionary, sound_id: int, things: PackedByteArray, record: int
) -> void:
	DisasterThingActions._queue_thing_sound(counters, sound_id, things, record)


static func _write_u32_be(data: PackedByteArray, offset: int, value: int) -> void:
	DisasterThingActions._write_u32_be(data, offset, value)


static func _record_connection_count_change(
	counters: Dictionary, tile_id: int, point: Vector2i
) -> void:
	DisasterThingActions._record_connection_count_change(counters, tile_id, point)


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	return DisasterThingActions._index(point, map_edge)
