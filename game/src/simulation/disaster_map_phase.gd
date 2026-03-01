class_name DisasterMapPhase
extends RefCounted

const DisasterMapDamage = preload("res://src/simulation/disaster_damage.gd")
const Demolish = preload("res://src/tools/city/demolish_command.gd")
const Growth = preload("res://src/simulation/growth_phase.gd")
const NetworkTiles = preload("res://src/tools/city/network_command.gd")
const FIRE_OVERLAY := 0xff
const TOXIC_OVERLAY := 0xfb
const FLOOD_OVERLAY := 0xfc
const RIOT_OVERLAY_FORWARD := 0xfd
const RIOT_OVERLAY_REVERSE := 0xfe
const SOUND_FIRE := 0x1fb
const SOUND_FLOOD := 0x1ff
const SOUND_RIOT := 0x200
const SOUND_HURRICANE := 0x1f6
const SOUND_EARTHQUAKE := 0x1f8
const TYPE_EXPLOSION := 6
const TYPE_POLICE := 7
const TYPE_FIRE_DISPATCH := 8
const TYPE_MILITARY := 14
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
	"XVAL": 64 * 64,
	"XTXT": CityState.TILE_COUNT,
	"XLAB": CityState.LABEL_COUNT * CityState.LABEL_RECORD_SIZE,
	"XMIC": CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE,
	"XTHG": CityState.THING_COUNT * CityState.THING_RECORD_SIZE,
	"XFIR": 32 * 32,
	"MISC": 4800,
}


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
	var runtime_events := DisasterMapDamage.new_runtime_events()
	var active := false

	for x in map_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y in map_edge:
			if city.simulation_slice != null and (y & 15) == 0:
				city.simulation_slice.checkpoint()

			var index := x * map_edge + y

			if OverlayData.read(payloads.XTXT, index) != FIRE_OVERLAY:
				continue

			active = true
			counters.fire_markers_scanned += 1

			if random.next_u15() & 3 != 0:
				continue

			counters.fire_updates += 1

			if payloads.XBIT[index] & 0x04 != 0:
				OverlayData.write(payloads.XTXT, index, 0)
				counters.water_extinctions += 1
				continue

			var point := Vector2i(x, y)
			var choice: int = random.next_u15() & 7

			if choice < 4:
				counters.spread_attempts += 1
				var target: Vector2i = point + CARDINAL_DIRECTIONS[choice]

				if _starts_fire(
					_apply_damage(
						city, payloads, target, random, lfsr_random, runtime_events
					)
				):
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
						payloads.XTXT, payloads.XTHG, point, 0, 0, 1, map_edge
					):
						counters.created_explosions += 1

					if SPECIAL_TOXIC_BUILDINGS.has(tile):
						counters.toxic_markers += _seed_special_toxic(payloads, toxic_site, point, map_edge)
			else:
				var coverage := int(payloads.XFIR[CityDataGrid.index(payloads.XFIR, map_edge, x, y)]) + 8

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
	counters["remaining_fires"] = OverlayData.occurrences(payloads.XTXT, FIRE_OVERLAY)
	counters["map_changed"] = map_changed
	counters["news_items"] = []
	counters["effect_events"] = runtime_events.effect_events
	var sound_events: Array[int] = runtime_events.sound_events

	if active:
		sound_events.append(SOUND_FIRE)

	counters["sound_events"] = sound_events
	counters["view_center_requests"] = []
	counters["complete"] = true

	return counters


static func run_flood(
	city: CityState, random, lfsr_random, map_counter: int
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
	var runtime_events := DisasterMapDamage.new_runtime_events()
	var active := false

	for x in map_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y in map_edge:
			if city.simulation_slice != null and (y & 15) == 0:
				city.simulation_slice.checkpoint()

			var index := x * map_edge + y

			if OverlayData.read(payloads.XTXT, index) != 0xfc:
				continue

			active = true
			counters.flood_markers_scanned += 1

			if counter == 0 and lfsr_random.next_mask(1) != 0:
				OverlayData.write(payloads.XTXT, index, 0)
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

				OverlayData.write(payloads.XTXT, index, 0)
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
					lfsr_random,
					runtime_events,
				) == 1:
					counters.spread_floods += 1

	var map_changed := _payloads_changed(original, payloads)

	if map_changed and not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the flood-map tick"}

	var sound_events: Array[int] = runtime_events.sound_events

	if active and random.next_u15() & 7 == 0:
		sound_events.append(SOUND_FLOOD)

	counters["ok"] = true
	counters["error"] = ""
	counters["active"] = active
	counters["remaining_floods"] = OverlayData.occurrences(payloads.XTXT, 0xfc)
	counters["map_counter"] = counter
	counters["map_changed"] = map_changed
	counters["news_items"] = []
	counters["effect_events"] = runtime_events.effect_events
	counters["sound_events"] = sound_events
	counters["view_center_requests"] = []
	counters["complete"] = true

	return counters


