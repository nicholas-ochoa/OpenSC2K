class_name AirThingTick
extends AirThingConstants


@warning_ignore_start("integer_division")


const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

static func update_airplane(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	counters: MovingThingResult,
	map_edge: int = 128,
	no_disasters := false,
	no_accidents := false,
) -> void:
	var offset := record * RECORD_SIZE
	var current := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var current_index := AirThingMotion._index(current, map_edge)
	var direction := int(ThingData.read(things, offset + 1))

	if current_index < 0 or direction < 0 or direction >= EIGHT_DIRECTIONS.size():
		MovingThingMotion.remove(text, things, record, map_edge)
		counters.removed_airplanes += 1
		counters.malformed_records += 1

		return

	var building := int(buildings[current_index])

	# no_accidents blocks spontaneous collisions and landings. A plane already
	# falling from a disaster (state 7) still follows no_disasters.
	if not no_disasters and not no_accidents and building > Tiles.DEVELOPED_FIRST and zones[current_index] & 0x0f != 8:
		if building > Tiles.DESALINIZATION:
			AirThingMotion._convert_to_explosion(
				things, record, 5, 1 if lfsr_random.next_mod(16) == 0 else 0
			)
			counters.crashed_airplanes += 1

			return

		# building artwork height is part of aircraft physics
		var sprite_height: int = BUILDING_SPRITE_HEIGHTS[building - BUILDING_SPRITE_HEIGHTS_FIRST]

		if ThingData.read(things, offset + 5) < int(sprite_height / 3):
			AirThingMotion._convert_to_explosion(things, record, 5, 1)
			counters.crashed_airplanes += 1

			return

	var state: int = int(ThingData.read(things, offset + 2)) & 0x0f

	if no_disasters and state == 7:
		AirThingMotion._remove_without_crash(text, things, record, map_edge)
		counters.removed_airplanes += 1

		return

	match state:
		0:
			if AirThingMotion._move_thing_eight_way(TYPE_AIRPLANE, text, things, record, direction, map_edge) < 0:
				counters.removed_airplanes += 1

				return

			counters.moved_airplanes += 1

			if ThingData.read(things, offset + 5) == 0:
				AirThingMotion._queue_thing_sound(counters, SOUND_AIRPLANE_TAKEOFF, things, record)

			if ThingData.read(things, offset + 5) < 14:
				ThingData.write(things, offset + 5, ThingData.read(things, offset + 5) + (1))
			else:
				ThingData.write(things, offset + 2, 2)
		1:
			if AirThingMotion._move_thing_eight_way(TYPE_AIRPLANE, text, things, record, direction, map_edge) < 0:
				counters.removed_airplanes += 1

				return

			counters.moved_airplanes += 1
			ThingData.write(things, offset + 5, (int(ThingData.read(things, offset + 5)) - 1) & 0xff)

			if ThingData.read(things, offset + 5) == 0:
				AirThingMotion._queue_thing_sound(counters, SOUND_AIRPLANE_LANDING, things, record)
				current = Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
				current_index = AirThingMotion._index(current, map_edge)

				if current_index >= 0:
					OverlayData.write(text, current_index, ThingData.read(things, offset + 10))

				if current_index < 0 or buildings[current_index] != Tiles.RUNWAY:
					if no_disasters or no_accidents:
						AirThingMotion._remove_without_crash(text, things, record, map_edge)
						counters.removed_airplanes += 1

						return

					AirThingMotion._convert_to_explosion(things, record, 5, 1)
					counters.crashed_airplanes += 1
				else:
					MovingThingMotion.remove(text, things, record, map_edge)
					counters.removed_airplanes += 1
					counters.landed_airplanes += 1
		2:
			direction = AirThingMotion._random_direction_step(direction, 5, random)
			ThingData.write(things, offset + 1, direction)
			AirThingMotion._advance_air_direction(buildings, things, record, map_edge)
			direction = int(ThingData.read(things, offset + 1))

			if AirThingMotion._move_thing_eight_way(TYPE_AIRPLANE, text, things, record, direction, map_edge) < 0:
				counters.removed_airplanes += 1

				return

			counters.moved_airplanes += 1
		3:
			var target := Vector2i(ThingData.read(things, offset + 8), ThingData.read(things, offset + 9))
			var planned_direction := MovingThingMotion.direction_quadrant(current, target)
			ThingData.write(things, offset + 1, planned_direction)
			AirThingMotion._advance_air_direction(buildings, things, record, map_edge)
			direction = int(ThingData.read(things, offset + 1))

			if AirThingMotion._move_thing_eight_way(TYPE_AIRPLANE, text, things, record, direction, map_edge) < 0:
				counters.removed_airplanes += 1

				return

			counters.moved_airplanes += 1
			current = Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))

			if AirThingMotion._thing_distance(current, target) < 2:
				var runway_axis: int = int(ThingData.read(things, offset + 2)) >> 4
				ThingData.write(things, offset + 1, AirThingMotion._turn_one_step(planned_direction, runway_axis))
				ThingData.write(things, offset + 2, runway_axis * 0x10 + 4)
				_adjust_airplane_target(things, offset, runway_axis)
		4:
			var target := Vector2i(ThingData.read(things, offset + 8), ThingData.read(things, offset + 9))
			direction = AirThingMotion._steer_direction(direction, current, target)
			ThingData.write(things, offset + 1, direction)

			if AirThingMotion._move_thing_eight_way(TYPE_AIRPLANE, text, things, record, direction, map_edge) < 0:
				counters.removed_airplanes += 1

				return

			counters.moved_airplanes += 1
			current = Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))

			if AirThingMotion._thing_distance(current, target) < 2:
				var runway_axis: int = int(ThingData.read(things, offset + 2)) >> 4
				ThingData.write(things, offset + 1, runway_axis)
				ThingData.write(things, offset + 2, 1)

				match runway_axis:
					1, 5:
						ThingData.write(things, offset + 3, ThingData.read(things, offset + 8))
					3, 7:
						ThingData.write(things, offset + 4, ThingData.read(things, offset + 9))
		7:
			if ThingData.read(things, offset + 5) != 0:
				ThingData.write(things, offset + 5, ThingData.read(things, offset + 5) - (1))

				if ThingData.read(things, offset + 5) == 8:
					AirThingMotion._queue_thing_sound(counters, SOUND_AIR_DISASTER, things, record)

				var old_direction := direction
				ThingData.write(things, offset + 1, (direction + 1) & 7)

				if AirThingMotion._move_thing_eight_way(
					TYPE_AIRPLANE, text, things, record, old_direction, map_edge
				) < 0:
					counters.removed_airplanes += 1

					return

				counters.moved_airplanes += 1
			else:
				AirThingMotion._convert_to_explosion(things, record, 5, 1)
				counters.crashed_airplanes += 1


