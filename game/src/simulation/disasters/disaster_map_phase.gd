class_name DisasterMapPhase
extends DisasterMapConstants



static func run_all(
	city: CityState, random, lfsr_random, map_counter: int, hurricane_counter := 0
) -> Dictionary:
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

	var original := _map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "disaster-map input chunks are missing or invalid"}

	var payloads := _duplicate_payloads(original)
	var counter := maxi(map_counter - 1, 0)
	var counters := {
		"fire_markers_scanned": 0,
		"fire_updates": 0,
		"spread_attempts": 0,
		"spread_fires": 0,
		"water_extinctions": 0,
		"coverage_extinctions": 0,
		"structure_collapses": 0,
		"created_explosions": 0,
		"toxic_markers": 0,
		"flood_markers_scanned": 0,
		"flood_updates": 0,
		"flood_spread_attempts": 0,
		"spread_floods": 0,
		"expired_floods": 0,
		"random_extinctions": 0,
		"damaged_structures": 0,
		"toxic_markers_scanned": 0,
		"toxic_updates": 0,
		"lfsr_expirations": 0,
		"water_expirations": 0,
		"moved_markers": 0,
		"blocked_moves": 0,
		"abandoned_structures": 0,
		"riot_markers_scanned": 0,
		"riot_updates": 0,
		"expired_riots": 0,
		"damage_attempts": 0,
		"started_fires": 0,
		"traffic_cells_cleared": 0,
		"propagated_riots": 0,
		"blocked_propagations": 0,
		"hurricane_damage_attempts": 0,
		"hurricane_damaged_structures": 0,
	}
	var dispatch := {
		"dispatch_markers_scanned": 0,
		"fire_suppression_attempts": 0,
		"fire_extinctions": 0,
		"riot_suppression_attempts": 0,
		"riot_suppressions": 0,
	}
	var runtime_events := DisasterMapDamage.new_runtime_events()
	var fire_active := false
	var flood_active := false
	var toxic_active := false
	var riot_active := false

	for x in map_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y in map_edge:
			if city.simulation_slice != null and (y & 15) == 0:
				city.simulation_slice.checkpoint()

			var index := x * map_edge + y
			var overlay := int(OverlayData.read(payloads.XTXT, index))

			if overlay == FIRE_OVERLAY:
				fire_active = true
				_process_fire_cell(
					city, payloads, Vector2i(x, y), index, random, lfsr_random,
					counters, runtime_events
				)
			elif overlay == RIOT_OVERLAY_REVERSE or overlay == RIOT_OVERLAY_FORWARD:
				riot_active = true
				_process_riot_cell(
					city,
					payloads,
					Vector2i(x, y),
					index,
					overlay,
					random,
					lfsr_random,
					counters,
					runtime_events,
				)
			elif overlay == TOXIC_OVERLAY:
				toxic_active = true
				_process_toxic_cell(
					city, payloads, Vector2i(x, y), index, random, lfsr_random, counters
				)
			elif overlay == 0xfc:
				flood_active = true
				_process_flood_cell(
					city,
					payloads,
					Vector2i(x, y),
					index,
					counter,
					random,
					lfsr_random,
					counters,
					runtime_events,
				)
			elif OverlayData.is_thing(overlay):
				_process_dispatch_cell(
					city,
					payloads,
					Vector2i(x, y),
					overlay,
					random,
					lfsr_random,
					dispatch
				)

	var sound_events: Array[int] = runtime_events.sound_events
	var effect_events: Array[Dictionary] = runtime_events.effect_events
	var view_center_requests: Array[Vector2i] = []

	if riot_active and random.next_u15() & 7 == 0:
		sound_events.append(SOUND_RIOT)

	if flood_active and random.next_u15() & 7 == 0:
		sound_events.append(SOUND_FLOOD)

	if fire_active:
		sound_events.append(SOUND_FIRE)

	var next_hurricane_counter := hurricane_counter

	if counter != 0 and hurricane_counter != 0:
		if random.next_u15() & 7 == 0:
			sound_events.append(SOUND_HURRICANE)

		if lfsr_random.next_mask(1) == 0:
			var hurricane_point := Vector2i(
				lfsr_random.next_mod(map_edge), lfsr_random.next_mod(map_edge)
			)
			var hurricane_index := _index(hurricane_point, map_edge)

			if payloads.XBLD[hurricane_index] > 0x70:
				counters.hurricane_damage_attempts += 1
				var damage := DisasterMapDamage.burn_structure(
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
					hurricane_point,
					random,
					lfsr_random,
					false,
					false,
					true,
				)

				if damage.get("changed", false):
					counters.hurricane_damaged_structures += 1

				DisasterMapDamage.append_damage_events(runtime_events, damage)
				view_center_requests.append(hurricane_point)

		next_hurricane_counter = maxi(hurricane_counter - 1, 0)

	var map_changed := _payloads_changed(original, payloads)

	if map_changed and not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the disaster-map tick"}

	counters["ok"] = true
	counters["error"] = ""
	counters["active"] = fire_active or flood_active or toxic_active or riot_active
	counters["fire_active"] = fire_active
	counters["flood_active"] = flood_active
	counters["toxic_active"] = toxic_active
	counters["riot_active"] = riot_active
	counters["remaining_fires"] = OverlayData.occurrences(payloads.XTXT, FIRE_OVERLAY)
	counters["remaining_floods"] = OverlayData.occurrences(payloads.XTXT, 0xfc)
	counters["remaining_toxic"] = OverlayData.occurrences(payloads.XTXT, TOXIC_OVERLAY)
	counters["remaining_riots"] = (
		OverlayData.occurrences(payloads.XTXT, RIOT_OVERLAY_FORWARD)
		+ OverlayData.occurrences(payloads.XTXT, RIOT_OVERLAY_REVERSE)
	)
	counters["map_counter"] = counter
	counters["hurricane_counter"] = next_hurricane_counter
	counters["map_changed"] = map_changed
	counters["news_items"] = []
	counters["effect_events"] = effect_events
	counters["sound_events"] = sound_events
	counters["view_center_requests"] = view_center_requests
	counters["complete"] = true
	dispatch["ok"] = true
	dispatch["error"] = ""
	dispatch["active"] = false
	dispatch["map_changed"] = map_changed
	dispatch["news_items"] = []
	dispatch["effect_events"] = []
	dispatch["sound_events"] = []
	dispatch["view_center_requests"] = []
	dispatch["complete"] = true
	counters["dispatch_map"] = dispatch

	return counters


