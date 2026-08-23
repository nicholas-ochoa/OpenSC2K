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

	city.resync_mirrors(["XTXT"])

	return DisasterStartObjectsState._result(disaster_type, clamped, true, true, record)
