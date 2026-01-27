class_name LandscapeCommand
extends RefCounted

const GROUP_NATURE := 1
const FULL_MAP_SIZE := CityState.MAP_SIZE
const SUBTOOL_TREES := 0
const SUBTOOL_WATER := 1
const FLAG_WATER := 0x04
const RADIOACTIVITY := 0x05
const FIRST_TREE := 0x06
const LAST_TREE := 0x0c
const FIRST_NON_LANDSCAPE_BUILDING := 0x0e
const FORBIDDEN_COAST := 0x2e
const WATERFALL := 0x3e
const MISC_FUNDS := 0x0014
const MISC_TILE_COUNTS := 0x01f0
const MILITARY_ZONE := 7

const CARDINAL_WATER_SHAPES := [13, 21, 18, 8, 19, 16, 5, 1, 20, 7, 17, 4, 6, 3, 2]
const DIAGONAL_WATER_SHAPES := [0, 9, 10, 0, 11, 0, 0, 0, 12, 0, 0, 0, 0, 0, 0, 0]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_NATURE and (
		subtool_index == SUBTOOL_TREES or subtool_index == SUBTOOL_WATER
	)


static func apply_path(
	city: CityState,
	group_index: int,
	subtool_index: int,
	points: Array[Vector2i],
	random: SimRandom,
	free_mode := false
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool is not a landscape tool"}
	if random == null:
		return {"ok": false, "error": "random state is required"}
	if points.is_empty():
		return {"ok": false, "error": "landscape path is empty"}

	var old_payloads := _city_payloads(city)
	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}
	var changed_payloads := _duplicate_payloads(old_payloads)
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var flags: PackedByteArray = changed_payloads.XBIT
	var altitude: PackedByteArray = changed_payloads.ALTM
	var misc: PackedByteArray = changed_payloads.MISC
	var text_overlays := city.text_overlays
	var listed_cost_per_tile := int(
		ToolCatalog.tool(group_index, subtool_index).cost
	)
	var cost_per_tile := 0 if free_mode else listed_cost_per_tile
	var old_funds := city.funds()
	var total_cost := 0
	var applied_indices := PackedInt32Array()
	var skipped_insufficient := 0
	var random_state_before := random.state

	for point in points:
		var index := city.index_of(point.x, point.y)
		if index < 0:
			continue
		if old_funds - total_cost < cost_per_tile:
			skipped_insufficient += 1
			continue
		var applied := false
		if subtool_index == SUBTOOL_TREES:
			applied = _place_tree(buildings, terrain, zones, flags, misc, index, random)
		else:
			applied = _place_water(
				buildings, terrain, zones, flags, altitude, text_overlays, misc, point, map_edge
			)
		if applied:
			total_cost += cost_per_tile
			applied_indices.append(index)

	if applied_indices.is_empty():
		return {
			"ok": false,
			"error": "insufficient funds" if skipped_insufficient > 0 else "no eligible tiles changed",
			"cost": cost_per_tile if skipped_insufficient > 0 else 0,
		}
	_write_u32_be(misc, MISC_FUNDS, old_funds - total_cost)

	var changed_ids := PackedStringArray()
	for chunk_id in ["XBLD", "XTER", "XZON", "XBIT", "ALTM", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)
	if not _apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		random.state = random_state_before
		return {"ok": false, "error": "cannot store landscape changes"}

	return {
		"ok": true,
		"command_type": "landscape",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"tile_indices": applied_indices,
		"cost": total_cost,
		"listed_cost": applied_indices.size() * listed_cost_per_tile,
		"free_mode": free_mode,
		"skipped_insufficient": skipped_insufficient,
		"changed_ids": changed_ids,
		"old_payloads": old_payloads,
		"new_payloads": changed_payloads,
		"random_state_before": random_state_before,
		"random_state_after": random.state,
		"error": "",
	}


static func undo(city: CityState, command: Dictionary, random: SimRandom) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not command.get("ok", false) or command.get("command_type", "") != "landscape":
		return {"ok": false, "error": "landscape command is invalid"}
	if random == null:
		return {"ok": false, "error": "random state is required"}
	if random.state != int(command.get("random_state_after", -1)):
		return {"ok": false, "error": "random state changed after this landscape command"}
	var changed_ids: PackedStringArray = command.get("changed_ids", PackedStringArray())
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})
	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return {"ok": false, "error": "city changed after this landscape command"}
	if not _apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore landscape changes"}
	random.state = int(command.random_state_before)
	var indices: PackedInt32Array = command.get("tile_indices", PackedInt32Array())
	return {"ok": true, "restored_tiles": indices.size(), "error": ""}


static func _place_tree(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	random: SimRandom
) -> bool:
	if flags[index] & FLAG_WATER or buildings[index] == RADIOACTIVITY:
		return false
	if terrain[index] == FORBIDDEN_COAST or terrain[index] == WATERFALL:
		return false
	var old_building := int(buildings[index])
	var new_building := 0
	if old_building < FIRST_TREE:
		new_building = FIRST_TREE + (random.next_u15() & 1)
	elif old_building < 0x0b:
		new_building = old_building + 1
	elif old_building <= LAST_TREE:
		new_building = 0x0b + (random.next_u15() & 1)
	else:
		return false
	_update_building_count(misc, zones[index] & 0x0f, old_building, new_building, int(sqrt(buildings.size())))
	buildings[index] = new_building
	return true


