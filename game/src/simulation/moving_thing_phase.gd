class_name MovingThingPhase
extends RefCounted

const TrainTick = preload("res://src/simulation/train_thing_tick.gd")
const SailboatTick = preload("res://src/simulation/sailboat_thing_tick.gd")
const ShipTick = preload("res://src/simulation/ship_thing_tick.gd")
const AirTick = preload("res://src/simulation/air_thing_tick.gd")
const MaxisManTick = preload("res://src/simulation/maxis_man_thing_tick.gd")
const DisasterTick = preload("res://src/simulation/disaster_thing_tick.gd")
const RECORD_SIZE := 12
const FIRST_RECORD := 1
const LAST_RECORD := 39
const TEXT_LABEL_BASE := 201
const TYPE_AIRPLANE := 1
const TYPE_HELICOPTER := 2
const TYPE_SHIP := 3
const TYPE_MONSTER := 5
const TYPE_EXPLOSION := 6
const TYPE_SAILBOAT := 9
const TYPE_TRAIN_ENGINE := 10
const TYPE_SUBWAY_ENGINE := 12
const TYPE_TORNADO := 15
const TYPE_MAXIS_MAN := 16
const MISC_CITY_CENTER_X := 0x1018
const MISC_CITY_CENTER_Y := 0x101c


