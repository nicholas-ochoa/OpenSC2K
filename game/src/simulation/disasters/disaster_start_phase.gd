class_name DisasterStartPhase
extends DisasterStartConstants



static func start(
	city: CityState, disaster_type: int, point: Vector2i, random, lfsr_random = null
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if disaster_type == DISASTER_NONE:
		return _result(disaster_type, point, false, true, 0)

	if disaster_type == DISASTER_FIRE:
		return _start_fire(city, random, lfsr_random)

	if disaster_type == DISASTER_FLOOD:
		return _start_flood(city, point, lfsr_random)

	if disaster_type == DISASTER_RIOT:
		return _start_riot(city, point, random)

	if disaster_type == DISASTER_TOXIC_SPILL:
		return _start_toxic_spill(city, point)

	if disaster_type == DISASTER_AIR_CRASH or disaster_type == DISASTER_HELICOPTER_CRASH:
		return _start_crash_wrapper(disaster_type, point)

	if disaster_type == DISASTER_EARTHQUAKE:
		return _start_earthquake(city, point, random, lfsr_random)

	if disaster_type == DISASTER_MELTDOWN:
		return _start_meltdown(city, point, random, lfsr_random)

	if disaster_type == DISASTER_MICROWAVE:
		return _start_microwave(city, random, lfsr_random)

	if disaster_type == DISASTER_VOLCANO:
		return _start_volcano(city, point, random)

	if disaster_type == DISASTER_FIRESTORM:
		return _start_firestorm(city, point, random, lfsr_random)

	if disaster_type == DISASTER_MASS_RIOTS:
		return _start_mass_riots(city, point, random)

	if disaster_type == DISASTER_MASS_FLOODS:
		return _start_mass_floods(city, point, random, lfsr_random)

	if disaster_type == DISASTER_POLLUTION:
		return _start_pollution(city, point, random)

	if disaster_type == DISASTER_HURRICANE:
		return _start_hurricane(city, point, random, lfsr_random)

	if disaster_type == DISASTER_PLANE_CRASH:
		return _start_plane_crash(city, lfsr_random)

	if disaster_type != DISASTER_TORNADO and disaster_type != DISASTER_MONSTER:
		return _result(disaster_type, point, false, false, 0)

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}

	var thing_chunk := city.document.find_chunk("XTHG")
	var text_chunk := city.document.find_chunk("XTXT")

	if (
		thing_chunk == null
		or thing_chunk.decoded_payload.size() != city.document.decoded_size("XTHG")
		or text_chunk == null
		or text_chunk.decoded_payload.size() != city.document.decoded_size("XTXT")
	):
		return {"ok": false, "error": "disaster moving-object data is missing or invalid"}

	var things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var text: PackedByteArray = text_chunk.decoded_payload.duplicate()

	if _count_type(things, TYPE_TORNADO if disaster_type == DISASTER_TORNADO else TYPE_MONSTER) > 0:
		return _result(disaster_type, point, false, true, 0)

	var clamped := Vector2i(clampi(point.x, 0, (map_edge - 1)), clampi(point.y, 0, (map_edge - 1)))
	var index := clamped.x * map_edge + clamped.y
	var overlay := int(OverlayData.read(text, index))

	if OverlayData.is_thing(overlay):
		_remove_thing(things, text, OverlayData.thing_record(overlay), map_edge)

	var record := _first_free_record(things)

	if record == 0:
		return _result(disaster_type, clamped, false, false, 0)

	var offset := record * CityState.THING_RECORD_SIZE
	ThingData.write(things, offset, TYPE_TORNADO if disaster_type == DISASTER_TORNADO else TYPE_MONSTER)
	ThingData.write(things, offset + 1, random.next_u15() & 7 if disaster_type == DISASTER_TORNADO else 2)
	ThingData.write(things, offset + 2, 0)
	ThingData.write(things, offset + 3, clamped.x)
	ThingData.write(things, offset + 4, clamped.y)
	ThingData.write(things, offset + 5, city.land_altitude(clamped.x, clamped.y) if disaster_type == DISASTER_TORNADO else 15)
	ThingData.write(things, offset + 6, 8)
	ThingData.write(things, offset + 7, 8)
	ThingData.write(things, offset + 8, random.next_u15() & 0x7f)
	ThingData.write(things, offset + 9, random.next_u15() & 0x7f)
	ThingData.write(things, offset + 10, OverlayData.read(text, index))

	if disaster_type == DISASTER_MONSTER:
		ThingData.write(things, offset + 11, 0)

		if random.next_u15() & 1 == 0:
			ThingData.write(things, offset + 11, random.next_u15() % 3 + 1)

	OverlayData.write(text, index, OverlayData.thing_id(record))
	var old_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()

	if not thing_chunk.set_decoded_payload(things):
		return {"ok": false, "error": "cannot store the disaster moving object"}

	if not text_chunk.set_decoded_payload(text):
		thing_chunk.set_decoded_payload(old_things)

		return {"ok": false, "error": "cannot link the disaster moving object"}

	city.text_overlays = text.duplicate()

	return _result(disaster_type, clamped, true, true, record)


