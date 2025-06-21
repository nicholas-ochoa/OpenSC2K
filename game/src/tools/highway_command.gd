class_name HighwayCommand
extends RefCounted

const GROUP_ROADS := 6
const SUBTOOL_HIGHWAY := 1
const RADIOACTIVITY := 0x05
const SMALL_PARK := 0x0d
const STRAIGHT_FIRST := 0x49
const STRAIGHT_LAST := 0x50
const SHAPED_FIRST := 0x61
const SHAPED_LAST := 0x6b
const FLAG_WATER := 0x04

const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const SHAPE_BY_CONNECTIONS := [2, 2, 3, 8, 2, 2, 9, 12, 3, 11, 3, 12, 10, 12, 12, 12]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_ROADS and subtool_index == SUBTOOL_HIGHWAY


static func snap_anchor(point: Vector2i) -> Vector2i:
	return Vector2i(point.x & ~1, point.y & ~1)


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	selected_start: Vector2i,
	selected_finish: Vector2i
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool is not a highway"}
	var start := snap_anchor(selected_start)
	var finish := snap_anchor(selected_finish)
	if not _anchor_is_in_bounds(start) or not _anchor_is_in_bounds(finish):
		return {"ok": false, "error": "highway is outside the city"}

	var old_payloads := NetworkCommand._city_payloads(city)
	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}
	var buildings: PackedByteArray = old_payloads.XBLD
	var terrain: PackedByteArray = old_payloads.XTER
	var flags: PackedByteArray = old_payloads.XBIT
	var sections := _plan_flat_route(buildings, terrain, flags, start, finish)
	if sections.is_empty():
		if _section_has_water(flags, start):
			return {"ok": false, "error": "highway bridges are not implemented"}
		return {"ok": false, "error": "highway cannot start on this section"}
	var cost := sections.size() * int(ToolCatalog.tool(group_index, subtool_index).cost)
	if city.funds() < cost:
		return {"ok": false, "error": "insufficient funds", "cost": cost}

	var changed_payloads := NetworkCommand._duplicate_payloads(old_payloads)
	buildings = changed_payloads.XBLD
	terrain = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	flags = changed_payloads.XBIT
	var misc: PackedByteArray = changed_payloads.MISC
	for section_index in sections.size():
		var direction := _section_direction(sections, section_index, finish)
		_place_straight_section(buildings, zones, misc, sections[section_index], direction & 1)
	_retile_affected_sections(buildings, zones, misc, sections, city.compass_rotation())
	BuildingCommand._write_u32_be(misc, BuildingCommand.MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()
	for chunk_id in ["XBLD", "XZON", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)
	if not NetworkCommand._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		return {"ok": false, "error": "cannot store highway changes"}
	var tile_indices := PackedInt32Array()
	for anchor in sections:
		for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var point: Vector2i = anchor + offset
			tile_indices.append(point.x * CityState.MAP_SIZE + point.y)
	return {
		"ok": true,
		"command_type": "highway",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"start": start,
		"finish": finish,
		"sections": sections,
		"tile_indices": tile_indices,
		"cost": cost,
		"stopped_early": sections[-1] != finish,
		"changed_ids": changed_ids,
		"old_payloads": old_payloads,
		"new_payloads": changed_payloads,
		"error": "",
	}


static func undo(city: CityState, command: Dictionary) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not command.get("ok", false) or command.get("command_type", "") != "highway":
		return {"ok": false, "error": "highway command is invalid"}
	var changed_ids: PackedStringArray = command.get("changed_ids", PackedStringArray())
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})
	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return {"ok": false, "error": "city changed after this highway command"}
	if not NetworkCommand._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore highway changes"}
	var tile_indices: PackedInt32Array = command.get("tile_indices", PackedInt32Array())
	return {"ok": true, "restored_tiles": tile_indices.size(), "error": ""}