static func run(
	city: CityState,
	random,
	lfsr_random,
	game_random = null,
	ship_home := Vector2i(-1, -1),
	allow_disaster_damage := true,
	traffic_news_time_msec := -1,
	traffic_news_deadline_msec := 0
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible random generator is required"}
	if (
		lfsr_random == null
		or not lfsr_random.has_method("next_mod")
		or not lfsr_random.has_method("next_mask")
	):
		return {"ok": false, "error": "a compatible LFSR generator is required"}
	if game_random == null:
		game_random = GameLcgRandom.new(1)
	if not game_random.has_method("next_mod"):
		return {"ok": false, "error": "a compatible game random generator is required"}
	if traffic_news_time_msec < 0:
		traffic_news_time_msec = Time.get_ticks_msec()
	var building_chunk := city.document.find_chunk("XBLD")
	var altitude_chunk := city.document.find_chunk("ALTM")
	var terrain_chunk := city.document.find_chunk("XTER")
	var underground_chunk := city.document.find_chunk("XUND")
	var zone_chunk := city.document.find_chunk("XZON")
	var traffic_chunk := city.document.find_chunk("XTRF")
	var text_chunk := city.document.find_chunk("XTXT")
	var thing_chunk := city.document.find_chunk("XTHG")
	var flag_chunk := city.document.find_chunk("XBIT")
	var label_chunk := city.document.find_chunk("XLAB")
	var microsim_chunk := city.document.find_chunk("XMIC")
	var misc_chunk := city.document.find_chunk("MISC")
	if (
		building_chunk == null
		or building_chunk.decoded_payload.size() != (map_edge * map_edge)
		or altitude_chunk == null
		or altitude_chunk.decoded_payload.size() != (map_edge * map_edge) * 2
		or terrain_chunk == null
		or terrain_chunk.decoded_payload.size() != (map_edge * map_edge)
		or underground_chunk == null
		or underground_chunk.decoded_payload.size() != (map_edge * map_edge)
		or zone_chunk == null
		or zone_chunk.decoded_payload.size() != (map_edge * map_edge)
		or traffic_chunk == null
		or traffic_chunk.decoded_payload.size() != (map_edge / 2) * (map_edge / 2)
		or text_chunk == null
		or text_chunk.decoded_payload.size() != city.document.decoded_size("XTXT")
		or thing_chunk == null
		or thing_chunk.decoded_payload.size() != city.document.decoded_size("XTHG")
		or flag_chunk == null
		or flag_chunk.decoded_payload.size() != (map_edge * map_edge)
		or label_chunk == null
		or label_chunk.decoded_payload.size() != city.document.decoded_size("XLAB")
		or microsim_chunk == null
		or microsim_chunk.decoded_payload.size() != city.document.decoded_size("XMIC")
		or misc_chunk == null
		or misc_chunk.decoded_payload.size() != 4800
	):
		return {"ok": false, "error": "moving-thing input chunks are missing or have the wrong size"}

	var original_buildings: PackedByteArray = building_chunk.decoded_payload.duplicate()
	var buildings: PackedByteArray = original_buildings.duplicate()
	var original_altitude: PackedByteArray = altitude_chunk.decoded_payload.duplicate()
	var altitude: PackedByteArray = original_altitude.duplicate()
	var original_terrain: PackedByteArray = terrain_chunk.decoded_payload.duplicate()
	var terrain: PackedByteArray = original_terrain.duplicate()
	var original_underground: PackedByteArray = underground_chunk.decoded_payload.duplicate()
	var underground: PackedByteArray = original_underground.duplicate()
	var original_zones: PackedByteArray = zone_chunk.decoded_payload.duplicate()
	var zones: PackedByteArray = original_zones.duplicate()
	var original_traffic: PackedByteArray = traffic_chunk.decoded_payload.duplicate()
	var traffic: PackedByteArray = original_traffic.duplicate()
	var original_flags: PackedByteArray = flag_chunk.decoded_payload.duplicate()
	var flags: PackedByteArray = original_flags.duplicate()
	var original_labels: PackedByteArray = label_chunk.decoded_payload.duplicate()
	var labels: PackedByteArray = original_labels.duplicate()
	var original_microsims: PackedByteArray = microsim_chunk.decoded_payload.duplicate()
	var microsims: PackedByteArray = original_microsims.duplicate()
	var original_misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var misc: PackedByteArray = original_misc.duplicate()
	var original_text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	var original_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var text: PackedByteArray = original_text.duplicate()
	var things: PackedByteArray = original_things.duplicate()
	var counters := {
		"scanned_records": ThingData.count(things) - 1,
		"active_airplanes": 0,
		"active_helicopters": 0,
		"active_ships": 0,
		"active_monsters": 0,
		"active_explosions": 0,
		"active_sailboats": 0,
		"active_trains": 0,
		"active_tornadoes": 0,
		"active_maxis_men": 0,
		"moved_helicopters": 0,
		"moved_airplanes": 0,
		"moved_ships": 0,
		"moved_monsters": 0,
		"moved_sailboats": 0,
		"moved_trains": 0,
		"moved_tornadoes": 0,
		"moved_maxis_men": 0,
		"turned_sailboats": 0,
		"turned_trains": 0,
		"paused_trains": 0,
		"reversed_trains": 0,
		"distressed_sailboats": 0,
		"removed_sailboats": 0,
		"removed_trains": 0,
		"removed_helicopters": 0,
		"crashed_helicopters": 0,
		"removed_airplanes": 0,
		"crashed_airplanes": 0,
		"landed_airplanes": 0,
		"removed_ships": 0,
		"crashed_ships": 0,
		"docked_ships": 0,
		"departing_ships": 0,
		"removed_explosions": 0,
		"removed_tornadoes": 0,
		"removed_maxis_men": 0,
		"removed_monsters": 0,
		"monster_damage_hits": 0,
		"monster_forced_airplanes": 0,
		"monster_forced_helicopters": 0,
		"monster_military_collisions": 0,
		"tornado_demolitions": 0,
		"maxis_man_extinguished_fires": 0,
		"maxis_man_destroyed_targets": 0,
		"maxis_man_explosions": 0,
		"spread_explosion_fires": 0,
		"rubble_explosion_hits": 0,
		"damaged_facilities": 0,
		"deferred_facility_explosion_hits": 0,
		"malformed_records": 0,
		"news_items": [],
		"sound_events": [],
		"traffic_news_checks": 0,
		"traffic_news_time_msec": traffic_news_time_msec,
		"traffic_news_deadline_msec": traffic_news_deadline_msec,
		"connection_count_changes": [],
		"created_train_crash_explosions": 0,
		"disaster_start_requests": [],
	}
	var city_center := Vector2i(
		city.document.misc_u32(MISC_CITY_CENTER_X),
		city.document.misc_u32(MISC_CITY_CENTER_Y)
	)

	for record in range(FIRST_RECORD, ThingData.count(things)):
		var offset := record * RECORD_SIZE
		match int(ThingData.read(things, offset)):
			TYPE_AIRPLANE:
				counters.active_airplanes += 1
				AirTick.update_airplane(
					buildings, zones, text, things, record,
					random, lfsr_random, counters, map_edge
				)
			TYPE_HELICOPTER:
				counters.active_helicopters += 1
				AirTick.update_helicopter(
					buildings, underground, traffic, text, things, record,
					city_center, random, counters, map_edge
				)
			TYPE_SHIP:
				counters.active_ships += 1
				ShipTick.update(
					buildings, underground, flags, text, things, record,
					ThingData.ship_home(things, record, ship_home), random, lfsr_random, counters, map_edge
				)
			TYPE_MONSTER:
				counters.active_monsters += 1
				DisasterTick.update_monster(
					city, altitude, buildings, terrain, zones, underground,
					flags, traffic, text, labels, microsims, misc, things,
					record, city_center, random, lfsr_random, counters
				)
			TYPE_EXPLOSION:
				counters.active_explosions += 1
				DisasterTick.update_explosion(
					city, altitude, buildings, terrain, zones, underground,
					flags, traffic, text, labels, microsims, misc, things,
					record, random, lfsr_random, allow_disaster_damage, counters
				)
			TYPE_SAILBOAT:
				counters.active_sailboats += 1
				SailboatTick.update(
					buildings, flags, text, things, record, random, lfsr_random, counters, map_edge
				)
			TYPE_TRAIN_ENGINE, TYPE_SUBWAY_ENGINE:
				counters.active_trains += 1
				TrainTick.update(
					buildings, underground, text, things, record,
					random, lfsr_random, game_random, counters, map_edge
				)
			TYPE_TORNADO:
				counters.active_tornadoes += 1
				DisasterTick.update_tornado(
					city, altitude, buildings, terrain, zones, underground,
					flags, text, labels, microsims, misc, things, record,
					random, counters
				)
			TYPE_MAXIS_MAN:
				counters.active_maxis_men += 1
				MaxisManTick.update(
					altitude, flags, text, things, record, random, counters, map_edge
				)

	var applied: Array = []
	for update in [
		[thing_chunk, things, original_things, "XTHG"],
		[text_chunk, text, original_text, "XTXT"],
		[altitude_chunk, altitude, original_altitude, "ALTM"],
		[building_chunk, buildings, original_buildings, "XBLD"],
		[terrain_chunk, terrain, original_terrain, "XTER"],
		[zone_chunk, zones, original_zones, "XZON"],
		[underground_chunk, underground, original_underground, "XUND"],
		[flag_chunk, flags, original_flags, "XBIT"],
		[traffic_chunk, traffic, original_traffic, "XTRF"],
		[label_chunk, labels, original_labels, "XLAB"],
		[microsim_chunk, microsims, original_microsims, "XMIC"],
		[misc_chunk, misc, original_misc, "MISC"],
	]:
		if update[1] == update[2]:
			continue
		if not update[0].set_decoded_payload(update[1]):
			for rollback in applied:
				rollback[0].set_decoded_payload(rollback[1])
			return {"ok": false, "error": "cannot store %s after the moving-thing tick" % update[3]}
		applied.push_front([update[0], update[2]])
	city.buildings = buildings.duplicate()
	city.terrain = terrain.duplicate()
	city.zones = zones.duplicate()
	city.underground = underground.duplicate()
	city.text_overlays = text.duplicate()
	city.tile_flags = flags.duplicate()
	for index in (map_edge * map_edge):
		city.altitude_words[index] = (altitude[index * 2] << 8) | altitude[index * 2 + 1]
	counters["ok"] = true
	counters["sailboats_complete"] = true
	counters["train_routes_complete"] = true
	counters["helicopters_save_visible_complete"] = true
	counters["ships_save_visible_complete"] = true
	counters["airplanes_save_visible_complete"] = true
	counters["explosion_records_complete"] = true
	counters["tornadoes_save_visible_complete"] = true
	counters["maxis_man_save_visible_complete"] = true
	counters["monsters_save_visible_complete"] = true
	counters["explosion_map_damage_complete"] = counters.deferred_facility_explosion_hits == 0
	counters["complete"] = counters.explosion_map_damage_complete
	counters["error"] = ""
	return counters
