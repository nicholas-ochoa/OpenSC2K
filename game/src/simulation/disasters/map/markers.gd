class_name DisasterMapMarkers
extends DisasterMapConstants


static func run_toxic(city: CityState, random, lfsr_random) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}

	if lfsr_random == null or not lfsr_random.has_method("next_mask"):
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	var original := DisasterMapState._map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "toxic-map input chunks are missing or invalid"}

	var payloads := DisasterMapState._duplicate_payloads(original)
	var counters := {
		"toxic_markers_scanned": 0,
		"toxic_updates": 0,
		"lfsr_expirations": 0,
		"water_expirations": 0,
		"moved_markers": 0,
		"blocked_moves": 0,
		"abandoned_structures": 0,
	}
	var active := false

	for x in map_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y in map_edge:
			if city.simulation_slice != null and (y & 15) == 0:
				city.simulation_slice.checkpoint()

			var index := x * map_edge + y

			if OverlayData.read(payloads.XTXT, index) != TOXIC_OVERLAY:
				continue

			active = true
			counters.toxic_markers_scanned += 1

			if random.next_u15() & 1 != 0:
				continue

			counters.toxic_updates += 1

			if lfsr_random.next_mask(0x3f) == 0:
				OverlayData.write(payloads.XTXT, index, 0)
				counters.lfsr_expirations += 1
				continue

			if payloads.XBIT[index] & 0x04 != 0 and random.next_u15() & 0x0f == 0:
				OverlayData.write(payloads.XTXT, index, 0)
				counters.water_expirations += 1
				continue

			var point := Vector2i(x, y)

			if _abandon_toxic_structure(city, payloads, point, random):
				counters.abandoned_structures += 1

			var direction := _lowest_toxic_direction(payloads.ALTM, point, map_edge)

			if direction < 0:
				direction = random.next_u15() & 3

			OverlayData.write(payloads.XTXT, index, 0)
			var target: Vector2i = point + CARDINAL_DIRECTIONS[direction]

			if DisasterMapState._place_toxic_marker(payloads.XTXT, target, map_edge):
				counters.moved_markers += 1
			else:
				counters.blocked_moves += 1

	var map_changed := DisasterMapState._payloads_changed(original, payloads)

	if map_changed and not DisasterMapState._apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the toxic-map tick"}

	counters["ok"] = true
	counters["error"] = ""
	counters["active"] = active
	counters["remaining_toxic"] = OverlayData.occurrences(payloads.XTXT, TOXIC_OVERLAY)
	counters["map_changed"] = map_changed
	counters["news_items"] = []
	counters["effect_events"] = []
	counters["sound_events"] = []
	counters["view_center_requests"] = []
	counters["complete"] = true

	return counters