static func _start_crash_wrapper(disaster_type: int, point: Vector2i) -> Dictionary:
	return DisasterStartObjectsState._start_crash_wrapper(disaster_type, point)


static func _start_plane_crash(city: CityState, lfsr_random) -> Dictionary:
	return DisasterStartObjectsState._start_plane_crash(city, lfsr_random)


static func _start_fire(city: CityState, random, lfsr_random) -> Dictionary:
	return DisasterStartFireTerrain._start_fire(city, random, lfsr_random)


static func _start_flood(city: CityState, requested_point: Vector2i, lfsr_random) -> Dictionary:
	return DisasterStartFloodWeather._start_flood(city, requested_point, lfsr_random)


static func _find_flood_shore(terrain: PackedByteArray, origin: Vector2i, map_edge: int = 128) -> Vector2i:
	return DisasterStartFloodWeather._find_flood_shore(terrain, origin, map_edge)


static func _start_toxic_spill(city: CityState, point: Vector2i) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	var index := _index(point, map_edge)

	if index < 0:
		return _result(DISASTER_TOXIC_SPILL, point, false, true, 0)

	var text_chunk := city.document.find_chunk("XTXT")

	if text_chunk == null or text_chunk.decoded_payload.size() != city.document.decoded_size("XTXT"):
		return {"ok": false, "error": "toxic-spill map data is missing or invalid"}

	var text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	OverlayData.write(text, index, 0xfb)

	if not text_chunk.set_decoded_payload(text):
		return {"ok": false, "error": "cannot store the toxic spill"}

	city.text_overlays = text.duplicate()

	return _result(DISASTER_TOXIC_SPILL, point, true, true, 0)


static func _start_riot(city: CityState, point: Vector2i, random) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}

	var riot_maps := _riot_map_payloads(city)

	if riot_maps.is_empty():
		return {"ok": false, "error": "riot disaster map data is missing or invalid"}

	var text: PackedByteArray = riot_maps.XTXT.duplicate()
	var current_point := point
	var seed_points: Array[Vector2i] = []

	for _attempt in 3:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var seed_point := _find_riot_seed(
			current_point, riot_maps.XBLD, riot_maps.XBIT, text, map_edge
		)

		if seed_point.x < 0:
			if seed_points.is_empty():
				return _riot_result(DISASTER_RIOT, point, seed_points, 3)

			continue

		current_point = seed_point
		OverlayData.write(text, _index(seed_point, map_edge), RIOT_OVERLAY_FORWARD + (random.next_u15() & 1))
		seed_points.append(seed_point)

	if not _store_riot_text(city, text):
		return {"ok": false, "error": "cannot store the riot disaster"}

	return _riot_result(DISASTER_RIOT, current_point, seed_points, 3)


static func _start_mass_riots(city: CityState, point: Vector2i, random) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}

	var riot_maps := _riot_map_payloads(city)

	if riot_maps.is_empty():
		return {"ok": false, "error": "mass-riot disaster map data is missing or invalid"}

	var attempt_count := (
		int(IntegerMath.div_trunc(city.document.misc_u32(MISC_NORMAL_POPULATION), 10000)) + 5
	) & 0xffff

	if attempt_count & 0x8000:
		attempt_count -= 0x10000

	var text: PackedByteArray = riot_maps.XTXT.duplicate()
	var final_point := point
	var seed_points: Array[Vector2i] = []

	if attempt_count > 0:
		for _attempt in attempt_count:
			var candidate := point + Vector2i(
				(random.next_u15() & 0x1f) - 16,
				(random.next_u15() & 0x1f) - 16,
			)

			if _index(candidate, map_edge) < 0:
				continue

			final_point = candidate
			var seed_point := _find_riot_seed(
				candidate, riot_maps.XBLD, riot_maps.XBIT, text, map_edge
			)

			if seed_point.x < 0:
				continue

			final_point = seed_point
			OverlayData.write(text, _index(seed_point, map_edge), RIOT_OVERLAY_FORWARD + (random.next_u15() & 1))
			seed_points.append(seed_point)

	if not seed_points.is_empty() and not _store_riot_text(city, text):
		return {"ok": false, "error": "cannot store the mass-riot disaster"}

	return _riot_result(
		DISASTER_MASS_RIOTS, final_point, seed_points, maxi(attempt_count, 0)
	)


