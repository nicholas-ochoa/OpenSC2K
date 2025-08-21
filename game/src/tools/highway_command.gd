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
const BRIDGE_CANCELLED := -2
const BRIDGE_UNSELECTED := -1
const BRIDGE_HIGHWAY := 5
const BRIDGE_REINFORCED := 6
const BRIDGE_COSTS := {BRIDGE_HIGHWAY: 200, BRIDGE_REINFORCED: 300}
const BRIDGE_NAMES := {
	BRIDGE_HIGHWAY: "Highway Bridge",
	BRIDGE_REINFORCED: "Reinforced Bridge",
}

const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const SHAPE_BY_CONNECTIONS := [2, 2, 3, 8, 2, 2, 9, 12, 3, 11, 3, 12, 10, 12, 12, 12]
const GRADED_SHAPE_BY_CONNECTIONS := [2, 2, 3, 3, 2, 2, 3, 2, 3, 3, 3, 2, 3, 2, 2, 2]
const EAST_WEST_KIND_CONNECTIONS := [
	false, false, true, false, true, false, true, false, true,
	true, true, true, true, false, true, false, true, false,
]
const NORTH_SOUTH_KIND_CONNECTIONS := [
	false, true, false, true, false, true, false, true, true,
	true, true, true, true, true, false, true, false, false,
]
const BRIDGE_DIRECTION_MASK_BY_LAND := [
	0, 6, 12, 4, 9, 0, 8, 12, 3, 2, 0, 6, 1, 3, 9, 0,
]
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
	connection_choice := CONNECTION_UNSELECTED,
	bridge_type := BRIDGE_UNSELECTED
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
	var bridge_plan := {}
	var bridge_attempted := false
	if sections.is_empty() and _section_has_water(flags, start):
		bridge_attempted = true
		bridge_plan = _plan_bridge_from_start(
			buildings, terrain, altitude, start, city.compass_rotation()
		)
	elif not sections.is_empty():
		var exit_direction := _section_direction(sections, sections.size() - 1, finish)
		var bridge_start: Vector2i = sections[-1] + DIRECTIONS[exit_direction] * 2
		if _section_has_water(flags, bridge_start):
			bridge_attempted = true
			bridge_plan = _scan_bridge(
				buildings, terrain, altitude, bridge_start, exit_direction
			)
	if sections.is_empty() and not bridge_plan.get("ok", false):
		if bridge_attempted:
			return {
				"ok": false,
				"error": bridge_plan.get("error", "highway bridge is invalid"),
			}
		return {"ok": false, "error": "highway cannot start on this section"}
	var route_cost := sections.size() * int(ToolCatalog.tool(group_index, subtool_index).cost)
	if city.funds() < route_cost:
		return {"ok": false, "error": "insufficient funds", "cost": route_cost}

	var selected_bridge := bridge_type
	var bridge_choices: Array[Dictionary] = []
	if bridge_plan.get("ok", false):
		bridge_choices = _bridge_choices(bridge_plan)
		if selected_bridge == BRIDGE_UNSELECTED:
			return {
				"ok": false,
				"bridge_selection_required": true,
				"bridge_choices": bridge_choices,
				"bridge_span_length": int(bridge_plan.span_length),
				"route_cost": route_cost,
				"dry_sections": sections,
				"error": "highway bridge type selection is required",
			}
		if selected_bridge >= 0 and not _bridge_choice_exists(
			bridge_choices, selected_bridge
		):
			return {"ok": false, "error": "selected highway bridge is not available"}
	elif selected_bridge >= 0:
		return {"ok": false, "error": "highway bridge is not available"}
	if (
		bridge_plan.get("ok", false)
		and selected_bridge == BRIDGE_CANCELLED
		and sections.is_empty()
	):
		return {"ok": false, "cancelled": true, "error": "bridge selection canceled"}

	var bridge_cost := 0
	var bridge_built := false
	var bridge_error := ""
	if bridge_plan.get("ok", false) and selected_bridge >= 0:
		bridge_cost = (
			int(bridge_plan.span_length) * int(BRIDGE_COSTS[selected_bridge])
		)
		if city.funds() - route_cost < bridge_cost:
			bridge_error = "insufficient funds for the highway bridge"
			if sections.is_empty():
				return {"ok": false, "error": "insufficient funds", "cost": bridge_cost}
		else:
			bridge_built = true

	var connection_anchor: Vector2i = sections[-1] if not sections.is_empty() else start
	var connection_available := (
		not bridge_attempted
		and not sections.is_empty()
		and _is_connection_exit(sections, finish)
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
	var cost := (
		route_cost
		+ (bridge_cost if bridge_built else 0)
		+ (CONNECTION_COST if connection_built else 0)
	)

	var changed_payloads := NetworkCommand._duplicate_payloads(old_payloads)
	buildings = changed_payloads.XBLD
	terrain = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	flags = changed_payloads.XBIT
	altitude = changed_payloads.ALTM
	text_overlays = changed_payloads.XTXT
	var misc: PackedByteArray = changed_payloads.MISC
	var graded_sections := 0
	var route_directions := {}
	for section_index in sections.size():
		var direction := _section_direction(sections, section_index, finish)
		var section := sections[section_index]
		route_directions[section] = direction
		var placement := _place_section(
			buildings,
			terrain,
			zones,
			flags,
			altitude,
			text_overlays,
			misc,
			section,
			direction,
			city.compass_rotation()
		)
		if not placement.ok:
			return placement
		if placement.graded:
			graded_sections += 1
	if connection_built:
		text_overlays[
			connection_anchor.x * CityState.MAP_SIZE + connection_anchor.y
		] = CONNECTION_LABEL
	_retile_affected_sections(
		buildings,
		terrain,
		zones,
		flags,
		altitude,
		misc,
		sections,
		city.compass_rotation(),
		text_overlays,
		route_directions
	)
	var bridge_sections: Array[Vector2i] = []
	var bridge_endpoint_sections: Array[Vector2i] = []
	if bridge_built:
		var bridge_result := _place_bridge(
			buildings,
			terrain,
			zones,
			flags,
			altitude,
			misc,
			bridge_plan,
			selected_bridge,
			city.compass_rotation()
		)
		bridge_sections = bridge_result.sections
		bridge_endpoint_sections = bridge_result.endpoint_sections
	BuildingCommand._write_u32_be(misc, BuildingCommand.MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()
	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XBIT", "XTXT", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)
	if not NetworkCommand._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		return {"ok": false, "error": "cannot store highway changes"}
	var tile_indices := PackedInt32Array()
	var affected_sections: Array[Vector2i] = sections.duplicate()
	for anchor in bridge_sections + bridge_endpoint_sections:
		if not affected_sections.has(anchor):
			affected_sections.append(anchor)
	for anchor in affected_sections:
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
		"bridge_built": bridge_built,
		"bridge_cancelled": (
			bridge_plan.get("ok", false) and selected_bridge == BRIDGE_CANCELLED
		),
		"bridge_type": selected_bridge if bridge_built else BRIDGE_UNSELECTED,
		"bridge_name": bridge_type_name(selected_bridge) if bridge_built else "",
		"bridge_sections": bridge_sections,
		"bridge_endpoint_sections": bridge_endpoint_sections,
		"bridge_span_length": int(bridge_plan.get("span_length", 0)),
		"bridge_cost": bridge_cost if bridge_built else 0,
		"bridge_error": bridge_error if bridge_attempted else "",
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
		"stopped_early": (
			not bridge_built
			and (sections.is_empty() or sections[-1] != finish)
		),
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


static func bridge_type_name(bridge_type: int) -> String:
	return String(BRIDGE_NAMES.get(bridge_type, "Unknown Bridge"))


static func _plan_bridge_from_start(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	start: Vector2i,
	view_rotation: int
) -> Dictionary:
	if not _section_is_bridge_clear(buildings, start):
		return {"ok": false, "error": "highway bridge start contains a structure"}
	var terrain_code := _bridge_terrain_code(terrain, start)
	if (terrain_code & 0x0f00) != 0:
		return {"ok": false, "error": "highway bridge start terrain is invalid"}
	if ((terrain_code >> 8) & 0xff) != 0:
		terrain_code >>= 12
	var direction_mask := int(
		BRIDGE_DIRECTION_MASK_BY_LAND[terrain_code & 0x0f]
	)
	for direction in [
		view_rotation & 3,
		(view_rotation + 2) & 3,
		(view_rotation + 1) & 3,
		(view_rotation - 1) & 3,
	]:
		if (direction_mask & (1 << direction)) != 0:
			return _scan_bridge(buildings, terrain, altitude, start, direction)
	return {"ok": false, "error": "highway bridge does not face open water"}


static func _scan_bridge(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	start: Vector2i,
	direction: int
) -> Dictionary:
	if not _section_is_bridge_clear(buildings, start):
		return {"ok": false, "error": "highway bridge start contains a structure"}
	var span_length := 0
	var checked := start
	while true:
		checked += DIRECTIONS[direction] * 2
		span_length += 1
		if not _anchor_is_in_bounds(checked):
			return {"ok": false, "error": "highway bridge does not reach another bank"}
		if not _section_is_bridge_clear(buildings, checked):
			return {"ok": false, "error": "highway bridge path contains a structure"}
		var terrain_code := _bridge_terrain_code(terrain, checked)
		if (terrain_code & 0x0f00) != 0:
			return {"ok": false, "error": "highway bridge bank terrain is invalid"}
		if (terrain_code & 0xff) == 0:
			break
	return {
		"ok": true,
		"start": start,
		"direction": direction,
		"span_length": span_length,
		"reinforced_allowed": _reinforced_bridge_is_allowed(
			buildings, terrain, altitude, start, direction, span_length
		),
		"error": "",
	}


static func _bridge_choices(plan: Dictionary) -> Array[Dictionary]:
	var span_length := int(plan.get("span_length", 0))
	var types := [BRIDGE_HIGHWAY]
	if plan.get("reinforced_allowed", false):
		types.append(BRIDGE_REINFORCED)
	var result: Array[Dictionary] = []
	for bridge_type in types:
		result.append({
			"type": bridge_type,
			"name": bridge_type_name(bridge_type),
			"cost_per_tile": int(BRIDGE_COSTS[bridge_type]),
			"cost": span_length * int(BRIDGE_COSTS[bridge_type]),
		})
	return result


static func _bridge_choice_exists(
	choices: Array[Dictionary], bridge_type: int
) -> bool:
	for choice in choices:
		if int(choice.type) == bridge_type:
			return true
	return false


static func _reinforced_bridge_is_allowed(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	start: Vector2i,
	direction: int,
	span_length: int
) -> bool:
	if span_length <= 2:
		return false
	var current_height := _section_altitude(terrain, altitude, start)
	var behind: Vector2i = start - DIRECTIONS[direction] * 2
	var far_bank: Vector2i = start + DIRECTIONS[direction] * span_length * 2
	return (
		_bridge_endpoint_is_allowed(
			buildings,
			terrain,
			altitude,
			behind,
			current_height,
			direction
		)
		and _bridge_endpoint_is_allowed(
			buildings,
			terrain,
			altitude,
			far_bank,
			current_height,
			(direction + 2) & 3
		)
	)


static func _bridge_endpoint_is_allowed(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	anchor: Vector2i,
	bridge_height: int,
	required_slope_direction: int
) -> bool:
	if not _section_is_bridge_clear(buildings, anchor):
		return false
	var endpoint_height := _section_altitude(terrain, altitude, anchor)
	if endpoint_height < bridge_height or endpoint_height > bridge_height + 1:
		return false
	var terrain_shape := _terrain_section_shape(
		buildings, terrain, altitude, anchor
	)
	if terrain_shape == INVALID_TERRAIN_SHAPE:
		return false
	return (
		endpoint_height != bridge_height
		or (terrain_shape & (1 << required_slope_direction)) != 0
	)


static func _section_is_bridge_clear(
	buildings: PackedByteArray, anchor: Vector2i
) -> bool:
	if not _anchor_is_in_bounds(anchor):
		return false
	for offset in [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
	]:
		var point: Vector2i = anchor + offset
		if int(buildings[point.x * CityState.MAP_SIZE + point.y]) > SMALL_PARK:
			return false
	return true


static func _bridge_terrain_code(
	terrain: PackedByteArray, anchor: Vector2i
) -> int:
	if not _anchor_is_in_bounds(anchor):
		return 0x0f00
	var result := 0
	for offset in [
		Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 1), Vector2i.ZERO,
	]:
		var point: Vector2i = anchor + offset
		var terrain_id := int(terrain[point.x * CityState.MAP_SIZE + point.y])
		result = ((result * 2) + _bridge_terrain_weight(terrain_id)) & 0xffff
	return result


static func _bridge_terrain_weight(terrain_id: int) -> int:
	if terrain_id == 0 or (terrain_id >= 0x40 and terrain_id <= 0x45):
		return 0x1000
	if terrain_id >= 1 and terrain_id <= 0x0f:
		return 0x0100
	if (terrain_id >= 0x10 and terrain_id <= 0x20) or terrain_id == 0x30:
		return 0x0010
	if (
		(terrain_id >= 0x21 and terrain_id <= 0x2f)
		or (terrain_id >= 0x31 and terrain_id <= 0x3f)
	):
		return 0x0001
	return 0


static func _place_bridge(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	misc: PackedByteArray,
	plan: Dictionary,
	bridge_type: int,
	rotation: int
) -> Dictionary:
	var start: Vector2i = plan.start
	var direction := int(plan.direction)
	var span_length := int(plan.span_length)
	var bridge_height := _section_altitude(terrain, altitude, start)
	var endpoint_sections: Array[Vector2i] = []
	if bridge_type == BRIDGE_REINFORCED:
		var behind: Vector2i = start - DIRECTIONS[direction] * 2
		var behind_kind := (
			direction & 1
			if bridge_height - _section_altitude(terrain, altitude, behind) == -1
			else ((direction + 1) & 3) + 4
		)
		_write_bridge_endpoint(
			buildings,
			terrain,
			zones,
			altitude,
			misc,
			behind,
			behind_kind,
			rotation
		)
		endpoint_sections.append(behind)
		var far_bank: Vector2i = start + DIRECTIONS[direction] * span_length * 2
		var far_kind := (
			direction & 1
			if bridge_height - _section_altitude(terrain, altitude, far_bank) == -1
			else ((direction - 1) & 3) + 4
		)
		_write_bridge_endpoint(
			buildings,
			terrain,
			zones,
			altitude,
			misc,
			far_bank,
			far_kind,
			rotation
		)
		endpoint_sections.append(far_bank)

	var sections: Array[Vector2i] = []
	for span_index in span_length:
		var anchor: Vector2i = start + DIRECTIONS[direction] * span_index * 2
		if bridge_type == BRIDGE_REINFORCED:
			_write_reinforced_bridge_section(
				buildings,
				zones,
				flags,
				misc,
				anchor,
				14 if (span_index & 1) == 0 else 13,
				direction,
				rotation
			)
		else:
			_write_normal_bridge_section(
				buildings, zones, misc, anchor, direction
			)
		sections.append(anchor)
	return {"sections": sections, "endpoint_sections": endpoint_sections}


static func _write_bridge_endpoint(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	altitude: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	kind: int,
	rotation: int
) -> void:
	var zone_types := PackedByteArray()
	for offset in [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
	]:
		var point: Vector2i = anchor + offset
		zone_types.append(zones[point.x * CityState.MAP_SIZE + point.y] & 0x0f)
	_write_section_kind(
		buildings, terrain, zones, altitude, misc, anchor, kind, rotation
	)
	for offset_index in zone_types.size():
		var offset: Vector2i = [
			Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
		][offset_index]
		var point: Vector2i = anchor + offset
		var index := point.x * CityState.MAP_SIZE + point.y
		zones[index] = (zones[index] & 0xf0) | zone_types[offset_index]


static func _write_normal_bridge_section(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	direction: int
) -> void:
	var tile_id := STRAIGHT_FIRST + (direction & 1)
	for offset in [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
	]:
		var point: Vector2i = anchor + offset
		var index := point.x * CityState.MAP_SIZE + point.y
		NetworkCommand._replace_building(buildings, zones, misc, index, tile_id)
		zones[index] |= 0xf0


static func _write_reinforced_bridge_section(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	kind: int,
	direction: int,
	rotation: int
) -> void:
	var offsets := [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
	]
	var zone_types := PackedByteArray()
	for offset in offsets:
		var point: Vector2i = anchor + offset
		var index := point.x * CityState.MAP_SIZE + point.y
		zone_types.append(zones[index] & 0x0f)
		NetworkCommand._replace_building(
			buildings, zones, misc, index, 0x5d + kind
		)
		if (direction & 1) == 0:
			flags[index] &= ~0x02 & 0xff
		else:
			flags[index] |= 0x02
	BuildingCommand._set_corners(
		zones, Rect2i(anchor, Vector2i(2, 2)), 2, rotation
	)
	for offset_index in offsets.size():
		var point: Vector2i = anchor + offsets[offset_index]
		var index := point.x * CityState.MAP_SIZE + point.y
		zones[index] = (zones[index] & 0xf0) | zone_types[offset_index]


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
		var slope_class := _terrain_class(terrain_id)
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


static func _terrain_class(terrain_id: int) -> int:
	if (terrain_id >= 1 and terrain_id <= 4) or (terrain_id >= 19 and terrain_id <= 38):
		return 1
	if terrain_id >= 5 and terrain_id <= 8:
		return 2
	if terrain_id >= 9 and terrain_id <= 12:
		return 3
	return 4 if terrain_id == 13 else 0


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


static func _place_section(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	text_overlays: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	direction: int,
	rotation: int
) -> Dictionary:
	if _terrain_section_shape(buildings, terrain, altitude, anchor) == INVALID_TERRAIN_SHAPE:
		return {"ok": false, "error": "highway terrain grade is invalid"}
	_clear_section_zone_types(zones, anchor)
	var old_kind := _section_kind(buildings, zones, flags, anchor)
	var kind := _select_section_kind(
		buildings,
		terrain,
		zones,
		flags,
		altitude,
		text_overlays,
		anchor,
		direction
	)
	var installed_grade := kind >= 4 and kind <= 7
	if kind >= 0:
		_write_section_kind(
			buildings, terrain, zones, altitude, misc, anchor, kind, rotation
		)
	for step in DIRECTIONS:
		var neighbor: Vector2i = anchor + step * 2
		if (
			_anchor_is_in_bounds(neighbor)
			and _section_kind(buildings, zones, flags, neighbor) > 1
		):
			_retile_section(
				buildings,
				terrain,
				zones,
				flags,
				altitude,
				text_overlays,
				misc,
				neighbor,
				direction,
				rotation
			)
	_retile_section(
		buildings,
		terrain,
		zones,
		flags,
		altitude,
		text_overlays,
		misc,
		anchor,
		direction,
		rotation
	)
	return {
		"ok": true,
		"kind": kind if kind >= 0 else old_kind,
		"graded": installed_grade,
		"error": "",
	}


static func _clear_section_zone_types(zones: PackedByteArray, anchor: Vector2i) -> void:
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		zones[point.x * CityState.MAP_SIZE + point.y] &= 0xf0


static func _retile_affected_sections(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	misc: PackedByteArray,
	placed: Array[Vector2i],
	rotation: int,
	text_overlays := PackedByteArray(),
	route_directions := {}
) -> void:
	var affected := {}
	for anchor in placed:
		affected[anchor] = true
		for step in DIRECTIONS:
			var neighbor: Vector2i = anchor + step * 2
			if (
				_anchor_is_in_bounds(neighbor)
				and _section_kind(buildings, zones, flags, neighbor) > 1
			):
				affected[neighbor] = true
	for anchor: Vector2i in affected:
		_retile_section(
			buildings,
			terrain,
			zones,
			flags,
			altitude,
			text_overlays,
			misc,
			anchor,
			int(route_directions.get(anchor, 0)),
			rotation
		)


static func _retile_section(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	text_overlays: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	direction: int,
	rotation: int
) -> int:
	var kind := _select_section_kind(
		buildings,
		terrain,
		zones,
		flags,
		altitude,
		text_overlays,
		anchor,
		direction
	)
	if kind >= 0:
		_write_section_kind(
			buildings, terrain, zones, altitude, misc, anchor, kind, rotation
		)
	return kind


static func _select_section_kind(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	text_overlays: PackedByteArray,
	anchor: Vector2i,
	direction: int
) -> int:
	if not _anchor_is_in_bounds(anchor):
		return -1
	var current_kind := _section_kind(buildings, zones, flags, anchor)
	if (
		current_kind == 0
		or current_kind == 1
		or (current_kind >= 4 and current_kind <= 7)
		or current_kind > 12
	):
		return -1
	var current_height := _section_altitude(terrain, altitude, anchor)
	var connections := 0
	for direction_index in 4:
		connections |= _neighbor_connection_flags(
			buildings,
			terrain,
			zones,
			flags,
			altitude,
			anchor,
			current_height,
			direction_index
		)
	if (
		text_overlays.size() == CityState.TILE_COUNT
		and text_overlays[anchor.x * CityState.MAP_SIZE + anchor.y] == CONNECTION_LABEL
	):
		if anchor.x < 2:
			connections |= 8
		if anchor.x > 125:
			connections |= 2
		if anchor.y < 2:
			connections |= 1
		if anchor.y > 125:
			connections |= 4

	var terrain_shape := _terrain_section_shape(
		buildings, terrain, altitude, anchor
	)
	if terrain_shape == INVALID_TERRAIN_SHAPE:
		return -1
	if current_kind == 2 or current_kind == 3:
		if connections == 1 or connections == 4:
			return 2
		if connections == 2 or connections == 8:
			return 3
		if terrain_shape == FILLED_FLAT_TERRAIN_SHAPE:
			return -1
	if connections == 0:
		if terrain_shape == FLAT_TERRAIN_SHAPE:
			return (direction & 1) + 2
		var grade_kind := _grade_kind_for_shape(terrain_shape)
		if grade_kind >= 0:
			return grade_kind
	if (connections & 0x10) != 0 and (terrain_shape & 2) != 0:
		return 5
	if (connections & 0x40) != 0 and (terrain_shape & 8) != 0:
		return 7
	if (connections & 0x80) != 0 and (terrain_shape & 1) != 0:
		return 4
	if (connections & 0x20) != 0 and (terrain_shape & 4) != 0:
		return 6
	var connection_mask := connections & 0x0f
	if terrain_shape != FLAT_TERRAIN_SHAPE:
		if (connections & 1) != 0 and (terrain_shape & 2) != 0:
			return 5
		if (connections & 4) != 0 and (terrain_shape & 8) != 0:
			return 7
		if (connections & 8) != 0 and (terrain_shape & 1) != 0:
			return 4
		if (connections & 2) != 0 and (terrain_shape & 4) != 0:
			return 6
		return GRADED_SHAPE_BY_CONNECTIONS[connection_mask]
	return SHAPE_BY_CONNECTIONS[connection_mask]


static func _neighbor_connection_flags(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	anchor: Vector2i,
	current_height: int,
	direction_index: int
) -> int:
	var neighbor: Vector2i = anchor + DIRECTIONS[direction_index] * 2
	if not _anchor_is_in_bounds(neighbor):
		return 0
	var neighbor_kind := _section_kind(buildings, zones, flags, neighbor)
	if not _neighbor_kind_connects(
		buildings, terrain, altitude, neighbor, neighbor_kind, direction_index
	):
		return 0
	var neighbor_height := _section_altitude(terrain, altitude, neighbor)
	var result := 1 << direction_index
	match direction_index:
		0:
			if current_height < neighbor_height and neighbor_kind != 5:
				result |= 0x10
			if neighbor_height < current_height or (
				neighbor_height == current_height and neighbor_kind == 5
			):
				result |= 0x40
		1:
			if current_height < neighbor_height and neighbor_kind != 6:
				result |= 0x20
			if neighbor_height < current_height or (
				neighbor_height == current_height and neighbor_kind == 6
			):
				result |= 0x80
		2:
			if current_height < neighbor_height and neighbor_kind != 7:
				result |= 0x40
			if neighbor_height < current_height or (
				neighbor_height == current_height and neighbor_kind == 7
			):
				result |= 0x10
		3:
			if current_height < neighbor_height and neighbor_kind != 4:
				result |= 0x80
			if neighbor_height < current_height or (
				neighbor_height == current_height and neighbor_kind == 4
			):
				result |= 0x20
	return result


static func _neighbor_kind_connects(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	neighbor: Vector2i,
	neighbor_kind: int,
	direction_index: int
) -> bool:
	var north_south := direction_index == 0 or direction_index == 2
	if north_south:
		if neighbor_kind == 1 or neighbor_kind == 3:
			return true
		if (
			neighbor_kind >= 0
			and neighbor_kind < NORTH_SOUTH_KIND_CONNECTIONS.size()
			and neighbor_kind > 3
			and NORTH_SOUTH_KIND_CONNECTIONS[neighbor_kind]
		):
			return true
		return (
			neighbor_kind == 2
			and _terrain_section_shape(buildings, terrain, altitude, neighbor)
			!= FILLED_FLAT_TERRAIN_SHAPE
		)
	if neighbor_kind == 0 or neighbor_kind == 2:
		return true
	if (
		neighbor_kind >= 0
		and neighbor_kind < EAST_WEST_KIND_CONNECTIONS.size()
		and neighbor_kind > 3
		and EAST_WEST_KIND_CONNECTIONS[neighbor_kind]
	):
		return true
	return (
		neighbor_kind == 3
		and _terrain_section_shape(buildings, terrain, altitude, neighbor)
		!= FILLED_FLAT_TERRAIN_SHAPE
	)


static func _section_kind(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	anchor: Vector2i
) -> int:
	if not _anchor_is_in_bounds(anchor):
		return -1
	var anchor_index := anchor.x * CityState.MAP_SIZE + anchor.y
	var anchor_tile := int(buildings[anchor_index])
	if not _is_highway_tile(anchor_tile):
		return -1
	if (zones[anchor_index] & 0xf0) != 0xf0:
		var shaped_kind := anchor_tile - 0x5d
		if shaped_kind > 12:
			var south_index := anchor.x * CityState.MAP_SIZE + anchor.y + 1
			return 16 if (flags[south_index] & 0x02) != 0 else 15
		return shaped_kind
	var last_tile := anchor_tile
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * CityState.MAP_SIZE + point.y
		last_tile = int(buildings[index])
		if last_tile >= 0x4b and last_tile <= 0x50:
			return last_tile & 1
		if (flags[index] & FLAG_WATER) != 0:
			return 13 if last_tile == 0x49 else 14
	if last_tile >= STRAIGHT_FIRST and last_tile <= 0x4a:
		return (last_tile & 1) + 2
	return -1


static func _is_highway_tile(tile_id: int) -> bool:
	return (
		(tile_id >= STRAIGHT_FIRST and tile_id <= STRAIGHT_LAST)
		or (tile_id >= SHAPED_FIRST and tile_id <= SHAPED_LAST)
	)


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


static func _prepare_shaped_terrain(
	terrain: PackedByteArray, altitude: PackedByteArray, anchor: Vector2i
) -> void:
	var target := _section_altitude(terrain, altitude, anchor)
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * CityState.MAP_SIZE + point.y
		if terrain[index] != 0 or _land_altitude(altitude, index) < target:
			terrain[index] = 0x0d


static func _write_section_kind(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	altitude: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	kind: int,
	rotation: int
) -> void:
	if kind < 4:
		_prepare_flat_terrain(terrain, altitude, anchor)
		var orientation := kind & 1
		for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var point: Vector2i = anchor + offset
			var old_tile := int(buildings[point.x * CityState.MAP_SIZE + point.y])
			if old_tile == 0x0e or old_tile == 0x1d or old_tile == 0x2c:
				orientation = 1
			elif old_tile == 0x0f or old_tile == 0x1e or old_tile == 0x2d:
				orientation = 0
		_place_straight_section(buildings, zones, misc, anchor, orientation)
		return
	if kind >= 4 and kind <= 7:
		_place_graded_section(
			altitude, buildings, terrain, zones, misc, anchor, kind, rotation
		)
		return
	if kind >= 8 and kind <= 12:
		_prepare_shaped_terrain(terrain, altitude, anchor)
		_write_shape(buildings, zones, misc, anchor, kind, rotation)


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
