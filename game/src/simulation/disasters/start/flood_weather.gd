class_name DisasterStartFloodWeather
extends DisasterStartConstants


static func _start_flood(city: CityState, requested_point: Vector2i, lfsr_random) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if lfsr_random == null or not lfsr_random.has_method("next_mask"):
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	var original := DisasterStartObjectsState._map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "flood disaster input chunks are missing or invalid"}

	var payloads := DisasterStartObjectsState._duplicate_payloads(original)
	var shore := _find_flood_shore(payloads.XTER, requested_point, map_edge)

	if shore.x >= 0:
		var offset := shore - requested_point

		if offset.x > 0:
			_seed_flood_if_dry(payloads, shore + Vector2i(-1, 0), map_edge)

		if offset.y > 0:
			_seed_flood_if_dry(payloads, shore + Vector2i(0, -1), map_edge)

		if offset.x < map_edge - 1:
			_seed_flood_if_dry(payloads, shore + Vector2i(1, 0), map_edge)

		if offset.y < map_edge - 1:
			_seed_flood_if_dry(payloads, shore + Vector2i(0, 1), map_edge)

		return _store_flood(city, original, payloads, shore)

	for _attempt in 200:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var point := Vector2i(lfsr_random.next_mod(map_edge), lfsr_random.next_mod(map_edge))

		if payloads.XTER[DisasterStartObjectsState._index(point, map_edge)] == 0:
			OverlayData.write(payloads.XTXT, DisasterStartObjectsState._index(point, map_edge), 0xfc)

			return _store_flood(city, original, payloads, point)

	return _flood_result(requested_point, false)


static func _find_flood_shore(terrain: PackedByteArray, origin: Vector2i, map_edge: int = 128) -> Vector2i:
	# retain the original search for legacy cities. extended cities select the
	# same first match: smallest square radius, then increasing x and y
	if map_edge == 128:
		for radius in map_edge:
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					var point := origin + Vector2i(dx, dy)
					var index := DisasterStartObjectsState._index(point, map_edge)

					if index >= 0 and terrain[index] >= 0x20 and terrain[index] < 0x30:
						return point

		return Vector2i(-1, -1)

	var selected := Vector2i(-1, -1)
	var nearest_radius := map_edge

	for x in map_edge:
		for y in map_edge:
			var tile := terrain[x * map_edge + y]

			if tile < 0x20 or tile >= 0x30:
				continue

			var radius := maxi(absi(x - origin.x), absi(y - origin.y))

			if radius < nearest_radius:
				nearest_radius = radius
				selected = Vector2i(x, y)

	return selected


static func _start_mass_floods(
	city: CityState, center: Vector2i, random, lfsr_random
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}

	if lfsr_random == null or not lfsr_random.has_method("next_mask"):
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	var original := DisasterStartObjectsState._map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "mass-flood disaster input chunks are missing or invalid"}

	var attempt_count := (
		int(IntegerMath.div_trunc(city.document.misc_u32(MISC_NORMAL_POPULATION), 10000)) + 5
	) & 0xffff

	if attempt_count & 0x8000:
		attempt_count -= 0x10000

	var candidate_points: Array[Vector2i] = []
	var seed_points: Array[Vector2i] = []

	if attempt_count > 0:
		for _attempt in attempt_count:
			var candidate := center + Vector2i(
				(random.next_u15() & 0x1f) - 16,
				(random.next_u15() & 0x1f) - 16,
			)

			if DisasterStartObjectsState._index(candidate, map_edge) < 0:
				continue

			candidate_points.append(candidate)
			var flood := _start_flood(city, candidate, lfsr_random)

			if not flood.get("ok", false):
				return flood

			if flood.get("started", false):
				seed_points.append(flood.point)

	var started := not seed_points.is_empty()
	var current := DisasterStartObjectsState._map_payloads(city)
	var map_changed := not current.is_empty() and DisasterStartObjectsState._payloads_changed(original, current)
	var result := DisasterStartObjectsState._result(DISASTER_MASS_FLOODS, center, started, true, 0)
	result["attempt_count"] = maxi(attempt_count, 0)
	result["valid_candidates"] = candidate_points.size()
	result["candidate_points"] = candidate_points
	result["seed_writes"] = seed_points.size()
	result["successful_starts"] = seed_points.size()
	result["seed_points"] = seed_points
	result["delay_frames"] = candidate_points.size()
	result["map_changed"] = map_changed

	if started:
		var sounds: Array[int] = []

		for _seed in seed_points:
			sounds.append(SOUND_FLOOD)

		sounds.append(SOUND_SIREN)
		result["sound_events"] = sounds
		result["map_counter"] = 60

	return result