static func run_fire(city: CityState, random, lfsr_random) -> Dictionary:
	return DisasterMapFireFlood.run_fire(city, random, lfsr_random)


static func run_flood(
	city: CityState, random, lfsr_random, map_counter: int
) -> Dictionary:
	return DisasterMapFireFlood.run_flood(city, random, lfsr_random, map_counter)


static func run_toxic(city: CityState, random, lfsr_random) -> Dictionary:
	return DisasterMapMarkers.run_toxic(city, random, lfsr_random)


static func run_riot(city: CityState, random, lfsr_random) -> Dictionary:
	return DisasterMapMarkers.run_riot(city, random, lfsr_random)


static func run_dispatch(city: CityState, random, lfsr_random) -> Dictionary:
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

	var original := _map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "dispatch-map input chunks are missing or invalid"}

	var payloads := _duplicate_payloads(original)
	var counters := {
		"dispatch_markers_scanned": 0,
		"fire_suppression_attempts": 0,
		"fire_extinctions": 0,
		"riot_suppression_attempts": 0,
		"riot_suppressions": 0,
	}

	for x in map_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y in map_edge:
			if city.simulation_slice != null and (y & 15) == 0:
				city.simulation_slice.checkpoint()

			var index := x * map_edge + y
			var overlay := int(OverlayData.read(payloads.XTXT, index))

			if not OverlayData.is_thing(overlay):
				continue

			var record := OverlayData.thing_record(overlay)
			var thing_type := int(payloads.XTHG[record * CityState.THING_RECORD_SIZE])
			counters.dispatch_markers_scanned += 1
			var suppresses_fire := thing_type == TYPE_FIRE_DISPATCH or thing_type == TYPE_MILITARY

			if thing_type == TYPE_POLICE:
				suppresses_fire = lfsr_random.next_mask(0x0f) == 0

			if suppresses_fire:
				counters.fire_suppression_attempts += 1
				var fire_target: Vector2i = (
					Vector2i(x, y) + CARDINAL_DIRECTIONS[random.next_u15() & 3]
				)

				if _extinguish_dispatch_fire(city, payloads, fire_target, random, lfsr_random):
					counters.fire_extinctions += 1

			if thing_type == TYPE_POLICE or thing_type == TYPE_MILITARY:
				counters.riot_suppression_attempts += 1
				var riot_target: Vector2i = (
					Vector2i(x, y) + CARDINAL_DIRECTIONS[random.next_u15() & 3]
				)

				if _clear_riot_marker(payloads.XTXT, riot_target, map_edge):
					counters.riot_suppressions += 1

	var map_changed := _payloads_changed(original, payloads)

	if map_changed and not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the dispatch-map tick"}

	counters["ok"] = true
	counters["error"] = ""
	counters["active"] = false
	counters["map_changed"] = map_changed
	counters["news_items"] = []
	counters["effect_events"] = []
	counters["sound_events"] = []
	counters["view_center_requests"] = []
	counters["complete"] = true

	return counters


