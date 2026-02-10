class_name OnrampCommand
extends RefCounted

const GROUP_ROADS := 6
const SUBTOOL_ONRAMP := 3
const MAX_CLEAR_BUILDING := 0x0d
const RADIOACTIVITY := 0x05
const HIGHWAY_FIRST := 0x49
const HIGHWAY_LAST := 0x50
const ROAD_FIRST := 0x1d
const ROAD_LAST := 0x2b
const ROAD_INTERSECTION := 0x2b
const RAMP_FIRST := 0x5d
const FLAG_FLIPPED := 0x02

# neighbor masks use north, east, south, and west bits. each value selects
# the road directions that can connect to the adjacent highway arrangement
const ROAD_MASK_BY_HIGHWAY_MASK := [0, 10, 5, 12, 10, 0, 9, 0, 5, 6, 0, 0, 3, 0, 0, 0]
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_ROADS and subtool_index == SUBTOOL_ONRAMP


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	point: Vector2i,
	free_mode := false,
	preview_only := false
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool is not an on-ramp"}
	var index := city.index_of(point.x, point.y)
	if index < 0:
		return {"ok": false, "error": "on-ramp is outside the city"}
	if city.buildings[index] > MAX_CLEAR_BUILDING or city.buildings[index] == RADIOACTIVITY:
		return {"ok": false, "error": "on-ramp site contains a protected building"}
	if city.terrain[index] != 0:
		return {"ok": false, "error": "on-ramp site is not clear terrain"}

	var highway_mask := 0
	var road_mask := 0
	for direction in 4:
		var neighbor: Vector2i = point + DIRECTIONS[direction]
		var neighbor_index := city.index_of(neighbor.x, neighbor.y)
		if neighbor_index < 0:
			continue
		var tile_id := int(city.buildings[neighbor_index])
		if tile_id >= HIGHWAY_FIRST and tile_id <= HIGHWAY_LAST:
			highway_mask |= 1 << direction
		if tile_id >= ROAD_FIRST and tile_id <= ROAD_LAST:
			road_mask |= 1 << direction
	road_mask &= ROAD_MASK_BY_HIGHWAY_MASK[highway_mask]
	if road_mask == 0:
		return {"ok": false, "error": "on-ramp requires perpendicular highway and road neighbors"}

	var listed_cost := int(ToolCatalog.tool(group_index, subtool_index).cost)
	var cost := 0 if free_mode else listed_cost
	if city.funds() < cost:
		return {"ok": false, "error": "insufficient funds", "cost": cost}

	var road_direction := 0
	while road_direction < 4 and (road_mask & (1 << road_direction)) == 0:
		road_direction += 1
	var ramp_tile := _ramp_tile(highway_mask, road_direction)
	var road_point: Vector2i = point + DIRECTIONS[road_direction]
	var road_index := city.index_of(road_point.x, road_point.y)

	if preview_only:
		return {"ok": true}
	var old_payloads := BuildingCommand._city_payloads(city)
	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}
	var changed_payloads := BuildingCommand._duplicate_payloads(old_payloads)
	var buildings: PackedByteArray = changed_payloads.XBLD
	var zones: PackedByteArray = changed_payloads.XZON
	var flags: PackedByteArray = changed_payloads.XBIT
	var misc: PackedByteArray = changed_payloads.MISC

	NetworkCommand._replace_building(buildings, zones, misc, road_index, ROAD_INTERSECTION)
	NetworkCommand._replace_building(buildings, zones, misc, index, ramp_tile)
	if road_direction == 0 or road_direction == 2:
		flags[index] |= FLAG_FLIPPED
	BuildingCommand._write_u32_be(misc, BuildingCommand.MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()
	for chunk_id in ["XBLD", "XBIT", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)
	if not BuildingCommand._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		return {"ok": false, "error": "cannot store on-ramp changes"}
	return {
		"ok": true,
		"command_type": "onramp",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"tile_id": ramp_tile,
		"road_direction": road_direction,
		"road_point": road_point,
		"cost": cost,
		"listed_cost": listed_cost,
		"free_mode": free_mode,
		"changed_ids": changed_ids,
		"old_payloads": old_payloads,
		"new_payloads": changed_payloads,
		"error": "",
	}


static func undo(city: CityState, command: Dictionary) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not command.get("ok", false) or command.get("command_type", "") != "onramp":
		return {"ok": false, "error": "on-ramp command is invalid"}
	var changed_ids: PackedStringArray = command.get("changed_ids", PackedStringArray())
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})
	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return {"ok": false, "error": "city changed after this on-ramp command"}
	if not BuildingCommand._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore on-ramp changes"}
	return {"ok": true, "restored_tiles": 2, "error": ""}


static func _ramp_tile(highway_mask: int, road_direction: int) -> int:
	match road_direction:
		0:
			return 0x5f if (highway_mask & 2) else 0x5e
		1:
			return RAMP_FIRST if (highway_mask & 1) else 0x60
		2:
			return 0x60 if (highway_mask & 2) else RAMP_FIRST
		_:
			return 0x5e if (highway_mask & 1) else 0x5f