static func _start_hurricane(
	city: CityState, requested_point: Vector2i, random, lfsr_random
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}

	if (
		lfsr_random == null
		or not lfsr_random.has_method("next_mask")
		or not lfsr_random.has_method("next_mod")
	):
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	var original := DisasterStartObjectsState._map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "hurricane disaster input chunks are missing or invalid"}

	var payloads := DisasterStartObjectsState._duplicate_payloads(original)
	var direction := (city.compass_rotation() + 1) & 3
	var damage_points: Array[Vector2i] = []
	var flood_points: Array[Vector2i] = []
	var runtime_events := DisasterMapDamage.new_runtime_events()
	var effect_events: Array[Dictionary] = runtime_events.effect_events
	var sounds: Array[int] = runtime_events.sound_events
	sounds.append(SOUND_HURRICANE)
	var damage_scans := 0

	if direction == 0:
		for _attempt in 20:
			damage_scans += 1
			var x: int = lfsr_random.next_mod(map_edge)
			var y := (map_edge - 1)

			while y >= 0:
				if y > 0 and payloads.XBLD[DisasterStartObjectsState._index(Vector2i(x, y), map_edge)] > 0x0c:
					break

				y -= lfsr_random.next_mod(20)

			if y > 0:
				_hurricane_damage(
					city, payloads, Vector2i(x, y), random, lfsr_random,
					damage_points, runtime_events, true
				)

		sounds.append(SOUND_HURRICANE)
		_hurricane_flood_edge(payloads, lfsr_random, direction, 50, flood_points, map_edge)
	elif direction == 1:
		for _attempt in 20:
			damage_scans += 1
			var y: int = lfsr_random.next_mod(map_edge)
			var x := (map_edge - 1)

			while x >= 0:
				if x > 0 and payloads.XBLD[DisasterStartObjectsState._index(Vector2i(x, y), map_edge)] > 0x0c:
					break

				x -= lfsr_random.next_mod(20)

			if x > 0:
				_hurricane_damage(
					city, payloads, Vector2i(x, y), random, lfsr_random,
					damage_points, runtime_events, false
				)

		sounds.append(SOUND_HURRICANE)
		_hurricane_flood_edge(payloads, lfsr_random, direction, 100, flood_points, map_edge)
	elif direction == 2:
		var attempt := 0

		while attempt < 20:
			damage_scans += 1
			var next_attempt := attempt + 1
			var x: int = lfsr_random.next_mod(map_edge)
			var y := 0

			while y < map_edge:
				if y < (map_edge - 1) and payloads.XBLD[DisasterStartObjectsState._index(Vector2i(x, y), map_edge)] > 0x0c:
					break

				y += lfsr_random.next_mod(20)

			if y < (map_edge - 1):
				next_attempt = attempt + 2
				_hurricane_damage(
					city, payloads, Vector2i(x, y), random, lfsr_random,
					damage_points, runtime_events, false
				)

			attempt = next_attempt

		sounds.append(SOUND_HURRICANE)
		_hurricane_flood_edge(payloads, lfsr_random, direction, 100, flood_points, map_edge)
	else:
		for _attempt in 20:
			damage_scans += 1
			var y: int = lfsr_random.next_mod(map_edge)
			var x := 0

			while x < map_edge:
				if x < (map_edge - 1) and payloads.XBLD[DisasterStartObjectsState._index(Vector2i(x, y), map_edge)] > 0x0c:
					break

				x += lfsr_random.next_mod(20)

			if x < (map_edge - 1):
				_hurricane_damage(
					city, payloads, Vector2i(x, y), random, lfsr_random,
					damage_points, runtime_events, true
				)

		sounds.append(SOUND_HURRICANE)
		_hurricane_flood_edge(payloads, lfsr_random, direction, 50, flood_points, map_edge)

	sounds.append(SOUND_HURRICANE)
	var map_changed := DisasterStartObjectsState._payloads_changed(original, payloads)

	if map_changed and not DisasterStartObjectsState._apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the hurricane disaster"}

	var result := DisasterStartObjectsState._result(DISASTER_HURRICANE, requested_point, true, true, 0)
	sounds.append(SOUND_SIREN)
	result["sound_events"] = sounds
	result["view_center_requests"] = []
	result["effect_events"] = effect_events
	result["map_counter"] = 60
	result["hurricane_counter"] = 50
	result["direction"] = direction
	result["damage_scans"] = damage_scans
	result["damage_attempts"] = damage_points.size()
	result["damage_points"] = damage_points
	result["flood_attempts"] = 50 if direction == 0 or direction == 3 else 100
	result["flood_writes"] = flood_points.size()
	result["flood_points"] = flood_points
	result["map_changed"] = map_changed

	return result