static func _riot_map_payloads(city: CityState) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	var result := {}

	for chunk_id in ["XBLD", "XBIT", "XTXT"]:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size(chunk_id):
			return {}

		result[chunk_id] = chunk.decoded_payload

	return result


static func _find_riot_seed(
	origin: Vector2i,
	buildings: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	map_edge: int = 128,
) -> Vector2i:
	var point := origin
	var direction := 0
	var run_length := 1
	var step := 0

	while run_length < map_edge:
		point += Vector2i(FIRE_SPIRAL_X[direction], FIRE_SPIRAL_Y[direction])
		var index := _index(point, map_edge)

		if (
			index >= 0
			and _riot_start_supports(int(buildings[index]))
			and flags[index] & 0x04 == 0
			and OverlayData.read(text, index) == 0
		):
			return point

		step += 1

		if step >= run_length:
			step = 0

			if direction & 1 != 0:
				run_length += 1

			direction = (direction + 1) & 3

	return Vector2i(-1, -1)


static func _riot_start_supports(tile: int) -> bool:
	return (
		(tile >= 0x1d and tile <= 0x2b)
		or (tile >= 0x3f and tile <= 0x46)
		or tile == 0x4b
		or tile == 0x4c
		or (tile >= 0x5d and tile <= 0x60)
	)


static func _store_riot_text(city: CityState, text: PackedByteArray) -> bool:
	var chunk := city.document.find_chunk("XTXT")

	if chunk == null or not chunk.set_decoded_payload(text):
		return false

	city.text_overlays = text.duplicate()

	return true


static func _riot_result(
	disaster_type: int,
	point: Vector2i,
	seed_points: Array[Vector2i],
	attempt_count: int
) -> Dictionary:
	var started := not seed_points.is_empty()
	var result := _result(disaster_type, point, started, true, 0)
	result["attempt_count"] = attempt_count
	result["seed_writes"] = seed_points.size()
	result["seed_points"] = seed_points
	var sounds: Array[int] = []

	for _seed in seed_points:
		sounds.append(SOUND_RIOT)

	if started:
		sounds.append(SOUND_SIREN)

	result["sound_events"] = sounds

	return result


static func _start_pollution(city: CityState, point: Vector2i, random) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}

	var text_chunk := city.document.find_chunk("XTXT")

	if text_chunk == null or text_chunk.decoded_payload.size() != city.document.decoded_size("XTXT"):
		return {"ok": false, "error": "pollution-disaster map data is missing or invalid"}

	var attempt_count := (
		int(IntegerMath.div_trunc(city.document.misc_u32(MISC_NORMAL_POPULATION), 10000)) + 5
	) & 0xffff

	if attempt_count & 0x8000:
		attempt_count -= 0x10000

	var text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	var seed_writes := 0

	if attempt_count > 0:
		for _attempt in attempt_count:
			var seed_point := point + Vector2i(
				(random.next_u15() & 7) - 4,
				(random.next_u15() & 7) - 4
			)
			var index := _index(seed_point, map_edge)

			if index < 0:
				continue

			OverlayData.write(text, index, 0xfb)
			seed_writes += 1

	if seed_writes > 0:
		if not text_chunk.set_decoded_payload(text):
			return {"ok": false, "error": "cannot store the pollution disaster"}

		city.text_overlays = text.duplicate()

	var result := _result(
		DISASTER_POLLUTION, point, seed_writes > 0, true, 0
	)
	result["attempt_count"] = maxi(attempt_count, 0)
	result["seed_writes"] = seed_writes

	return result


static func _start_earthquake(
	city: CityState, point: Vector2i, random, lfsr_random
) -> Dictionary:
	return DisasterStartFireTerrain._start_earthquake(city, point, random, lfsr_random)


static func _start_meltdown(
	city: CityState, requested_point: Vector2i, random, lfsr_random
) -> Dictionary:
	return DisasterStartPowerAccidents._start_meltdown(city, requested_point, random, lfsr_random)


static func _find_nuclear_power_plant(
	buildings: PackedByteArray, requested_point: Vector2i,
	map_edge: int = 128,
) -> Vector2i:
	return DisasterStartPowerAccidents._find_nuclear_power_plant(buildings, requested_point, map_edge)


static func _write_radioactivity(payloads: Dictionary, point: Vector2i, map_edge: int = 128) -> bool:
	return DisasterStartPowerAccidents._write_radioactivity(payloads, point, map_edge)


static func _start_microwave(city: CityState, random, lfsr_random) -> Dictionary:
	return DisasterStartPowerAccidents._start_microwave(city, random, lfsr_random)


