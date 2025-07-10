class_name MovingThingPhase
extends RefCounted

const NetworkTiles = preload("res://src/tools/network_command.gd")
const MAP_SIZE := 128
const RECORD_SIZE := 12
const FIRST_RECORD := 1
const LAST_RECORD := 39
const TEXT_LABEL_BASE := 201
const TYPE_AIRPLANE := 1
const TYPE_HELICOPTER := 2
const TYPE_SHIP := 3
const TYPE_EXPLOSION := 6
const TYPE_SAILBOAT := 9
const TYPE_TRAIN_ENGINE := 10
const TYPE_TRAIN_CAR := 11
const TYPE_SUBWAY_ENGINE := 12
const TYPE_SUBWAY_CAR := 13
const TILE_PIER := 0xdf
const TILE_MARINA := 0xf8
const TILE_RAIL_STATION := 0xed
const SUBTILE_LIMIT := 16
const MISC_CITY_CENTER_X := 0x1018
const MISC_CITY_CENTER_Y := 0x101c
const SAIL_SUBTILE_X := [0, 16, 0, -16]
const SAIL_SUBTILE_Y := [-16, 0, 16, 0]
const CARDINAL_DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]
const EIGHT_DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]
const AIR_ROUTE_DELTAS := [
	Vector2i(0, -3), Vector2i(3, -3), Vector2i(3, 0), Vector2i(3, 3),
	Vector2i(0, 3), Vector2i(-3, 3), Vector2i(-3, 0), Vector2i(-3, -3),
]
const AIR_DIRECTION_OFFSETS := [1, 7, 2, 6, 3, 5, 4]
const SHIP_ROUTE_DELTAS := [
	Vector2i(0, -4), Vector2i(3, -3), Vector2i(4, 0), Vector2i(3, 3),
	Vector2i(0, 4), Vector2i(-3, 3), Vector2i(-4, 0), Vector2i(-3, -3),
]
const SHIP_SUBTILE_DELTAS := SHIP_ROUTE_DELTAS
const SHIP_DIRECTION_OFFSETS := [0, 1, 2, 3, 4, 5, 6, 7, 0]
const SHIP_REVERSE_OFFSETS := [0, 7, 6, 5, 4, 3, 2, 1]
const SHIP_PIER_DELTAS := [
	Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(0, -2),
]
const SHIP_ROUTE_BUILDINGS := {
	0x51: true, 0x52: true, 0x54: true, 0x55: true, 0x58: true,
	0x59: true, 0x5b: true, 0x5c: true, 0x6b: true,
}
const THING_SPEEDS := {
	TYPE_AIRPLANE: 16,
	TYPE_HELICOPTER: 8,
}
# final supplied smallmed.dat metadata heights for sprite ids 0x71 through 0xfa
const BUILDING_SPRITE_HEIGHTS := [
	5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 8, 7, 6, 6, 8,
	12, 7, 9, 5, 8, 6, 7, 5, 5, 5, 5, 10, 11, 11, 11, 16,
	14, 20, 20, 9, 11, 11, 12, 12, 14, 19, 17, 19, 22, 11, 11, 11,
	10, 10, 14, 15, 16, 10, 12, 12, 17, 14, 15, 18, 19, 18, 23, 15,
	24, 16, 22, 17, 24, 16, 30, 35, 20, 28, 38, 13, 24, 15, 15, 15,
	13, 21, 17, 18, 24, 9, 9, 11, 23, 29, 21, 20, 24, 18, 28, 18,
	21, 19, 17, 15, 14, 15, 22, 19, 23, 17, 13, 5, 5, 5, 6, 11,
	16, 18, 5, 6, 6, 5, 5, 6, 6, 5, 17, 10, 11, 10, 10, 10,
	14, 9, 10, 10, 14, 10, 13, 14, 13, 16,
]
const TRAIN_DIRECTION_ORDERS := [
	[0, 3, 1, 2],
	[0, 1, 3, 2],
]
const TRAIN_TRANSITIONS := [
	0, 1, 2, 7,
	1, 2, 3, 4,
	2, 3, 4, 5,
	7, 4, 5, 6,
]


