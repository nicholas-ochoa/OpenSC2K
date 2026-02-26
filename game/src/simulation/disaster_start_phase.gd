class_name DisasterStartPhase
extends RefCounted

const DisasterMapDamage = preload("res://src/simulation/disaster_damage.gd")
const Demolish = preload("res://src/tools/demolish_command.gd")
const SpecialZoneGrowth = preload("res://src/simulation/special_zone_growth.gd")
const TerrainCommand = preload("res://src/tools/terrain_command.gd")
const DISASTER_NONE := 0
const DISASTER_FIRE := 1
const DISASTER_FLOOD := 2
const DISASTER_RIOT := 3
const DISASTER_TOXIC_SPILL := 4
const DISASTER_AIR_CRASH := 5
const DISASTER_EARTHQUAKE := 6
const DISASTER_TORNADO := 7
const DISASTER_MONSTER := 8
const DISASTER_MELTDOWN := 9
const DISASTER_MICROWAVE := 10
const DISASTER_VOLCANO := 11
const DISASTER_FIRESTORM := 12
const DISASTER_MASS_RIOTS := 13
const DISASTER_MASS_FLOODS := 14
const DISASTER_POLLUTION := 15
const DISASTER_HURRICANE := 16
const DISASTER_HELICOPTER_CRASH := 17
const DISASTER_PLANE_CRASH := 18
const TYPE_AIRPLANE := 1
const TYPE_MONSTER := 5
const TYPE_EXPLOSION := 6
const TYPE_TORNADO := 15
const TEXT_THING_BASE := 201
const SOUND_SIREN := 520
const SOUND_FLOOD := 511
const SOUND_RIOT := 512
const SOUND_MICROWAVE := 514
const SOUND_EARTHQUAKE := 504
const SOUND_VOLCANO := 507
const SOUND_HURRICANE := 502
const VOLCANO_BUDGET := 25000
const MISC_CITY_CENTER_X := 0x1018
const MISC_CITY_CENTER_Y := 0x101c
const MISC_NORMAL_POPULATION := 0x102c
const FIRE_SPIRAL_X := [0, 1, 0, -1]
const FIRE_SPIRAL_Y := [-1, 0, 1, 0]
const RIOT_OVERLAY_FORWARD := 0xfd
const RIOT_OVERLAY_REVERSE := 0xfe
const NUCLEAR_POWER_PLANT := 0xcb
const RADIOACTIVITY_TILE := 0x05
const MICROWAVE_POWER_PLANT := 0xcd
const EIGHT_DIRECTIONS := [
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
]
const MAP_CHUNK_SIZES := {
	"ALTM": CityState.TILE_COUNT * 2,
	"XBLD": CityState.TILE_COUNT,
	"XTER": CityState.TILE_COUNT,
	"XZON": CityState.TILE_COUNT,
	"XUND": CityState.TILE_COUNT,
	"XBIT": CityState.TILE_COUNT,
	"XTRF": 64 * 64,
	"XTXT": CityState.TILE_COUNT,
	"XLAB": CityState.LABEL_COUNT * CityState.LABEL_RECORD_SIZE,
	"XMIC": CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE,
	"MISC": 4800,
}


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
	var result := _result(disaster_type, point, true, true, 0)
	result.view_center_requests = []

	return result


