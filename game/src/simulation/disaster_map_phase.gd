class_name DisasterMapPhase
extends RefCounted

const DisasterMapDamage = preload("res://src/simulation/disaster_damage.gd")
const Demolish = preload("res://src/tools/demolish_command.gd")
const FIRE_OVERLAY := 0xff
const TOXIC_OVERLAY := 0xfb
const SOUND_FIRE := 0x1fb
const SOUND_FLOOD := 0x1ff
const TYPE_EXPLOSION := 6
const TEXT_THING_BASE := 201
const SPECIAL_TOXIC_BUILDINGS := {0x85: true, 0x9f: true, 0xbc: true}
const CARDINAL_DIRECTIONS := [
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1),
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
	"XTHG": CityState.THING_COUNT * CityState.THING_RECORD_SIZE,
	"XFIR": 32 * 32,
	"MISC": 4800,
}


static func run_fire(city: CityState, random, lfsr_random) -> Dictionary:
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
		return {"ok": false, "error": "fire-map input chunks are missing or invalid"}
	var payloads := _duplicate_payloads(original)
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
	}
	var active := false
	for x in CityState.MAP_SIZE:
		for y in CityState.MAP_SIZE:
			var index := x * CityState.MAP_SIZE + y
			if payloads.XTXT[index] != FIRE_OVERLAY:
				continue
			active = true
			counters.fire_markers_scanned += 1
			if random.next_u15() & 3 != 0:
				continue
			counters.fire_updates += 1
			if payloads.XBIT[index] & 0x04 != 0:
				payloads.XTXT[index] = 0
				counters.water_extinctions += 1
				continue
			var point := Vector2i(x, y)
			var choice: int = random.next_u15() & 7
			if choice < 4:
				counters.spread_attempts += 1
				var target: Vector2i = point + CARDINAL_DIRECTIONS[choice]
				if _starts_fire(_apply_damage(city, payloads, target, random, lfsr_random)):
					counters.spread_fires += 1
			elif choice == 5:
				var tile := int(payloads.XBLD[index])
				if tile > 0x6f:
					var toxic_site := Rect2i()
					if SPECIAL_TOXIC_BUILDINGS.has(tile):
						toxic_site = _building_site(city, payloads, point, tile)
					_collapse_structure(city, payloads, point, tile, random, lfsr_random)
					counters.structure_collapses += 1
					if lfsr_random.next_mask(0x0f) == 0 and _spawn_explosion(
						payloads.XTXT, payloads.XTHG, point, 0, 0, 1
					):
						counters.created_explosions += 1
					if SPECIAL_TOXIC_BUILDINGS.has(tile):
						counters.toxic_markers += _seed_special_toxic(payloads, toxic_site, point)
			else:
				var coverage := int(payloads.XFIR[int(x / 4) * 32 + int(y / 4)]) + 8
				if (random.next_u15() & 0xff) < coverage:
					_collapse_structure(
						city, payloads, point, int(payloads.XBLD[index]), random, lfsr_random
					)
					counters.coverage_extinctions += 1
	var map_changed := _payloads_changed(original, payloads)
	if map_changed and not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the fire-map tick"}
	counters["ok"] = true
	counters["error"] = ""
	counters["active"] = active
	counters["remaining_fires"] = payloads.XTXT.count(FIRE_OVERLAY)
	counters["map_changed"] = map_changed
	counters["news_items"] = []
	counters["effect_events"] = []
	counters["sound_events"] = [SOUND_FIRE] if active else []
	counters["view_center_requests"] = []
	counters["complete"] = true
	return counters