static func _find_first_building(buildings: PackedByteArray, tile_id: int, map_edge: int = 128) -> Vector2i:
	return DisasterStartPowerAccidents._find_first_building(buildings, tile_id, map_edge)


static func _start_volcano(city: CityState, center: Vector2i, random) -> Dictionary:
	return DisasterStartFireTerrain._start_volcano(city, center, random)


static func _volcano_raise_is_valid(
	heights: PackedInt32Array,
	zones: PackedByteArray,
	flags: PackedByteArray,
	point: Vector2i,
	visited := {},
	map_edge: int = 128,
) -> bool:
	return DisasterStartFireTerrain._volcano_raise_is_valid(heights, zones, flags, point, visited, map_edge)


static func _start_firestorm(
	city: CityState, center: Vector2i, random, lfsr_random
) -> Dictionary:
	return DisasterStartFireTerrain._start_firestorm(city, center, random, lfsr_random)


static func _start_mass_floods(
	city: CityState, center: Vector2i, random, lfsr_random
) -> Dictionary:
	return DisasterStartFloodWeather._start_mass_floods(city, center, random, lfsr_random)


static func _start_hurricane(
	city: CityState, requested_point: Vector2i, random, lfsr_random
) -> Dictionary:
	return DisasterStartFloodWeather._start_hurricane(city, requested_point, random, lfsr_random)


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
	DisasterStartFloodWeather._hurricane_damage(
		city, payloads, point, random, lfsr_random, damage_points, runtime_events, emit_effects
	)


static func _hurricane_flood_edge(
	payloads: Dictionary,
	lfsr_random,
	direction: int,
	attempt_count: int,
	flood_points: Array[Vector2i],
	map_edge: int = 128,
) -> void:
	DisasterStartFloodWeather._hurricane_flood_edge(payloads, lfsr_random, direction, attempt_count, flood_points, map_edge)


static func _seed_flood_if_dry(payloads: Dictionary, point: Vector2i, map_edge: int = 128) -> void:
	DisasterStartFloodWeather._seed_flood_if_dry(payloads, point, map_edge)


static func _store_flood(
	city: CityState, original: Dictionary, payloads: Dictionary, point: Vector2i
) -> Dictionary:
	return DisasterStartFloodWeather._store_flood(city, original, payloads, point)


static func _flood_result(point: Vector2i, started: bool) -> Dictionary:
	return DisasterStartFloodWeather._flood_result(point, started)


static func _apply_fire_damage(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	random,
	lfsr_random,
	runtime_events: Dictionary = {},
) -> int:
	return DisasterStartFireTerrain._apply_fire_damage(city, payloads, point, random, lfsr_random, runtime_events)


static func _starts_fire(result_code: int) -> bool:
	return DisasterStartFireTerrain._starts_fire(result_code)


static func _store_fire(
	city: CityState,
	original: Dictionary,
	payloads: Dictionary,
	point: Vector2i,
	runtime_events: Dictionary,
) -> Dictionary:
	return DisasterStartFireTerrain._store_fire(city, original, payloads, point, runtime_events)


static func has_active_object(city: CityState, _disaster_type: int) -> bool:
	return DisasterStartObjectsState.has_active_object(city, _disaster_type)


static func _result(
	disaster_type: int, point: Vector2i, started: bool, complete: bool, record: int
) -> Dictionary:
	return DisasterStartObjectsState._result(disaster_type, point, started, complete, record)


static func _count_type(things: PackedByteArray, thing_type: int) -> int:
	return DisasterStartObjectsState._count_type(things, thing_type)


static func _first_free_record(things: PackedByteArray) -> int:
	return DisasterStartObjectsState._first_free_record(things)


static func _remove_thing(things: PackedByteArray, text: PackedByteArray, record: int, map_edge: int = 128) -> void:
	DisasterStartObjectsState._remove_thing(things, text, record, map_edge)


static func _map_payloads(city: CityState) -> Dictionary:
	return DisasterStartObjectsState._map_payloads(city)


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary:
	return DisasterStartObjectsState._duplicate_payloads(payloads)


static func _payloads_changed(original: Dictionary, payloads: Dictionary) -> bool:
	return DisasterStartObjectsState._payloads_changed(original, payloads)


static func _apply_map_payloads(
	city: CityState, original: Dictionary, payloads: Dictionary
) -> bool:
	return DisasterStartObjectsState._apply_map_payloads(city, original, payloads)


static func _refresh_city_arrays(city: CityState) -> void:
	DisasterStartObjectsState._refresh_city_arrays(city)


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return DisasterStartObjectsState._read_u32_be(data, offset)


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	return DisasterStartObjectsState._index(point, map_edge)
