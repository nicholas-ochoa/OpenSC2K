class_name ScurkPlaceCommand
extends RefCounted

const Buildings = preload("res://src/tools/building_command.gd")
const Demolish = preload("res://src/tools/demolish_command.gd")
const Networks = preload("res://src/tools/network_command.gd")
const PickCopy = preload("res://src/tools/scurk_pick_copy.gd")

const ROAD_FIRST := 0x1d
const RADIOACTIVITY := 0x05
const SMALL_PARK := 0x0d
const BIG_PARK := 0xd5
const HYDRO_DAM_FIRST := 0xc6
const HYDRO_DAM_LAST := 0xc7
const MARINA := 0xf8
const STATUE := 0xdb
const WATER_PUMP := 0xdc
const SUBWAY_STATION := 0xe9
const FLAG_WATER := 0x04
const FLAG_PIPED := 0x20
const FLAG_POWERED := 0x40
const FLAG_POWERABLE := 0x80
const STRUCTURE_FLAGS := FLAG_PIPED | FLAG_POWERED | FLAG_POWERABLE

const BUDGET_CURRENT := {
	0xd1: 7,
	0xd2: 5,
	0xd3: 6,
	0xd6: 8,
	0xd9: 9,
}

const VARIABLE_ZONE_TILES := {
	0x88: 1,
	0x89: 1,
	0x8a: 2,
	0x8b: 2,
	0xa6: 2,
	0xa7: 2,
	0xa8: 2,
	0xa9: 2,
	0xaa: 2,
	0xab: 2,
	0xac: 2,
	0xad: 1,
	0xc2: 2,
	0xc3: 2,
	0xc4: 1,
	0xc5: 1,
}