static func _process_fire_cell(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	index: int,
	random,
	lfsr_random,
	counters: Dictionary,
	runtime_events: Dictionary,
) -> void:
	DisasterMapFireFlood._process_fire_cell(city, payloads, point, index, random, lfsr_random, counters, runtime_events)


static func _process_flood_cell(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	index: int,
	counter: int,
	random,
	lfsr_random,
	counters: Dictionary,
	runtime_events: Dictionary,
) -> void:
	DisasterMapFireFlood._process_flood_cell(
		city, payloads, point, index, counter, random, lfsr_random, counters, runtime_events
	)


static func _process_toxic_cell(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	index: int,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	DisasterMapMarkers._process_toxic_cell(city, payloads, point, index, random, lfsr_random, counters)


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
	DisasterMapMarkers._process_riot_cell(city, payloads, point, index, marker, random, lfsr_random, counters, runtime_events)


static func _process_dispatch_cell(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	overlay: int,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	var map_edge: int = city.map_size if city != null else 128
	var record := OverlayData.thing_record(overlay)
	var thing_type := int(payloads.XTHG[record * CityState.THING_RECORD_SIZE])
	counters.dispatch_markers_scanned += 1
	var suppresses_fire := thing_type == TYPE_FIRE_DISPATCH or thing_type == TYPE_MILITARY

	if thing_type == TYPE_POLICE:
		suppresses_fire = lfsr_random.next_mask(0x0f) == 0

	if suppresses_fire:
		counters.fire_suppression_attempts += 1
		var fire_target: Vector2i = point + CARDINAL_DIRECTIONS[random.next_u15() & 3]

		if _extinguish_dispatch_fire(city, payloads, fire_target, random, lfsr_random):
			counters.fire_extinctions += 1

	if thing_type == TYPE_POLICE or thing_type == TYPE_MILITARY:
		counters.riot_suppression_attempts += 1
		var riot_target: Vector2i = point + CARDINAL_DIRECTIONS[random.next_u15() & 3]

		if _clear_riot_marker(payloads.XTXT, riot_target, map_edge):
			counters.riot_suppressions += 1


static func _apply_damage(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	random,
	lfsr_random,
	runtime_events: Dictionary = {},
) -> int:
	return DisasterMapFireFlood._apply_damage(city, payloads, point, random, lfsr_random, runtime_events)


static func _starts_fire(result_code: int) -> bool:
	return DisasterMapFireFlood._starts_fire(result_code)


static func _apply_flood_damage(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	maximum_altitude: int,
	random,
	lfsr_random,
	runtime_events: Dictionary = {},
) -> int:
	return DisasterMapFireFlood._apply_flood_damage(city, payloads, point, maximum_altitude, random, lfsr_random, runtime_events)


static func _collapse_structure(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	_tile: int,
	random,
	lfsr_random
) -> void:
	DisasterMapState._collapse_structure(city, payloads, point, _tile, random, lfsr_random)


static func _building_site(
	city: CityState, payloads: Dictionary, point: Vector2i, tile: int
) -> Rect2i:
	return DisasterMapState._building_site(city, payloads, point, tile)


static func _abandon_toxic_structure(
	city: CityState, payloads: Dictionary, point: Vector2i, random
) -> bool:
	return DisasterMapMarkers._abandon_toxic_structure(city, payloads, point, random)


static func _is_construction_or_abandoned(tile: int) -> bool:
	return DisasterMapMarkers._is_construction_or_abandoned(tile)


static func _lowest_toxic_direction(altitude: PackedByteArray, point: Vector2i, map_edge: int = 128) -> int:
	return DisasterMapMarkers._lowest_toxic_direction(altitude, point, map_edge)


static func _place_toxic_marker(text: PackedByteArray, point: Vector2i, map_edge: int = 128) -> bool:
	return DisasterMapState._place_toxic_marker(text, point, map_edge)


static func _riot_supports(buildings: PackedByteArray, point: Vector2i, map_edge: int = 128) -> bool:
	return DisasterMapMarkers._riot_supports(buildings, point, map_edge)


static func _place_riot_marker(
	text: PackedByteArray, point: Vector2i, marker: int,
	map_edge: int = 128,
) -> bool:
	return DisasterMapMarkers._place_riot_marker(text, point, marker, map_edge)


static func _extinguish_dispatch_fire(
	city: CityState, payloads: Dictionary, point: Vector2i, random, lfsr_random
) -> bool:
	var map_edge: int = city.map_size if city != null else 128
	var index := _index(point, map_edge)

	if index < 0 or OverlayData.read(payloads.XTXT, index) != FIRE_OVERLAY:
		return false

	OverlayData.write(payloads.XTXT, index, 0)
	var tile := int(payloads.XBLD[index])

	if tile >= 0x3f and tile <= 0x42:
		return true

	if tile < 0x61:
		Demolish._demolish_point(
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
			true,
			true,
			false,
		)
		NetworkTiles._replace_building(
			payloads.XBLD, payloads.XZON, payloads.MISC, index, lfsr_random.next_mod(4) + 1
		)
	elif payloads.XBIT[index] & 0xf0 == 0xf0:
		Demolish._demolish_point(
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
			true,
			true,
			false,
		)

	return true


static func _clear_riot_marker(text: PackedByteArray, point: Vector2i, map_edge: int = 128) -> bool:
	return DisasterMapState._clear_riot_marker(text, point, map_edge)


static func _seed_special_toxic(
	payloads: Dictionary, site: Rect2i, point: Vector2i,
	map_edge: int = 128,
) -> int:
	return DisasterMapState._seed_special_toxic(payloads, site, point, map_edge)


static func _spawn_explosion(
	text: PackedByteArray,
	things: PackedByteArray,
	point: Vector2i,
	height: int,
	state: int,
	goal: int,
	map_edge: int = 128,
) -> bool:
	return DisasterMapState._spawn_explosion(text, things, point, height, state, goal, map_edge)


static func _map_payloads(city: CityState) -> Dictionary:
	return DisasterMapState._map_payloads(city)


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary:
	return DisasterMapState._duplicate_payloads(payloads)


static func _payloads_changed(original: Dictionary, payloads: Dictionary) -> bool:
	return DisasterMapState._payloads_changed(original, payloads)


static func _apply_map_payloads(
	city: CityState, original: Dictionary, payloads: Dictionary
) -> bool:
	return DisasterMapState._apply_map_payloads(city, original, payloads)


static func _refresh_city_arrays(city: CityState) -> void:
	DisasterMapState._refresh_city_arrays(city)


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	return DisasterMapState._index(point, map_edge)


static func _altitude_word(altitude: PackedByteArray, index: int) -> int:
	return DisasterMapState._altitude_word(altitude, index)
