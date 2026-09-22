class_name DisasterThingActions
extends DisasterThingConstants



const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

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
	counters: MovingThingResult
) -> void:
	var map_edge: int = city.map_size if city != null else 128
	var point := current + Vector2i.ONE
	var index := _index(point, map_edge)

	if index < 0:
		return

	var building := int(buildings[index])
	var goal := int(ThingData.read(things, offset + 11))

	if goal == 0:
		if building <= Tiles.RADIOACTIVE_WASTE:
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

	if flags[index] & 0x04 or building <= Tiles.SMALL_PARK or building == Tiles.WIND_POWER:
		return

	var demolition := DemolishStructures._demolish_point(
		city, altitude, buildings, terrain, zones, underground,
		flags, text, labels, microsims, misc, point, random, true, true, false
	)

	if not demolition.changed:
		return

	match goal:
		1:
			NetworkState.replace_building(
				buildings, zones, misc, index, (random.next_u15() & 3) + 9
			)
		2:
			Landscape._place_water(
				buildings, terrain, zones, flags, altitude, text, misc, point, map_edge
			)
		3:
			var overlay_id := BuildingFacilities.provision_microsim(
				microsims, labels, text, Tiles.WIND_POWER, city.current_year(), random
			)
			NetworkState.replace_building(buildings, zones, misc, index, Tiles.WIND_POWER)
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


static func _random_direction_step(direction: int, divisor: int, random: SimRandom) -> int:
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
	counters: MovingThingResult, sound_id: int, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	counters.sound_events.append(SoundEvent.for_thing(sound_id, int(ThingData.read(things, offset)), record,
		Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))))


static func _record_connection_count_change(
	counters: MovingThingResult, tile_id: int, point: Vector2i
) -> void:
	var is_commerce := (
		(tile_id >= Tiles.ROAD_STRAIGHT_1 and tile_id <= Tiles.ROAD_CROSSROADS)
		or (tile_id >= Tiles.TUNNEL_ENTRANCE_1 and tile_id <= Tiles.ROAD_RAIL_CROSSING_2)
		or tile_id == Tiles.HIGHWAY_ROAD_CROSSING_1
		or tile_id == Tiles.HIGHWAY_ROAD_CROSSING_2
		or (tile_id >= Tiles.HIGHWAY_ONRAMP_1 and tile_id <= Tiles.HIGHWAY_ONRAMP_4)
	)
	counters.connection_count_changes.append(MovingThingResult.ConnectionChange.new(
		"commerce" if is_commerce else "industry", -1, point))


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.x >= map_edge or point.y < 0 or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y
