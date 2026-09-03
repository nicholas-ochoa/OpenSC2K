class_name DisasterMapFireFlood
extends DisasterMapConstants


static func run_fire(city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom) -> DisasterMapResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return DisasterMapResult.failure("city is invalid")

	if random == null:
		return DisasterMapResult.failure("a compatible process random generator is required")

	if lfsr_random == null:
		return DisasterMapResult.failure("a compatible LFSR generator is required")

	var original := DisasterMapState._map_payloads(city)

	if original.is_empty():
		return DisasterMapResult.failure("fire-map input chunks are missing or invalid")

	var payloads := DisasterMapState._duplicate_payloads(original)
	var counters: Dictionary[String, int] = {
		"fire_markers_scanned": 0,
		"fire_updates": 0,
		"spread_attempts": 0,
		"spread_fires": 0,
		"water_extinctions": 0,
		"coverage_extinctions": 0,
		"structure_collapses": 0,
		"created_explosions": 0,
		"toxic_markers": 0,
	}
	var runtime_events := DisasterMapDamage.new_runtime_events()
	var active := false

	for x in map_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y in map_edge:
			if city.simulation_slice != null and (y & 15) == 0:
				city.simulation_slice.checkpoint()

			var index := x * map_edge + y

			if OverlayData.read(payloads.XTXT, index) != FIRE_OVERLAY:
				continue

			active = true
			counters.fire_markers_scanned += 1

			if random.next_u15() & 3 != 0:
				continue

			counters.fire_updates += 1

			if payloads.XBIT[index] & 0x04 != 0:
				OverlayData.write(payloads.XTXT, index, 0)
				counters.water_extinctions += 1
				continue

			var point := Vector2i(x, y)
			var choice: int = random.next_u15() & 7

			if choice < 4:
				counters.spread_attempts += 1
				var target: Vector2i = point + CARDINAL_DIRECTIONS[choice]

				if _starts_fire(
					_apply_damage(
						city, payloads, target, random, lfsr_random, runtime_events
					)
				):
					counters.spread_fires += 1
			elif choice == 5:
				var tile := int(payloads.XBLD[index])

				if tile > 0x6f:
					var toxic_site := Rect2i()

					if SPECIAL_TOXIC_BUILDINGS.has(tile):
						toxic_site = DisasterMapState._building_site(city, payloads, point, tile)

					DisasterMapState._collapse_structure(city, payloads, point, tile, random, lfsr_random)
					counters.structure_collapses += 1

					if lfsr_random.next_mask(0x0f) == 0 and DisasterMapState._spawn_explosion(
						payloads.XTXT, payloads.XTHG, point, 0, 0, 1, map_edge
					):
						counters.created_explosions += 1

					if SPECIAL_TOXIC_BUILDINGS.has(tile):
						counters.toxic_markers += DisasterMapState._seed_special_toxic(payloads, toxic_site, point, map_edge)
			else:
				var coverage := int(payloads.XFIR[CityDataGrid.index(payloads.XFIR, map_edge, x, y)]) + 8

				if (random.next_u15() & 0xff) < coverage:
					DisasterMapState._collapse_structure(
						city, payloads, point, int(payloads.XBLD[index]), random, lfsr_random
					)
					counters.coverage_extinctions += 1

	var map_changed := DisasterMapState._payloads_changed(original, payloads)

	if map_changed and not DisasterMapState._apply_map_payloads(city, original, payloads):
		return DisasterMapResult.failure("cannot store the fire-map tick")

	var result := DisasterMapResult.new()
	result.counters = counters
	result.ok = true
	result.error = ""
	result.active = active
	counters["remaining_fires"] = OverlayData.occurrences(payloads.XTXT, FIRE_OVERLAY)
	result.map_changed = map_changed
	result.news_items = []
	result.effect_events = runtime_events.effect_events
	var sound_events: Array[int] = runtime_events.sound_events

	if active:
		sound_events.append(SOUND_FIRE)

	result.sound_events = sound_events
	result.view_center_requests = []
	result.complete = true

	return result