static func _hurricane_damage(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	random,
	lfsr_random,
	damage_points: Array[Vector2i],
	runtime_events: Dictionary,
	emit_effects: bool
) -> void:
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
		point,
		random,
		lfsr_random,
		false,
		false,
		emit_effects,
	)
	damage_points.append(point)

	if emit_effects:
		DisasterMapDamage.append_damage_events(runtime_events, damage)


static func _hurricane_flood_edge(
	payloads: Dictionary,
	lfsr_random,
	direction: int,
	attempt_count: int,
	flood_points: Array[Vector2i],
	map_edge: int = 128,
) -> void:
	for _attempt in attempt_count:
		var fixed: int = lfsr_random.next_mod(map_edge)
		var point := Vector2i.ZERO

		if direction == 0:
			point = Vector2i(fixed, (map_edge - 1))

			while point.y >= 0 and payloads.XBLD[DisasterStartObjectsState._index(point, map_edge)] <= 5:
				point.y -= 1

			if point.y <= 0:
				continue
		elif direction == 1:
			point = Vector2i((map_edge - 1), fixed)

			while point.x >= 0 and payloads.XBLD[DisasterStartObjectsState._index(point, map_edge)] <= 5:
				point.x -= 1

			if point.x <= 0:
				continue
		elif direction == 2:
			point = Vector2i(fixed, 0)

			while point.y < (map_edge - 1) and payloads.XBLD[DisasterStartObjectsState._index(point, map_edge)] <= 5:
				point.y += 1

			if point.y >= (map_edge - 1):
				continue
		else:
			point = Vector2i(0, fixed)

			while point.x < map_edge and payloads.XBLD[DisasterStartObjectsState._index(point, map_edge)] <= 5:
				point.x += 1

			if point.x >= (map_edge - 1):
				continue

		OverlayData.write(payloads.XTXT, DisasterStartObjectsState._index(point, map_edge), 0xfc)
		flood_points.append(point)


static func _seed_flood_if_dry(payloads: Dictionary, point: Vector2i, map_edge: int = 128) -> void:
	var index := DisasterStartObjectsState._index(point, map_edge)

	if index >= 0 and payloads.XBIT[index] & 0x04 == 0:
		OverlayData.write(payloads.XTXT, index, 0xfc)


static func _store_flood(
	city: CityState, original: Dictionary, payloads: Dictionary, point: Vector2i
) -> Dictionary:
	if not DisasterStartObjectsState._apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the flood disaster"}

	return _flood_result(point, true)


static func _flood_result(point: Vector2i, started: bool) -> Dictionary:
	var result := DisasterStartObjectsState._result(DISASTER_FLOOD, point, started, true, 0)
	result["sound_events"] = [SOUND_FLOOD, SOUND_SIREN] if started else []
	result["map_counter"] = 60 if started else 0

	return result
