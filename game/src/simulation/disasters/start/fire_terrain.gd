class_name DisasterStartFireTerrain
extends DisasterStartConstants


static func _start_fire(city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom) -> DisasterStartResult:
	var map_edge: int = city.map_size if city != null else 128

	if random == null:
		return DisasterStartResult.failed("a compatible process random generator is required")

	if lfsr_random == null:
		return DisasterStartResult.failed("a compatible LFSR generator is required")

	var original := DisasterStartObjectsState._map_payloads(city)

	if original.is_empty():
		return DisasterStartResult.failed("fire disaster input chunks are missing or invalid")

	var payloads := DisasterStartObjectsState._duplicate_payloads(original)
	var runtime_events := DisasterMapDamage.new_runtime_events()
	var point := Vector2i(
		DisasterStartObjectsState._read_u32_be(payloads.MISC, MISC_CITY_CENTER_X) - 20 + random.next_u15() % 40,
		DisasterStartObjectsState._read_u32_be(payloads.MISC, MISC_CITY_CENTER_Y) - 20 + random.next_u15() % 40
	)
	var direction := 0
	var run_length := 1
	var step := 0

	while run_length < 64:
		point.x += FIRE_SPIRAL_X[direction]
		point.y += FIRE_SPIRAL_Y[direction]
		var index := DisasterStartObjectsState._index(point, map_edge)

		if (
			index >= 0
			and payloads.XBLD[index] > BuildingTileIds.RAIL_SUBWAY_ENTRANCE_4
			and _starts_fire(
				_apply_fire_damage(
					city, payloads, point, random, lfsr_random, runtime_events
				)
			)
		):
			return _store_fire(city, original, payloads, point, runtime_events)

		step += 1

		if step >= run_length:
			step = 0

			if direction & 1 != 0:
				run_length += 1

			direction = (direction + 1) & 3

	for _attempt in 200:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		point = Vector2i(lfsr_random.next_mod(map_edge), lfsr_random.next_mod(map_edge))

		if _starts_fire(
			_apply_fire_damage(city, payloads, point, random, lfsr_random, runtime_events)
		):
			return _store_fire(city, original, payloads, point, runtime_events)

	var result := DisasterStartObjectsState._result(DISASTER_FIRE, point, false, true, 0)
	result.notice_ids = [0xf5]

	return result


static func _start_earthquake(
	city: CityState, point: Vector2i, random: SimRandom, lfsr_random: SimLfsrRandom
) -> DisasterStartResult:
	var map_edge: int = city.map_size if city != null else 128

	if random == null:
		return DisasterStartResult.failed("a compatible process random generator is required")

	if lfsr_random == null:
		return DisasterStartResult.failed("a compatible LFSR generator is required")

	var original := DisasterStartObjectsState._map_payloads(city)

	if original.is_empty():
		return DisasterStartResult.failed("earthquake disaster input chunks are missing or invalid")

	var payloads := DisasterStartObjectsState._duplicate_payloads(original)
	var runtime_events := DisasterMapDamage.new_runtime_events()
	var gate_hits := 0
	var eligible_targets := 0
	var fire_damage_attempts := 0
	var structure_damage_attempts := 0

	for x_offset in range(-32, 33):
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y_offset in range(-32, 33):
			if random.next_u15() & 0x3f != 0:
				continue

			gate_hits += 1
			var target := point + Vector2i(x_offset, y_offset)
			var index := DisasterStartObjectsState._index(target, map_edge)

			if index < 0 or payloads.XBLD[index] <= BuildingTileIds.SMALL_PARK:
				continue

			eligible_targets += 1

			if random.next_u15() & 3 == 0:
				fire_damage_attempts += 1
				_apply_fire_damage(
					city, payloads, target, random, lfsr_random, runtime_events
				)
			else:
				structure_damage_attempts += 1
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
					target,
					random,
					lfsr_random,
					false,
					false
				)

	var map_changed := DisasterStartObjectsState._payloads_changed(original, payloads)

	if map_changed and not DisasterStartObjectsState._apply_map_payloads(city, original, payloads):
		return DisasterStartResult.failed("cannot store the earthquake disaster")

	var result := DisasterStartObjectsState._result(DISASTER_EARTHQUAKE, point, true, true, 0)
	result.counters["gate_attempts"] = 65 * 65
	result.counters["gate_hits"] = gate_hits
	result.counters["eligible_targets"] = eligible_targets
	result.counters["fire_damage_attempts"] = fire_damage_attempts
	result.counters["structure_damage_attempts"] = structure_damage_attempts
	result.map_changed = map_changed
	var effect_events: Array[EffectEvent] = [EffectEvent.earthquake()]
	effect_events.append_array(runtime_events.effect_events)
	result.effect_events = effect_events
	var sounds: Array[int] = []

	for _frame in 24:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		sounds.append(SOUND_EARTHQUAKE)

	sounds.append_array(runtime_events.sound_events)
	sounds.append(SOUND_SIREN)
	result.sound_events = SoundEvent.from_ids(sounds)

	return result


