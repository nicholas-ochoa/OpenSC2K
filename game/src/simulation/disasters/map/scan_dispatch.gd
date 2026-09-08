class_name DisasterMapScanDispatch
extends DisasterMapConstants


static func run_all(
	city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom, map_counter: int, hurricane_counter := 0
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
		return DisasterMapResult.failure("disaster-map input chunks are missing or invalid")

	var payloads := DisasterMapState._duplicate_payloads(original)
	var counter := maxi(map_counter - 1, 0)
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
	var dispatch: Dictionary[String, int] = {
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
				DisasterMapFireFlood._process_fire_cell(
					city, payloads, Vector2i(x, y), index, random, lfsr_random,
					counters, runtime_events
				)
			elif overlay == RIOT_OVERLAY_REVERSE or overlay == RIOT_OVERLAY_FORWARD:
				riot_active = true
				DisasterMapMarkers._process_riot_cell(
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
				DisasterMapMarkers._process_toxic_cell(
					city, payloads, Vector2i(x, y), index, random, lfsr_random, counters
				)
			elif overlay == 0xfc:
				flood_active = true
				DisasterMapFireFlood._process_flood_cell(
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
	var effect_events: Array[EffectEvent] = runtime_events.effect_events
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
			var hurricane_index := DisasterMapState._index(hurricane_point, map_edge)

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

				if damage.changed:
					counters.hurricane_damaged_structures += 1

				DisasterMapDamage.append_damage_events(runtime_events, damage)
				view_center_requests.append(hurricane_point)

		next_hurricane_counter = maxi(hurricane_counter - 1, 0)

	var map_changed := DisasterMapState._payloads_changed(original, payloads)

	if map_changed and not DisasterMapState._apply_map_payloads(city, original, payloads):
		return DisasterMapResult.failure("cannot store the disaster-map tick")

	counters["remaining_fires"] = OverlayData.occurrences(payloads.XTXT, FIRE_OVERLAY)
	counters["remaining_floods"] = OverlayData.occurrences(payloads.XTXT, 0xfc)
	counters["remaining_toxic"] = OverlayData.occurrences(payloads.XTXT, TOXIC_OVERLAY)
	counters["remaining_riots"] = (
		OverlayData.occurrences(payloads.XTXT, RIOT_OVERLAY_FORWARD)
		+ OverlayData.occurrences(payloads.XTXT, RIOT_OVERLAY_REVERSE)
	)
	var result := DisasterMapResult.new()
	result.ok = true
	result.active = fire_active or flood_active or toxic_active or riot_active
	result.active_markers = {
		"fire": fire_active, "flood": flood_active,
		"toxic": toxic_active, "riot": riot_active,
	}
	result.counters = counters
	result.map_counter = counter
	result.hurricane_counter = next_hurricane_counter
	result.map_changed = map_changed
	result.effect_events = effect_events
	result.sound_events = SoundEvent.from_ids(sound_events)
	result.view_center_requests = view_center_requests
	result.dispatch_map = DisasterMapResult.new()
	result.dispatch_map.ok = true
	result.dispatch_map.map_changed = map_changed
	result.dispatch_map.counters = dispatch

	return result


static func run_dispatch(city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom) -> DisasterMapResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return DisasterMapResult.failure("city is invalid")

	if random == null:
		return DisasterMapResult.failure("a compatible process random generator is required")

	if lfsr_random == null:
		return DisasterMapResult.failure("a compatible LFSR generator is required")

	var original := DisasterMapState._map_payloads(city)

	if original.is_empty():
		return DisasterMapResult.failure("dispatch-map input chunks are missing or invalid")

	var payloads := DisasterMapState._duplicate_payloads(original)
	var counters: Dictionary[String, int] = {
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

				if DisasterMapState._clear_riot_marker(payloads.XTXT, riot_target, map_edge):
					counters.riot_suppressions += 1

	var map_changed := DisasterMapState._payloads_changed(original, payloads)

	if map_changed and not DisasterMapState._apply_map_payloads(city, original, payloads):
		return DisasterMapResult.failure("cannot store the dispatch-map tick")

	var result := DisasterMapResult.new()
	result.ok = true
	result.map_changed = map_changed
	result.counters = counters

	return result


static func _process_dispatch_cell(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	overlay: int,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
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

		if DisasterMapState._clear_riot_marker(payloads.XTXT, riot_target, map_edge):
			counters.riot_suppressions += 1


static func _extinguish_dispatch_fire(
	city: CityState, payloads: Dictionary, point: Vector2i, random: SimRandom, lfsr_random: SimLfsrRandom
) -> bool:
	var map_edge: int = city.map_size if city != null else 128
	var index := DisasterMapState._index(point, map_edge)

	if index < 0 or OverlayData.read(payloads.XTXT, index) != FIRE_OVERLAY:
		return false

	OverlayData.write(payloads.XTXT, index, 0)
	var tile := int(payloads.XBLD[index])

	if tile >= 0x3f and tile <= 0x42:
		return true

	if tile < 0x61:
		DemolishStructures._demolish_point(
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
		NetworkState.replace_building(
			payloads.XBLD, payloads.XZON, payloads.MISC, index, lfsr_random.next_mod(4) + 1
		)
	elif payloads.XBIT[index] & 0xf0 == 0xf0:
		DemolishStructures._demolish_point(
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
