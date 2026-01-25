class_name SubwayToRailCommand
extends RefCounted

const GROUP_RAIL := 7
const SUBTOOL_CONNECTION := 4
const CONNECTOR_FIRST := 0x6c
const RADIOACTIVITY := 0x05
const MAX_CLEAR_BUILDING := 0x0c
const FLAG_PIPED := 0x20
const DIRECTIONS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_RAIL and subtool_index == SUBTOOL_CONNECTION


static func apply(
	city: CityState, group_index: int, subtool_index: int, point: Vector2i, preview_only := false
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool is not a subway-to-rail connection"}
	var index := city.index_of(point.x, point.y)
	if index < 0:
		return {"ok": false, "error": "connection is outside the city"}
	if city.buildings[index] > MAX_CLEAR_BUILDING or city.buildings[index] == RADIOACTIVITY:
		return {"ok": false, "error": "connection site contains a protected building"}
	if city.terrain[index] != 0:
		return {"ok": false, "error": "connection site is not clear terrain"}

	var neighbor := Vector2i(-1, -1)
	var orientation := -1
	for direction in 4:
		var checked: Vector2i = point + DIRECTIONS[direction]
		if city.index_of(checked.x, checked.y) >= 0 and _surface_rail_connects(city.building_id(checked.x, checked.y)):
			neighbor = checked
			orientation = direction
			break
	if orientation < 0:
		for direction in 4:
			var checked: Vector2i = point + DIRECTIONS[direction]
			if city.index_of(checked.x, checked.y) >= 0 and _subway_connects(city.underground_id(checked.x, checked.y)):
				neighbor = checked
				orientation = (direction + 2) & 3
				break
	if orientation < 0:
		return {"ok": false, "error": "connection requires an adjacent rail or subway"}

	if preview_only:
		return {"ok": true}
	var old_payloads := BuildingCommand._city_payloads(city)
	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}
	var changed_payloads := BuildingCommand._duplicate_payloads(old_payloads)
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var underground: PackedByteArray = changed_payloads.XUND
	var flags: PackedByteArray = changed_payloads.XBIT
	var misc: PackedByteArray = changed_payloads.MISC

	BuildingCommand._place_subway_station(
		underground, terrain, zones, flags, misc, point, map_edge
	)
	var tile_id := CONNECTOR_FIRST + orientation
	NetworkCommand._replace_building(buildings, zones, misc, index, tile_id)
	zones[index] |= 0xf0
	NetworkCommand._retile_surface(
		buildings,
		terrain,
		zones,
		flags,
		misc,
		neighbor,
		NetworkCommand.MODE_RAIL,
		changed_payloads.XTXT, map_edge
	)

	var changed_ids := PackedStringArray()
	for chunk_id in ["XBLD", "XZON", "XUND", "XBIT", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)
	if not BuildingCommand._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		return {"ok": false, "error": "cannot store subway-to-rail changes"}
	return {
		"ok": true,
		"command_type": "subway_to_rail",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"tile_id": tile_id,
		"orientation": orientation,
		"neighbor": neighbor,
		"tile_indices": PackedInt32Array([index]),
		"listed_cost": int(ToolCatalog.tool(group_index, subtool_index).cost),
		"cost": 0,
		"changed_ids": changed_ids,
		"old_payloads": old_payloads,
		"new_payloads": changed_payloads,
		"error": "",
	}


static func undo(city: CityState, command: Dictionary) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not command.get("ok", false) or command.get("command_type", "") != "subway_to_rail":
		return {"ok": false, "error": "subway-to-rail command is invalid"}
	var changed_ids: PackedStringArray = command.get("changed_ids", PackedStringArray())
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})
	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return {"ok": false, "error": "city changed after this subway-to-rail command"}
	if not BuildingCommand._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore subway-to-rail changes"}
	return {"ok": true, "restored_tiles": 1, "error": ""}


static func _surface_rail_connects(tile_id: int) -> bool:
	return (
		(tile_id >= 0x2c and tile_id <= 0x3e)
		or (tile_id >= 0x45 and tile_id <= 0x48)
		or (tile_id >= 0x6c and tile_id <= 0x6f)
	)


static func _subway_connects(tile_id: int) -> bool:
	return (
		(tile_id >= 0x01 and tile_id <= 0x0f)
		or tile_id == 0x1f
		or tile_id == 0x20
		or tile_id == 0x22
		or tile_id == 0x23
	)