static func _start_plane_crash(city: CityState, lfsr_random) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if lfsr_random == null or not lfsr_random.has_method("next_mask"):
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	var thing_chunk := city.document.find_chunk("XTHG")
	var text_chunk := city.document.find_chunk("XTXT")

	if (
		thing_chunk == null
		or thing_chunk.decoded_payload.size()
		!= city.document.decoded_size("XTHG")
		or text_chunk == null
		or text_chunk.decoded_payload.size() != city.document.decoded_size("XTXT")
	):
		return {"ok": false, "error": "plane-crash moving-object data is missing or invalid"}

	var things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	var point := Vector2i.ZERO

	while true:
		point = Vector2i(
			lfsr_random.next_mask(0xffff) % (map_edge / 2) + map_edge / 4,
			lfsr_random.next_mask(0xffff) % (map_edge / 2) + map_edge / 4
		)

		if OverlayData.read(text, _index(point, map_edge)) == 0:
			break

	var record := _first_free_record(things)

	if record == 0:
		return _result(DISASTER_PLANE_CRASH, point, false, true, 0)

	var offset := record * CityState.THING_RECORD_SIZE
	ThingData.write(things, offset, TYPE_AIRPLANE)
	ThingData.write(things, offset + 2, 7)
	ThingData.write(things, offset + 3, point.x)
	ThingData.write(things, offset + 4, point.y)
	ThingData.write(things, offset + 5, 16)
	ThingData.write(things, offset + 6, 8)
	ThingData.write(things, offset + 7, 8)
	ThingData.write(things, offset + 10, 0)
	OverlayData.write(text, _index(point, map_edge), OverlayData.thing_id(record))
	var old_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()

	if not thing_chunk.set_decoded_payload(things):
		return {"ok": false, "error": "cannot store the crashing plane"}

	if not text_chunk.set_decoded_payload(text):
		thing_chunk.set_decoded_payload(old_things)

		return {"ok": false, "error": "cannot link the crashing plane"}

	city.text_overlays = text.duplicate()

	return _result(DISASTER_PLANE_CRASH, point, true, true, record)


static func _start_fire(city: CityState, random, lfsr_random) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

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
		return {"ok": false, "error": "fire disaster input chunks are missing or invalid"}

	var payloads := _duplicate_payloads(original)
	var runtime_events := DisasterMapDamage.new_runtime_events()
	var point := Vector2i(
		_read_u32_be(payloads.MISC, MISC_CITY_CENTER_X) - 20 + random.next_u15() % 40,
		_read_u32_be(payloads.MISC, MISC_CITY_CENTER_Y) - 20 + random.next_u15() % 40
	)
	var direction := 0
	var run_length := 1
	var step := 0

	while run_length < 64:
		point.x += FIRE_SPIRAL_X[direction]
		point.y += FIRE_SPIRAL_Y[direction]
		var index := _index(point, map_edge)

		if (
			index >= 0
			and payloads.XBLD[index] > 0x6f
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

	var result := _result(DISASTER_FIRE, point, false, true, 0)
	result["notice_ids"] = [0xf5]

	return result


static func _start_flood(city: CityState, requested_point: Vector2i, lfsr_random) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if lfsr_random == null or not lfsr_random.has_method("next_mask"):
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	var original := _map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "flood disaster input chunks are missing or invalid"}

	var payloads := _duplicate_payloads(original)
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

		if payloads.XTER[_index(point, map_edge)] == 0:
			OverlayData.write(payloads.XTXT, _index(point, map_edge), 0xfc)

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
					var index := _index(point, map_edge)

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
	var map_edge: int = city.map_size if city != null else 128

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
		return {"ok": false, "error": "earthquake disaster input chunks are missing or invalid"}

	var payloads := _duplicate_payloads(original)
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
			var index := _index(target, map_edge)

			if index < 0 or payloads.XBLD[index] <= 0x0d:
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

	var map_changed := _payloads_changed(original, payloads)

	if map_changed and not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the earthquake disaster"}

	var result := _result(DISASTER_EARTHQUAKE, point, true, true, 0)
	result["gate_attempts"] = 65 * 65
	result["gate_hits"] = gate_hits
	result["eligible_targets"] = eligible_targets
	result["fire_damage_attempts"] = fire_damage_attempts
	result["structure_damage_attempts"] = structure_damage_attempts
	result["map_changed"] = map_changed
	var effect_events: Array[Dictionary] = [{
		"type": "earthquake",
		"frames": 24,
		"frame_msec": 5,
		"distance": 4,
	}]
	effect_events.append_array(runtime_events.effect_events)
	result["effect_events"] = effect_events
	var sounds: Array[int] = []

	for _frame in 24:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		sounds.append(SOUND_EARTHQUAKE)

	sounds.append_array(runtime_events.sound_events)
	sounds.append(SOUND_SIREN)
	result["sound_events"] = sounds

	return result


