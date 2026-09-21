class_name DisasterStartRiotsPollution
extends DisasterStartConstants

@warning_ignore_start("integer_division")


const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

static func _start_toxic_spill(city: CityState, point: Vector2i) -> DisasterStartResult:
	var map_edge: int = city.map_size if city != null else 128
	var index := DisasterStartObjectsState._index(point, map_edge)

	if index < 0:
		return DisasterStartObjectsState._result(DISASTER_TOXIC_SPILL, point, false, true, 0)

	var text_chunk := city.document.find_chunk("XTXT")

	if text_chunk == null or text_chunk.decoded_payload.size() != city.document.decoded_size("XTXT"):
		return DisasterStartResult.failed("toxic-spill map data is missing or invalid")

	var text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	OverlayData.write(text, index, 0xfb)

	if not text_chunk.set_decoded_payload(text):
		return DisasterStartResult.failed("cannot store the toxic spill")

	city.resync_mirrors(["XTXT"])

	return DisasterStartObjectsState._result(DISASTER_TOXIC_SPILL, point, true, true, 0)


static func _start_riot(city: CityState, point: Vector2i, random: SimRandom) -> DisasterStartResult:
	var map_edge: int = city.map_size if city != null else 128

	if random == null:
		return DisasterStartResult.failed("a compatible process random generator is required")

	var riot_maps := _riot_map_payloads(city)

	if riot_maps.is_empty():
		return DisasterStartResult.failed("riot disaster map data is missing or invalid")

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
		OverlayData.write(text, DisasterStartObjectsState._index(seed_point, map_edge), RIOT_OVERLAY_FORWARD + (random.next_u15() & 1))
		seed_points.append(seed_point)

	if not _store_riot_text(city, text):
		return DisasterStartResult.failed("cannot store the riot disaster")

	return _riot_result(DISASTER_RIOT, current_point, seed_points, 3)


static func _start_mass_riots(city: CityState, point: Vector2i, random: SimRandom) -> DisasterStartResult:
	var map_edge: int = city.map_size if city != null else 128

	if random == null:
		return DisasterStartResult.failed("a compatible process random generator is required")

	var riot_maps := _riot_map_payloads(city)

	if riot_maps.is_empty():
		return DisasterStartResult.failed("mass-riot disaster map data is missing or invalid")

	var attempt_count := (
		int(city.document.misc_u32(MISC_NORMAL_POPULATION) / 10000) + 5
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

			if DisasterStartObjectsState._index(candidate, map_edge) < 0:
				continue

			final_point = candidate
			var seed_point := _find_riot_seed(
				candidate, riot_maps.XBLD, riot_maps.XBIT, text, map_edge
			)

			if seed_point.x < 0:
				continue

			final_point = seed_point
			OverlayData.write(text, DisasterStartObjectsState._index(seed_point, map_edge), RIOT_OVERLAY_FORWARD + (random.next_u15() & 1))
			seed_points.append(seed_point)

	if not seed_points.is_empty() and not _store_riot_text(city, text):
		return DisasterStartResult.failed("cannot store the mass-riot disaster")

	return _riot_result(
		DISASTER_MASS_RIOTS, final_point, seed_points, maxi(attempt_count, 0)
	)


static func _riot_map_payloads(city: CityState) -> Dictionary[String, PackedByteArray]:
	var map_edge: int = city.map_size if city != null else 128
	var result: Dictionary[String, PackedByteArray] = {}

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
		var index := DisasterStartObjectsState._index(point, map_edge)

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
		(tile >= Tiles.ROAD_STRAIGHT_1 and tile <= Tiles.ROAD_CROSSROADS)
		or (tile >= Tiles.TUNNEL_ENTRANCE_1 and tile <= Tiles.ROAD_RAIL_CROSSING_2)
		or tile == Tiles.HIGHWAY_ROAD_CROSSING_1
		or tile == Tiles.HIGHWAY_ROAD_CROSSING_2
		or (tile >= Tiles.HIGHWAY_ONRAMP_1 and tile <= Tiles.HIGHWAY_ONRAMP_4)
	)


static func _store_riot_text(city: CityState, text: PackedByteArray) -> bool:
	var chunk := city.document.find_chunk("XTXT")

	if chunk == null or not chunk.set_decoded_payload(text):
		return false

	city.resync_mirrors(["XTXT"])

	return true


static func _riot_result(
	disaster_type: int,
	point: Vector2i,
	seed_points: Array[Vector2i],
	attempt_count: int
) -> DisasterStartResult:
	var started := not seed_points.is_empty()
	var result := DisasterStartObjectsState._result(disaster_type, point, started, true, 0)
	result.counters["attempt_count"] = attempt_count
	result.counters["seed_writes"] = seed_points.size()
	result.seed_points = seed_points
	var sounds: Array[int] = []

	for _seed in seed_points:
		sounds.append(SOUND_RIOT)

	if started:
		sounds.append(SOUND_SIREN)

	result.sound_events = SoundEvent.from_ids(sounds)

	return result


static func _start_pollution(city: CityState, point: Vector2i, random: SimRandom) -> DisasterStartResult:
	var map_edge: int = city.map_size if city != null else 128

	if random == null:
		return DisasterStartResult.failed("a compatible process random generator is required")

	var text_chunk := city.document.find_chunk("XTXT")

	if text_chunk == null or text_chunk.decoded_payload.size() != city.document.decoded_size("XTXT"):
		return DisasterStartResult.failed("pollution-disaster map data is missing or invalid")

	var attempt_count := (
		int(city.document.misc_u32(MISC_NORMAL_POPULATION) / 10000) + 5
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
			var index := DisasterStartObjectsState._index(seed_point, map_edge)

			if index < 0:
				continue

			OverlayData.write(text, index, 0xfb)
			seed_writes += 1

	if seed_writes > 0:
		if not text_chunk.set_decoded_payload(text):
			return DisasterStartResult.failed("cannot store the pollution disaster")

		city.resync_mirrors(["XTXT"])

	var result := DisasterStartObjectsState._result(
		DISASTER_POLLUTION, point, seed_writes > 0, true, 0
	)
	result.counters["attempt_count"] = maxi(attempt_count, 0)
	result.counters["seed_writes"] = seed_writes

	return result