static func run_flood(
	city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom, map_counter: int
) -> DisasterMapResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return DisasterMapResult.failure("city is invalid")

	if random == null:
		return DisasterMapResult.failure("a compatible process random generator is required")

	if lfsr_random == null:
		return DisasterMapResult.failure("a compatible LFSR generator is required")

	var original := DisasterMapState._map_payloads(city)

	if original.is_empty():
		return DisasterMapResult.failure("flood-map input chunks are missing or invalid")

	var payloads := DisasterMapState._duplicate_payloads(original)
	var counter := maxi(map_counter - 1, 0)
	var counters: Dictionary[String, int] = {
		"flood_markers_scanned": 0,
		"flood_updates": 0,
		"spread_attempts": 0,
		"spread_floods": 0,
		"expired_floods": 0,
		"random_extinctions": 0,
		"damaged_structures": 0,
	}
	var runtime_events := DisasterMapDamage.new_runtime_events()
	var active := false

	for x in map_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y in map_edge:
			if city.simulation_slice != null and (y & 15) == 0:
				city.simulation_slice.checkpoint()

			var index := x * map_edge + y

			if OverlayData.read(payloads.XTXT, index) != 0xfc:
				continue

			active = true
			counters.flood_markers_scanned += 1

			if counter == 0 and lfsr_random.next_mask(1) != 0:
				OverlayData.write(payloads.XTXT, index, 0)
				counters.expired_floods += 1
				continue

			var update := counter > 51

			if not update:
				update = random.next_u15() & 3 == 0

			if not update:
				continue

			counters.flood_updates += 1
			var point := Vector2i(x, y)

			if counter < 30 and random.next_u15() & 3 == 0:
				if payloads.XBLD[index] > 0x6f:
					DisasterMapDamage.burn_structure(
						city,
						payloads.ALTM,
						payloads.XBLD,
						payloads.XTER,
						payloads.XZON,
						payloads.XUND,
						payloads.XBIT,
						payloads.XTXT,
						payloads.XLAB,
						payloads.XMIC,
						payloads.MISC,
						point,
						random,
						lfsr_random,
						false,
						false
					)
					counters.damaged_structures += 1

				OverlayData.write(payloads.XTXT, index, 0)
				counters.random_extinctions += 1

			if counter > 0:
				counters.spread_attempts += 1
				var target: Vector2i = point + CARDINAL_DIRECTIONS[random.next_u15() & 3]

				if _apply_flood_damage(
					city,
					payloads,
					target,
					DisasterMapState._altitude_word(payloads.ALTM, index) & 0x1f,
					random,
					lfsr_random,
					runtime_events,
				) == 1:
					counters.spread_floods += 1

	var map_changed := DisasterMapState._payloads_changed(original, payloads)

	if map_changed and not DisasterMapState._apply_map_payloads(city, original, payloads):
		return DisasterMapResult.failure("cannot store the flood-map tick")

	var sound_events: Array[int] = runtime_events.sound_events

	if active and random.next_u15() & 7 == 0:
		sound_events.append(SOUND_FLOOD)

	var result := DisasterMapResult.new()
	result.counters = counters
	result.ok = true
	result.error = ""
	result.active = active
	counters["remaining_floods"] = OverlayData.occurrences(payloads.XTXT, 0xfc)
	result.map_counter = counter
	result.map_changed = map_changed
	result.news_items = []
	result.effect_events = runtime_events.effect_events
	result.sound_events = sound_events
	result.view_center_requests = []
	result.complete = true

	return result