static func run_toxic(city: CityState, random, lfsr_random) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}

	if lfsr_random == null or not lfsr_random.has_method("next_mask"):
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	var original := _map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "toxic-map input chunks are missing or invalid"}

	var payloads := _duplicate_payloads(original)
	var counters := {
		"toxic_markers_scanned": 0,
		"toxic_updates": 0,
		"lfsr_expirations": 0,
		"water_expirations": 0,
		"moved_markers": 0,
		"blocked_moves": 0,
		"abandoned_structures": 0,
	}
	var active := false

	for x in map_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y in map_edge:
			if city.simulation_slice != null and (y & 15) == 0:
				city.simulation_slice.checkpoint()

			var index := x * map_edge + y

			if OverlayData.read(payloads.XTXT, index) != TOXIC_OVERLAY:
				continue

			active = true
			counters.toxic_markers_scanned += 1

			if random.next_u15() & 1 != 0:
				continue

			counters.toxic_updates += 1

			if lfsr_random.next_mask(0x3f) == 0:
				OverlayData.write(payloads.XTXT, index, 0)
				counters.lfsr_expirations += 1
				continue

			if payloads.XBIT[index] & 0x04 != 0 and random.next_u15() & 0x0f == 0:
				OverlayData.write(payloads.XTXT, index, 0)
				counters.water_expirations += 1
				continue

			var point := Vector2i(x, y)

			if _abandon_toxic_structure(city, payloads, point, random):
				counters.abandoned_structures += 1

			var direction := _lowest_toxic_direction(payloads.ALTM, point, map_edge)

			if direction < 0:
				direction = random.next_u15() & 3

			OverlayData.write(payloads.XTXT, index, 0)
			var target: Vector2i = point + CARDINAL_DIRECTIONS[direction]

			if _place_toxic_marker(payloads.XTXT, target, map_edge):
				counters.moved_markers += 1
			else:
				counters.blocked_moves += 1

	var map_changed := _payloads_changed(original, payloads)

	if map_changed and not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the toxic-map tick"}

	counters["ok"] = true
	counters["error"] = ""
	counters["active"] = active
	counters["remaining_toxic"] = OverlayData.occurrences(payloads.XTXT, TOXIC_OVERLAY)
	counters["map_changed"] = map_changed
	counters["news_items"] = []
	counters["effect_events"] = []
	counters["sound_events"] = []
	counters["view_center_requests"] = []
	counters["complete"] = true

	return counters


