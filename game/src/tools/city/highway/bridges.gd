class_name HighwayBridges
extends HighwayConstants


static func bridge_type_name(bridge_type: int) -> String:
	return String(BRIDGE_NAMES.get(bridge_type, "Unknown Bridge"))


static func plan_bridge_from_start(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	start: Vector2i,
	view_rotation: int,
	map_edge: int = 128,
) -> Dictionary:
	if not _section_is_bridge_clear(buildings, start, map_edge):
		return {"ok": false, "error": "highway bridge start contains a structure"}

	var terrain_code := bridge_terrain_code(terrain, start, map_edge)

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
			return _scan_bridge(buildings, terrain, altitude, start, direction, map_edge)

	return {"ok": false, "error": "highway bridge does not face open water"}


static func _scan_bridge(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	start: Vector2i,
	direction: int,
	map_edge: int = 128,
) -> Dictionary:
	if not _section_is_bridge_clear(buildings, start, map_edge):
		return {"ok": false, "error": "highway bridge start contains a structure"}

	var span_length := 0
	var checked := start

	while true:
		checked += DIRECTIONS[direction] * 2
		span_length += 1

		if not HighwayGeometry._anchor_is_in_bounds(checked, map_edge):
			return {"ok": false, "error": "highway bridge does not reach another bank"}

		if not _section_is_bridge_clear(buildings, checked, map_edge):
			return {"ok": false, "error": "highway bridge path contains a structure"}

		var terrain_code := bridge_terrain_code(terrain, checked, map_edge)

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
			buildings, terrain, altitude, start, direction, span_length, map_edge
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
	span_length: int,
	map_edge: int = 128,
) -> bool:
	if span_length <= 2:
		return false

	var current_height := HighwayGeometry._section_altitude(terrain, altitude, start, map_edge)
	var behind: Vector2i = start - DIRECTIONS[direction] * 2
	var far_bank: Vector2i = start + DIRECTIONS[direction] * span_length * 2

	return (
		_bridge_endpoint_is_allowed(
			buildings,
			terrain,
			altitude,
			behind,
			current_height,
			direction, map_edge
		)
		and _bridge_endpoint_is_allowed(
			buildings,
			terrain,
			altitude,
			far_bank,
			current_height,
			(direction + 2) & 3, map_edge
		)
	)


static func _bridge_endpoint_is_allowed(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	anchor: Vector2i,
	bridge_height: int,
	required_slope_direction: int,
	map_edge: int = 128,
) -> bool:
	if not _section_is_bridge_clear(buildings, anchor, map_edge):
		return false

	var endpoint_height := HighwayGeometry._section_altitude(terrain, altitude, anchor, map_edge)

	if endpoint_height < bridge_height or endpoint_height > bridge_height + 1:
		return false

	var terrain_shape := HighwayGeometry.terrain_section_shape(
		buildings, terrain, altitude, anchor, map_edge
	)

	if terrain_shape == INVALID_TERRAIN_SHAPE:
		return false

	return (
		endpoint_height != bridge_height
		or (terrain_shape & (1 << required_slope_direction)) != 0
	)


static func _section_is_bridge_clear(
	buildings: PackedByteArray, anchor: Vector2i,
	map_edge: int = 128,
) -> bool:
	if not HighwayGeometry._anchor_is_in_bounds(anchor, map_edge):
		return false

	for offset in [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
	]:
		var point: Vector2i = anchor + offset

		if int(buildings[point.x * map_edge + point.y]) > SMALL_PARK:
			return false

	return true


static func bridge_terrain_code(
	terrain: PackedByteArray, anchor: Vector2i,
	map_edge: int = 128,
) -> int:
	if not HighwayGeometry._anchor_is_in_bounds(anchor, map_edge):
		return 0x0f00

	var result := 0

	for offset in [
		Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 1), Vector2i.ZERO,
	]:
		var point: Vector2i = anchor + offset
		var terrain_id := int(terrain[point.x * map_edge + point.y])
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
	rotation: int,
	map_edge: int = 128,
) -> Dictionary:
	var start: Vector2i = plan.start
	var direction := int(plan.direction)
	var span_length := int(plan.span_length)
	var bridge_height := HighwayGeometry._section_altitude(terrain, altitude, start, map_edge)
	var endpoint_sections: Array[Vector2i] = []

	if bridge_type == BRIDGE_REINFORCED:
		var behind: Vector2i = start - DIRECTIONS[direction] * 2
		var behind_kind := (
			direction & 1
			if bridge_height - HighwayGeometry._section_altitude(terrain, altitude, behind, map_edge) == -1
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
			rotation, map_edge
		)
		endpoint_sections.append(behind)
		var far_bank: Vector2i = start + DIRECTIONS[direction] * span_length * 2
		var far_kind := (
			direction & 1
			if bridge_height - HighwayGeometry._section_altitude(terrain, altitude, far_bank, map_edge) == -1
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
			rotation, map_edge
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
				rotation, map_edge
			)
		else:
			_write_normal_bridge_section(
				buildings, zones, misc, anchor, direction, map_edge
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
	rotation: int,
	map_edge: int = 128,
) -> void:
	var zone_types := PackedByteArray()

	for offset in [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
	]:
		var point: Vector2i = anchor + offset
		zone_types.append(zones[point.x * map_edge + point.y] & 0x0f)

	HighwayPlacement._write_section_kind(
		buildings, terrain, zones, altitude, misc, anchor, kind, rotation, map_edge
	)

	for offset_index in zone_types.size():
		var offset: Vector2i = [
			Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
		][offset_index]
		var point: Vector2i = anchor + offset
		var index := point.x * map_edge + point.y
		zones[index] = (zones[index] & 0xf0) | zone_types[offset_index]


static func _write_normal_bridge_section(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	direction: int,
	map_edge: int = 128,
) -> void:
	var tile_id := STRAIGHT_FIRST + (direction & 1)

	for offset in [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
	]:
		var point: Vector2i = anchor + offset
		var index := point.x * map_edge + point.y
		NetworkState.replace_building(buildings, zones, misc, index, tile_id)
		zones[index] |= 0xf0


static func _write_reinforced_bridge_section(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	kind: int,
	direction: int,
	rotation: int,
	map_edge: int = 128,
) -> void:
	var offsets := [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
	]
	var zone_types := PackedByteArray()

	for offset in offsets:
		var point: Vector2i = anchor + offset
		var index := point.x * map_edge + point.y
		zone_types.append(zones[index] & 0x0f)
		NetworkState.replace_building(
			buildings, zones, misc, index, 0x5d + kind
		)

		if (direction & 1) == 0:
			flags[index] &= ~0x02 & 0xff
		else:
			flags[index] |= 0x02

	BuildingSites.set_corners(
		zones, Rect2i(anchor, Vector2i(2, 2)), 2, rotation, map_edge
	)

	for offset_index in offsets.size():
		var point: Vector2i = anchor + offsets[offset_index]
		var index := point.x * map_edge + point.y
		zones[index] = (zones[index] & 0xf0) | zone_types[offset_index]