static func _start_meltdown(
	city: CityState, requested_point: Vector2i, random, lfsr_random
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}

	if lfsr_random == null or not lfsr_random.has_method("next_mod"):
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	var original := _map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "meltdown disaster input chunks are missing or invalid"}

	var payloads := _duplicate_payloads(original)
	var runtime_events := DisasterMapDamage.new_runtime_events()
	var plant_point := _find_nuclear_power_plant(payloads.XBLD, requested_point, map_edge)

	if plant_point.x < 0:
		return _result(DISASTER_MELTDOWN, requested_point, false, true, 0)

	var center := plant_point
	var site := Demolish._find_building_site(
		payloads.XBLD,
		payloads.XZON,
		plant_point,
		NUCLEAR_POWER_PLANT,
		4,
		city.compass_rotation(), map_edge,
	)

	if site.size != Vector2i.ZERO:
		center = Vector2i(site.position.x + 1, site.end.y - 2)

	var plant_damage := DisasterMapDamage.burn_structure(
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
		center,
		random,
		lfsr_random,
		true,
		true,
		true,
	)
	DisasterMapDamage.append_damage_events(runtime_events, plant_damage)

	var gate_hits := 0
	var fire_damage_attempts := 0
	var structure_damage_attempts := 0
	var radioactive_writes := 0
	var toxic_writes := 0

	for x_offset in range(-32, 33):
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y_offset in range(-32, 33):
			if random.next_u15() & 0x1f != 0:
				continue

			gate_hits += 1
			var target := center + Vector2i(x_offset, y_offset)
			var index := _index(target, map_edge)

			if index < 0:
				continue

			if random.next_u15() & 3 == 0:
				fire_damage_attempts += 1
				DisasterMapDamage.apply(
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
					target,
					random,
					lfsr_random,
					true,
					runtime_events,
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
					false,
				)

				if random.next_u15() & 1 != 0:
					if payloads.XBIT[index] & 0x04 == 0:
						if _write_radioactivity(payloads, target, map_edge):
							radioactive_writes += 1
					else:
						OverlayData.write(payloads.XTXT, index, 0xfb)
						toxic_writes += 1

	for x_offset in range(-1, 3):
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y_offset in range(-2, 2):
			if random.next_u15() & 1 != 0:
				if _write_radioactivity(payloads, center + Vector2i(x_offset, y_offset), map_edge):
					radioactive_writes += 1

	var map_changed := _payloads_changed(original, payloads)

	if map_changed and not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the meltdown disaster"}

	var result := _result(DISASTER_MELTDOWN, center, true, true, 0)
	result["plant_point"] = plant_point
	result["plant_site"] = site
	result["gate_attempts"] = 65 * 65
	result["gate_hits"] = gate_hits
	result["fire_damage_attempts"] = fire_damage_attempts
	result["structure_damage_attempts"] = structure_damage_attempts
	result["radioactive_writes"] = radioactive_writes
	result["toxic_writes"] = toxic_writes
	result["map_changed"] = map_changed
	result["effect_events"] = runtime_events.effect_events
	var sounds: Array[int] = runtime_events.sound_events.duplicate()
	sounds.append(SOUND_SIREN)
	result["sound_events"] = sounds

	return result


static func _find_nuclear_power_plant(
	buildings: PackedByteArray, requested_point: Vector2i,
	map_edge: int = 128,
) -> Vector2i:
	var requested_index := _index(requested_point, map_edge)

	if requested_index >= 0 and buildings[requested_index] == NUCLEAR_POWER_PLANT:
		return requested_point

	for x in map_edge:
		for y in map_edge:
			if buildings[x * map_edge + y] == NUCLEAR_POWER_PLANT:
				return Vector2i(x, y)

	return Vector2i(-1, -1)