static func run_riot(city: CityState, random, lfsr_random) -> Dictionary:
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
		return {"ok": false, "error": "riot-map input chunks are missing or invalid"}

	var payloads := _duplicate_payloads(original)
	var counters := {
		"riot_markers_scanned": 0,
		"riot_updates": 0,
		"expired_riots": 0,
		"damage_attempts": 0,
		"started_fires": 0,
		"traffic_cells_cleared": 0,
		"propagated_riots": 0,
		"blocked_propagations": 0,
	}
	var runtime_events := DisasterMapDamage.new_runtime_events()
	var active := false

	for x in map_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y in map_edge:
			if city.simulation_slice != null and (y & 15) == 0:
				city.simulation_slice.checkpoint()

			var index := x * map_edge + y
			var marker := int(OverlayData.read(payloads.XTXT, index))

			if marker != RIOT_OVERLAY_FORWARD and marker != RIOT_OVERLAY_REVERSE:
				continue

			active = true
			counters.riot_markers_scanned += 1

			if random.next_u15() & 3 != 0:
				continue

			counters.riot_updates += 1

			if random.next_u15() & 0xff == 0 or payloads.XBIT[index] & 0x04 != 0:
				OverlayData.write(payloads.XTXT, index, 0)
				counters.expired_riots += 1
				continue

			var traffic_index := CityDataGrid.index(payloads.XTRF, map_edge, x, y)

			if payloads.XTRF[traffic_index] != 0:
				counters.traffic_cells_cleared += 1

			payloads.XTRF[traffic_index] = 0
			var damage_direction: int = random.next_u15() & 0x7f

			if damage_direction < 4:
				counters.damage_attempts += 1

				if _starts_fire(
					_apply_damage(
						city,
						payloads,
						Vector2i(x, y) + CARDINAL_DIRECTIONS[damage_direction],
						random,
						lfsr_random,
						runtime_events,
					)
				):
					counters.started_fires += 1

			var first_direction: int = 0 if marker == RIOT_OVERLAY_REVERSE else 2
			var second_direction: int = 1 if marker == RIOT_OVERLAY_REVERSE else 3
			var connections := 0

			if _riot_supports(payloads.XBLD, Vector2i(x, y) + CARDINAL_DIRECTIONS[first_direction], map_edge):
				connections |= 1

			if _riot_supports(payloads.XBLD, Vector2i(x, y) + CARDINAL_DIRECTIONS[second_direction], map_edge):
				connections |= 2

			var opposite_marker: int = (
				RIOT_OVERLAY_FORWARD
				if marker == RIOT_OVERLAY_REVERSE
				else RIOT_OVERLAY_REVERSE
			)

			if connections == 0:
				OverlayData.write(payloads.XTXT, index, opposite_marker)
				continue

			OverlayData.write(payloads.XTXT, index, opposite_marker if random.next_u15() & 7 == 0 else 0)

			if connections == 3:
				connections = (random.next_u15() & 1) + 1

			var spread_direction: int = first_direction if connections == 1 else second_direction

			if _place_riot_marker(
				payloads.XTXT,
				Vector2i(x, y) + CARDINAL_DIRECTIONS[spread_direction],
				marker, map_edge,
			):
				counters.propagated_riots += 1
			else:
				counters.blocked_propagations += 1

	var map_changed := _payloads_changed(original, payloads)

	if map_changed and not _apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the riot-map tick"}

	var sound_events: Array[int] = runtime_events.sound_events

	if active and random.next_u15() & 7 == 0:
		sound_events.append(SOUND_RIOT)

	counters["ok"] = true
	counters["error"] = ""
	counters["active"] = active
	counters["remaining_riots"] = (
		OverlayData.occurrences(payloads.XTXT, RIOT_OVERLAY_FORWARD)
		+ OverlayData.occurrences(payloads.XTXT, RIOT_OVERLAY_REVERSE)
	)
	counters["map_changed"] = map_changed
	counters["news_items"] = []
	counters["effect_events"] = runtime_events.effect_events
	counters["sound_events"] = sound_events
	counters["view_center_requests"] = []
	counters["complete"] = true

	return counters


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
	var map_edge: int = city.map_size if city != null else 128
	counters.fire_markers_scanned += 1

	if random.next_u15() & 3 != 0:
		return

	counters.fire_updates += 1

	if payloads.XBIT[index] & 0x04 != 0:
		OverlayData.write(payloads.XTXT, index, 0)
		counters.water_extinctions += 1

		return

	var choice: int = random.next_u15() & 7

	if choice < 4:
		counters.spread_attempts += 1
		var target: Vector2i = point + CARDINAL_DIRECTIONS[choice]

		if _starts_fire(
			_apply_damage(city, payloads, target, random, lfsr_random, runtime_events)
		):
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
				payloads.XTXT, payloads.XTHG, point, 0, 0, 1, map_edge
			):
				counters.created_explosions += 1

			if SPECIAL_TOXIC_BUILDINGS.has(tile):
				counters.toxic_markers += _seed_special_toxic(payloads, toxic_site, point, map_edge)
	else:
		var coverage := int(payloads.XFIR[CityDataGrid.index(payloads.XFIR, map_edge, point.x, point.y)]) + 8

		if (random.next_u15() & 0xff) < coverage:
			_collapse_structure(
				city, payloads, point, int(payloads.XBLD[index]), random, lfsr_random
			)
			counters.coverage_extinctions += 1


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
	counters.flood_markers_scanned += 1

	if counter == 0 and lfsr_random.next_mask(1) != 0:
		OverlayData.write(payloads.XTXT, index, 0)
		counters.expired_floods += 1

		return

	var update := counter > 51

	if not update:
		update = random.next_u15() & 3 == 0

	if not update:
		return

	counters.flood_updates += 1

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

		OverlayData.write(payloads.XTXT, index, 0)
		counters.random_extinctions += 1

	if counter > 0:
		counters.flood_spread_attempts += 1
		var target: Vector2i = point + CARDINAL_DIRECTIONS[random.next_u15() & 3]

		if _apply_flood_damage(
			city,
			payloads,
			target,
			_altitude_word(payloads.ALTM, index) & 0x1f,
			random,
			lfsr_random,
			runtime_events,
		) == 1:
			counters.spread_floods += 1