static func run(
	city: CityState,
	random,
	lfsr_random,
	game_random = null,
	ship_home := Vector2i(-1, -1),
	allow_disaster_damage := true
) -> Dictionary:
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
	var building_chunk := city.document.find_chunk("XBLD")
	var underground_chunk := city.document.find_chunk("XUND")
	var zone_chunk := city.document.find_chunk("XZON")
	var traffic_chunk := city.document.find_chunk("XTRF")
	var text_chunk := city.document.find_chunk("XTXT")
	var thing_chunk := city.document.find_chunk("XTHG")
	var flag_chunk := city.document.find_chunk("XBIT")
	var label_chunk := city.document.find_chunk("XLAB")
	var misc_chunk := city.document.find_chunk("MISC")
	if (
		building_chunk == null
		or building_chunk.decoded_payload.size() != CityState.TILE_COUNT
		or underground_chunk == null
		or underground_chunk.decoded_payload.size() != CityState.TILE_COUNT
		or zone_chunk == null
		or zone_chunk.decoded_payload.size() != CityState.TILE_COUNT
		or traffic_chunk == null
		or traffic_chunk.decoded_payload.size() != 64 * 64
		or text_chunk == null
		or text_chunk.decoded_payload.size() != CityState.TILE_COUNT
		or thing_chunk == null
		or thing_chunk.decoded_payload.size() != CityState.THING_COUNT * RECORD_SIZE
		or flag_chunk == null
		or flag_chunk.decoded_payload.size() != CityState.TILE_COUNT
		or label_chunk == null
		or label_chunk.decoded_payload.size() != CityState.LABEL_COUNT * CityState.LABEL_RECORD_SIZE
		or misc_chunk == null
		or misc_chunk.decoded_payload.size() != 4800
	):
		return {"ok": false, "error": "moving-thing input chunks are missing or have the wrong size"}

	var original_buildings: PackedByteArray = building_chunk.decoded_payload.duplicate()
	var buildings: PackedByteArray = original_buildings.duplicate()
	var underground: PackedByteArray = underground_chunk.decoded_payload
	var original_zones: PackedByteArray = zone_chunk.decoded_payload.duplicate()
	var zones: PackedByteArray = original_zones.duplicate()
	var original_traffic: PackedByteArray = traffic_chunk.decoded_payload.duplicate()
	var traffic: PackedByteArray = original_traffic.duplicate()
	var flags: PackedByteArray = flag_chunk.decoded_payload
	var original_labels: PackedByteArray = label_chunk.decoded_payload.duplicate()
	var labels: PackedByteArray = original_labels.duplicate()
	var original_misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var misc: PackedByteArray = original_misc.duplicate()
	var original_text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	var original_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var text: PackedByteArray = original_text.duplicate()
	var things: PackedByteArray = original_things.duplicate()
	var counters := {
		"scanned_records": LAST_RECORD,
		"active_airplanes": 0,
		"active_helicopters": 0,
		"active_ships": 0,
		"active_explosions": 0,
		"active_sailboats": 0,
		"active_trains": 0,
		"moved_helicopters": 0,
		"moved_airplanes": 0,
		"moved_ships": 0,
		"moved_sailboats": 0,
		"moved_trains": 0,
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
		"spread_explosion_fires": 0,
		"rubble_explosion_hits": 0,
		"deferred_facility_explosion_hits": 0,
		"deferred_connection_count_updates": 0,
		"malformed_records": 0,
		"deferred_news": 0,
		"deferred_traffic_news_checks": 0,
		"created_train_crash_explosions": 0,
	}
	var city_center := Vector2i(
		city.document.misc_u32(MISC_CITY_CENTER_X),
		city.document.misc_u32(MISC_CITY_CENTER_Y)
	)

	for record in range(FIRST_RECORD, LAST_RECORD + 1):
		var offset := record * RECORD_SIZE
		match int(things[offset]):
			TYPE_AIRPLANE:
				counters.active_airplanes += 1
				_update_airplane(
					buildings, zones, text, things, record,
					random, lfsr_random, counters
				)
			TYPE_HELICOPTER:
				counters.active_helicopters += 1
				_update_helicopter(
					buildings, underground, traffic, text, things, record,
					city_center, random, counters
				)
			TYPE_SHIP:
				counters.active_ships += 1
				_update_ship(
					buildings, underground, flags, text, things, record,
					ship_home, random, lfsr_random, counters
				)
			TYPE_EXPLOSION:
				counters.active_explosions += 1
				_update_explosion(
					buildings, zones, flags, traffic, text, labels, misc,
					things, record, lfsr_random, allow_disaster_damage, counters
				)
			TYPE_SAILBOAT:
				counters.active_sailboats += 1
				_update_sailboat(
					buildings, flags, text, things, record, random, lfsr_random, counters
				)
			TYPE_TRAIN_ENGINE, TYPE_SUBWAY_ENGINE:
				counters.active_trains += 1
				_update_train(
					buildings, underground, text, things, record,
					random, lfsr_random, game_random, counters
				)

	var applied: Array = []
	for update in [
		[thing_chunk, things, original_things, "XTHG"],
		[text_chunk, text, original_text, "XTXT"],
		[building_chunk, buildings, original_buildings, "XBLD"],
		[zone_chunk, zones, original_zones, "XZON"],
		[traffic_chunk, traffic, original_traffic, "XTRF"],
		[label_chunk, labels, original_labels, "XLAB"],
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
	city.zones = zones.duplicate()
	city.text_overlays = text.duplicate()
	counters["ok"] = true
	counters["sailboats_complete"] = true
	counters["train_routes_complete"] = true
	counters["helicopters_save_visible_complete"] = true
	counters["ships_save_visible_complete"] = true
	counters["airplanes_save_visible_complete"] = true
	counters["explosion_records_complete"] = true
	counters["explosion_map_damage_complete"] = (
		counters.deferred_facility_explosion_hits == 0
		and counters.deferred_connection_count_updates == 0
	)
	counters["complete"] = false
	counters["error"] = ""
	return counters


static func _update_explosion(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	traffic: PackedByteArray,
	text: PackedByteArray,
	labels: PackedByteArray,
	misc: PackedByteArray,
	things: PackedByteArray,
	record: int,
	lfsr_random,
	allow_disaster_damage: bool,
	counters: Dictionary
) -> void:
	var offset := record * RECORD_SIZE
	var frame := int(things[offset + 1])
	if frame == 0:
		counters.deferred_news += 1
	if frame < 2:
		things[offset + 1] = (frame + 1) & 0xff
		return
	var center := Vector2i(things[offset + 3], things[offset + 4])
	var center_index := _index(center)
	_remove_thing(text, things, record)
	counters.removed_explosions += 1
	if center_index < 0:
		counters.malformed_records += 1
		return
	buildings[center_index] = 0
	if things[offset + 11] == 0 or not allow_disaster_damage:
		return
	for _attempt in 4:
		var damaged := center + Vector2i(
			lfsr_random.next_mod(5) - 2,
			lfsr_random.next_mod(5) - 2
		)
		var damage_result := _apply_explosion_damage(
			buildings, zones, flags, traffic, text, labels, misc, damaged, lfsr_random
		)
		if damage_result == 1:
			counters.spread_explosion_fires += 1
		elif damage_result == 4:
			counters.spread_explosion_fires += 1
			counters.deferred_connection_count_updates += 1
		elif damage_result == 2:
			counters.rubble_explosion_hits += 1
		elif damage_result == 3:
			counters.deferred_facility_explosion_hits += 1


static func _apply_explosion_damage(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	traffic: PackedByteArray,
	text: PackedByteArray,
	labels: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	lfsr_random
) -> int:
	var index := _index(point)
	if index < 0 or flags[index] & 0x04 != 0:
		return 0
	var overlay := int(text[index])
	var result_code := 1
	if overlay > 0:
		if overlay < 51:
			labels[overlay * CityState.LABEL_RECORD_SIZE] = 0
		elif overlay < TEXT_LABEL_BASE:
			# this path demolishes the full linked facility before it starts fire
			return 3
		elif overlay < 241:
			return 0
		elif overlay < 250:
			NetworkTiles._replace_building(
				buildings, zones, misc, index, lfsr_random.next_mod(4) + 1
			)
			return 2
		elif overlay != 250:
			return 0
		else:
			result_code = 4
	text[index] = 0xff
	traffic[int(point.x / 2) * 64 + int(point.y / 2)] = 0
	return result_code


static func _update_airplane(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	var offset := record * RECORD_SIZE
	var current := Vector2i(things[offset + 3], things[offset + 4])
	var current_index := _index(current)
	var direction := int(things[offset + 1])
	if current_index < 0 or direction < 0 or direction >= EIGHT_DIRECTIONS.size():
		_remove_thing(text, things, record)
		counters.removed_airplanes += 1
		counters.malformed_records += 1
		return
	var building := int(buildings[current_index])
	if building > 0x70 and zones[current_index] & 0x0f != 8:
		if building > 0xfa:
			_convert_to_explosion(
				things, record, 5, 1 if lfsr_random.next_mod(16) == 0 else 0
			)
			counters.crashed_airplanes += 1
			return
		var sprite_height: int = BUILDING_SPRITE_HEIGHTS[building - 0x71]
		if things[offset + 5] < int(sprite_height / 3):
			_convert_to_explosion(things, record, 5, 1)
			counters.crashed_airplanes += 1
			return
	var state: int = int(things[offset + 2]) & 0x0f
	match state:
		0:
			if _move_thing_eight_way(TYPE_AIRPLANE, text, things, record, direction) < 0:
				counters.removed_airplanes += 1
				return
			counters.moved_airplanes += 1
			if things[offset + 5] == 0:
				counters.deferred_news += 1
			if things[offset + 5] < 14:
				things[offset + 5] += 1
			else:
				things[offset + 2] = 2
		1:
			if _move_thing_eight_way(TYPE_AIRPLANE, text, things, record, direction) < 0:
				counters.removed_airplanes += 1
				return
			counters.moved_airplanes += 1
			things[offset + 5] = (int(things[offset + 5]) - 1) & 0xff
			if things[offset + 5] == 0:
				counters.deferred_news += 1
				current = Vector2i(things[offset + 3], things[offset + 4])
				current_index = _index(current)
				if current_index >= 0:
					text[current_index] = things[offset + 10]
				if current_index < 0 or buildings[current_index] != 0xdd:
					_convert_to_explosion(things, record, 5, 1)
					counters.crashed_airplanes += 1
				else:
					_remove_thing(text, things, record)
					counters.removed_airplanes += 1
					counters.landed_airplanes += 1
		2:
			direction = _random_direction_step(direction, 5, random)
			things[offset + 1] = direction
			_advance_air_direction(buildings, things, record)
			direction = int(things[offset + 1])
			if _move_thing_eight_way(TYPE_AIRPLANE, text, things, record, direction) < 0:
				counters.removed_airplanes += 1
				return
			counters.moved_airplanes += 1
		3:
			var target := Vector2i(things[offset + 8], things[offset + 9])
			var planned_direction := _direction_quadrant(current, target)
			things[offset + 1] = planned_direction
			_advance_air_direction(buildings, things, record)
			direction = int(things[offset + 1])
			if _move_thing_eight_way(TYPE_AIRPLANE, text, things, record, direction) < 0:
				counters.removed_airplanes += 1
				return
			counters.moved_airplanes += 1
			current = Vector2i(things[offset + 3], things[offset + 4])
			if _thing_distance(current, target) < 2:
				var runway_axis: int = int(things[offset + 2]) >> 4
				things[offset + 1] = _turn_one_step(planned_direction, runway_axis)
				things[offset + 2] = runway_axis * 0x10 + 4
				_adjust_airplane_target(things, offset, runway_axis)
		4:
			var target := Vector2i(things[offset + 8], things[offset + 9])
			direction = _steer_direction(direction, current, target)
			things[offset + 1] = direction
			if _move_thing_eight_way(TYPE_AIRPLANE, text, things, record, direction) < 0:
				counters.removed_airplanes += 1
				return
			counters.moved_airplanes += 1
			current = Vector2i(things[offset + 3], things[offset + 4])
			if _thing_distance(current, target) < 2:
				var runway_axis: int = int(things[offset + 2]) >> 4
				things[offset + 1] = runway_axis
				things[offset + 2] = 1
				match runway_axis:
					1, 5:
						things[offset + 3] = things[offset + 8]
					3, 7:
						things[offset + 4] = things[offset + 9]
		7:
			if things[offset + 5] != 0:
				things[offset + 5] -= 1
				if things[offset + 5] == 8:
					counters.deferred_news += 1
				var old_direction := direction
				things[offset + 1] = (direction + 1) & 7
				if _move_thing_eight_way(
					TYPE_AIRPLANE, text, things, record, old_direction
				) < 0:
					counters.removed_airplanes += 1
					return
				counters.moved_airplanes += 1
			else:
				_convert_to_explosion(things, record, 5, 1)
				counters.crashed_airplanes += 1


static func _adjust_airplane_target(
	things: PackedByteArray, offset: int, runway_axis: int
) -> void:
	match runway_axis:
		1:
			things[offset + 9] = (int(things[offset + 9]) - 6) & 0xff
		3:
			things[offset + 8] = (int(things[offset + 8]) + 6) & 0xff
		5:
			things[offset + 9] = (int(things[offset + 9]) + 6) & 0xff
		7:
			things[offset + 8] = (int(things[offset + 8]) - 6) & 0xff


static func _update_helicopter(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	traffic: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	city_center: Vector2i,
	random,
	counters: Dictionary
) -> void:
	var offset := record * RECORD_SIZE
	var current := Vector2i(things[offset + 3], things[offset + 4])
	var current_index := _index(current)
	var direction := int(things[offset + 1])
	if current_index < 0 or direction < 0 or direction >= EIGHT_DIRECTIONS.size():
		_remove_thing(text, things, record)
		counters.removed_helicopters += 1
		counters.malformed_records += 1
		return
	if buildings[current_index] > 0xfa:
		_convert_to_explosion(things, record, 5, 0)
		counters.crashed_helicopters += 1
		return
	match int(things[offset + 2]):
		0:
			things[offset + 1] = (direction + 1) & 7
			if things[offset + 5] < 10:
				things[offset + 5] += 1
			else:
				things[offset + 2] = 2
		2:
			var target := Vector2i(things[offset + 8], things[offset + 9])
			direction = _steer_direction(direction, current, target)
			things[offset + 1] = direction
			_advance_air_direction(buildings, things, record)
			direction = int(things[offset + 1])
			var motion := _move_thing_eight_way(
				TYPE_HELICOPTER, text, things, record, direction
			)
			if motion < 0:
				counters.removed_helicopters += 1
				return
			counters.moved_helicopters += 1
			current = Vector2i(things[offset + 3], things[offset + 4])
			var traffic_index := int(current.x / 2) * 64 + int(current.y / 2)
			if traffic[traffic_index] > 0xa9:
				counters.deferred_traffic_news_checks += 1
			if _thing_distance(current, target) < 2:
				var target_x: int = (random.next_u15() & 0x3f) - 0x20 + city_center.x
				var target_y: int = (random.next_u15() & 0x3f) - 0x20 + city_center.y
				if target_x < 0 or target_x >= MAP_SIZE:
					target_x = (random.next_u15() & 0x3f) + 0x20
				if target_y < 0 or target_y >= MAP_SIZE:
					target_y = (random.next_u15() & 0x3f) + 0x20
				things[offset + 8] = target_x
				things[offset + 9] = target_y
				if (
					random.next_u15() & 1
					and buildings[_index(current)] == 0
					and underground[_index(current)] == 0
				):
					things[offset + 2] = 3
		3:
			things[offset + 1] = (direction + 1) & 7
			if things[offset + 5] > 2:
				things[offset + 5] -= 1
			else:
				things[offset + 2] = 4
		4:
			if random.next_u15() % 20 == 0:
				things[offset + 2] = 0
		5:
			things[offset + 1] = (direction + 2) & 7
			if things[offset + 5] == 4:
				counters.deferred_news += 1
			if things[offset + 5] > 2:
				things[offset + 5] -= 1
			else:
				_convert_to_explosion(things, record, 0x11, 1)
				counters.crashed_helicopters += 1


static func _update_ship(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	ship_home: Vector2i,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	var offset := record * RECORD_SIZE
	if random.next_u15() & 0xff == 0:
		counters.deferred_news += 1
	var current := Vector2i(things[offset + 3], things[offset + 4])
	var current_index := _index(current)
	var direction := int(things[offset + 1])
	if current_index < 0 or direction < 0 or direction >= EIGHT_DIRECTIONS.size():
		_convert_to_explosion(things, record, 0, 0)
		counters.crashed_ships += 1
		counters.malformed_records += 1
		return
	if flags[current_index] & 0x04 == 0:
		_convert_to_explosion(things, record, 0, 0)
		counters.crashed_ships += 1
		return
	var target := Vector2i(things[offset + 8], things[offset + 9])
	match int(things[offset + 2]):
		0:
			if lfsr_random.next_mod(10) == 0:
				var turned := _steer_direction(direction, current, target)
				if _ship_route_valid(
					buildings, underground, flags, text, current, turned
				):
					direction = turned
					things[offset + 1] = direction
			if _ship_route_valid(buildings, underground, flags, text, current, direction):
				_move_ship(text, things, record, direction)
				counters.moved_ships += 1
			else:
				things[offset + 2] = 1
			for pier_delta in SHIP_PIER_DELTAS:
				var pier_index := _index(current + pier_delta)
				if pier_index >= 0 and buildings[pier_index] == TILE_PIER:
					things[offset + 2] = 3
					counters.docked_ships += 1
		1:
			var desired := _direction_between(current, target)
			direction = _turn_one_step(direction, desired)
			things[offset + 1] = direction
			if direction == desired:
				things[offset + 2] = (
					0
					if _ship_route_valid(
						buildings, underground, flags, text, current, desired
					)
					else 2
				)
		2:
			var offsets = (
				SHIP_REVERSE_OFFSETS
				if lfsr_random.next_mod(2) == 0
				else SHIP_DIRECTION_OFFSETS
			)
			var found := false
			for direction_offset in offsets.slice(0, 8):
				direction = (int(things[offset + 1]) + int(direction_offset)) & 7
				if _ship_route_valid(
					buildings, underground, flags, text, current, direction
				):
					found = true
					break
			if not found:
				_remove_thing(text, things, record)
				counters.removed_ships += 1
				direction = (
					(int(things[offset + 1]) + 2) & 7
					if offsets == SHIP_REVERSE_OFFSETS
					else int(things[offset + 1]) & 7
				)
			things[offset + 1] = direction
			things[offset + 2] = 0
		3:
			if lfsr_random.next_mod(30) == 0:
				things[offset + 2] = 4
				counters.deferred_news += 1
				counters.departing_ships += 1
				var home := ship_home if _index(ship_home) >= 0 else current
				things[offset + 8] = home.x
				things[offset + 9] = home.y
		4:
			if _ship_route_valid(buildings, underground, flags, text, current, direction):
				_move_ship(text, things, record, direction)
				counters.moved_ships += 1
				return
			var start_offset: int = lfsr_random.next_mod(2)
			for order_index in range(start_offset, SHIP_DIRECTION_OFFSETS.size()):
				direction = (
					int(things[offset + 1]) + SHIP_DIRECTION_OFFSETS[order_index]
				) & 7
				if _ship_route_valid(
					buildings, underground, flags, text, current, direction
				):
					break
			things[offset + 1] = direction


static func _ship_route_valid(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	current: Vector2i,
	direction: int
) -> bool:
	var route_point: Vector2i = current + SHIP_ROUTE_DELTAS[direction]
	var route_index := _index(route_point)
	if route_index < 0:
		return true
	return (
		_ship_water_route(buildings, underground, flags, route_index)
		and text[route_index] < TEXT_LABEL_BASE
	)


static func _ship_water_route(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	index: int
) -> bool:
	if flags[index] & 0x04 == 0:
		return false
	var underground_tile := int(underground[index])
	if underground_tile >= 0x10 and underground_tile <= 0x1f:
		return false
	var building := int(buildings[index])
	if building == TILE_MARINA:
		return false
	return building == 0 or SHIP_ROUTE_BUILDINGS.has(building)


static func _move_ship(
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int
) -> bool:
	var offset := record * RECORD_SIZE
	var subtile_x: int = int(things[offset + 6]) + SHIP_SUBTILE_DELTAS[direction].x
	var subtile_y: int = int(things[offset + 7]) + SHIP_SUBTILE_DELTAS[direction].y
	var tile_delta := Vector2i.ZERO
	if subtile_x > 12:
		subtile_x -= 12
		tile_delta.x = 1
	elif subtile_x < 0:
		subtile_x += 12
		tile_delta.x = -1
	if subtile_y > 12:
		subtile_y -= 12
		tile_delta.y = 1
	elif subtile_y < 0:
		subtile_y += 12
		tile_delta.y = -1
	things[offset + 6] = subtile_x
	things[offset + 7] = subtile_y
	if tile_delta == Vector2i.ZERO:
		return true
	var current := Vector2i(things[offset + 3], things[offset + 4])
	var current_index := _index(current)
	if current_index >= 0:
		text[current_index] = things[offset + 10]
	var next := current + tile_delta
	var next_index := _index(next)
	if next_index < 0:
		return false
	things[offset + 3] = next.x
	things[offset + 4] = next.y
	things[offset + 10] = text[next_index]
	text[next_index] = record + TEXT_LABEL_BASE
	return true


static func _update_sailboat(
	buildings: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	var offset := record * RECORD_SIZE
	if counters.active_sailboats > 4:
		_remove_thing(text, things, record)
		counters.removed_sailboats += 1
		return
	var direction := int(things[offset + 1])
	if direction < 0 or direction >= CARDINAL_DIRECTIONS.size():
		_remove_thing(text, things, record)
		counters.removed_sailboats += 1
		counters.malformed_records += 1
		return
	if things[offset + 2] != 0:
		if lfsr_random.next_mod(5) == 0:
			_remove_thing(text, things, record)
			counters.removed_sailboats += 1
		return
	if lfsr_random.next_mod(4) == 0:
		var current := Vector2i(things[offset + 3], things[offset + 4])
		var current_index := _index(current)
		if current_index < 0 or flags[current_index] & 0x04 == 0:
			_remove_thing(text, things, record)
			counters.removed_sailboats += 1
			return
		if lfsr_random.next_mod(4000) == 0:
			things[offset + 2] = 1
			counters.distressed_sailboats += 1
			counters.deferred_news += 1
		things[offset + 1] = (direction + random.next_u15() % 3 - 1) & 3
		counters.turned_sailboats += 1
		return
	var route_state := _sailboat_route_state(buildings, flags, text, things, record, direction)
	if route_state < 0:
		counters.removed_sailboats += 1
	elif route_state > 0:
		_move_sailboat(text, things, record, direction, counters)


static func _sailboat_route_state(
	buildings: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int
) -> int:
	var offset := record * RECORD_SIZE
	var next: Vector2i = (
		Vector2i(things[offset + 3], things[offset + 4]) + CARDINAL_DIRECTIONS[direction]
	)
	var next_index := _index(next)
	if next_index < 0:
		return 1
	if buildings[next_index] == TILE_MARINA:
		_remove_thing(text, things, record)
		return -1
	if buildings[next_index] == TILE_PIER or text[next_index] != 0:
		return 0
	return 1 if flags[next_index] & 0x04 != 0 else 0


static func _move_sailboat(
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int,
	counters: Dictionary
) -> void:
	var offset := record * RECORD_SIZE
	var subtile_x: int = int(things[offset + 6]) + SAIL_SUBTILE_X[direction]
	var subtile_y: int = int(things[offset + 7]) + SAIL_SUBTILE_Y[direction]
	var tile_delta := Vector2i.ZERO
	if subtile_x > SUBTILE_LIMIT:
		subtile_x -= SUBTILE_LIMIT
		tile_delta.x = 1
	elif subtile_x < 0:
		subtile_x += SUBTILE_LIMIT
		tile_delta.x = -1
	if subtile_y > SUBTILE_LIMIT:
		subtile_y -= SUBTILE_LIMIT
		tile_delta.y = 1
	elif subtile_y < 0:
		subtile_y += SUBTILE_LIMIT
		tile_delta.y = -1
	things[offset + 6] = subtile_x
	things[offset + 7] = subtile_y
	if tile_delta != Vector2i.ZERO:
		var old_point := Vector2i(things[offset + 3], things[offset + 4])
		var old_index := _index(old_point)
		if old_index >= 0:
			text[old_index] = 0
		var next := old_point + tile_delta
		if next.x < 0 or next.x > 126 or next.y < 0 or next.y > 126:
			_remove_thing(text, things, record)
			counters.removed_sailboats += 1
			return
		things[offset + 3] = next.x
		things[offset + 4] = next.y
		text[_index(next)] = record + TEXT_LABEL_BASE
	counters.moved_sailboats += 1


static func _update_train(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	random,
	lfsr_random,
	game_random,
	counters: Dictionary
) -> void:
	var offset := record * RECORD_SIZE
	var engine_type := int(things[offset])
	var first_car := int(things[offset + 2])
	if first_car < 0 or first_car > LAST_RECORD:
		_remove_thing(text, things, record)
		counters.removed_trains += 1
		counters.malformed_records += 1
		return
	var first_car_offset := first_car * RECORD_SIZE
	var second_car := int(things[first_car_offset + 2])
	if second_car < 0 or second_car > LAST_RECORD:
		_remove_thing(text, things, record)
		_remove_thing(text, things, first_car)
		counters.removed_trains += 1
		counters.malformed_records += 1
		return
	var second_car_offset := second_car * RECORD_SIZE
	var current := Vector2i(things[offset + 3], things[offset + 4])
	var direction := int(things[offset + 1]) & 0x0f
	if direction >= CARDINAL_DIRECTIONS.size():
		_remove_train(text, things, record, first_car, second_car)
		counters.removed_trains += 1
		counters.malformed_records += 1
		return
	if engine_type == TYPE_TRAIN_ENGINE and lfsr_random.next_mask(1) != 0:
		var station_offset := Vector2i.ZERO
		if direction & 1 == 0:
			station_offset.x = -1 if game_random.next_mod(2) == 0 else 1
		else:
			station_offset.y = -1 if game_random.next_mod(2) == 0 else 1
		var station_index := _index(current + station_offset)
		if station_index >= 0 and buildings[station_index] == TILE_RAIL_STATION:
			counters.paused_trains += 1
			return
	if not _train_current_route(buildings, underground, current):
		_remove_train(text, things, record, first_car, second_car)
		counters.active_trains -= 1
		counters.removed_trains += 1
		if _spawn_explosion(text, things, current, 0, 0, 0):
			counters.created_train_crash_explosions += 1
		return
	var destination := Vector2i(things[offset + 6], things[offset + 7])
	var destination_index := _index(destination)
	if destination_index < 0:
		_remove_train(text, things, record, first_car, second_car)
		counters.removed_trains += 1
		counters.malformed_records += 1
		return
	var destination_overlay := int(text[destination_index])
	if destination_overlay >= TEXT_LABEL_BASE and destination_overlay != second_car + TEXT_LABEL_BASE:
		return
	if not _train_record_points_are_valid(things, [record, first_car, second_car]):
		_remove_train(text, things, record, first_car, second_car)
		counters.removed_trains += 1
		counters.malformed_records += 1
		return
	if current != destination:
		text[_record_index(things, record)] = first_car + TEXT_LABEL_BASE
		text[_record_index(things, first_car)] = second_car + TEXT_LABEL_BASE
		text[_record_index(things, second_car)] = things[second_car_offset + 10]
		_copy_train_record(things, first_car, second_car)
		_copy_train_record(things, record, first_car)
		things[offset + 10] = text[destination_index]
		text[destination_index] = record + TEXT_LABEL_BASE
		counters.moved_trains += 1
	things[offset + 3] = destination.x
	things[offset + 4] = destination.y
	current = destination
	var current_index := _index(current)
	if buildings[current_index] >= 0x6c and buildings[current_index] <= 0x70:
		things[offset] = TYPE_SUBWAY_ENGINE if engine_type == TYPE_TRAIN_ENGINE else TYPE_TRAIN_ENGINE
		engine_type = int(things[offset])
	direction = int(things[offset + 1]) & 0x0f
	if lfsr_random.next_mod(4) == 0:
		var turn_direction := (
			(direction - 1) & 3 if lfsr_random.next_mod(2) == 0 else (direction + 1) & 3
		)
		if _train_route_valid(
			buildings, underground, text, current + CARDINAL_DIRECTIONS[turn_direction],
			engine_type
		):
			direction = turn_direction
			counters.turned_trains += 1
		if random.next_u15() & 0xff == 0:
			counters.deferred_news += 1
	var next: Vector2i = current + CARDINAL_DIRECTIONS[direction]
	if not _train_route_valid(buildings, underground, text, next, engine_type):
		var selected := _select_train_direction(
			buildings, underground, text, current, direction, engine_type, game_random
		)
		if selected < 0:
			_reverse_train(things, record, second_car)
			counters.reversed_trains += 1
			return
		things[offset + 1] = selected
		things[offset + 8] = TRAIN_TRANSITIONS[direction * 4 + selected]
		next = current + CARDINAL_DIRECTIONS[selected]
	else:
		things[offset + 1] = int(things[offset + 1]) & 0x0f
		things[offset + 8] = direction * 2
	things[offset + 6] = next.x
	things[offset + 7] = next.y


static func _train_current_route(
	buildings: PackedByteArray, underground: PackedByteArray, point: Vector2i
) -> bool:
	var index := _index(point)
	if index < 0:
		return false
	var surface := int(buildings[index])
	if _surface_train_route(surface) or (surface >= 0x6c and surface <= 0x70):
		return true
	return _underground_train_route(underground[index])


static func _train_route_valid(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	text: PackedByteArray,
	point: Vector2i,
	engine_type: int
) -> bool:
	var index := _index(point)
	if index < 0 or text[index] >= TEXT_LABEL_BASE:
		return false
	if engine_type == TYPE_TRAIN_ENGINE:
		return _surface_train_route(buildings[index])
	return (
		_underground_train_route(underground[index])
		or (buildings[index] >= 0x6c and buildings[index] <= 0x70)
	)


static func _surface_train_route(tile_value: int) -> bool:
	var tile := int(tile_value)
	return (
		(tile >= 0x2c and tile <= 0x3e)
		or (tile >= 0x45 and tile <= 0x48)
		or (tile >= 0x6c and tile <= 0x6f)
		or tile == 0x4d
		or tile == 0x4e
		or tile == 0x5a
		or tile == 0x5b
	)


static func _underground_train_route(tile_value: int) -> bool:
	var tile := int(tile_value)
	return (
		(tile > 0 and tile < 0x10)
		or tile == 0x1f
		or tile == 0x20
		or tile == 0x22
		or tile == 0x23
	)


static func _select_train_direction(
	buildings: PackedByteArray,
	underground: PackedByteArray,
	text: PackedByteArray,
	point: Vector2i,
	initial_direction: int,
	engine_type: int,
	game_random
) -> int:
	var order_index: int = game_random.next_mod(2)
	for direction_offset in TRAIN_DIRECTION_ORDERS[order_index]:
		var direction := (initial_direction + int(direction_offset)) & 3
		if _train_route_valid(
			buildings, underground, text, point + CARDINAL_DIRECTIONS[direction], engine_type
		):
			return direction
	return -1


static func _copy_train_record(
	things: PackedByteArray, source_record: int, destination_record: int
) -> void:
	var source := source_record * RECORD_SIZE
	var destination := destination_record * RECORD_SIZE
	for field in [3, 4, 6, 7, 10, 1, 8, 0]:
		things[destination + field] = things[source + field]
	if things[destination] == TYPE_TRAIN_ENGINE:
		things[destination] = TYPE_TRAIN_CAR
	elif things[destination] == TYPE_SUBWAY_ENGINE:
		things[destination] = TYPE_SUBWAY_CAR


static func _reverse_train(
	things: PackedByteArray, engine_record: int, second_car_record: int
) -> void:
	var engine := engine_record * RECORD_SIZE
	var second_car := second_car_record * RECORD_SIZE
	var tail_x := things[second_car + 3]
	var tail_y := things[second_car + 4]
	var tail_label := things[second_car + 10]
	var reverse_direction := (int(things[second_car + 1]) + 2) & 3
	for field in [3, 4, 6, 7, 10]:
		things[second_car + field] = things[engine + field]
	things[engine + 3] = tail_x
	things[engine + 4] = tail_y
	things[engine + 6] = tail_x
	things[engine + 7] = tail_y
	things[engine + 10] = tail_label
	things[engine + 8] = reverse_direction + 4
	things[engine + 1] = reverse_direction


static func _train_record_points_are_valid(
	things: PackedByteArray, records: Array
) -> bool:
	for record_value in records:
		var record := int(record_value)
		if _record_index(things, record) < 0:
			return false
	return true


static func _record_index(things: PackedByteArray, record: int) -> int:
	var offset := record * RECORD_SIZE
	return _index(Vector2i(things[offset + 3], things[offset + 4]))


static func _remove_train(
	text: PackedByteArray,
	things: PackedByteArray,
	engine_record: int,
	first_car_record: int,
	second_car_record: int
) -> void:
	_remove_thing(text, things, engine_record)
	_remove_thing(text, things, first_car_record)
	_remove_thing(text, things, second_car_record)


static func _spawn_explosion(
	text: PackedByteArray,
	things: PackedByteArray,
	point: Vector2i,
	height: int,
	state: int,
	goal: int
) -> bool:
	var index := _index(point)
	if index < 0 or text[index] >= TEXT_LABEL_BASE:
		return false
	var record := 0
	for checked_record in range(FIRST_RECORD, LAST_RECORD + 1):
		if things[checked_record * RECORD_SIZE] == 0:
			record = checked_record
			break
	if record == 0:
		return false
	var offset := record * RECORD_SIZE
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
	text[index] = record + TEXT_LABEL_BASE
	return true


static func _remove_thing(
	text: PackedByteArray, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	things[offset] = 0
	var point := Vector2i(things[offset + 3], things[offset + 4])
	var index := _index(point)
	if index >= 0:
		text[index] = 0


static func _convert_to_explosion(
	things: PackedByteArray, record: int, state: int, goal: int
) -> void:
	var offset := record * RECORD_SIZE
	things[offset] = TYPE_EXPLOSION
	things[offset + 1] = 0
	things[offset + 2] = state
	things[offset + 11] = goal


static func _move_thing_eight_way(
	thing_type: int,
	text: PackedByteArray,
	things: PackedByteArray,
	record: int,
	direction: int
) -> int:
	if not THING_SPEEDS.has(thing_type) or direction < 0 or direction >= EIGHT_DIRECTIONS.size():
		_remove_thing(text, things, record)
		return -1
	var offset := record * RECORD_SIZE
	var speed: int = THING_SPEEDS[thing_type]
	var subtile_x: int = int(things[offset + 6]) + EIGHT_DIRECTIONS[direction].x * speed
	var subtile_y: int = int(things[offset + 7]) + EIGHT_DIRECTIONS[direction].y * speed
	var tile_delta := Vector2i.ZERO
	if subtile_x > SUBTILE_LIMIT:
		subtile_x -= SUBTILE_LIMIT
		tile_delta.x = 1
	elif subtile_x < 0:
		subtile_x += SUBTILE_LIMIT
		tile_delta.x = -1
	if subtile_y > SUBTILE_LIMIT:
		subtile_y -= SUBTILE_LIMIT
		tile_delta.y = 1
	elif subtile_y < 0:
		subtile_y += SUBTILE_LIMIT
		tile_delta.y = -1
	things[offset + 6] = subtile_x
	things[offset + 7] = subtile_y
	if tile_delta == Vector2i.ZERO:
		return 0
	var current := Vector2i(things[offset + 3], things[offset + 4])
	var current_index := _index(current)
	if current_index < 0:
		_remove_thing(text, things, record)
		return -1
	text[current_index] = things[offset + 10]
	var next := current + tile_delta
	var next_index := _index(next)
	while next_index >= 0 and text[next_index] >= TEXT_LABEL_BASE:
		things[offset + 3] = next.x
		things[offset + 4] = next.y
		next += tile_delta
		next_index = _index(next)
	if next_index < 0:
		_remove_thing(text, things, record)
		return -1
	things[offset + 3] = next.x
	things[offset + 4] = next.y
	things[offset + 10] = text[next_index]
	text[next_index] = record + TEXT_LABEL_BASE
	return 1


static func _advance_air_direction(
	buildings: PackedByteArray, things: PackedByteArray, record: int
) -> void:
	var offset := record * RECORD_SIZE
	var direction := int(things[offset + 1]) & 7
	var current := Vector2i(things[offset + 3], things[offset + 4])
	if not _air_route_blocked(buildings, current, direction):
		return
	for direction_offset in AIR_DIRECTION_OFFSETS:
		direction = (int(things[offset + 1]) + int(direction_offset)) & 7
		if not _air_route_blocked(buildings, current, direction):
			break
	things[offset + 1] = direction


static func _air_route_blocked(
	buildings: PackedByteArray, current: Vector2i, direction: int
) -> bool:
	var checked_index := _index(current + AIR_ROUTE_DELTAS[direction])
	return checked_index >= 0 and buildings[checked_index] >= 0xfb


static func _turn_one_step(direction: int, target: int) -> int:
	if direction <= target:
		return (direction - 1) & 7 if target - direction > 4 else (direction + 1) & 7
	return (direction + 1) & 7 if direction - target > 4 else (direction - 1) & 7


static func _random_direction_step(direction: int, divisor: int, random) -> int:
	if random.next_u15() % divisor == 0:
		return (direction + random.next_u15() % 3 - 1) & 7
	return direction


static func _direction_quadrant(start: Vector2i, target: Vector2i) -> int:
	var difference := target - start
	if difference.x < 0:
		if difference.y < 0:
			return 7
		return 6 if difference.y == 0 else 5
	if difference.x == 0:
		return 0 if difference.y < 0 else 4
	if difference.y < 0:
		return 1
	return 2 if difference.y == 0 else 3


static func _direction_between(start: Vector2i, target: Vector2i) -> int:
	var difference := target - start
	var absolute_x := absi(difference.x)
	var absolute_y := absi(difference.y)
	if absolute_x < int((absolute_y + 1) / 2):
		return 0 if difference.y < 0 else 4
	if absolute_y < int((absolute_x + 1) / 2):
		return 6 if difference.x < 0 else 2
	if difference.x < 0:
		return 7 if difference.y < 0 else 5
	return 1 if difference.y < 0 else 3


static func _steer_direction(direction: int, start: Vector2i, target: Vector2i) -> int:
	var desired := _direction_between(start, target)
	return direction if desired == direction else _turn_one_step(direction, desired)


static func _thing_distance(start: Vector2i, target: Vector2i) -> int:
	return absi(target.x - start.x) + absi(target.y - start.y)


static func _index(point: Vector2i) -> int:
	if point.x < 0 or point.x >= MAP_SIZE or point.y < 0 or point.y >= MAP_SIZE:
		return -1
	return point.x * MAP_SIZE + point.y