static func _plan_flat_route(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	flags: PackedByteArray,
	start: Vector2i,
	finish: Vector2i
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current := start
	var direction := _primary_direction(current, finish)
	if not _section_is_flat_eligible(buildings, terrain, flags, current, direction):
		return result
	result.append(current)
	while current != finish:
		direction = _primary_direction(current, finish)
		var next: Vector2i = current + DIRECTIONS[direction] * 2
		if not _section_is_flat_eligible(buildings, terrain, flags, next, direction):
			var alternate := _alternate_direction(current, finish, direction)
			if alternate < 0:
				break
			next = current + DIRECTIONS[alternate] * 2
			if not _section_is_flat_eligible(buildings, terrain, flags, next, alternate):
				break
			direction = alternate
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


static func _section_is_flat_eligible(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	flags: PackedByteArray,
	anchor: Vector2i,
	direction: int
) -> bool:
	if not _anchor_is_in_bounds(anchor):
		return false
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * CityState.MAP_SIZE + point.y
		if terrain[index] != 0 or (flags[index] & FLAG_WATER) != 0:
			return false
		var tile_id := int(buildings[index])
		if not _building_is_allowed(tile_id):
			return false
		if tile_id > 0x0e and not _network_can_cross(tile_id, direction):
			return false
	return true


static func _building_is_allowed(tile_id: int) -> bool:
	if (tile_id >= SHAPED_FIRST and tile_id <= SHAPED_LAST) or (tile_id >= STRAIGHT_FIRST and tile_id <= STRAIGHT_LAST):
		return true
	if tile_id == SMALL_PARK or tile_id == RADIOACTIVITY:
		return false
	if tile_id >= 0x1f and tile_id <= 0x2b:
		return false
	if tile_id >= 0x2e and tile_id <= 0x48:
		return false
	return tile_id <= STRAIGHT_LAST


static func _network_can_cross(tile_id: int, direction: int) -> bool:
	var directional_id := tile_id + (direction & 1)
	return directional_id == 0x0f or directional_id == 0x1e or directional_id == 0x2d or directional_id == 0x40


static func _place_straight_section(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	orientation: int
) -> void:
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * CityState.MAP_SIZE + point.y
		zones[index] &= 0xf0
		var tile_id := _straight_replacement(buildings[index], orientation)
		NetworkCommand._replace_building(buildings, zones, misc, index, tile_id)
		zones[index] |= 0xf0


static func _straight_replacement(old_tile: int, orientation: int) -> int:
	match old_tile:
		0x0e:
			return 0x50
		0x0f:
			return 0x4f
		0x1d:
			return 0x4c
		0x1e:
			return 0x4b
		0x2c:
			return 0x4e
		0x2d:
			return 0x4d
		_:
			return STRAIGHT_FIRST + orientation


static func _retile_affected_sections(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	placed: Array[Vector2i],
	rotation: int
) -> void:
	var affected := {}
	for anchor in placed:
		affected[anchor] = true
		for direction in DIRECTIONS:
			var neighbor: Vector2i = anchor + direction * 2
			if _anchor_is_in_bounds(neighbor) and _section_exists(buildings, neighbor):
				affected[neighbor] = true
	for anchor: Vector2i in affected:
		if _crossing_orientation(buildings, anchor) >= 0:
			continue
		var connections := 0
		for direction_index in 4:
			var neighbor: Vector2i = anchor + DIRECTIONS[direction_index] * 2
			if _neighbor_can_connect(buildings, neighbor, direction_index):
				connections |= 1 << direction_index
		_write_shape(
			buildings, zones, misc, anchor, SHAPE_BY_CONNECTIONS[connections], rotation
		)


static func _neighbor_can_connect(
	buildings: PackedByteArray, neighbor: Vector2i, direction_from_current: int
) -> bool:
	if not _anchor_is_in_bounds(neighbor) or not _section_exists(buildings, neighbor):
		return false
	var crossing_orientation := _crossing_orientation(buildings, neighbor)
	if crossing_orientation < 0:
		return true
	return crossing_orientation == (direction_from_current & 1)


static func _section_exists(buildings: PackedByteArray, anchor: Vector2i) -> bool:
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var tile_id := int(buildings[point.x * CityState.MAP_SIZE + point.y])
		if not (
			(tile_id >= STRAIGHT_FIRST and tile_id <= STRAIGHT_LAST)
			or (tile_id >= SHAPED_FIRST and tile_id <= SHAPED_LAST)
		):
			return false
	return true


static func _crossing_orientation(buildings: PackedByteArray, anchor: Vector2i) -> int:
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var tile_id := int(buildings[point.x * CityState.MAP_SIZE + point.y])
		if tile_id >= 0x4b and tile_id <= 0x50:
			return 0 if (tile_id & 1) == 1 else 1
	return -1


static func _write_shape(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	kind: int,
	rotation: int
) -> void:
	if kind == 2 or kind == 3:
		_place_straight_section(buildings, zones, misc, anchor, kind - 2)
		return
	var tile_id := 0x5d + kind
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * CityState.MAP_SIZE + point.y
		zones[index] = 0
		NetworkCommand._replace_building(buildings, zones, misc, index, tile_id)
	BuildingCommand._set_corners(zones, Rect2i(anchor, Vector2i(2, 2)), 2, rotation)


static func _section_direction(
	sections: Array[Vector2i], section_index: int, finish: Vector2i
) -> int:
	if section_index + 1 < sections.size():
		return _direction_between(sections[section_index], sections[section_index + 1])
	if section_index > 0:
		return _direction_between(sections[section_index - 1], sections[section_index])
	return _primary_direction(sections[section_index], finish)


static func _direction_between(start: Vector2i, finish: Vector2i) -> int:
	var difference := finish - start
	if difference.x > 0:
		return 1
	if difference.x < 0:
		return 3
	return 2 if difference.y >= 0 else 0


static func _anchor_is_in_bounds(anchor: Vector2i) -> bool:
	return anchor.x >= 0 and anchor.x <= 126 and anchor.y >= 0 and anchor.y <= 126


static func _section_has_water(flags: PackedByteArray, anchor: Vector2i) -> bool:
	if not _anchor_is_in_bounds(anchor):
		return false
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		if (flags[point.x * CityState.MAP_SIZE + point.y] & FLAG_WATER) != 0:
			return true
	return false