static func _process_toxic_cell(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	index: int,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	var map_edge: int = city.map_size if city != null else 128
	counters.toxic_markers_scanned += 1

	if random.next_u15() & 1 != 0:
		return

	counters.toxic_updates += 1

	if lfsr_random.next_mask(0x3f) == 0:
		OverlayData.write(payloads.XTXT, index, 0)
		counters.lfsr_expirations += 1

		return

	if payloads.XBIT[index] & 0x04 != 0 and random.next_u15() & 0x0f == 0:
		OverlayData.write(payloads.XTXT, index, 0)
		counters.water_expirations += 1

		return

	if _abandon_toxic_structure(city, payloads, point, random):
		counters.abandoned_structures += 1

	var direction := _lowest_toxic_direction(payloads.ALTM, point, map_edge)

	if direction < 0:
		direction = random.next_u15() & 3

	OverlayData.write(payloads.XTXT, index, 0)
	var target: Vector2i = point + CARDINAL_DIRECTIONS[direction]

	if _place_toxic_marker(payloads.XTXT, target, map_edge):
		counters.moved_markers += 1
	else:
		counters.blocked_moves += 1


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
	var map_edge: int = city.map_size if city != null else 128
	counters.riot_markers_scanned += 1

	if random.next_u15() & 3 != 0:
		return

	counters.riot_updates += 1

	if random.next_u15() & 0xff == 0 or payloads.XBIT[index] & 0x04 != 0:
		OverlayData.write(payloads.XTXT, index, 0)
		counters.expired_riots += 1

		return

	var traffic_index := CityDataGrid.index(payloads.XTRF, map_edge, point.x, point.y)

	if payloads.XTRF[traffic_index] != 0:
		counters.traffic_cells_cleared += 1

	payloads.XTRF[traffic_index] = 0
	var damage_direction: int = random.next_u15() & 0x7f

	if damage_direction < 4:
		counters.damage_attempts += 1

		if _starts_fire(
			_apply_damage(
				city,
				payloads,
				point + CARDINAL_DIRECTIONS[damage_direction],
				random,
				lfsr_random,
				runtime_events,
			)
		):
			counters.started_fires += 1

	var first_direction: int = 0 if marker == RIOT_OVERLAY_REVERSE else 2
	var second_direction: int = 1 if marker == RIOT_OVERLAY_REVERSE else 3
	var connections := 0

	if _riot_supports(payloads.XBLD, point + CARDINAL_DIRECTIONS[first_direction], map_edge):
		connections |= 1

	if _riot_supports(payloads.XBLD, point + CARDINAL_DIRECTIONS[second_direction], map_edge):
		connections |= 2

	var opposite_marker: int = (
		RIOT_OVERLAY_FORWARD if marker == RIOT_OVERLAY_REVERSE else RIOT_OVERLAY_REVERSE
	)

	if connections == 0:
		OverlayData.write(payloads.XTXT, index, opposite_marker)

		return

	OverlayData.write(payloads.XTXT, index, opposite_marker if random.next_u15() & 7 == 0 else 0)

	if connections == 3:
		connections = (random.next_u15() & 1) + 1

	var spread_direction: int = first_direction if connections == 1 else second_direction

	if _place_riot_marker(
		payloads.XTXT, point + CARDINAL_DIRECTIONS[spread_direction], marker, map_edge
	):
		counters.propagated_riots += 1
	else:
		counters.blocked_propagations += 1


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


static func _apply_flood_damage(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	maximum_altitude: int,
	random,
	lfsr_random,
	runtime_events: Dictionary = {},
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
		lfsr_random,
		runtime_events,
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
	var map_edge: int = city.map_size if city != null else 128
	var area: int = Demolish._building_area(tile)

	return Demolish._find_building_site(
		payloads.XBLD, payloads.XZON, point, tile, area, city.compass_rotation(), map_edge
	)


static func _abandon_toxic_structure(
	city: CityState, payloads: Dictionary, point: Vector2i, random
) -> bool:
	var map_edge: int = city.map_size if city != null else 128
	var index := _index(point, map_edge)
	var tile := int(payloads.XBLD[index])

	if tile < 0x70 or tile > 0xc5 or _is_construction_or_abandoned(tile):
		return false

	var area: int = Demolish._building_area(tile)
	var site := Demolish._find_building_site(
		payloads.XBLD, payloads.XZON, point, tile, area, city.compass_rotation(), map_edge
	)

	if site.size == Vector2i.ZERO:
		return false

	var anchor := Vector2i(site.position.x, site.end.y - 1)
	Growth._abandon(
		payloads.XBLD,
		payloads.XZON,
		payloads.XBIT,
		payloads.MISC,
		anchor,
		4 if area == 3 else area,
		0,
		random,
		city.compass_rotation(),
		payloads.XVAL, map_edge,
	)

	return payloads.XBLD[index] != tile


static func _is_construction_or_abandoned(tile: int) -> bool:
	return (
		(tile >= 0x88 and tile <= 0x8b)
		or (tile >= 0xa6 and tile <= 0xad)
		or (tile >= 0xc2 and tile <= 0xc5)
	)


static func _lowest_toxic_direction(altitude: PackedByteArray, point: Vector2i, map_edge: int = 128) -> int:
	var point_index := _index(point, map_edge)
	var lowest := _altitude_word(altitude, point_index) & 0x1f
	var direction := -1

	for checked_direction in CARDINAL_DIRECTIONS.size():
		var target: Vector2i = point + CARDINAL_DIRECTIONS[checked_direction]
		var target_index := _index(target, map_edge)

		if target_index < 0:
			continue

		var target_height := _altitude_word(altitude, target_index) & 0x1f

		if target_height < lowest:
			lowest = target_height
			direction = checked_direction

	return direction


static func _place_toxic_marker(text: PackedByteArray, point: Vector2i, map_edge: int = 128) -> bool:
	var index := _index(point, map_edge)

	if index < 0 or (OverlayData.read(text, index) != 0 and not OverlayData.is_sign(OverlayData.read(text, index))):
		return false

	OverlayData.write(text, index, TOXIC_OVERLAY)

	return true


static func _riot_supports(buildings: PackedByteArray, point: Vector2i, map_edge: int = 128) -> bool:
	var index := _index(point, map_edge)

	if index < 0:
		return false

	var tile := int(buildings[index])

	return (
		(tile > 0 and tile < 5)
		or (tile > 0x1d and tile < 0x2c)
		or (tile > 0x3e and tile < 0x47)
		or tile == 0x4b
		or tile == 0x4c
		or (tile > 0x5c and tile < 0x61)
	)


static func _place_riot_marker(
	text: PackedByteArray, point: Vector2i, marker: int,
	map_edge: int = 128,
) -> bool:
	var index := _index(point, map_edge)

	if index < 0 or (OverlayData.read(text, index) != 0 and not OverlayData.is_sign(OverlayData.read(text, index))):
		return false

	OverlayData.write(text, index, marker)

	return true


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
	var index := _index(point, map_edge)

	if index < 0:
		return false

	var marker := int(OverlayData.read(text, index))

	if marker != RIOT_OVERLAY_FORWARD and marker != RIOT_OVERLAY_REVERSE:
		return false

	OverlayData.write(text, index, 0)

	return true


static func _seed_special_toxic(
	payloads: Dictionary, site: Rect2i, point: Vector2i,
	map_edge: int = 128,
) -> int:
	if site.size == Vector2i.ZERO:
		site = Rect2i(point, Vector2i.ONE)

	var changed := 0

	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var index := x * map_edge + y

			if OverlayData.read(payloads.XTXT, index) < 51:
				OverlayData.write(payloads.XTXT, index, TOXIC_OVERLAY)
				changed += 1

	return changed


static func _spawn_explosion(
	text: PackedByteArray,
	things: PackedByteArray,
	point: Vector2i,
	height: int,
	state: int,
	goal: int,
	map_edge: int = 128,
) -> bool:
	var index := _index(point, map_edge)

	if index < 0 or OverlayData.blocks_thing(OverlayData.read(text, index)):
		return false

	var record := 0

	for checked_record in range(1, ThingData.count(things)):
		if ThingData.read(things, checked_record * CityState.THING_RECORD_SIZE) == 0:
			record = checked_record
			break

	if record == 0:
		return false

	var offset := record * CityState.THING_RECORD_SIZE
	ThingData.write(things, offset, TYPE_EXPLOSION)
	ThingData.write(things, offset + 1, 0)
	ThingData.write(things, offset + 2, state)
	ThingData.write(things, offset + 3, point.x)
	ThingData.write(things, offset + 4, point.y)
	ThingData.write(things, offset + 5, height)
	ThingData.write(things, offset + 6, 8)
	ThingData.write(things, offset + 7, 8)
	ThingData.write(things, offset + 10, OverlayData.read(text, index))
	ThingData.write(things, offset + 11, goal)
	OverlayData.write(text, index, OverlayData.thing_id(record))

	return true


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


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.y < 0 or point.x >= map_edge or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y


static func _altitude_word(altitude: PackedByteArray, index: int) -> int:
	return (altitude[index * 2] << 8) | altitude[index * 2 + 1]
