class_name DisasterStartPhase
extends DisasterStartConstants



static func start(
	city: CityState, disaster_type: int, point: Vector2i, random: SimRandom, lfsr_random: SimLfsrRandom = null
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if disaster_type == DISASTER_NONE:
		return DisasterStartObjectsState._result(disaster_type, point, false, true, 0)

	if disaster_type == DISASTER_FIRE:
		return DisasterStartFireTerrain._start_fire(city, random, lfsr_random)

	if disaster_type == DISASTER_FLOOD:
		return DisasterStartFloodWeather._start_flood(city, point, lfsr_random)

	if disaster_type == DISASTER_RIOT:
		return DisasterStartRiotsPollution._start_riot(city, point, random)

	if disaster_type == DISASTER_TOXIC_SPILL:
		return DisasterStartRiotsPollution._start_toxic_spill(city, point)

	if disaster_type == DISASTER_AIR_CRASH or disaster_type == DISASTER_HELICOPTER_CRASH:
		return DisasterStartObjectsState._start_crash_wrapper(disaster_type, point)

	if disaster_type == DISASTER_EARTHQUAKE:
		return DisasterStartFireTerrain._start_earthquake(city, point, random, lfsr_random)

	if disaster_type == DISASTER_MELTDOWN:
		return DisasterStartPowerAccidents._start_meltdown(city, point, random, lfsr_random)

	if disaster_type == DISASTER_MICROWAVE:
		return DisasterStartPowerAccidents._start_microwave(city, random, lfsr_random)

	if disaster_type == DISASTER_VOLCANO:
		return DisasterStartFireTerrain._start_volcano(city, point, random)

	if disaster_type == DISASTER_FIRESTORM:
		return DisasterStartFireTerrain._start_firestorm(city, point, random, lfsr_random)

	if disaster_type == DISASTER_MASS_RIOTS:
		return DisasterStartRiotsPollution._start_mass_riots(city, point, random)

	if disaster_type == DISASTER_MASS_FLOODS:
		return DisasterStartFloodWeather._start_mass_floods(city, point, random, lfsr_random)

	if disaster_type == DISASTER_POLLUTION:
		return DisasterStartRiotsPollution._start_pollution(city, point, random)

	if disaster_type == DISASTER_HURRICANE:
		return DisasterStartFloodWeather._start_hurricane(city, point, random, lfsr_random)

	if disaster_type == DISASTER_PLANE_CRASH:
		return DisasterStartObjectsState._start_plane_crash(city, lfsr_random)

	if disaster_type != DISASTER_TORNADO and disaster_type != DISASTER_MONSTER:
		return DisasterStartObjectsState._result(disaster_type, point, false, false, 0)

	if random == null:
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

	if DisasterStartObjectsState._count_type(things, TYPE_TORNADO if disaster_type == DISASTER_TORNADO else TYPE_MONSTER) > 0:
		return DisasterStartObjectsState._result(disaster_type, point, false, true, 0)

	var clamped := Vector2i(clampi(point.x, 0, (map_edge - 1)), clampi(point.y, 0, (map_edge - 1)))
	var index := clamped.x * map_edge + clamped.y
	var overlay := int(OverlayData.read(text, index))

	if OverlayData.is_thing(overlay):
		DisasterStartObjectsState._remove_thing(things, text, OverlayData.thing_record(overlay), map_edge)

	var record := DisasterStartObjectsState._first_free_record(things)

	if record == 0:
		return DisasterStartObjectsState._result(disaster_type, clamped, false, false, 0)

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

	return DisasterStartObjectsState._result(disaster_type, clamped, true, true, record)


static func _start_crash_wrapper(disaster_type: int, point: Vector2i) -> Dictionary:
	return DisasterStartObjectsState._start_crash_wrapper(disaster_type, point)


static func _start_plane_crash(city: CityState, lfsr_random: SimLfsrRandom) -> Dictionary:
	return DisasterStartObjectsState._start_plane_crash(city, lfsr_random)


static func _start_fire(city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom) -> Dictionary:
	return DisasterStartFireTerrain._start_fire(city, random, lfsr_random)


static func _start_flood(city: CityState, requested_point: Vector2i, lfsr_random: SimLfsrRandom) -> Dictionary:
	return DisasterStartFloodWeather._start_flood(city, requested_point, lfsr_random)


static func _find_flood_shore(terrain: PackedByteArray, origin: Vector2i, map_edge: int = 128) -> Vector2i:
	return DisasterStartFloodWeather._find_flood_shore(terrain, origin, map_edge)


static func _start_toxic_spill(city: CityState, point: Vector2i) -> Dictionary:
	return DisasterStartRiotsPollution._start_toxic_spill(city, point)


static func _start_riot(city: CityState, point: Vector2i, random: SimRandom) -> Dictionary:
	return DisasterStartRiotsPollution._start_riot(city, point, random)


static func _start_mass_riots(city: CityState, point: Vector2i, random: SimRandom) -> Dictionary:
	return DisasterStartRiotsPollution._start_mass_riots(city, point, random)


static func _riot_map_payloads(city: CityState) -> Dictionary:
	return DisasterStartRiotsPollution._riot_map_payloads(city)


static func _find_riot_seed(
	origin: Vector2i,
	buildings: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	map_edge: int = 128,
) -> Vector2i:
	return DisasterStartRiotsPollution._find_riot_seed(origin, buildings, flags, text, map_edge)


static func _riot_start_supports(tile: int) -> bool:
	return DisasterStartRiotsPollution._riot_start_supports(tile)


static func _store_riot_text(city: CityState, text: PackedByteArray) -> bool:
	return DisasterStartRiotsPollution._store_riot_text(city, text)


static func _riot_result(
	disaster_type: int,
	point: Vector2i,
	seed_points: Array[Vector2i],
	attempt_count: int
) -> Dictionary:
	return DisasterStartRiotsPollution._riot_result(disaster_type, point, seed_points, attempt_count)


static func _start_pollution(city: CityState, point: Vector2i, random: SimRandom) -> Dictionary:
	return DisasterStartRiotsPollution._start_pollution(city, point, random)


static func _start_earthquake(
	city: CityState, point: Vector2i, random: SimRandom, lfsr_random: SimLfsrRandom
) -> Dictionary:
	return DisasterStartFireTerrain._start_earthquake(city, point, random, lfsr_random)


static func _start_meltdown(
	city: CityState, requested_point: Vector2i, random: SimRandom, lfsr_random: SimLfsrRandom
) -> Dictionary:
	return DisasterStartPowerAccidents._start_meltdown(city, requested_point, random, lfsr_random)


static func _find_nuclear_power_plant(
	buildings: PackedByteArray, requested_point: Vector2i,
	map_edge: int = 128,
) -> Vector2i:
	return DisasterStartPowerAccidents._find_nuclear_power_plant(buildings, requested_point, map_edge)


static func _write_radioactivity(payloads: Dictionary, point: Vector2i, map_edge: int = 128) -> bool:
	return DisasterStartPowerAccidents._write_radioactivity(payloads, point, map_edge)


static func _start_microwave(city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom) -> Dictionary:
	return DisasterStartPowerAccidents._start_microwave(city, random, lfsr_random)


static func _find_first_building(buildings: PackedByteArray, tile_id: int, map_edge: int = 128) -> Vector2i:
	return DisasterStartPowerAccidents._find_first_building(buildings, tile_id, map_edge)


static func _start_volcano(city: CityState, center: Vector2i, random: SimRandom) -> Dictionary:
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
	city: CityState, center: Vector2i, random: SimRandom, lfsr_random: SimLfsrRandom
) -> Dictionary:
	return DisasterStartFireTerrain._start_firestorm(city, center, random, lfsr_random)


static func _start_mass_floods(
	city: CityState, center: Vector2i, random: SimRandom, lfsr_random: SimLfsrRandom
) -> Dictionary:
	return DisasterStartFloodWeather._start_mass_floods(city, center, random, lfsr_random)


static func _start_hurricane(
	city: CityState, requested_point: Vector2i, random: SimRandom, lfsr_random: SimLfsrRandom
) -> Dictionary:
	return DisasterStartFloodWeather._start_hurricane(city, requested_point, random, lfsr_random)


static func _hurricane_damage(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	damage_points: Array[Vector2i],
	runtime_events: Dictionary,
	emit_effects: bool
) -> void:
	DisasterStartFloodWeather._hurricane_damage(
		city, payloads, point, random, lfsr_random, damage_points, runtime_events, emit_effects
	)


static func _hurricane_flood_edge(
	payloads: Dictionary,
	lfsr_random: SimLfsrRandom,
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
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
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