static func _place_water(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	text_overlays: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> bool:
	var index := point.x * map_edge + point.y
	if flags[index] & FLAG_WATER or (OverlayData.read(text_overlays, index) > 0xf9 and OverlayData.read(text_overlays, index) <= 255):
		return false
	var old_building := int(buildings[index])
	if old_building >= FIRST_NON_LANDSCAPE_BUILDING or old_building == RADIOACTIVITY:
		return false
	if terrain[index] == FORBIDDEN_COAST or terrain[index] == WATERFALL:
		return false

	var shape := _water_shape(flags, point.x, point.y, map_edge)
	var transition := _water_transition(terrain[index], shape)
	if not transition.early_return:
		terrain[index] = transition.value
		_update_building_count(misc, zones[index] & 0x0f, old_building, 0, map_edge)
		buildings[index] = 0
		var altitude_offset := index * 2
		var word := (altitude[altitude_offset] << 8) | altitude[altitude_offset + 1]
		word = (word & 0xfc1f) | ((word & 0x1f) << 5)
		altitude[altitude_offset] = (word >> 8) & 0xff
		altitude[altitude_offset + 1] = word & 0xff
		flags[index] |= FLAG_WATER
		for near_x in range(maxi(point.x - 1, 0), mini(point.x + 2, map_edge)):
			for near_y in range(maxi(point.y - 1, 0), mini(point.y + 2, map_edge)):
				if near_x == point.x and near_y == point.y:
					continue
				var near_index := near_x * map_edge + near_y
				if not flags[near_index] & FLAG_WATER:
					continue
				var near_shape := _water_shape(flags, near_x, near_y, map_edge)
				var near_transition := _water_transition(terrain[near_index], near_shape)
				if not near_transition.early_return:
					terrain[near_index] = near_transition.value
	zones[index] &= 0xf0
	return true


static func _water_shape(flags: PackedByteArray, x: int, y: int, map_edge: int = 128) -> int:
	var cardinal := 0
	if y > 0 and flags[x * map_edge + y - 1] & FLAG_WATER:
		cardinal |= 1
	if x < map_edge - 1 and flags[(x + 1) * map_edge + y] & FLAG_WATER:
		cardinal |= 2
	if y < map_edge - 1 and flags[x * map_edge + y + 1] & FLAG_WATER:
		cardinal |= 4
	if x > 0 and flags[(x - 1) * map_edge + y] & FLAG_WATER:
		cardinal |= 8
	if cardinal < 15:
		return CARDINAL_WATER_SHAPES[cardinal]
	var missing_diagonal := 0
	if x > 0 and y > 0 and not flags[(x - 1) * map_edge + y - 1] & FLAG_WATER:
		missing_diagonal |= 1
	if x < map_edge - 1 and y > 0 and not flags[(x + 1) * map_edge + y - 1] & FLAG_WATER:
		missing_diagonal |= 2
	if x < map_edge - 1 and y < map_edge - 1 and not flags[(x + 1) * map_edge + y + 1] & FLAG_WATER:
		missing_diagonal |= 4
	if x > 0 and y < map_edge - 1 and not flags[(x - 1) * map_edge + y + 1] & FLAG_WATER:
		missing_diagonal |= 8
	return DIAGONAL_WATER_SHAPES[missing_diagonal]


static func _water_transition(current: int, shape: int) -> Dictionary:
	if current < 0x10:
		return {"value": shape + 0x30, "early_return": false}
	if current < 0x30:
		if current > 0x1f:
			if ((shape ^ current) & 0x0f) == 0:
				return {"value": current, "early_return": true}
			return {"value": current - 0x10, "early_return": false}
		return {"value": current, "early_return": false}
	if current == shape + 0x30:
		return {"value": current, "early_return": true}
	return {"value": shape + 0x30, "early_return": false}


static func _update_building_count(
	misc: PackedByteArray, zone: int, old_building: int, new_building: int, map_edge: int = 128
) -> void:
	if zone == MILITARY_ZONE:
		return
	var old_offset := MISC_TILE_COUNTS + old_building * 4
	var new_offset := MISC_TILE_COUNTS + new_building * 4
	var old_count := _read_u32_be(misc, old_offset)
	_write_u32_be(misc, old_offset, (old_count - 1) & (0xffff if map_edge == 128 else 0xffffffff))
	var new_count := _read_u32_be(misc, new_offset)
	_write_u32_be(misc, new_offset, (new_count + 1) & (0xffff if map_edge == 128 else 0xffffffff))


static func _city_payloads(city: CityState) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	var result := {}
	for checked in [
		["XBLD", (map_edge * map_edge)],
		["XTER", (map_edge * map_edge)],
		["XZON", (map_edge * map_edge)],
		["XBIT", (map_edge * map_edge)],
		["ALTM", (map_edge * map_edge) * 2],
		["MISC", 4800],
	]:
		var chunk := city.document.find_chunk(checked[0])
		if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size(str(checked[0])):
			return {}
		result[checked[0]] = chunk.decoded_payload.duplicate()
	return result


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary:
	var result := {}
	for chunk_id in payloads:
		result[chunk_id] = payloads[chunk_id].duplicate()
	return result


static func _apply_payloads(
	city: CityState, chunk_ids: PackedStringArray, payloads: Dictionary, rollback: Dictionary
) -> bool:
	var applied := PackedStringArray()
	for chunk_id in chunk_ids:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or not payloads.has(chunk_id) or not chunk.set_decoded_payload(payloads[chunk_id]):
			for rollback_id in applied:
				city.document.find_chunk(rollback_id).set_decoded_payload(rollback[rollback_id])
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
	city.tile_flags = city.document.find_chunk("XBIT").decoded_payload.duplicate()
	var altitude := city.document.find_chunk("ALTM").decoded_payload
	for index in (map_edge * map_edge):
		city.altitude_words[index] = (altitude[index * 2] << 8) | altitude[index * 2 + 1]


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _write_u32_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff
