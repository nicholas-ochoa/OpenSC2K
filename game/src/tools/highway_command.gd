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
const CONNECTION_LABEL := 0xfa
const CONNECTION_COST := 1500
const CONNECTION_UNSELECTED := -1
const CONNECTION_CANCELLED := 0
const CONNECTION_CONFIRMED := 1

const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const SHAPE_BY_CONNECTIONS := [2, 2, 3, 8, 2, 2, 9, 12, 3, 11, 3, 12, 10, 12, 12, 12]
const SLOPE_CLASS := [0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4]
const INVALID_TERRAIN_SHAPE := -1
const FLAT_TERRAIN_SHAPE := 0x0f
const FILLED_FLAT_TERRAIN_SHAPE := 0x4000


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_ROADS and subtool_index == SUBTOOL_HIGHWAY


static func snap_anchor(point: Vector2i) -> Vector2i:
	return Vector2i(point.x & ~1, point.y & ~1)


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	selected_start: Vector2i,
	selected_finish: Vector2i,
	connection_choice := CONNECTION_UNSELECTED
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
	var text_chunk := city.document.find_chunk("XTXT")
	if text_chunk == null or text_chunk.decoded_payload.size() != CityState.TILE_COUNT:
		return {"ok": false, "error": "required city data is missing or invalid"}
	old_payloads["XTXT"] = text_chunk.decoded_payload.duplicate()
	var buildings: PackedByteArray = old_payloads.XBLD
	var terrain: PackedByteArray = old_payloads.XTER
	var flags: PackedByteArray = old_payloads.XBIT
	var altitude: PackedByteArray = old_payloads.ALTM
	var text_overlays: PackedByteArray = old_payloads.XTXT
	var sections := _plan_flat_route(
		buildings, terrain, flags, altitude, start, finish
	)
	if sections.is_empty():
		if _section_has_water(flags, start):
			return {"ok": false, "error": "highway bridges are not implemented"}
		return {"ok": false, "error": "highway cannot start on this section"}
	var route_cost := sections.size() * int(ToolCatalog.tool(group_index, subtool_index).cost)
	if city.funds() < route_cost:
		return {"ok": false, "error": "insufficient funds", "cost": route_cost}
	var connection_anchor: Vector2i = sections[-1]
	var connection_available := (
		_is_connection_exit(sections, finish)
		and text_overlays[start.x * CityState.MAP_SIZE + start.y] != CONNECTION_LABEL
	)
	var connection_affordable := city.funds() - route_cost >= CONNECTION_COST
	if (
		connection_available
		and connection_affordable
		and connection_choice == CONNECTION_UNSELECTED
	):
		return {
			"ok": false,
			"connection_selection_required": true,
			"connection_anchor": connection_anchor,
			"connection_cost": CONNECTION_COST,
			"route_cost": route_cost,
			"sections": sections,
			"error": "neighbor connection confirmation is required",
		}
	if connection_choice == CONNECTION_CONFIRMED:
		if not connection_available:
			return {"ok": false, "error": "neighbor connection is not available"}
		if not connection_affordable:
			return {
				"ok": false,
				"error": "insufficient funds",
				"cost": route_cost + CONNECTION_COST,
			}
	var connection_built := connection_choice == CONNECTION_CONFIRMED
	var cost := route_cost + (CONNECTION_COST if connection_built else 0)

	var changed_payloads := NetworkCommand._duplicate_payloads(old_payloads)
	buildings = changed_payloads.XBLD
	terrain = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	flags = changed_payloads.XBIT
	altitude = changed_payloads.ALTM
	text_overlays = changed_payloads.XTXT
	var misc: PackedByteArray = changed_payloads.MISC
	var graded_sections := 0
	for section_index in sections.size():
		var direction := _section_direction(sections, section_index, finish)
		var section := sections[section_index]
		var terrain_shape := _terrain_section_shape(
			buildings, terrain, altitude, section
		)
		if terrain_shape == FLAT_TERRAIN_SHAPE:
			_place_straight_section(buildings, zones, misc, section, direction & 1)
		elif terrain_shape == FILLED_FLAT_TERRAIN_SHAPE or terrain_shape == 0:
			_prepare_flat_terrain(terrain, altitude, section)
			_place_straight_section(buildings, zones, misc, section, direction & 1)
			graded_sections += 1
		else:
			var grade_kind := _grade_kind_for_shape(terrain_shape)
			if grade_kind < 0:
				return {"ok": false, "error": "highway terrain grade is invalid"}
			_place_graded_section(
				altitude,
				buildings,
				terrain,
				zones,
				misc,
				section,
				grade_kind,
				city.compass_rotation()
			)
			graded_sections += 1
	if connection_built:
		text_overlays[
			connection_anchor.x * CityState.MAP_SIZE + connection_anchor.y
		] = CONNECTION_LABEL
	_retile_affected_sections(
		buildings,
		zones,
		misc,
		sections,
		city.compass_rotation(),
		text_overlays
	)
	BuildingCommand._write_u32_be(misc, BuildingCommand.MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()
	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XTXT", "MISC"]:
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
		"route_cost": route_cost,
		"connection_built": connection_built,
		"connection_cancelled": (
			connection_available and connection_choice == CONNECTION_CANCELLED
		),
		"connection_anchor": connection_anchor,
		"connection_cost": CONNECTION_COST if connection_built else 0,
		"graded_sections": graded_sections,
		"connection_error": (
			"insufficient funds for the neighbor connection"
			if connection_available and not connection_affordable
			else ""
		),
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
	altitude: PackedByteArray,
	start: Vector2i,
	finish: Vector2i
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current := start
	var direction := _primary_direction(current, finish)
	if not _section_is_flat_eligible(
		buildings, terrain, flags, altitude, current, direction
	):
		return result
	result.append(current)
	while current != finish:
		var current_shape := _terrain_section_shape(
			buildings, terrain, altitude, current
		)
		if current_shape == FLAT_TERRAIN_SHAPE:
			direction = _primary_direction(current, finish)
		var next: Vector2i = current + DIRECTIONS[direction] * 2
		if not _section_follows(
			buildings, terrain, flags, altitude, current, next, direction
		):
			if current_shape != FLAT_TERRAIN_SHAPE:
				break
			var alternate := _alternate_direction(current, finish, direction)
			if alternate < 0:
				break
			next = current + DIRECTIONS[alternate] * 2
			if not _section_follows(
				buildings, terrain, flags, altitude, current, next, alternate
			):
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
	altitude: PackedByteArray,
	anchor: Vector2i,
	direction: int
) -> bool:
	if not _anchor_is_in_bounds(anchor):
		return false
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * CityState.MAP_SIZE + point.y
		if (flags[index] & FLAG_WATER) != 0:
			return false
		var tile_id := int(buildings[index])
		if not _building_is_allowed(tile_id):
			return false
		if tile_id > 0x0e and not _network_can_cross(tile_id, direction):
			return false
	return (
		_terrain_section_shape(buildings, terrain, altitude, anchor)
		!= INVALID_TERRAIN_SHAPE
	)


static func _section_follows(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	current: Vector2i,
	candidate: Vector2i,
	direction: int
) -> bool:
	if not _section_is_flat_eligible(
		buildings, terrain, flags, altitude, candidate, direction
	):
		return false
	return absi(
		_section_altitude(terrain, altitude, candidate)
		- _section_altitude(terrain, altitude, current)
	) <= 1


static func _terrain_section_shape(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	anchor: Vector2i
) -> int:
	if not _anchor_is_in_bounds(anchor):
		return INVALID_TERRAIN_SHAPE
	if (
		buildings.size() != CityState.TILE_COUNT
		or terrain.size() != CityState.TILE_COUNT
		or altitude.size() != CityState.TILE_COUNT * 2
	):
		return INVALID_TERRAIN_SHAPE
	var offsets := [
		Vector2i.ZERO,
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(0, 1),
	]
	var class_masks := PackedInt32Array([0, 0, 0, 0, 0])
	var heights := PackedInt32Array()
	for offset_index in offsets.size():
		var point: Vector2i = anchor + offsets[offset_index]
		var index := point.x * CityState.MAP_SIZE + point.y
		if not _building_is_allowed(int(buildings[index])):
			return INVALID_TERRAIN_SHAPE
		var terrain_id := int(terrain[index])
		var slope_class: int = (
			SLOPE_CLASS[terrain_id] if terrain_id < SLOPE_CLASS.size() else 0
		)
		class_masks[slope_class] |= 1 << offset_index
		heights.append(_land_altitude(altitude, index))
	var odd_slope_mask := class_masks[1] | class_masks[3]
	var terrain_mask := (
		class_masks[1] | class_masks[2] | class_masks[3] | class_masks[4]
	)
	if terrain_mask == 0:
		return FLAT_TERRAIN_SHAPE
	if (
		(heights[2] < heights[0] and (terrain_mask & 1) != 0)
		or (heights[0] < heights[2] and (terrain_mask & 4) != 0)
		or (heights[3] < heights[1] and (terrain_mask & 2) != 0)
		or (heights[1] < heights[3] and (terrain_mask & 8) != 0)
	):
		return INVALID_TERRAIN_SHAPE
	var minimum_height := heights[0]
	for height in heights:
		minimum_height = mini(minimum_height, height)
	var raised_mask := 0
	for height_index in heights.size():
		if minimum_height < heights[height_index]:
			raised_mask |= 1 << height_index
	if 0x0f - raised_mask == class_masks[4]:
		return FILLED_FLAT_TERRAIN_SHAPE
	if raised_mask == 0 and int(terrain[anchor.x * CityState.MAP_SIZE + anchor.y]) == 0x0d:
		return FILLED_FLAT_TERRAIN_SHAPE

	var result := 0
	if raised_mask == 0:
		if odd_slope_mask == 8 or odd_slope_mask == 1 or odd_slope_mask == 9:
			result |= 1
		if odd_slope_mask == 1 or odd_slope_mask == 2 or odd_slope_mask == 3:
			result |= 2
		if odd_slope_mask == 2 or odd_slope_mask == 4 or odd_slope_mask == 6:
			result |= 4
		if odd_slope_mask == 4 or odd_slope_mask == 8 or odd_slope_mask == 12:
			result |= 8
	if (
		(raised_mask == 8 or raised_mask == 1 or raised_mask == 9)
		and (odd_slope_mask & 6) == 6
	):
		result |= 1
	if (
		(raised_mask == 1 or raised_mask == 2 or raised_mask == 3)
		and (odd_slope_mask & 12) == 12
	):
		result |= 2
	if (
		(raised_mask == 2 or raised_mask == 4 or raised_mask == 6)
		and (odd_slope_mask & 9) == 9
	):
		result |= 4
	if (
		(raised_mask == 4 or raised_mask == 8 or raised_mask == 12)
		and (odd_slope_mask & 3) == 3
	):
		result |= 8
	if terrain_mask == 7:
		if (class_masks[3] & 1) != 0:
			result |= 4
		if (class_masks[3] & 4) != 0:
			result |= 2
	if terrain_mask == 11:
		if (class_masks[3] & 8) != 0:
			result |= 2
		if (class_masks[3] & 2) != 0:
			result |= 1
	if terrain_mask == 13:
		if (class_masks[3] & 4) != 0:
			result |= 1
		if (class_masks[3] & 1) != 0:
			result |= 8
	if terrain_mask == 14:
		if (class_masks[3] & 8) != 0:
			result |= 4
		if (class_masks[3] & 2) != 0:
			result |= 8
	return result


static func _section_altitude(
	terrain: PackedByteArray, altitude: PackedByteArray, anchor: Vector2i
) -> int:
	var result := 0
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * CityState.MAP_SIZE + point.y
		var height := _land_altitude(altitude, index)
		if terrain[index] != 0:
			height += 1
		result = maxi(result, height)
	return result


static func _land_altitude(altitude: PackedByteArray, index: int) -> int:
	return ((altitude[index * 2] << 8) | altitude[index * 2 + 1]) & 0x1f


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
	rotation: int,
	text_overlays := PackedByteArray()
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
		if _section_grade_kind(buildings, anchor) >= 0:
			continue
		var connections := 0
		for direction_index in 4:
			var neighbor: Vector2i = anchor + DIRECTIONS[direction_index] * 2
			if _neighbor_can_connect(buildings, neighbor, direction_index):
				connections |= 1 << direction_index
		if (
			text_overlays.size() == CityState.TILE_COUNT
			and text_overlays[anchor.x * CityState.MAP_SIZE + anchor.y] == CONNECTION_LABEL
		):
			if anchor.y < 2:
				connections |= 1
			if anchor.x > 125:
				connections |= 2
			if anchor.y > 125:
				connections |= 4
			if anchor.x < 2:
				connections |= 8
		_write_shape(
			buildings,
			zones,
			misc,
			anchor,
			SHAPE_BY_CONNECTIONS[connections],
			rotation
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


static func _section_grade_kind(buildings: PackedByteArray, anchor: Vector2i) -> int:
	var kind := -1
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var tile_id := int(buildings[point.x * CityState.MAP_SIZE + point.y])
		if tile_id < 0x61 or tile_id > 0x64:
			return -1
		var tile_kind := tile_id - 0x5d
		if kind >= 0 and tile_kind != kind:
			return -1
		kind = tile_kind
	return kind


static func _grade_kind_for_shape(terrain_shape: int) -> int:
	if (terrain_shape & 2) != 0:
		return 5
	if (terrain_shape & 8) != 0:
		return 7
	if (terrain_shape & 1) != 0:
		return 4
	if (terrain_shape & 4) != 0:
		return 6
	return -1


static func _prepare_flat_terrain(
	terrain: PackedByteArray, altitude: PackedByteArray, anchor: Vector2i
) -> void:
	var target := _section_altitude(terrain, altitude, anchor)
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * CityState.MAP_SIZE + point.y
		if _land_altitude(altitude, index) < target:
			terrain[index] = 0x0d


static func _place_graded_section(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	kind: int,
	rotation: int
) -> void:
	var target := _section_altitude(terrain, altitude, anchor)
	var offsets := [
		Vector2i.ZERO,
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(0, 1),
	]
	var all_at_target := true
	for offset in offsets:
		var point: Vector2i = anchor + offset
		var index := point.x * CityState.MAP_SIZE + point.y
		if _land_altitude(altitude, index) != target:
			all_at_target = false
			break
	if not all_at_target:
		for offset in offsets:
			var point: Vector2i = anchor + offset
			_set_land_altitude(
				altitude, point.x * CityState.MAP_SIZE + point.y, target - 1
			)
	var terrain_pattern: Array[int]
	match kind:
		4:
			terrain_pattern = [0x0d, 0x01, 0x01, 0x0d]
		5:
			terrain_pattern = [0x0d, 0x0d, 0x02, 0x02]
		6:
			terrain_pattern = [0x03, 0x0d, 0x0d, 0x03]
		7:
			terrain_pattern = [0x04, 0x04, 0x0d, 0x0d]
		_:
			return
	var tile_id := 0x5d + kind
	for offset_index in offsets.size():
		var point: Vector2i = anchor + offsets[offset_index]
		var index := point.x * CityState.MAP_SIZE + point.y
		terrain[index] = terrain_pattern[offset_index]
		zones[index] &= 0xf0
		NetworkCommand._replace_building(buildings, zones, misc, index, tile_id)
	BuildingCommand._set_corners(zones, Rect2i(anchor, Vector2i(2, 2)), 2, rotation)


static func _set_land_altitude(
	altitude: PackedByteArray, index: int, value: int
) -> void:
	var offset := index * 2
	var word := (altitude[offset] << 8) | altitude[offset + 1]
	word = (word & ~0x1f) | (value & 0x1f)
	altitude[offset] = (word >> 8) & 0xff
	altitude[offset + 1] = word & 0xff


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


static func _is_connection_exit(
	sections: Array[Vector2i], finish: Vector2i
) -> bool:
	if sections.is_empty():
		return false
	var last_index := sections.size() - 1
	var direction := _section_direction(sections, last_index, finish)
	var after_exit: Vector2i = sections[last_index] + DIRECTIONS[direction] * 2
	if not _anchor_is_in_bounds(after_exit):
		return true
	return sections.size() == 1 and _anchor_is_on_border(sections[0])


static func _anchor_is_on_border(anchor: Vector2i) -> bool:
	return anchor.x == 0 or anchor.x == 126 or anchor.y == 0 or anchor.y == 126


static func _section_has_water(flags: PackedByteArray, anchor: Vector2i) -> bool:
	if not _anchor_is_in_bounds(anchor):
		return false
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		if (flags[point.x * CityState.MAP_SIZE + point.y] & FLAG_WATER) != 0:
			return true
	return false