static func _process_fire_cell(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	index: int,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	counters: Dictionary,
	runtime_events: DisasterDamage.RuntimeEvents,
) -> void:
	var map_edge: int = city.map_size if city != null else 128
	counters.fire_markers_scanned += 1

	if random.next_u15() & 3 != 0:
		return

	counters.fire_updates += 1

	if payloads.XBIT[index] & 0x04 != 0:
		OverlayData.write(payloads.XTXT, index, 0)
		counters.water_extinctions += 1

		return

	var choice: int = random.next_u15() & 7

	if choice < 4:
		counters.spread_attempts += 1
		var target: Vector2i = point + CARDINAL_DIRECTIONS[choice]

		if _starts_fire(
			_apply_damage(city, payloads, target, random, lfsr_random, runtime_events)
		):
			counters.spread_fires += 1
	elif choice == 5:
		var tile := int(payloads.XBLD[index])

		if tile > 0x6f:
			var toxic_site := Rect2i()

			if SPECIAL_TOXIC_BUILDINGS.has(tile):
				toxic_site = DisasterMapState._building_site(city, payloads, point, tile)

			DisasterMapState._collapse_structure(city, payloads, point, tile, random, lfsr_random)
			counters.structure_collapses += 1

			if lfsr_random.next_mask(0x0f) == 0 and DisasterMapState._spawn_explosion(
				payloads.XTXT, payloads.XTHG, point, 0, 0, 1, map_edge
			):
				counters.created_explosions += 1

			if SPECIAL_TOXIC_BUILDINGS.has(tile):
				counters.toxic_markers += DisasterMapState._seed_special_toxic(payloads, toxic_site, point, map_edge)
	else:
		var coverage := int(payloads.XFIR[CityDataGrid.index(payloads.XFIR, map_edge, point.x, point.y)]) + 8

		if (random.next_u15() & 0xff) < coverage:
			DisasterMapState._collapse_structure(
				city, payloads, point, int(payloads.XBLD[index]), random, lfsr_random
			)
			counters.coverage_extinctions += 1


static func _process_flood_cell(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	index: int,
	counter: int,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	counters: Dictionary,
	runtime_events: DisasterDamage.RuntimeEvents,
) -> void:
	counters.flood_markers_scanned += 1

	if counter == 0 and lfsr_random.next_mask(1) != 0:
		OverlayData.write(payloads.XTXT, index, 0)
		counters.expired_floods += 1

		return

	var update := counter > 51

	if not update:
		update = random.next_u15() & 3 == 0

	if not update:
		return

	counters.flood_updates += 1

	if counter < 30 and random.next_u15() & 3 == 0:
		if payloads.XBLD[index] > 0x6f:
			DisasterMapDamage.burn_structure(
				city,
				payloads.ALTM,
				payloads.XBLD,
				payloads.XTER,
				payloads.XZON,
				payloads.XUND,
				payloads.XBIT,
				payloads.XTXT,
				payloads.XLAB,
				payloads.XMIC,
				payloads.MISC,
				point,
				random,
				lfsr_random,
				false,
				false
			)
			counters.damaged_structures += 1

		OverlayData.write(payloads.XTXT, index, 0)
		counters.random_extinctions += 1

	if counter > 0:
		counters.flood_spread_attempts += 1
		var target: Vector2i = point + CARDINAL_DIRECTIONS[random.next_u15() & 3]

		if _apply_flood_damage(
			city,
			payloads,
			target,
			DisasterMapState._altitude_word(payloads.ALTM, index) & 0x1f,
			random,
			lfsr_random,
			runtime_events,
		) == 1:
			counters.spread_floods += 1


static func _apply_damage(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	runtime_events: DisasterDamage.RuntimeEvents = null,
) -> int:
	return DisasterMapDamage.apply(
		city,
		payloads.ALTM,
		payloads.XBLD,
		payloads.XTER,
		payloads.XZON,
		payloads.XUND,
		payloads.XBIT,
		payloads.XTRF,
		payloads.XTXT,
		payloads.XLAB,
		payloads.XMIC,
		payloads.MISC,
		point,
		random,
		lfsr_random,
		false,
		runtime_events,
	)


static func _starts_fire(result_code: int) -> bool:
	return result_code == 1 or result_code == 3 or result_code == 4


static func _apply_flood_damage(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	maximum_altitude: int,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	runtime_events: DisasterDamage.RuntimeEvents = null,
) -> int:
	return DisasterMapDamage.apply_flood(
		city,
		payloads.ALTM,
		payloads.XBLD,
		payloads.XTER,
		payloads.XZON,
		payloads.XUND,
		payloads.XBIT,
		payloads.XTRF,
		payloads.XTXT,
		payloads.XLAB,
		payloads.XMIC,
		payloads.MISC,
		point,
		maximum_altitude,
		random,
		lfsr_random,
		runtime_events,
	)