static func _adjust_airplane_target(
	things: PackedByteArray, offset: int, runway_axis: int
) -> void:
	match runway_axis:
		1:
			ThingData.write(things, offset + 9, (int(ThingData.read(things, offset + 9)) - 6))
		3:
			ThingData.write(things, offset + 8, (int(ThingData.read(things, offset + 8)) + 6))
		5:
			ThingData.write(things, offset + 9, (int(ThingData.read(things, offset + 9)) + 6))
		7:
			ThingData.write(things, offset + 8, (int(ThingData.read(things, offset + 8)) - 6))


static func update_helicopter(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	traffic: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	city_center: Vector2i,
	random: SimRandom,
	counters: MovingThingResult,
	map_edge: int = 128,
	no_disasters := false,
	no_accidents := false,
) -> void:
	var offset := record * RECORD_SIZE
	var current := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
	var current_index := AirThingMotion._index(current, map_edge)
	var direction := int(ThingData.read(things, offset + 1))

	if current_index < 0 or direction < 0 or direction >= EIGHT_DIRECTIONS.size():
		MovingThingMotion.remove(text, things, record, map_edge)
		counters.removed_helicopters += 1
		counters.malformed_records += 1

		return

	if no_disasters and ThingData.read(things, offset + 2) == 5:
		AirThingMotion._remove_without_crash(text, things, record, map_edge)
		counters.removed_helicopters += 1

		return

	if not no_disasters and not no_accidents and buildings[current_index] > Tiles.DESALINIZATION:
		AirThingMotion._convert_to_explosion(things, record, 5, 0)
		counters.crashed_helicopters += 1

		return

	match int(ThingData.read(things, offset + 2)):
		0:
			ThingData.write(things, offset + 1, (direction + 1) & 7)

			if ThingData.read(things, offset + 5) < 10:
				ThingData.write(things, offset + 5, ThingData.read(things, offset + 5) + (1))
			else:
				ThingData.write(things, offset + 2, 2)
		2:
			var target := Vector2i(ThingData.read(things, offset + 8), ThingData.read(things, offset + 9))
			direction = AirThingMotion._steer_direction(direction, current, target)
			ThingData.write(things, offset + 1, direction)
			AirThingMotion._advance_air_direction(buildings, things, record, map_edge)
			direction = int(ThingData.read(things, offset + 1))
			var motion := AirThingMotion._move_thing_eight_way(
				TYPE_HELICOPTER, text, things, record, direction, map_edge
			)

			if motion < 0:
				counters.removed_helicopters += 1

				return

			counters.moved_helicopters += 1
			current = Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
			var traffic_index := CityDataGrid.index(traffic, map_edge, current.x, current.y)

			if traffic[traffic_index] > 0xa9:
				counters.traffic_news_checks += 1

				if counters.traffic_news_deadline_msec < counters.traffic_news_time_msec:
					counters.traffic_news_deadline_msec = (
						counters.traffic_news_time_msec + HELICOPTER_SOUND_DELAY_MSEC
					)
					AirThingMotion._queue_thing_sound(counters, SOUND_HELICOPTER, things, record)

			if AirThingMotion._thing_distance(current, target) < 2:
				var target_x: int = (random.next_u15() & 0x3f) - 0x20 + city_center.x
				var target_y: int = (random.next_u15() & 0x3f) - 0x20 + city_center.y

				if target_x < 0 or target_x >= map_edge:
					target_x = random.next_u15() % (map_edge / 2) + (map_edge / 4)

				if target_y < 0 or target_y >= map_edge:
					target_y = random.next_u15() % (map_edge / 2) + (map_edge / 4)

				ThingData.write(things, offset + 8, target_x)
				ThingData.write(things, offset + 9, target_y)

				if (
					random.next_u15() & 1
					and buildings[AirThingMotion._index(current, map_edge)] == Tiles.EMPTY
					and underground[AirThingMotion._index(current, map_edge)] == UndergroundTileIds.EMPTY
				):
					ThingData.write(things, offset + 2, 3)
		3:
			ThingData.write(things, offset + 1, (direction + 1) & 7)

			if ThingData.read(things, offset + 5) > 2:
				ThingData.write(things, offset + 5, ThingData.read(things, offset + 5) - (1))
			else:
				ThingData.write(things, offset + 2, 4)
		4:
			if random.next_u15() % 20 == 0:
				ThingData.write(things, offset + 2, 0)
		5:
			ThingData.write(things, offset + 1, (direction + 2) & 7)

			if ThingData.read(things, offset + 5) == 4:
				AirThingMotion._queue_thing_sound(counters, SOUND_AIR_DISASTER, things, record)

			if ThingData.read(things, offset + 5) > 2:
				ThingData.write(things, offset + 5, ThingData.read(things, offset + 5) - (1))
			else:
				AirThingMotion._convert_to_explosion(things, record, 0x11, 1)
				counters.crashed_helicopters += 1
