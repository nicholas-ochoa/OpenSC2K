class_name NetworkCommand
extends RefCounted

const MISC_FUNDS := 0x0014
const MISC_TILE_COUNTS := 0x01f0
const MILITARY_ZONE := 7
const FLAG_WATER := 0x04
const FLAG_PIPED := 0x20
const FLAG_POWERABLE := 0x80

const MODE_ROAD := 0
const MODE_RAIL := 1
const MODE_POWER := 2
const MODE_SUBWAY := 3
const MODE_PIPE := 4

const NETWORK_TOOLS := {
	36: MODE_POWER,
	48: MODE_PIPE,
	72: MODE_ROAD,
	84: MODE_RAIL,
	85: MODE_SUBWAY,
}

const NETWORK_SHAPES := [0, 0, 1, 6, 0, 0, 7, 11, 1, 9, 1, 10, 8, 13, 12, 14]
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const TERRAIN_REQUIRES_GRADING := [
	false, false, false, false, false, true, true, true,
	true, true, true, true, true, false, false, false,
]
const TERRAIN_IS_NETWORK_SLOPE := [
	false, true, true, true, true, false, false, false,
	false, true, true, true, true, false, false, false,
]
const TERRAIN_BLOCKS_DIRECTION := [
	false, false, false, false,
	true, false, true, false,
	false, true, false, true,
	true, false, true, false,
	false, true, false, true,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	true, false, true, false,
	true, false, true, false,
]
const GRADED_TERRAIN := [
	0, 0, 1, 0,
	0, 0, 0, 0,
	0, 0, 1, 1,
	0, 0, 1, 1,
	0, 0, 0, 0,
	0, 0, 0, 0,
	0, 0, 0, 0,
	0, 0, 0, 0,
	0, 0, 0, 0,
	2, 1, 2, 1,
	2, 3, 2, 3,
	4, 3, 4, 3,
	4, 1, 4, 1,
	0, 0, 1, 6,
	0, 0, 7, 11,
	1, 9, 1, 10,
]
const NETWORK_SLOPE_SHAPES := [0, 2, 3, 4, 5]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return NETWORK_TOOLS.has(group_index * ToolCatalog.MAX_SLOTS_PER_GROUP + subtool_index)


static func route(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [start]
	var current := start
	while current != finish:
		var direction := _primary_direction(current, finish)
		current += DIRECTIONS[direction]
		result.append(current)
	return result


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	finish: Vector2i
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool is not a linear network tool"}
	if city.index_of(start.x, start.y) < 0 or city.index_of(finish.x, finish.y) < 0:
		return {"ok": false, "error": "network path is outside the city"}

	var old_payloads := _city_payloads(city)
	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}
	var changed_payloads := _duplicate_payloads(old_payloads)
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var underground: PackedByteArray = changed_payloads.XUND
	var flags: PackedByteArray = changed_payloads.XBIT
	var misc: PackedByteArray = changed_payloads.MISC
	var altitude: PackedByteArray = changed_payloads.ALTM
	var mode := int(NETWORK_TOOLS[group_index * ToolCatalog.MAX_SLOTS_PER_GROUP + subtool_index])

	var planned := _plan_route(buildings, terrain, zones, underground, flags, altitude, start, finish, mode)
	if planned.is_empty():
		return {"ok": false, "error": "network cannot start on this tile"}
	var tool := ToolCatalog.tool(group_index, subtool_index)
	var graded_tiles := 0
	if mode == MODE_ROAD or mode == MODE_RAIL or mode == MODE_POWER:
		for point in planned:
			var terrain_id := int(terrain[point.x * CityState.MAP_SIZE + point.y])
			if terrain_id < 0x30 and TERRAIN_REQUIRES_GRADING[terrain_id & 0x0f]:
				graded_tiles += 1
	var cost := planned.size() * int(tool.cost) + graded_tiles * 25
	if city.funds() < cost:
		return {"ok": false, "error": "insufficient funds", "cost": cost}

	for point_index in planned.size():
		var point := planned[point_index]
		var direction := _route_direction(planned, point_index)
		match mode:
			MODE_ROAD:
				_place_surface(buildings, terrain, zones, flags, misc, point, MODE_ROAD, direction)
			MODE_RAIL:
				_place_surface(buildings, terrain, zones, flags, misc, point, MODE_RAIL, direction)
			MODE_POWER:
				_place_surface(buildings, terrain, zones, flags, misc, point, MODE_POWER, direction)
			MODE_SUBWAY:
				_place_underground(underground, terrain, flags, point, false)
			MODE_PIPE:
				_place_underground(underground, terrain, flags, point, true)
	_write_u32_be(misc, MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()
	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)
	if not _apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		return {"ok": false, "error": "cannot store network changes"}
	return {
		"ok": true,
		"command_type": "network",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"mode": mode,
		"points": planned,
		"cost": cost,
		"graded_tiles": graded_tiles,
		"stopped_early": planned[-1] != finish,
		"changed_ids": changed_ids,
		"old_payloads": old_payloads,
		"new_payloads": changed_payloads,
		"error": "",
	}