static func placeable_large_ids(group: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if group == PickCopy.GROUP_ALL:
		for tile_id in 500:
			result.append(1000 + tile_id)
		return result
	result = PickCopy.group_large_ids(group)
	if group == 5:
		for tile_id in range(0x0e, 0x70):
			result.append(1000 + tile_id)
	return result


static func is_placeable_tile(tile_id: int) -> bool:
	return tile_id >= 0 and tile_id < 500


static func footprint(tile_id: int, selected: Vector2i) -> Rect2i:
	if not is_placeable_tile(tile_id):
		return Rect2i()
	return Buildings.footprint(selected, Demolish.structure_area(tile_id) if tile_id <= 255 else 1)


static func apply(
	city: CityState,
	tile_id: int,
	selected: Vector2i,
	process_random: SimRandom,
	selected_zone := 0,
	australian_locale := false
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	if city == null or not city.is_valid():
		return _failure("city is invalid")
	if not is_placeable_tile(tile_id):
		return _failure("object is not available in Place & Print")
	if process_random == null:
		return _failure("process random state is required")

	if tile_id > 255:
		if selected.x < 0 or selected.y < 0 or selected.x >= map_edge or selected.y >= map_edge:
			return _failure("object does not fit inside the map")
		var before := city.scurk_artwork_stamps.duplicate(true)
		city.scurk_artwork_stamps.append({"tile_id": tile_id, "point": selected})
		return {"ok": true, "error": "", "command_type": "scurk_artwork",
			"scurk_place_history": true, "area": 1, "old_stamps": before,
			"new_stamps": city.scurk_artwork_stamps.duplicate(true)}
	var area := Demolish.structure_area(tile_id)
	var site := Buildings.footprint(selected, area)
	if not Buildings._footprint_is_in_bounds(site, area, map_edge):
		return _failure("object does not fit inside the map")

	var old_payloads := Buildings._city_payloads(city)
	if old_payloads.is_empty():
		return _failure("required city data is missing or invalid")
	var changed_payloads := Buildings._duplicate_payloads(old_payloads)
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var flags: PackedByteArray = changed_payloads.XBIT
	var underground: PackedByteArray = changed_payloads.XUND
	var text_overlays: PackedByteArray = changed_payloads.XTXT
	var labels: PackedByteArray = changed_payloads.XLAB
	var microsims: PackedByteArray = changed_payloads.XMIC
	var misc: PackedByteArray = changed_payloads.MISC

	var site_check := _check_site(buildings, terrain, flags, site, tile_id, map_edge)
	if not site_check.ok:
		return _failure(site_check.error)

	var process_random_state_before := process_random.state
	var overlay_id := Buildings._provision_microsim(
		microsims,
		labels,
		text_overlays,
		tile_id,
		city.current_year(),
		process_random,
		misc,
		australian_locale,
		true
	)
	var zone_id := _zone_for_tile(tile_id, zones, site, selected_zone, map_edge)
	var placed_flags := (
		FLAG_PIPED if tile_id == SMALL_PARK or tile_id == BIG_PARK else STRUCTURE_FLAGS
	)
	if tile_id < 0x70:
		placed_flags = FLAG_POWERABLE if tile_id >= 0x0e else 0
	var tile_indices := PackedInt32Array()
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var index := x * map_edge + y
			Networks._replace_building(buildings, zones, misc, index, tile_id)
			zones[index] = zone_id
			flags[index] = (flags[index] & 0x1f) | placed_flags
			if overlay_id != 0:
				OverlayData.write(text_overlays, index, overlay_id)
			tile_indices.append(index)
	Buildings._set_corners(zones, site, area, city.compass_rotation(), map_edge)

	if tile_id == STATUE:
		flags[selected.x * map_edge + selected.y] &= ~FLAG_POWERABLE & 0xff
	elif tile_id == WATER_PUMP:
		Buildings._place_pipe(underground, terrain, zones, flags, misc, selected, map_edge)
	elif tile_id == SUBWAY_STATION:
		Buildings._place_subway_station(underground, terrain, zones, flags, misc, selected, map_edge)
	if BUDGET_CURRENT.has(tile_id):
		var budget_offset: int = (
			Buildings.MISC_BUDGETS
			+ int(BUDGET_CURRENT[tile_id]) * Buildings.BUDGET_RECORD_SIZE
		)
		Buildings._write_u32_be(
			misc,
			budget_offset,
			Buildings._read_u32_be(misc, budget_offset) + 1
		)

	var changed_ids := PackedStringArray()
	for chunk_id in ["XBLD", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)
	if not Buildings._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		process_random.state = process_random_state_before
		return _failure("cannot store Place & Print changes")

	return {
		"ok": true,
		"error": "",
		"command_type": "scurk_place_object",
		"scurk_place_history": true,
		"tile_id": tile_id,
		"area": area,
		"site": site,
		"tile_indices": tile_indices,
		"zone_id": zone_id,
		"overlay_id": overlay_id,
		"changed_ids": changed_ids,
		"old_payloads": old_payloads,
		"new_payloads": changed_payloads,
		"process_random_state_before": process_random_state_before,
		"process_random_state_after": process_random.state,
	}


static func undo(
	city: CityState, command: Dictionary, process_random: SimRandom
) -> Dictionary:
	return _apply_history(city, command, process_random, false)


static func redo(
	city: CityState, command: Dictionary, process_random: SimRandom
) -> Dictionary:
	return _apply_history(city, command, process_random, true)


static func _apply_history(
	city: CityState,
	command: Dictionary,
	process_random: SimRandom,
	forward: bool
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	if city == null or not city.is_valid():
		return _failure("city is invalid")
	if not command.get("ok", false) or not command.get(
		"scurk_place_history", false
	):
		return _failure("Place & Print command is invalid")
	if command.get("command_type", "") == "scurk_artwork":
		var expected: Array = command.old_stamps if forward else command.new_stamps
		if city.scurk_artwork_stamps != expected:
			return _failure("artwork changed after this command")
		city.scurk_artwork_stamps.assign((command.new_stamps if forward else command.old_stamps).duplicate(true))
		return {"ok": true, "error": "", "restored_tiles": 1}
	var before_random_key := ""
	var after_random_key := ""
	if command.has("process_random_state_before"):
		before_random_key = "process_random_state_before"
		after_random_key = "process_random_state_after"
	elif command.has("random_state_before"):
		before_random_key = "random_state_before"
		after_random_key = "random_state_after"
	if not before_random_key.is_empty():
		if process_random == null:
			return _failure("process random state is required")
		var expected_state := int(command.get(
			before_random_key if forward else after_random_key, -1
		))
		if process_random.state != expected_state:
			return _failure(
				"process random state changed after this Place & Print command"
			)
	var changed_ids: PackedStringArray = command.get(
		"changed_ids", PackedStringArray()
	)
	var source_payloads: Dictionary = command.get(
		"old_payloads" if forward else "new_payloads", {}
	)
	var destination_payloads: Dictionary = command.get(
		"new_payloads" if forward else "old_payloads", {}
	)
	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)
		if (
			chunk == null
			or not source_payloads.has(chunk_id)
			or chunk.decoded_payload != source_payloads[chunk_id]
		):
			return _failure("city changed after this Place & Print command")
	if not Buildings._apply_payloads(
		city, changed_ids, destination_payloads, source_payloads
	):
		return _failure("cannot restore Place & Print changes")
	if changed_ids.has("ALTM"):
		var altitude: PackedByteArray = destination_payloads.ALTM
		for index in (map_edge * map_edge):
			city.altitude_words[index] = (
				(altitude[index * 2] << 8) | altitude[index * 2 + 1]
			)
	if not before_random_key.is_empty():
		process_random.state = int(command.get(
			after_random_key if forward else before_random_key, -1
		))
	return {
		"ok": true,
		"error": "",
		"restored_tiles": maxi(
			command.get("tile_indices", PackedInt32Array()).size(),
			command.get("points", []).size()
		),
	}


static func _check_site(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	flags: PackedByteArray,
	site: Rect2i,
	tile_id: int,
	map_edge: int = 128,
) -> Dictionary:
	var marina_water_tiles := 0
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var index := x * map_edge + y
			var old_building := int(buildings[index])
			if (
				old_building >= ROAD_FIRST
				or old_building == RADIOACTIVITY
				or old_building == SMALL_PARK
			):
				return _failure("site contains a protected tile")
			if tile_id == SMALL_PARK and old_building > 0x0c:
				return _failure("site contains a protected tile")
			var is_water := (flags[index] & FLAG_WATER) != 0
			if tile_id == MARINA:
				if is_water:
					marina_water_tiles += 1
			elif tile_id >= HYDRO_DAM_FIRST and tile_id <= HYDRO_DAM_LAST:
				if terrain[index] == 0 or not is_water:
					return _failure("hydroelectric dam requires water terrain")
			elif tile_id >= 0x70 and (terrain[index] != 0 or is_water):
				return _failure("site is not flat clear land")
	if tile_id == MARINA and (
		marina_water_tiles == 0
		or marina_water_tiles == site.size.x * site.size.y
	):
		return _failure("marina must span land and water")
	return {"ok": true, "error": ""}


static func _zone_for_tile(
	tile_id: int, zones: PackedByteArray, site: Rect2i, selected_zone: int,
	map_edge: int = 128,
) -> int:
	if VARIABLE_ZONE_TILES.has(tile_id):
		var result := (
			selected_zone
			if selected_zone >= 1 and selected_zone <= 9
			else int(VARIABLE_ZONE_TILES[tile_id])
		)
		for x in range(site.position.x, site.end.x):
			for y in range(site.position.y, site.end.y):
				var existing_zone := zones[x * map_edge + y] & 0x0f
				if existing_zone != 0:
					result = existing_zone
		return result
	if tile_id >= 0x70 and tile_id <= 0x7b:
		return 1
	if tile_id >= 0x8c and tile_id <= 0x93 or tile_id >= 0xae and tile_id <= 0xb1:
		return 2
	if tile_id >= 0x7c and tile_id <= 0x83:
		return 3
	if tile_id >= 0x94 and tile_id <= 0x9d or tile_id >= 0xb2 and tile_id <= 0xbb:
		return 4
	if tile_id >= 0x84 and tile_id <= 0x87 or tile_id >= 0xa4 and tile_id <= 0xa5:
		return 5
	if tile_id >= 0x9e and tile_id <= 0xa3 or tile_id >= 0xbc and tile_id <= 0xc1:
		return 6
	if tile_id in [0xe2, 0xe7, 0xef, 0xf1, 0xf9]:
		return 7
	if tile_id in [0xe1, 0xe4, 0xe5, 0xe6, 0xe8, 0xea, 0xee, 0xf6]:
		return 8
	if tile_id in [0xe0, 0xf0, 0xf2]:
		return 9
	return 0


static func _group_is_placeable(group: int) -> bool:
	return (
		group >= 0
		and group < PickCopy.GROUP_TILE_IDS.size()
		and group != PickCopy.GROUP_ANIMATING_I
		and group != PickCopy.GROUP_ANIMATING_II
	)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