static func run_flood(
	city: CityState, random, lfsr_random, map_counter: int
) -> Dictionary:
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
		return {"ok": false, "error": "flood-map input chunks are missing or invalid"}
	var payloads := _duplicate_payloads(original)
	var counter := maxi(map_counter - 1, 0)
	var counters := {
		"flood_markers_scanned": 0,
		"flood_updates": 0,
		"spread_attempts": 0,
		"spread_floods": 0,
		"expired_floods": 0,
		"random_extinctions": 0,
		"damaged_structures": 0,
	}
	var active := false
	for x in CityState.MAP_SIZE:
		for y in CityState.MAP_SIZE:
			var index := x * CityState.MAP_SIZE + y
			if payloads.XTXT[index] != 0xfc:
				continue
			active = true
			counters.flood_markers_scanned += 1
			if counter == 0 and lfsr_random.next_mask(1) != 0:
				payloads.XTXT[index] = 0
				counters.expired_floods += 1
				continue
			var update := counter > 51
			if not update:
				update = random.next_u15() & 3 == 0
			if not update:
				continue
			counters.flood_updates += 1
			var point := Vector2i(x, y)
			if counter < 30 and random.next_u15() & 3 == 0:
				if payloads.XBLD[index] > 0x6f:
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
						point,
						random,
						lfsr_random,
						false,
						false
					)
					counters.damaged_structures += 1
				payloads.XTXT[index] = 0
				counters.random_extinctions += 1
			if counter > 0:
				counters.spread_attempts += 1
				var target: Vector2i = point + CARDINAL_DIRECTIONS[random.next_u15() & 3]
				if _apply_flood_damage(
					city,
					payloads,
					target,
					_altitude_word(payloads.ALTM, index) & 0x1f,
					random,
					lfsr_random
				) == 1:
					counters.spread_floods += 1
	var map_changed := _payloads_changed(original, payloads)
	if map_changed and not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the flood-map tick"}
	var sound_events: Array[int] = []
	if active and random.next_u15() & 7 == 0:
		sound_events.append(SOUND_FLOOD)
	counters["ok"] = true
	counters["error"] = ""
	counters["active"] = active
	counters["remaining_floods"] = payloads.XTXT.count(0xfc)
	counters["map_counter"] = counter
	counters["map_changed"] = map_changed
	counters["news_items"] = []
	counters["effect_events"] = []
	counters["sound_events"] = sound_events
	counters["view_center_requests"] = []
	counters["complete"] = true
	return counters


static func _apply_damage(
	city: CityState, payloads: Dictionary, point: Vector2i, random, lfsr_random
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
		lfsr_random
	)


static func _starts_fire(result_code: int) -> bool:
	return result_code == 1 or result_code == 3 or result_code == 4


static func _apply_flood_damage(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	maximum_altitude: int,
	random,
	lfsr_random
) -> int:
	return DisasterMapDamage.apply_flood(
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
		maximum_altitude,
		random,
		lfsr_random
	)


static func _collapse_structure(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	_tile: int,
	random,
	lfsr_random
) -> void:
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
		point,
		random,
		lfsr_random
	)


static func _building_site(
	city: CityState, payloads: Dictionary, point: Vector2i, tile: int
) -> Rect2i:
	var area: int = Demolish._building_area(tile)
	return Demolish._find_building_site(
		payloads.XBLD, payloads.XZON, point, tile, area, city.compass_rotation()
	)


static func _seed_special_toxic(
	payloads: Dictionary, site: Rect2i, point: Vector2i
) -> int:
	if site.size == Vector2i.ZERO:
		site = Rect2i(point, Vector2i.ONE)
	var changed := 0
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var index := x * CityState.MAP_SIZE + y
			if payloads.XTXT[index] < 51:
				payloads.XTXT[index] = TOXIC_OVERLAY
				changed += 1
	return changed


static func _spawn_explosion(
	text: PackedByteArray,
	things: PackedByteArray,
	point: Vector2i,
	height: int,
	state: int,
	goal: int
) -> bool:
	var index := _index(point)
	if index < 0 or text[index] >= TEXT_THING_BASE:
		return false
	var record := 0
	for checked_record in range(1, CityState.THING_COUNT):
		if things[checked_record * CityState.THING_RECORD_SIZE] == 0:
			record = checked_record
			break
	if record == 0:
		return false
	var offset := record * CityState.THING_RECORD_SIZE
	things[offset] = TYPE_EXPLOSION
	things[offset + 1] = 0
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = height
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 10] = text[index]
	things[offset + 11] = goal
	text[index] = record + TEXT_THING_BASE
	return true


static func _map_payloads(city: CityState) -> Dictionary:
	var result := {}
	for chunk_id in MAP_CHUNK_SIZES:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or chunk.decoded_payload.size() != MAP_CHUNK_SIZES[chunk_id]:
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
	city.buildings = city.document.find_chunk("XBLD").decoded_payload.duplicate()
	city.terrain = city.document.find_chunk("XTER").decoded_payload.duplicate()
	city.zones = city.document.find_chunk("XZON").decoded_payload.duplicate()
	city.underground = city.document.find_chunk("XUND").decoded_payload.duplicate()
	city.tile_flags = city.document.find_chunk("XBIT").decoded_payload.duplicate()
	city.text_overlays = city.document.find_chunk("XTXT").decoded_payload.duplicate()
	var altitude: PackedByteArray = city.document.find_chunk("ALTM").decoded_payload
	for index in CityState.TILE_COUNT:
		city.altitude_words[index] = (altitude[index * 2] << 8) | altitude[index * 2 + 1]


static func _index(point: Vector2i) -> int:
	if point.x < 0 or point.y < 0 or point.x >= CityState.MAP_SIZE or point.y >= CityState.MAP_SIZE:
		return -1
	return point.x * CityState.MAP_SIZE + point.y


static func _altitude_word(altitude: PackedByteArray, index: int) -> int:
	return (altitude[index * 2] << 8) | altitude[index * 2 + 1]