static func _write_radioactivity(payloads: Dictionary, point: Vector2i, map_edge: int = 128) -> bool:
	var index := _index(point, map_edge)

	if index < 0:
		return false

	var old_tile := int(payloads.XBLD[index])
	SpecialZoneGrowth.replace_building(
		payloads.XBLD, payloads.XZON, payloads.MISC, index, RADIOACTIVITY_TILE
	)

	return old_tile != RADIOACTIVITY_TILE


static func _start_microwave(city: CityState, random, lfsr_random) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}

	if lfsr_random == null or not lfsr_random.has_method("next_mod"):
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	var original := _map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "microwave disaster input chunks are missing or invalid"}

	var payloads := _duplicate_payloads(original)
	var plant_point := _find_first_building(payloads.XBLD, MICROWAVE_POWER_PLANT, map_edge)

	if plant_point.x < 0:
		return _result(DISASTER_MICROWAVE, plant_point, false, true, 0)

	var point := plant_point
	var remaining := 39
	var direction: int = random.next_u15()
	var damage_points: Array[Vector2i] = []
	var toxic_writes := 0
	var view_centers: Array[Vector2i] = [plant_point]
	var runtime_events := DisasterMapDamage.new_runtime_events()

	while remaining > 0:
		var index := _index(point, map_edge)

		if index < 0:
			break

		if payloads.XBLD[index] != MICROWAVE_POWER_PLANT:
			if payloads.XBIT[index] & 0x04 != 0:
				OverlayData.write(payloads.XTXT, index, 0xfb)
				toxic_writes += 1

			if remaining % 10 == 0:
				view_centers.append(point)

			DisasterMapDamage.apply(
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
			damage_points.append(point)
			runtime_events.sound_events.append(SOUND_MICROWAVE)

		remaining -= 1
		point += EIGHT_DIRECTIONS[direction & 7]
		direction = random.next_u15()

	var map_changed := _payloads_changed(original, payloads)

	if map_changed and not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the microwave disaster"}

	var result := _result(DISASTER_MICROWAVE, plant_point, true, true, 0)
	var sounds: Array[int] = runtime_events.sound_events.duplicate()
	sounds.append(SOUND_SIREN)
	result["sound_events"] = sounds
	result["effect_events"] = runtime_events.effect_events
	result["view_center_requests"] = view_centers
	result["plant_point"] = plant_point
	result["path_finish"] = point
	result["path_steps"] = 39 - remaining
	result["damage_points"] = damage_points
	result["damage_attempts"] = damage_points.size()
	result["toxic_writes"] = toxic_writes
	result["map_changed"] = map_changed

	return result


static func _find_first_building(buildings: PackedByteArray, tile_id: int, map_edge: int = 128) -> Vector2i:
	for x in map_edge:
		for y in map_edge:
			if buildings[x * map_edge + y] == tile_id:
				return Vector2i(x, y)

	return Vector2i(-1, -1)


static func _start_volcano(city: CityState, center: Vector2i, random) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}

	var original := _map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "volcano disaster input chunks are missing or invalid"}

	var payloads := _duplicate_payloads(original)
	var heights := TerrainCommand._decode_heights(payloads.ALTM, map_edge)
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

			if _index(near_point, map_edge) >= 0:
				break

		var near_index := _index(near_point, map_edge)

		if random.next_u15() & 1 == 0:
			OverlayData.write(payloads.XTXT, near_index, 0xfb)
			near_toxic_writes += 1
		else:
			OverlayData.write(payloads.XTXT, near_index, 0xff)
			near_fire_writes += 1

		if _volcano_raise_is_valid(heights, payloads.XZON, payloads.XBIT, near_point, {}, map_edge):
			var trial := TerrainCommand._plan_raise(
				heights, payloads.XZON, payloads.XBLD, near_point, remaining_budget, map_edge
			)

			if trial.get("valid", false):
				heights = trial.heights
				remaining_budget = int(trial.funds)
				TerrainCommand._write_heights(payloads.ALTM, heights, trial.modified)

				for index in trial.zone_indices:
					payloads.XZON[index] &= 0xf0

				var retile_indices := TerrainCommand._expanded_indices(trial.modified, map_edge)
				TerrainCommand._retile_region(
					payloads.ALTM,
					payloads.XBLD,
					payloads.XTER,
					payloads.XZON,
					payloads.XBIT,
					payloads.MISC,
					retile_indices,
					_read_u32_be(payloads.MISC, 0x0e40), map_edge,
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
		var distant_index := _index(distant_point, map_edge)

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

	var map_changed := _payloads_changed(original, payloads)

	if map_changed and not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the volcano disaster"}

	var result := _result(DISASTER_VOLCANO, center, true, true, 0)
	sounds.append(SOUND_SIREN)
	result["sound_events"] = sounds
	result["iterations"] = iterations
	result["successful_raises"] = successful_raises
	result["rejected_raises"] = rejected_raises
	result["temporary_budget_spent"] = VOLCANO_BUDGET - remaining_budget
	result["near_toxic_writes"] = near_toxic_writes
	result["near_fire_writes"] = near_fire_writes
	result["distant_toxic_writes"] = distant_toxic_writes
	result["distant_fire_writes"] = distant_fire_writes
	result["terrain_indices"] = changed_indices
	result["map_changed"] = map_changed

	return result


static func _volcano_raise_is_valid(
	heights: PackedInt32Array,
	zones: PackedByteArray,
	flags: PackedByteArray,
	point: Vector2i,
	visited := {},
	map_edge: int = 128,
) -> bool:
	var index := _index(point, map_edge)

	if index < 0 or visited.has(index):
		return true

	if zones[index] & 0x0f == TerrainCommand.MILITARY_ZONE:
		return false

	if flags[index] & 0x04 != 0 or heights[index] > TerrainCommand.MAX_RAISE_SOURCE:
		return false

	visited[index] = true

	for offset in TerrainCommand.NEIGHBOR_OFFSETS:
		var neighbor: Vector2i = point + offset
		var neighbor_index := _index(neighbor, map_edge)

		if neighbor_index < 0:
			continue

		if zones[neighbor_index] & 0x0f == TerrainCommand.MILITARY_ZONE:
			return false

		if flags[neighbor_index] & 0x04 != 0:
			return false

	for offset in TerrainCommand.CARDINAL_OFFSETS:
		var neighbor: Vector2i = point + offset
		var neighbor_index := _index(neighbor, map_edge)

		if neighbor_index >= 0 and heights[neighbor_index] < heights[index]:
			if not _volcano_raise_is_valid(heights, zones, flags, neighbor, visited, map_edge):
				return false

	return true


static func _start_firestorm(
	city: CityState, center: Vector2i, random, lfsr_random
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}

	if lfsr_random == null or not lfsr_random.has_method("next_mod"):
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	var original := _map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "firestorm disaster input chunks are missing or invalid"}

	var payloads := _duplicate_payloads(original)
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

		if _index(point, map_edge) >= 0:
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
	var map_changed := _payloads_changed(original, payloads)

	if map_changed and not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the firestorm disaster"}

	var result := _result(DISASTER_FIRESTORM, center, started, true, 0)
	result["requested_point"] = center
	result["scan_finish"] = point
	result["scan_steps"] = scan_steps
	result["attempted_in_map"] = attempted_in_map
	result["successful_cells"] = 65 - remaining
	result["remaining_cells"] = remaining
	result["result_codes"] = result_codes
	result["accepted_points"] = accepted_points
	result["map_changed"] = map_changed
	result["effect_events"] = runtime_events.effect_events

	if started:
		result["view_center_requests"] = [point]
		var sounds: Array[int] = runtime_events.sound_events.duplicate()
		sounds.append(SOUND_SIREN)
		result["sound_events"] = sounds

	return result