static func _start_volcano(city: CityState, center: Vector2i, random: SimRandom) -> DisasterStartResult:
	var map_edge: int = city.map_size if city != null else 128

	if random == null:
		return DisasterStartResult.failed("a compatible process random generator is required")

	var original := DisasterStartObjectsState._map_payloads(city)

	if original.is_empty():
		return DisasterStartResult.failed("volcano disaster input chunks are missing or invalid")

	var payloads := DisasterStartObjectsState._duplicate_payloads(original)
	var heights := TerrainEditHeights._decode_heights(payloads.ALTM, map_edge)
	var remaining_budget := VOLCANO_BUDGET
	var iterations := 0
	var successful_raises := 0
	var rejected_raises := 0
	var near_toxic_writes := 0
	var near_fire_writes := 0
	var distant_toxic_writes := 0
	var distant_fire_writes := 0
	var changed_indices := PackedInt32Array()
	var sounds: Array[int] = [SOUND_VOLCANO]

	while remaining_budget > 0:
		var near_point := Vector2i.ZERO

		while true:
			near_point = center + Vector2i(
				random.next_u15() % 5 - 2,
				random.next_u15() % 5 - 2,
			)

			if DisasterStartObjectsState._index(near_point, map_edge) >= 0:
				break

		var near_index := DisasterStartObjectsState._index(near_point, map_edge)

		if random.next_u15() & 1 == 0:
			OverlayData.write(payloads.XTXT, near_index, 0xfb)
			near_toxic_writes += 1
		else:
			OverlayData.write(payloads.XTXT, near_index, 0xff)
			near_fire_writes += 1

		if _volcano_raise_is_valid(heights, payloads.XZON, payloads.XBIT, near_point, {}, map_edge):
			var trial := TerrainEditHeights.plan_raise(
				heights, payloads.XZON, payloads.XBLD, near_point, remaining_budget, map_edge
			)

			if trial.valid:
				heights = trial.heights
				remaining_budget = int(trial.funds)
				TerrainEditHeights._write_heights(payloads.ALTM, heights, trial.modified)

				for index in trial.zone_indices:
					payloads.XZON[index] &= 0xf0

				var retile_indices := TerrainEditSurface._expanded_indices(trial.modified, map_edge)
				TerrainRetile.retile_region(
					payloads.ALTM,
					payloads.XBLD,
					payloads.XTER,
					payloads.XZON,
					payloads.XBIT,
					payloads.MISC,
					retile_indices,
					DisasterStartObjectsState._read_u32_be(payloads.MISC, 0x0e40), map_edge,
				)

				for index in retile_indices:
					if not changed_indices.has(index):
						changed_indices.append(index)

				successful_raises += 1
			else:
				remaining_budget -= 1000
				rejected_raises += 1
		else:
			remaining_budget -= 1000
			rejected_raises += 1

		var distant_point := center + Vector2i(
			(random.next_u15() & 0x1f) - 16,
			(random.next_u15() & 0x1f) - 16,
		)
		var distant_index := DisasterStartObjectsState._index(distant_point, map_edge)

		if distant_index >= 0:
			if payloads.XBIT[distant_index] & 0x04 != 0:
				OverlayData.write(payloads.XTXT, distant_index, 0xfb)
				distant_toxic_writes += 1
			else:
				OverlayData.write(payloads.XTXT, distant_index, 0xff)
				distant_fire_writes += 1

		iterations += 1

		if random.next_u15() & 7 != 0:
			sounds.append(SOUND_EARTHQUAKE)

	var map_changed := DisasterStartObjectsState._payloads_changed(original, payloads)

	if map_changed and not DisasterStartObjectsState._apply_map_payloads(city, original, payloads):
		return DisasterStartResult.failed("cannot store the volcano disaster")

	var result := DisasterStartObjectsState._result(DISASTER_VOLCANO, center, true, true, 0)
	sounds.append(SOUND_SIREN)
	result.sound_events = SoundEvent.from_ids(sounds)
	result.counters["iterations"] = iterations
	result.counters["successful_raises"] = successful_raises
	result.counters["rejected_raises"] = rejected_raises
	result.counters["temporary_budget_spent"] = VOLCANO_BUDGET - remaining_budget
	result.counters["near_toxic_writes"] = near_toxic_writes
	result.counters["near_fire_writes"] = near_fire_writes
	result.counters["distant_toxic_writes"] = distant_toxic_writes
	result.counters["distant_fire_writes"] = distant_fire_writes
	result.terrain_indices = changed_indices
	result.map_changed = map_changed

	return result