static func run_riot(city: CityState, random, lfsr_random) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}

	if (
		lfsr_random == null
		or not lfsr_random.has_method("next_mask")
		or not lfsr_random.has_method("next_mod")
	):
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	var original := DisasterMapState._map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "riot-map input chunks are missing or invalid"}

	var payloads := DisasterMapState._duplicate_payloads(original)
	var counters := {
		"riot_markers_scanned": 0,
		"riot_updates": 0,
		"expired_riots": 0,
		"damage_attempts": 0,
		"started_fires": 0,
		"traffic_cells_cleared": 0,
		"propagated_riots": 0,
		"blocked_propagations": 0,
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
			var marker := int(OverlayData.read(payloads.XTXT, index))

			if marker != RIOT_OVERLAY_FORWARD and marker != RIOT_OVERLAY_REVERSE:
				continue

			active = true
			counters.riot_markers_scanned += 1

			if random.next_u15() & 3 != 0:
				continue

			counters.riot_updates += 1

			if random.next_u15() & 0xff == 0 or payloads.XBIT[index] & 0x04 != 0:
				OverlayData.write(payloads.XTXT, index, 0)
				counters.expired_riots += 1
				continue

			var traffic_index := CityDataGrid.index(payloads.XTRF, map_edge, x, y)

			if payloads.XTRF[traffic_index] != 0:
				counters.traffic_cells_cleared += 1

			payloads.XTRF[traffic_index] = 0
			var damage_direction: int = random.next_u15() & 0x7f

			if damage_direction < 4:
				counters.damage_attempts += 1

				if DisasterMapFireFlood._starts_fire(
					DisasterMapFireFlood._apply_damage(
						city,
						payloads,
						Vector2i(x, y) + CARDINAL_DIRECTIONS[damage_direction],
						random,
						lfsr_random,
						runtime_events,
					)
				):
					counters.started_fires += 1

			var first_direction: int = 0 if marker == RIOT_OVERLAY_REVERSE else 2
			var second_direction: int = 1 if marker == RIOT_OVERLAY_REVERSE else 3
			var connections := 0

			if _riot_supports(payloads.XBLD, Vector2i(x, y) + CARDINAL_DIRECTIONS[first_direction], map_edge):
				connections |= 1

			if _riot_supports(payloads.XBLD, Vector2i(x, y) + CARDINAL_DIRECTIONS[second_direction], map_edge):
				connections |= 2

			var opposite_marker: int = (
				RIOT_OVERLAY_FORWARD
				if marker == RIOT_OVERLAY_REVERSE
				else RIOT_OVERLAY_REVERSE
			)

			if connections == 0:
				OverlayData.write(payloads.XTXT, index, opposite_marker)
				continue

			OverlayData.write(payloads.XTXT, index, opposite_marker if random.next_u15() & 7 == 0 else 0)

			if connections == 3:
				connections = (random.next_u15() & 1) + 1

			var spread_direction: int = first_direction if connections == 1 else second_direction

			if _place_riot_marker(
				payloads.XTXT,
				Vector2i(x, y) + CARDINAL_DIRECTIONS[spread_direction],
				marker, map_edge,
			):
				counters.propagated_riots += 1
			else:
				counters.blocked_propagations += 1

	var map_changed := DisasterMapState._payloads_changed(original, payloads)

	if map_changed and not DisasterMapState._apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the riot-map tick"}

	var sound_events: Array[int] = runtime_events.sound_events

	if active and random.next_u15() & 7 == 0:
		sound_events.append(SOUND_RIOT)

	counters["ok"] = true
	counters["error"] = ""
	counters["active"] = active
	counters["remaining_riots"] = (
		OverlayData.occurrences(payloads.XTXT, RIOT_OVERLAY_FORWARD)
		+ OverlayData.occurrences(payloads.XTXT, RIOT_OVERLAY_REVERSE)
	)
	counters["map_changed"] = map_changed
	counters["news_items"] = []
	counters["effect_events"] = runtime_events.effect_events
	counters["sound_events"] = sound_events
	counters["view_center_requests"] = []
	counters["complete"] = true

	return counters


static func _process_toxic_cell(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	index: int,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	var map_edge: int = city.map_size if city != null else 128
	counters.toxic_markers_scanned += 1

	if random.next_u15() & 1 != 0:
		return

	counters.toxic_updates += 1

	if lfsr_random.next_mask(0x3f) == 0:
		OverlayData.write(payloads.XTXT, index, 0)
		counters.lfsr_expirations += 1

		return

	if payloads.XBIT[index] & 0x04 != 0 and random.next_u15() & 0x0f == 0:
		OverlayData.write(payloads.XTXT, index, 0)
		counters.water_expirations += 1

		return

	if _abandon_toxic_structure(city, payloads, point, random):
		counters.abandoned_structures += 1

	var direction := _lowest_toxic_direction(payloads.ALTM, point, map_edge)

	if direction < 0:
		direction = random.next_u15() & 3

	OverlayData.write(payloads.XTXT, index, 0)
	var target: Vector2i = point + CARDINAL_DIRECTIONS[direction]

	if DisasterMapState._place_toxic_marker(payloads.XTXT, target, map_edge):
		counters.moved_markers += 1
	else:
		counters.blocked_moves += 1


static func _process_riot_cell(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	index: int,
	marker: int,
	random,
	lfsr_random,
	counters: Dictionary,
	runtime_events: Dictionary,
) -> void:
	var map_edge: int = city.map_size if city != null else 128
	counters.riot_markers_scanned += 1

	if random.next_u15() & 3 != 0:
		return

	counters.riot_updates += 1

	if random.next_u15() & 0xff == 0 or payloads.XBIT[index] & 0x04 != 0:
		OverlayData.write(payloads.XTXT, index, 0)
		counters.expired_riots += 1

		return

	var traffic_index := CityDataGrid.index(payloads.XTRF, map_edge, point.x, point.y)

	if payloads.XTRF[traffic_index] != 0:
		counters.traffic_cells_cleared += 1

	payloads.XTRF[traffic_index] = 0
	var damage_direction: int = random.next_u15() & 0x7f

	if damage_direction < 4:
		counters.damage_attempts += 1

		if DisasterMapFireFlood._starts_fire(
			DisasterMapFireFlood._apply_damage(
				city,
				payloads,
				point + CARDINAL_DIRECTIONS[damage_direction],
				random,
				lfsr_random,
				runtime_events,
			)
		):
			counters.started_fires += 1

	var first_direction: int = 0 if marker == RIOT_OVERLAY_REVERSE else 2
	var second_direction: int = 1 if marker == RIOT_OVERLAY_REVERSE else 3
	var connections := 0

	if _riot_supports(payloads.XBLD, point + CARDINAL_DIRECTIONS[first_direction], map_edge):
		connections |= 1

	if _riot_supports(payloads.XBLD, point + CARDINAL_DIRECTIONS[second_direction], map_edge):
		connections |= 2

	var opposite_marker: int = (
		RIOT_OVERLAY_FORWARD if marker == RIOT_OVERLAY_REVERSE else RIOT_OVERLAY_REVERSE
	)

	if connections == 0:
		OverlayData.write(payloads.XTXT, index, opposite_marker)

		return

	OverlayData.write(payloads.XTXT, index, opposite_marker if random.next_u15() & 7 == 0 else 0)

	if connections == 3:
		connections = (random.next_u15() & 1) + 1

	var spread_direction: int = first_direction if connections == 1 else second_direction

	if _place_riot_marker(
		payloads.XTXT, point + CARDINAL_DIRECTIONS[spread_direction], marker, map_edge
	):
		counters.propagated_riots += 1
	else:
		counters.blocked_propagations += 1


static func _abandon_toxic_structure(
	city: CityState, payloads: Dictionary, point: Vector2i, random
) -> bool:
	var map_edge: int = city.map_size if city != null else 128
	var index := DisasterMapState._index(point, map_edge)
	var tile := int(payloads.XBLD[index])

	if tile < 0x70 or tile > 0xc5 or _is_construction_or_abandoned(tile):
		return false

	var area: int = Demolish._building_area(tile)
	var site := Demolish._find_building_site(
		payloads.XBLD, payloads.XZON, point, tile, area, city.compass_rotation(), map_edge
	)

	if site.size == Vector2i.ZERO:
		return false

	var anchor := Vector2i(site.position.x, site.end.y - 1)
	Growth._abandon(
		payloads.XBLD,
		payloads.XZON,
		payloads.XBIT,
		payloads.MISC,
		anchor,
		4 if area == 3 else area,
		0,
		random,
		city.compass_rotation(),
		payloads.XVAL, map_edge,
	)

	return payloads.XBLD[index] != tile


static func _is_construction_or_abandoned(tile: int) -> bool:
	return (
		(tile >= 0x88 and tile <= 0x8b)
		or (tile >= 0xa6 and tile <= 0xad)
		or (tile >= 0xc2 and tile <= 0xc5)
	)


static func _lowest_toxic_direction(altitude: PackedByteArray, point: Vector2i, map_edge: int = 128) -> int:
	var point_index := DisasterMapState._index(point, map_edge)
	var lowest := DisasterMapState._altitude_word(altitude, point_index) & 0x1f
	var direction := -1

	for checked_direction in CARDINAL_DIRECTIONS.size():
		var target: Vector2i = point + CARDINAL_DIRECTIONS[checked_direction]
		var target_index := DisasterMapState._index(target, map_edge)

		if target_index < 0:
			continue

		var target_height := DisasterMapState._altitude_word(altitude, target_index) & 0x1f

		if target_height < lowest:
			lowest = target_height
			direction = checked_direction

	return direction


static func _riot_supports(buildings: PackedByteArray, point: Vector2i, map_edge: int = 128) -> bool:
	var index := DisasterMapState._index(point, map_edge)

	if index < 0:
		return false

	var tile := int(buildings[index])

	return (
		(tile > 0 and tile < 5)
		or (tile > 0x1d and tile < 0x2c)
		or (tile > 0x3e and tile < 0x47)
		or tile == 0x4b
		or tile == 0x4c
		or (tile > 0x5c and tile < 0x61)
	)


static func _place_riot_marker(
	text: PackedByteArray, point: Vector2i, marker: int,
	map_edge: int = 128,
) -> bool:
	var index := DisasterMapState._index(point, map_edge)

	if index < 0 or (OverlayData.read(text, index) != 0 and not OverlayData.is_sign(OverlayData.read(text, index))):
		return false

	OverlayData.write(text, index, marker)

	return true