static func _start_mass_floods(
	city: CityState, center: Vector2i, random, lfsr_random
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}

	if lfsr_random == null or not lfsr_random.has_method("next_mask"):
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	var original := _map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "mass-flood disaster input chunks are missing or invalid"}

	var attempt_count := (
		int(city.document.misc_u32(MISC_NORMAL_POPULATION) / 10000) + 5
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

			if _index(candidate, map_edge) < 0:
				continue

			candidate_points.append(candidate)
			var flood := _start_flood(city, candidate, lfsr_random)

			if not flood.get("ok", false):
				return flood

			if flood.get("started", false):
				seed_points.append(flood.point)

	var started := not seed_points.is_empty()
	var current := _map_payloads(city)
	var map_changed := not current.is_empty() and _payloads_changed(original, current)
	var result := _result(DISASTER_MASS_FLOODS, center, started, true, 0)
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

	var original := _map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "hurricane disaster input chunks are missing or invalid"}

	var payloads := _duplicate_payloads(original)
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
				if y > 0 and payloads.XBLD[_index(Vector2i(x, y), map_edge)] > 0x0c:
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
				if x > 0 and payloads.XBLD[_index(Vector2i(x, y), map_edge)] > 0x0c:
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
				if y < (map_edge - 1) and payloads.XBLD[_index(Vector2i(x, y), map_edge)] > 0x0c:
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
				if x < (map_edge - 1) and payloads.XBLD[_index(Vector2i(x, y), map_edge)] > 0x0c:
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
	var map_changed := _payloads_changed(original, payloads)

	if map_changed and not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the hurricane disaster"}

	var result := _result(DISASTER_HURRICANE, requested_point, true, true, 0)
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

			while point.y >= 0 and payloads.XBLD[_index(point, map_edge)] <= 5:
				point.y -= 1

			if point.y <= 0:
				continue
		elif direction == 1:
			point = Vector2i((map_edge - 1), fixed)

			while point.x >= 0 and payloads.XBLD[_index(point, map_edge)] <= 5:
				point.x -= 1

			if point.x <= 0:
				continue
		elif direction == 2:
			point = Vector2i(fixed, 0)

			while point.y < (map_edge - 1) and payloads.XBLD[_index(point, map_edge)] <= 5:
				point.y += 1

			if point.y >= (map_edge - 1):
				continue
		else:
			point = Vector2i(0, fixed)

			while point.x < map_edge and payloads.XBLD[_index(point, map_edge)] <= 5:
				point.x += 1

			if point.x >= (map_edge - 1):
				continue

		OverlayData.write(payloads.XTXT, _index(point, map_edge), 0xfc)
		flood_points.append(point)


