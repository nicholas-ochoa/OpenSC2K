class_name ZoneCommand
extends RefCounted

const GROUP_PORTS := 8
const GROUP_BULLDOZER := 0
const SUBTOOL_DEZONE := 4
const GROUP_RESIDENTIAL := 9
const GROUP_COMMERCIAL := 10
const GROUP_INDUSTRIAL := 11
const FLAG_WATER := 0x04
const FIRST_ROAD := 0x1d
const FIRST_DEVELOPED_BUILDING := 0x70
const RADIOACTIVITY := 0x05
const SMALL_PARK := 0x0d
const MILITARY_ZONE := 0x07
const TERRAIN_REQUIRES_SURCHARGE := [
	false, false, false, false, false, true, true, true,
	true, true, true, true, true, false, false, false,
]

const ZONE_TYPES := {
	GROUP_PORTS: [9, 8],
	GROUP_RESIDENTIAL: [1, 2],
	GROUP_COMMERCIAL: [3, 4],
	GROUP_INDUSTRIAL: [5, 6],
}


static func apply_rectangle(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	finish: Vector2i,
	dragged := true,
	free_mode := false,
	zone_type_override := -1
) -> ZoneEditResult:
	var preview := preview_rectangle(
		city,
		group_index,
		subtool_index,
		start,
		finish,
		dragged,
		free_mode,
		zone_type_override
	)

	if not preview.get("ok", false):
		return ZoneEditResult.rejected(preview.error)

	var zone_type := int(preview.zone_type)
	var minimum := Vector2i(mini(start.x, finish.x), mini(start.y, finish.y))
	var maximum := Vector2i(maxi(start.x, finish.x), maxi(start.y, finish.y))
	var changed := city.zones.duplicate()
	var changed_buildings := city.buildings.duplicate()
	var tile_indices := PackedInt32Array()
	var previous_values := PackedByteArray()
	var previous_buildings := PackedByteArray()

	for x in range(minimum.x, maximum.x + 1):
		for y in range(minimum.y, maximum.y + 1):
			var index := city.index_of(x, y)

			if not _tile_is_eligible(city, index):
				continue

			if (changed[index] & 0x0f) == zone_type:
				continue

			tile_indices.append(index)
			previous_values.append(changed[index])
			previous_buildings.append(changed_buildings[index])
			changed[index] = (changed[index] & 0xf0) | zone_type

			if zone_type == 0 and changed_buildings[index] > 0 and changed_buildings[index] < 5:
				changed_buildings[index] = 0

	var cost := int(preview.cost)

	if int(preview.changed_tiles) == 0 and cost == 0:
		return ZoneEditResult.rejected("no eligible tiles would change")

	var previous_funds := city.funds()

	if previous_funds < cost:
		return ZoneEditResult.rejected("insufficient funds", cost)

	if not city.replace_zones(changed):
		return ZoneEditResult.rejected("cannot store updated XZON data")

	if not city.replace_buildings(changed_buildings):
		city.replace_zones(_restore_values(changed, tile_indices, previous_values))

		return ZoneEditResult.rejected("cannot store updated XBLD data")

	if cost > 0 and not city.set_funds(previous_funds - cost):
		city.replace_zones(_restore_values(changed, tile_indices, previous_values))
		city.replace_buildings(
			_restore_values(changed_buildings, tile_indices, previous_buildings)
		)

		return ZoneEditResult.rejected("cannot store the updated city funds")

	var old_payloads := {
		"XZON": _restore_values(changed, tile_indices, previous_values),
		"XBLD": _restore_values(changed_buildings, tile_indices, previous_buildings),
		"MISC": city.document.find_chunk("MISC").decoded_payload.duplicate(),
	}

	if cost > 0:
		old_payloads.MISC = old_payloads.MISC.duplicate()
		_write_i32_be(old_payloads.MISC, 0x14, previous_funds)

	var new_payloads := {
		"XZON": city.document.find_chunk("XZON").decoded_payload.duplicate(),
		"XBLD": city.document.find_chunk("XBLD").decoded_payload.duplicate(),
		"MISC": city.document.find_chunk("MISC").decoded_payload.duplicate(),
	}
	var changed_ids := PackedStringArray()

	for chunk_id in ["XZON", "XBLD", "MISC"]:
		if old_payloads[chunk_id] != new_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	var result := ZoneEditResult.new()
	result.ok = true
	result.command_type = "zone"
	result.group_index = group_index
	result.subtool_index = subtool_index
	result.zone_type = zone_type
	result.dragged = dragged
	result.charged_tiles = int(preview.charged_tiles)
	result.terrain_surcharges = int(preview.terrain_surcharges)
	result.tile_indices = tile_indices
	result.previous_values = previous_values
	result.new_values = _values_at(changed, tile_indices)
	result.previous_buildings = previous_buildings
	result.new_buildings = _values_at(changed_buildings, tile_indices)
	result.previous_funds = previous_funds
	result.cost = cost
	result.listed_cost = int(preview.listed_cost)
	result.free_mode = free_mode
	result.changed_ids = changed_ids
	result.old_payloads = old_payloads
	result.new_payloads = new_payloads

	return result


static func preview_rectangle(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	finish: Vector2i,
	dragged := true,
	free_mode := false,
	zone_type_override := -1
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if not _point_is_valid(start, map_edge) or not _point_is_valid(finish, map_edge):
		return {"ok": false, "error": "zone rectangle is outside the city"}

	var tool := ToolCatalog.tool(group_index, subtool_index)
	var has_override := (
		free_mode and zone_type_override >= 1 and zone_type_override <= 9
	)
	var zone_type := (
		zone_type_override
		if has_override
		else _zone_type_for_tool(group_index, subtool_index)
	)

	if (tool.is_empty() and not has_override) or zone_type < 0:
		return {"ok": false, "error": "tool is not a zoning tool"}

	var start_index := city.index_of(start.x, start.y)

	if city.tile_flags[start_index] & FLAG_WATER:
		return {"ok": false, "error": "a zone selection cannot start on water"}

	if (
		city.buildings[start_index] == RADIOACTIVITY
		or (city.zones[start_index] & 0x0f) == MILITARY_ZONE
	):
		return {"ok": false, "error": "a zone selection cannot start on this tile"}

	var charged_tiles := 0
	var terrain_surcharges := 0
	var changed_tiles := 0

	if not dragged:
		charged_tiles = 1
		var terrain_id := int(city.terrain[start_index])

		if (
			terrain_id < 0x30
			and TERRAIN_REQUIRES_SURCHARGE[terrain_id & 0x0f]
		):
			terrain_surcharges = 1

		if (
			_tile_is_eligible(city, start_index)
			and (city.zones[start_index] & 0x0f) != zone_type
		):
			changed_tiles = 1
	else:
		var minimum := Vector2i(mini(start.x, finish.x), mini(start.y, finish.y))
		var maximum := Vector2i(maxi(start.x, finish.x), maxi(start.y, finish.y))

		for x in range(minimum.x, maximum.x + 1):
			for y in range(minimum.y, maximum.y + 1):
				var index := city.index_of(x, y)

				if not _tile_is_drag_price_eligible(city, index, zone_type):
					continue

				charged_tiles += 1

				if _tile_is_eligible(city, index):
					changed_tiles += 1

	var listed_cost := (
		charged_tiles * int(tool.get("cost", 0)) + terrain_surcharges * 25
	)
	var cost := 0 if free_mode else listed_cost

	return {
		"ok": true,
		"zone_type": zone_type,
		"dragged": dragged,
		"charged_tiles": charged_tiles,
		"changed_tiles": changed_tiles,
		"terrain_surcharges": terrain_surcharges,
		"cost": cost,
		"listed_cost": listed_cost,
		"affordable": free_mode or city.funds() >= cost,
		"free_mode": free_mode,
		"error": "",
	}


# undo also rejects a command of another family
static func undo(city: CityState, command: ZoneEditResult) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok:
		return EditCommandResult.failure("zone command is invalid")

	var indices := command.tile_indices
	var previous := command.previous_values
	var expected := command.new_values
	var previous_buildings := command.previous_buildings
	var expected_buildings := command.new_buildings

	if (
		indices.size() != previous.size()
		or indices.size() != expected.size()
		or indices.size() != previous_buildings.size()
		or indices.size() != expected_buildings.size()
	):
		return EditCommandResult.failure("zone undo data has the wrong size")

	for position in indices.size():
		if (
			city.zones[indices[position]] != expected[position]
			or city.buildings[indices[position]] != expected_buildings[position]
		):
			return EditCommandResult.failure("city changed after this zone command")

	var current := city.zones.duplicate()
	var current_buildings := city.buildings.duplicate()
	var restored := _restore_values(current, indices, previous)
	var restored_buildings := _restore_values(current_buildings, indices, previous_buildings)
	var current_funds := city.funds()

	if not city.replace_zones(restored):
		return EditCommandResult.failure("cannot restore XZON data")

	if not city.replace_buildings(restored_buildings):
		city.replace_zones(current)

		return EditCommandResult.failure("cannot restore XBLD data")

	if not city.set_funds(command.previous_funds):
		city.replace_zones(current)
		city.replace_buildings(current_buildings)
		city.set_funds(current_funds)

		return EditCommandResult.failure("cannot restore city funds")

	return EditCommandResult.undone(indices.size())


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return _zone_type_for_tool(group_index, subtool_index) >= 0


static func _zone_type_for_tool(group_index: int, subtool_index: int) -> int:
	if group_index == GROUP_BULLDOZER and subtool_index == SUBTOOL_DEZONE:
		return 0

	if not ZONE_TYPES.has(group_index):
		return -1

	var zone_types: Array = ZONE_TYPES[group_index]

	if subtool_index < 0 or subtool_index >= zone_types.size():
		return -1

	return zone_types[subtool_index]


static func _tile_is_eligible(city: CityState, index: int) -> bool:
	var building := city.buildings[index]

	return (
		not city.tile_flags[index] & FLAG_WATER
		and city.terrain[index] == 0
		and building < FIRST_ROAD
		and building < FIRST_DEVELOPED_BUILDING
		and building != RADIOACTIVITY
		and building != SMALL_PARK
		and (city.zones[index] & 0x0f) != MILITARY_ZONE
	)


static func _tile_is_drag_price_eligible(
	city: CityState, index: int, zone_type: int
) -> bool:
	var building := city.buildings[index]

	return (
		city.terrain[index] == 0
		and building < FIRST_ROAD
		and building != RADIOACTIVITY
		and building != SMALL_PARK
		and (city.zones[index] & 0x0f) != MILITARY_ZONE
		and (city.zones[index] & 0x0f) != zone_type
	)


static func _point_is_valid(point: Vector2i, map_edge: int = 128) -> bool:
	return point.x >= 0 and point.x < map_edge and point.y >= 0 and point.y < map_edge


static func _write_i32_be(data: PackedByteArray, offset: int, value: int) -> void:
	var encoded := value & 0xffffffff
	data[offset] = (encoded >> 24) & 0xff
	data[offset + 1] = (encoded >> 16) & 0xff
	data[offset + 2] = (encoded >> 8) & 0xff
	data[offset + 3] = encoded & 0xff


static func _restore_values(
	data: PackedByteArray, indices: PackedInt32Array, values: PackedByteArray
) -> PackedByteArray:
	var result := data.duplicate()

	for position in indices.size():
		result[indices[position]] = values[position]

	return result


static func _values_at(data: PackedByteArray, indices: PackedInt32Array) -> PackedByteArray:
	var result := PackedByteArray()

	for index in indices:
		result.append(data[index])

	return result
