class_name TunnelCommand
extends RefCounted

const GROUP_ROADS := 6
const SUBTOOL_TUNNEL := 2
const MAX_CLEAR_BUILDING := 0x0d
const RADIOACTIVITY := 0x05
const FIRST_ENTRANCE := 0x3f
const TUNNEL_MASK := 0x7c00
const ALTITUDE_DATA_MASK := 0x03ff
const ONE_TUNNEL_LEVEL := 0x0400
const CONFIRMATION_UNSELECTED := -1
const CONFIRMATION_CANCELLED := 0
const CONFIRMATION_CONFIRMED := 1
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_ROADS and subtool_index == SUBTOOL_TUNNEL


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	confirmation_choice := CONFIRMATION_UNSELECTED,
	free_mode := false
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool is not a tunnel"}
	var start_index := city.index_of(start.x, start.y)
	if start_index < 0:
		return {"ok": false, "error": "tunnel entrance is outside the city"}
	if city.buildings[start_index] > MAX_CLEAR_BUILDING or city.buildings[start_index] == RADIOACTIVITY:
		return {"ok": false, "error": "tunnel entrance contains a protected building"}
	if city.underground[start_index] != 0:
		return {"ok": false, "error": "tunnel entrance conflicts with an underground network"}

	var start_terrain := int(city.terrain[start_index])
	if start_terrain < 1 or start_terrain > 4:
		return {"ok": false, "error": "tunnel entrance requires a cardinal slope"}
	var direction_index := (start_terrain + 2) & 3
	var direction: Vector2i = DIRECTIONS[direction_index]
	var start_altitude := city.land_altitude(start.x, start.y)
	var current := start

	while true:
		if current.x < 0 or current.x > 126 or current.y < 0 or current.y > 126:
			return {"ok": false, "error": "tunnel cannot reach an opposite slope"}
		var current_index := city.index_of(current.x, current.y)
		var altitude_word := int(city.altitude_words[current_index])
		if (altitude_word & TUNNEL_MASK) != 0:
			return {"ok": false, "error": "tunnel path conflicts with another tunnel"}
		var altitude_difference := (altitude_word & 0x1f) - start_altitude
		if altitude_difference > 30:
			return {"ok": false, "error": "tunnel path is too deep"}
		if altitude_difference == 1 and _underground_blocks_tunnel(city.underground[current_index]):
			return {"ok": false, "error": "tunnel path conflicts with an underground network"}
		current += direction
		var next_index := city.index_of(current.x, current.y)
		if next_index < 0 or city.land_altitude(current.x, current.y) <= start_altitude:
			break

	var finish := current
	var finish_index := city.index_of(finish.x, finish.y)
	var expected_terrain := ((start_terrain + 1) & 3) + 1
	if finish_index < 0 or city.terrain[finish_index] != expected_terrain:
		return {"ok": false, "error": "tunnel cannot reach an opposite slope"}

	var points: Array[Vector2i] = []
	current = start
	while true:
		points.append(current)
		if current == finish:
			break
		current += direction
	var listed_cost := (
		points.size() * int(ToolCatalog.tool(group_index, subtool_index).cost)
	)
	var cost := 0 if free_mode else listed_cost
	if confirmation_choice == CONFIRMATION_UNSELECTED:
		return {
			"ok": false,
			"confirmation_required": true,
			"start": start,
			"finish": finish,
			"points": points,
			"cost": cost,
			"listed_cost": listed_cost,
			"free_mode": free_mode,
			"error": "tunnel construction confirmation is required",
		}
	if confirmation_choice == CONFIRMATION_CANCELLED:
		return {
			"ok": false,
			"cancelled": true,
			"start": start,
			"finish": finish,
			"points": points,
			"cost": cost,
			"listed_cost": listed_cost,
			"free_mode": free_mode,
			"error": "tunnel construction canceled",
		}
	if confirmation_choice != CONFIRMATION_CONFIRMED:
		return {"ok": false, "error": "tunnel confirmation choice is invalid"}
	if city.funds() < cost:
		return {"ok": false, "error": "insufficient funds", "cost": cost}

	var old_payloads := NetworkCommand._city_payloads(city)
	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}
	var changed_payloads := NetworkCommand._duplicate_payloads(old_payloads)
	var altitude: PackedByteArray = changed_payloads.ALTM
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var flags: PackedByteArray = changed_payloads.XBIT
	var text_overlays: PackedByteArray = changed_payloads.XTXT
	var misc: PackedByteArray = changed_payloads.MISC

	var start_tile := start_terrain + 0x3e
	var finish_tile := ((start_terrain + 1) & 3) + FIRST_ENTRANCE
	NetworkCommand._replace_building(buildings, zones, misc, start_index, start_tile)
	_set_tunnel_level(altitude, start_index, 1)
	_retile_adjacent_roads(
		buildings, terrain, zones, flags, misc, start, text_overlays
	)
	for point_index in range(1, points.size() - 1):
		var point := points[point_index]
		var index := point.x * CityState.MAP_SIZE + point.y
		_set_tunnel_level(altitude, index, city.land_altitude(point.x, point.y) - start_altitude + 1)
	NetworkCommand._replace_building(buildings, zones, misc, finish_index, finish_tile)
	_set_tunnel_level(altitude, finish_index, 1)
	_retile_adjacent_roads(
		buildings, terrain, zones, flags, misc, finish, text_overlays
	)
	BuildingCommand._write_u32_be(misc, BuildingCommand.MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()
	for chunk_id in ["ALTM", "XBLD", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)
	if not NetworkCommand._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		return {"ok": false, "error": "cannot store tunnel changes"}
	return {
		"ok": true,
		"command_type": "tunnel",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"start": start,
		"finish": finish,
		"points": points,
		"start_tile": start_tile,
		"finish_tile": finish_tile,
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
	if not command.get("ok", false) or command.get("command_type", "") != "tunnel":
		return {"ok": false, "error": "tunnel command is invalid"}
	var changed_ids: PackedStringArray = command.get("changed_ids", PackedStringArray())
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})
	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return {"ok": false, "error": "city changed after this tunnel command"}
	if not NetworkCommand._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore tunnel changes"}
	var points: Array = command.get("points", [])
	return {"ok": true, "restored_tiles": points.size(), "error": ""}


static func _underground_blocks_tunnel(tile_id: int) -> bool:
	return (
		(tile_id >= 0x01 and tile_id <= 0x20)
		or tile_id == 0x22
		or tile_id == 0x23
	)


static func _set_tunnel_level(altitude: PackedByteArray, index: int, level: int) -> void:
	var offset := index * 2
	var word := (altitude[offset] << 8) | altitude[offset + 1]
	word = (word & ALTITUDE_DATA_MASK) | ((level & 0x1f) << 10)
	altitude[offset] = (word >> 8) & 0xff
	altitude[offset + 1] = word & 0xff


static func _retile_adjacent_roads(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	text_overlays := PackedByteArray()
) -> void:
	for offset in DIRECTIONS:
		var neighbor: Vector2i = point + offset
		if neighbor.x >= 0 and neighbor.x < 128 and neighbor.y >= 0 and neighbor.y < 128:
			NetworkCommand._retile_surface(
				buildings,
				terrain,
				zones,
				flags,
				misc,
				neighbor,
				NetworkCommand.MODE_ROAD,
				text_overlays
			)