static func _seed_flood_if_dry(payloads: Dictionary, point: Vector2i, map_edge: int = 128) -> void:
	var index := _index(point, map_edge)

	if index >= 0 and payloads.XBIT[index] & 0x04 == 0:
		OverlayData.write(payloads.XTXT, index, 0xfc)


static func _store_flood(
	city: CityState, original: Dictionary, payloads: Dictionary, point: Vector2i
) -> Dictionary:
	if not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the flood disaster"}

	return _flood_result(point, true)


static func _flood_result(point: Vector2i, started: bool) -> Dictionary:
	var result := _result(DISASTER_FLOOD, point, started, true, 0)
	result["sound_events"] = [SOUND_FLOOD, SOUND_SIREN] if started else []
	result["map_counter"] = 60 if started else 0

	return result


static func _apply_fire_damage(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	random,
	lfsr_random,
	runtime_events: Dictionary = {},
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
	runtime_events: Dictionary,
) -> Dictionary:
	if not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the fire disaster"}

	var result := _result(DISASTER_FIRE, point, true, true, 0)
	result["effect_events"] = runtime_events.effect_events
	var sounds: Array[int] = runtime_events.sound_events.duplicate()
	sounds.append(SOUND_SIREN)
	result["sound_events"] = sounds

	return result


static func has_active_object(city: CityState, _disaster_type: int) -> bool:
	if city == null or not city.is_valid():
		return false

	var chunk := city.document.find_chunk("XTHG")

	if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size("XTHG"):
		return false

	var things: PackedByteArray = chunk.decoded_payload

	for record in range(1, ThingData.count(things)):
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var offset := record * CityState.THING_RECORD_SIZE
		var type := int(ThingData.read(things, offset))

		if type == TYPE_MONSTER or type == TYPE_TORNADO or type == TYPE_EXPLOSION:
			return true

		if type == TYPE_AIRPLANE and ThingData.read(things, offset + 2) == 7:
			return true

	return false