static func _volcano_raise_is_valid(
	heights: PackedInt32Array,
	zones: PackedByteArray,
	flags: PackedByteArray,
	point: Vector2i,
	visited := {},
	map_edge: int = 128,
) -> bool:
	var index := DisasterStartObjectsState._index(point, map_edge)

	if index < 0 or visited.has(index):
		return true

	if zones[index] & 0x0f == TerrainCommand.MILITARY_ZONE:
		return false

	if flags[index] & 0x04 != 0 or heights[index] > TerrainCommand.MAX_RAISE_SOURCE:
		return false

	visited[index] = true

	for offset in TerrainCommand.NEIGHBOR_OFFSETS:
		var neighbor: Vector2i = point + offset
		var neighbor_index := DisasterStartObjectsState._index(neighbor, map_edge)

		if neighbor_index < 0:
			continue

		if zones[neighbor_index] & 0x0f == TerrainCommand.MILITARY_ZONE:
			return false

		if flags[neighbor_index] & 0x04 != 0:
			return false

	for offset in TerrainCommand.CARDINAL_OFFSETS:
		var neighbor: Vector2i = point + offset
		var neighbor_index := DisasterStartObjectsState._index(neighbor, map_edge)

		if neighbor_index >= 0 and heights[neighbor_index] < heights[index]:
			if not _volcano_raise_is_valid(heights, zones, flags, neighbor, visited, map_edge):
				return false

	return true


static func _start_firestorm(
	city: CityState, center: Vector2i, random: SimRandom, lfsr_random: SimLfsrRandom
) -> DisasterStartResult:
	var map_edge: int = city.map_size if city != null else 128

	if random == null:
		return DisasterStartResult.failed("a compatible process random generator is required")

	if lfsr_random == null:
		return DisasterStartResult.failed("a compatible LFSR generator is required")

	var original := DisasterStartObjectsState._map_payloads(city)

	if original.is_empty():
		return DisasterStartResult.failed("firestorm disaster input chunks are missing or invalid")

	var payloads := DisasterStartObjectsState._duplicate_payloads(original)
	var point := center
	var direction := 0
	var run_length := 1
	var run_step := 0
	var remaining := 65
	var scan_steps := 0
	var attempted_in_map := 0
	var result_codes := PackedInt32Array()
	var accepted_points: Array[Vector2i] = []
	var runtime_events := DisasterMapDamage.new_runtime_events()

	while remaining > 0 and run_length < map_edge:
		point += Vector2i(FIRE_SPIRAL_X[direction], FIRE_SPIRAL_Y[direction])
		scan_steps += 1

		if DisasterStartObjectsState._index(point, map_edge) >= 0:
			attempted_in_map += 1
			var result_code := DisasterMapDamage.apply(
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
				true,
				runtime_events,
			)

			if result_code != 0:
				remaining -= 1
				result_codes.append(result_code)
				accepted_points.append(point)

		run_step += 1

		if run_step >= run_length:
			run_step = 0

			if direction & 1 != 0:
				run_length += 1

			direction = (direction + 1) & 3

	var started := remaining < 65
	var map_changed := DisasterStartObjectsState._payloads_changed(original, payloads)

	if map_changed and not DisasterStartObjectsState._apply_map_payloads(city, original, payloads):
		return DisasterStartResult.failed("cannot store the firestorm disaster")

	var result := DisasterStartObjectsState._result(DISASTER_FIRESTORM, center, started, true, 0)
	result.requested_point = center
	result.scan_finish = point
	result.counters["scan_steps"] = scan_steps
	result.counters["attempted_in_map"] = attempted_in_map
	result.counters["successful_cells"] = 65 - remaining
	result.counters["remaining_cells"] = remaining
	result.result_codes = result_codes
	result.accepted_points = accepted_points
	result.map_changed = map_changed
	result.effect_events = runtime_events.effect_events

	if started:
		result.view_center_requests = [point]
		var sounds: Array[int] = runtime_events.sound_events.duplicate()
		sounds.append(SOUND_SIREN)
		result.sound_events = SoundEvent.from_ids(sounds)

	return result


static func _apply_fire_damage(
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


static func _store_fire(
	city: CityState,
	original: Dictionary,
	payloads: Dictionary,
	point: Vector2i,
	runtime_events: DisasterDamage.RuntimeEvents,
) -> DisasterStartResult:
	if not DisasterStartObjectsState._apply_map_payloads(city, original, payloads):
		return DisasterStartResult.failed("cannot store the fire disaster")

	var result := DisasterStartObjectsState._result(DISASTER_FIRE, point, true, true, 0)
	result.effect_events = runtime_events.effect_events
	var sounds: Array[int] = runtime_events.sound_events.duplicate()
	sounds.append(SOUND_SIREN)
	result.sound_events = SoundEvent.from_ids(sounds)

	return result