static func undo(city: CityState, command: Dictionary) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not command.get("ok", false) or command.get("command_type", "") != "network":
		return {"ok": false, "error": "network command is invalid"}
	var changed_ids: PackedStringArray = command.get("changed_ids", PackedStringArray())
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})
	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return {"ok": false, "error": "city changed after this network command"}
	if not _apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore network changes"}
	var points: Array = command.get("points", [])
	return {"ok": true, "restored_tiles": points.size(), "error": ""}


static func _plan_route(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	start: Vector2i,
	finish: Vector2i,
	mode: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current := start
	var direction := _primary_direction(current, finish)
	if not _tile_is_eligible(buildings, terrain, zones, underground, flags, altitude, current, mode, direction):
		if start == finish:
			for candidate_direction in DIRECTIONS.size():
				if _tile_is_eligible(
					buildings, terrain, zones, underground, flags, altitude,
					current, mode, candidate_direction
				):
					result.append(current)
					return result
		var start_alternate := _alternate_direction(current, finish, direction)
		if start_alternate < 0 or not _tile_is_eligible(
			buildings, terrain, zones, underground, flags, altitude,
			current, mode, start_alternate
		):
			return result
	result.append(current)
	while current != finish:
		direction = _primary_direction(current, finish)
		var next: Vector2i = current + DIRECTIONS[direction]
		if not _tile_is_eligible(buildings, terrain, zones, underground, flags, altitude, next, mode, direction):
			var alternate := _alternate_direction(current, finish, direction)
			if alternate < 0:
				break
			next = current + DIRECTIONS[alternate]
			if not _tile_is_eligible(buildings, terrain, zones, underground, flags, altitude, next, mode, alternate):
				break
		current = next
		result.append(current)
	return result


static func _primary_direction(current: Vector2i, finish: Vector2i) -> int:
	var difference := finish - current
	if absi(difference.y) < absi(difference.x):
		return 1 if difference.x >= 0 else 3
	return 2 if difference.y >= 0 else 0


static func _alternate_direction(current: Vector2i, finish: Vector2i, primary: int) -> int:
	var difference := finish - current
	if primary == 1 or primary == 3:
		if difference.y == 0:
			return -1
		return 2 if difference.y > 0 else 0
	if difference.x == 0:
		return -1
	return 1 if difference.x > 0 else 3


static func _route_direction(points: Array[Vector2i], index: int) -> int:
	if points.size() <= 1:
		return 0
	var difference: Vector2i
	if index + 1 < points.size():
		difference = points[index + 1] - points[index]
	else:
		difference = points[index] - points[index - 1]
	for direction in DIRECTIONS.size():
		if DIRECTIONS[direction] == difference:
			return direction
	return 0


static func _tile_is_eligible(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	point: Vector2i,
	mode: int,
	direction: int
) -> bool:
	if point.x < 0 or point.x >= 128 or point.y < 0 or point.y >= 128:
		return false
	var index := point.x * CityState.MAP_SIZE + point.y
	if (zones[index] & 0x0f) == MILITARY_ZONE:
		return false
	if mode == MODE_SUBWAY or mode == MODE_PIPE:
		var altitude_offset := index * 2
		var altitude_word := (altitude[altitude_offset] << 8) | altitude[altitude_offset + 1]
		var tunnel_level := (altitude_word & 0x7c00) >> 10
		if tunnel_level == 1 or tunnel_level == 2:
			return false
		var under_tile := int(underground[index])
		if under_tile == 0:
			return true
		if mode == MODE_PIPE:
			return under_tile + (direction & 1) == 0x11
		return under_tile + (direction & 1) == 0x02

	if flags[index] & FLAG_WATER:
		return false
	var terrain_id := int(terrain[index])
	if terrain_id >= 0x10 and terrain_id < 0x20:
		return false
	if terrain_id < 0x40 and TERRAIN_BLOCKS_DIRECTION[(terrain_id & 0x0f) * 4 + direction]:
		return false
	var building := int(buildings[index])
	if building == 0x05 or building == 0x0d or building > 0x50:
		return false
	if building <= 0x0c:
		return true
	var directional_id := building + (direction & 1)
	return directional_id == 0x0f or directional_id == 0x1e or directional_id == 0x2d or directional_id == 0x4a


static func _place_surface(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	mode: int,
	direction: int
) -> void:
	var index := point.x * CityState.MAP_SIZE + point.y
	_grade_surface_terrain(terrain, flags, point, direction)
	var old_tile := int(buildings[index])
	var new_tile := _surface_replacement(old_tile, mode)
	if new_tile < 0:
		return
	_replace_building(buildings, zones, misc, index, new_tile)
	if mode == MODE_POWER:
		flags[index] |= FLAG_POWERABLE
	else:
		zones[index] &= 0xf0
	_retile_surface_neighborhood(buildings, terrain, zones, flags, misc, point, mode)


static func _grade_surface_terrain(
	terrain: PackedByteArray, flags: PackedByteArray, point: Vector2i, direction: int
) -> void:
	var index := point.x * CityState.MAP_SIZE + point.y
	var terrain_id := int(terrain[index])
	if terrain_id >= 0x30:
		return
	var shape := terrain_id & 0x0f
	if not TERRAIN_REQUIRES_GRADING[shape]:
		return
	if TERRAIN_IS_NETWORK_SLOPE[shape]:
		terrain[index] = (terrain_id & 0xf0) | GRADED_TERRAIN[shape * 4 + direction]
		return
	terrain[index] = 0x0d if terrain_id < 0x10 else 0x1d
	flags[index] &= ~FLAG_WATER


static func _surface_replacement(old_tile: int, mode: int) -> int:
	if mode == MODE_ROAD:
		if old_tile < 0x0e:
			return 0x1d
		return {0x0e: 0x44, 0x0f: 0x43, 0x2c: 0x46, 0x2d: 0x45, 0x49: 0x4b, 0x4a: 0x4c}.get(old_tile, -1)
	if mode == MODE_RAIL:
		if old_tile < 0x0e:
			return 0x2c
		return {0x0e: 0x48, 0x0f: 0x47, 0x1d: 0x45, 0x1e: 0x46, 0x49: 0x4d, 0x4a: 0x4e}.get(old_tile, -1)
	if old_tile < 0x0e:
		return 0x0e
	return {0x1d: 0x43, 0x1e: 0x44, 0x2c: 0x47, 0x2d: 0x48, 0x49: 0x4f, 0x4a: 0x50}.get(old_tile, -1)


static func _retile_surface_neighborhood(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	mode: int
) -> void:
	_retile_surface(buildings, terrain, zones, flags, misc, point, mode)
	for offset in DIRECTIONS:
		var near: Vector2i = point + offset
		if near.x >= 0 and near.x < 128 and near.y >= 0 and near.y < 128:
			_retile_surface(buildings, terrain, zones, flags, misc, near, mode)


static func _retile_surface(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	mode: int
) -> void:
	var index := point.x * CityState.MAP_SIZE + point.y
	var current := int(buildings[index])
	var base := 0
	if mode == MODE_ROAD:
		if current < 0x1d or current > 0x2b:
			return
		base = 0x1d
	elif mode == MODE_RAIL:
		if current < 0x2c or current > 0x3a:
			return
		base = 0x2c
	else:
		if current < 0x0e or current > 0x1c:
			return
		base = 0x0e

	var terrain_id := int(terrain[index])
	if terrain_id < 0x30:
		var terrain_shape := terrain_id & 0x0f
		if TERRAIN_IS_NETWORK_SLOPE[terrain_shape] and terrain_shape < NETWORK_SLOPE_SHAPES.size():
			_replace_building(
				buildings, zones, misc, index,
				base + NETWORK_SLOPE_SHAPES[terrain_shape]
			)
			return

	var connections := 0
	for direction in 4:
		var near: Vector2i = point + DIRECTIONS[direction]
		if near.x < 0 or near.x >= 128 or near.y < 0 or near.y >= 128:
			continue
		var near_index := near.x * CityState.MAP_SIZE + near.y
		var connects := false
		if mode == MODE_POWER:
			connects = (flags[near_index] & FLAG_POWERABLE) != 0
		elif mode == MODE_ROAD:
			connects = _road_connects(buildings[near_index])
		else:
			connects = _rail_connects(buildings[near_index])
		if connects:
			connections |= 1 << direction
	_replace_building(buildings, zones, misc, index, base + NETWORK_SHAPES[connections])


static func _road_connects(tile_id: int) -> bool:
	return (
		(tile_id >= 0x1d and tile_id <= 0x2b)
		or (tile_id >= 0x3f and tile_id <= 0x46)
		or tile_id == 0x4b
		or tile_id == 0x4c
		or (tile_id >= 0x5d and tile_id <= 0x60)
	)


static func _rail_connects(tile_id: int) -> bool:
	return (
		(tile_id >= 0x2c and tile_id <= 0x3e)
		or (tile_id >= 0x45 and tile_id <= 0x48)
		or tile_id == 0x4d
		or tile_id == 0x4e
		or (tile_id >= 0x6c and tile_id <= 0x6f)
	)


static func _place_underground(
	underground: PackedByteArray,
	terrain: PackedByteArray,
	flags: PackedByteArray,
	point: Vector2i,
	pipes: bool
) -> void:
	var index := point.x * CityState.MAP_SIZE + point.y
	var old_tile := int(underground[index])
	if pipes:
		if old_tile == 0:
			underground[index] = 0x10
		elif old_tile == 0x01:
			underground[index] = 0x1f
		elif old_tile == 0x02:
			underground[index] = 0x20
		else:
			return
		flags[index] |= FLAG_PIPED
	else:
		if old_tile == 0:
			underground[index] = 0x01
		elif old_tile == 0x10:
			underground[index] = 0x20
		elif old_tile == 0x11:
			underground[index] = 0x1f
		else:
			return
	_retile_underground_neighborhood(underground, terrain, point, pipes)


static func _retile_underground_neighborhood(
	underground: PackedByteArray, terrain: PackedByteArray, point: Vector2i, pipes: bool
) -> void:
	BuildingCommand._retile_neighborhood(underground, terrain, point, pipes)


static func _replace_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	var old_tile := int(buildings[index])
	if old_tile == new_tile:
		return
	var zone := zones[index] & 0x0f
	if zone != MILITARY_ZONE:
		var old_offset := MISC_TILE_COUNTS + old_tile * 4
		var new_offset := MISC_TILE_COUNTS + new_tile * 4
		_write_u32_be(misc, old_offset, (_read_u32_be(misc, old_offset) - 1) & 0xffff)
		_write_u32_be(misc, new_offset, (_read_u32_be(misc, new_offset) + 1) & 0xffff)
	buildings[index] = new_tile


static func _city_payloads(city: CityState) -> Dictionary:
	var result := {}
	for checked in [
		["ALTM", CityState.TILE_COUNT * 2],
		["XBLD", CityState.TILE_COUNT],
		["XTER", CityState.TILE_COUNT],
		["XZON", CityState.TILE_COUNT],
		["XUND", CityState.TILE_COUNT],
		["XBIT", CityState.TILE_COUNT],
		["MISC", 4800],
	]:
		var chunk := city.document.find_chunk(checked[0])
		if chunk == null or chunk.decoded_payload.size() != checked[1]:
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
	var altitude := city.document.find_chunk("ALTM").decoded_payload
	for index in CityState.TILE_COUNT:
		city.altitude_words[index] = (altitude[index * 2] << 8) | altitude[index * 2 + 1]
	city.buildings = city.document.find_chunk("XBLD").decoded_payload.duplicate()
	city.terrain = city.document.find_chunk("XTER").decoded_payload.duplicate()
	city.zones = city.document.find_chunk("XZON").decoded_payload.duplicate()
	city.underground = city.document.find_chunk("XUND").decoded_payload.duplicate()
	city.tile_flags = city.document.find_chunk("XBIT").decoded_payload.duplicate()


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