static func _result(
	disaster_type: int, point: Vector2i, started: bool, complete: bool, record: int
) -> Dictionary:
	return {
		"ok": true,
		"error": "",
		"disaster_type": disaster_type,
		"point": point,
		"started": started,
		"implemented": complete,
		"record": record,
		"news_items": [],
		"notice_ids": [],
		"map_counter": 0,
		"sound_events": [SOUND_SIREN] if started else [],
		"view_center_requests": [point] if started else [],
		"complete": complete,
	}


static func _count_type(things: PackedByteArray, thing_type: int) -> int:
	var count := 0

	for record in range(1, ThingData.count(things)):
		if ThingData.read(things, record * CityState.THING_RECORD_SIZE) == thing_type:
			count += 1

	return count


static func _first_free_record(things: PackedByteArray) -> int:
	for record in range(1, ThingData.count(things)):
		if ThingData.read(things, record * CityState.THING_RECORD_SIZE) == 0:
			return record

	return 0


static func _remove_thing(things: PackedByteArray, text: PackedByteArray, record: int, map_edge: int = 128) -> void:
	if record <= 0 or record >= ThingData.count(things):
		return

	var offset := record * CityState.THING_RECORD_SIZE
	var point := Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))

	if point.x < map_edge and point.y < map_edge:
		var index := point.x * map_edge + point.y

		if OverlayData.read(text, index) == OverlayData.thing_id(record):
			OverlayData.write(text, index, ThingData.read(things, offset + 10))

	for byte_index in CityState.THING_RECORD_SIZE:
		ThingData.write(things, offset + byte_index, 0)


static func _map_payloads(city: CityState) -> Dictionary:
	var result := {}

	for chunk_id in MAP_CHUNK_SIZES:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size(chunk_id):
			return {}

		result[chunk_id] = chunk.decoded_payload.duplicate()

	return result


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary:
	var result := {}

	for chunk_id in payloads:
		result[chunk_id] = payloads[chunk_id].duplicate()

	return result


static func _payloads_changed(original: Dictionary, payloads: Dictionary) -> bool:
	for chunk_id in MAP_CHUNK_SIZES:
		if payloads[chunk_id] != original[chunk_id]:
			return true

	return false


static func _apply_map_payloads(
	city: CityState, original: Dictionary, payloads: Dictionary
) -> bool:
	var applied := PackedStringArray()

	for chunk_id in MAP_CHUNK_SIZES:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		if payloads[chunk_id] == original[chunk_id]:
			continue

		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not chunk.set_decoded_payload(payloads[chunk_id]):
			for rollback_id in applied:
				city.document.find_chunk(rollback_id).set_decoded_payload(original[rollback_id])

			_refresh_city_arrays(city)

			return false

		applied.append(chunk_id)

	_refresh_city_arrays(city)

	return true


static func _refresh_city_arrays(city: CityState) -> void:
	var map_edge: int = city.map_size if city != null else 128
	city.buildings = city.document.find_chunk("XBLD").decoded_payload.duplicate()
	city.terrain = city.document.find_chunk("XTER").decoded_payload.duplicate()
	city.zones = city.document.find_chunk("XZON").decoded_payload.duplicate()
	city.underground = city.document.find_chunk("XUND").decoded_payload.duplicate()
	city.tile_flags = city.document.find_chunk("XBIT").decoded_payload.duplicate()
	city.text_overlays = city.document.find_chunk("XTXT").decoded_payload.duplicate()
	var altitude: PackedByteArray = city.document.find_chunk("ALTM").decoded_payload

	for index in (map_edge * map_edge):
		if city.simulation_slice != null and (index & 127) == 0:
			city.simulation_slice.checkpoint()

		city.altitude_words[index] = (altitude[index * 2] << 8) | altitude[index * 2 + 1]


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.y < 0 or point.x >= map_edge or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y
