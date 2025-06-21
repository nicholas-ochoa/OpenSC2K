class_name DemolishCommand
extends RefCounted

const GROUP_BULLDOZER := 0
const SUBTOOL_DEMOLISH := 0
const RADIOACTIVITY := 0x05
const MILITARY_ZONE := 0x07
const DYNAMIC_LABEL_FIRST := 61
const DYNAMIC_LABEL_LAST := 200
const MICROSIM_LABEL_BASE := 51
const PROTECTED_CONNECTION_LABEL := 0xff
const FLAG_CLEAR_AFTER_STRUCTURE := 0x3d
const SPECIAL_HIGHWAY_FIRST := 0x49
const SPECIAL_HIGHWAY_LAST := 0x5c
const SPECIAL_SHAPED_HIGHWAY_FIRST := 0x61
const SPECIAL_SHAPED_HIGHWAY_LAST := 0x6b
const TUNNEL_FIRST := 0x3f
const TUNNEL_LAST := 0x42
const FIRE_FIRST := 0xdd
const FIRE_LAST := 0xe0
const SUBWAY_STATION := 0xe9

const CORNER_BOTTOM_LEFT := [0x10, 0x20, 0x40, 0x80]
const CORNER_BOTTOM_RIGHT := [0x20, 0x40, 0x80, 0x10]
const CORNER_TOP_LEFT := [0x40, 0x80, 0x10, 0x20]
const CORNER_TOP_RIGHT := [0x80, 0x10, 0x20, 0x40]
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_BULLDOZER and subtool_index == SUBTOOL_DEMOLISH


static func apply_path(
	city: CityState,
	group_index: int,
	subtool_index: int,
	points: Array[Vector2i],
	random: SimRandom
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool is not the demolish tool"}
	if random == null:
		return {"ok": false, "error": "random state is required"}
	if points.is_empty():
		return {"ok": false, "error": "demolish path is empty"}

	var old_payloads := BuildingCommand._city_payloads(city)
	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}
	var changed_payloads := BuildingCommand._duplicate_payloads(old_payloads)
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var underground: PackedByteArray = changed_payloads.XUND
	var flags: PackedByteArray = changed_payloads.XBIT
	var text_overlays: PackedByteArray = changed_payloads.XTXT
	var labels: PackedByteArray = changed_payloads.XLAB
	var microsims: PackedByteArray = changed_payloads.XMIC
	var misc: PackedByteArray = changed_payloads.MISC
	var cost_per_action := int(ToolCatalog.tool(group_index, subtool_index).cost)
	var total_cost := 0
	var action_count := 0
	var changed_indices := PackedInt32Array()
	var skipped_specialized := 0
	var skipped_insufficient := 0
	var easter_events := 0
	var random_state_before := random.state

	for point in points:
		if city.index_of(point.x, point.y) < 0:
			continue
		if city.funds() - total_cost < cost_per_action:
			skipped_insufficient += 1
			continue
		var result := _demolish_point(
			city,
			buildings,
			terrain,
			zones,
			underground,
			flags,
			text_overlays,
			labels,
			microsims,
			misc,
			point,
			random
		)
		if result.get("specialized", false):
			skipped_specialized += 1
			continue
		if not result.get("changed", false):
			continue
		action_count += 1
		total_cost += cost_per_action
		if result.get("easter_event", false):
			easter_events += 1
		for index in result.get("indices", PackedInt32Array()):
			if not changed_indices.has(index):
				changed_indices.append(index)

	if action_count == 0:
		random.state = random_state_before
		if skipped_insufficient > 0:
			return {"ok": false, "error": "insufficient funds", "cost": cost_per_action}
		if skipped_specialized > 0:
			return {"ok": false, "error": "specialized highway, bridge, tunnel, or fire demolition is not implemented"}
		return {"ok": false, "error": "no eligible tiles changed"}
	BuildingCommand._write_u32_be(misc, BuildingCommand.MISC_FUNDS, city.funds() - total_cost)

	var changed_ids := PackedStringArray()
	for chunk_id in ["XBLD", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)
	if not BuildingCommand._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		random.state = random_state_before
		return {"ok": false, "error": "cannot store demolition changes"}
	return {
		"ok": true,
		"command_type": "demolish",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"tile_indices": changed_indices,
		"action_count": action_count,
		"cost": total_cost,
		"skipped_specialized": skipped_specialized,
		"skipped_insufficient": skipped_insufficient,
		"easter_events": easter_events,
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
	if not command.get("ok", false) or command.get("command_type", "") != "demolish":
		return {"ok": false, "error": "demolish command is invalid"}
	if random == null:
		return {"ok": false, "error": "random state is required"}
	if random.state != int(command.get("random_state_after", -1)):
		return {"ok": false, "error": "random state changed after this demolish command"}
	var changed_ids: PackedStringArray = command.get("changed_ids", PackedStringArray())
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})
	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return {"ok": false, "error": "city changed after this demolish command"}
	if not BuildingCommand._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore demolition changes"}
	random.state = int(command.random_state_before)
	var indices: PackedInt32Array = command.get("tile_indices", PackedInt32Array())
	return {"ok": true, "restored_tiles": indices.size(), "error": ""}


static func _demolish_point(
	city: CityState,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	random: SimRandom
) -> Dictionary:
	var index := point.x * CityState.MAP_SIZE + point.y
	var tile_id := int(buildings[index])
	if (zones[index] & 0x0f) == MILITARY_ZONE or tile_id == RADIOACTIVITY:
		return {"changed": false}
	if text_overlays[index] == PROTECTED_CONNECTION_LABEL:
		return {"changed": false}
	if terrain[index] >= 0x30:
		return {"changed": false, "specialized": true}
	if tile_id == 0:
		return {"changed": false}
	if _requires_special_demolition(tile_id):
		return {"changed": false, "specialized": true}

	if tile_id < 0x0d:
		if tile_id >= 0x06 and random.next_u15() % 20 == 0:
			return {"changed": true, "easter_event": true, "indices": PackedInt32Array()}
		NetworkCommand._replace_building(buildings, zones, misc, index, 0)
		_retile_after_demolition(buildings, terrain, zones, underground, flags, misc, [point])
		return {"changed": true, "indices": PackedInt32Array([index])}

	var area := _building_area(tile_id)
	var site := _find_building_site(buildings, zones, point, tile_id, area, city.compass_rotation())
	if site.size == Vector2i.ZERO:
		return {"changed": false}
	var indices := PackedInt32Array()
	var changed_points: Array[Vector2i] = []
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var changed_index := x * CityState.MAP_SIZE + y
			var rubble := 1 + (random.next_u15() & 3) if terrain[changed_index] == 0 else 0
			NetworkCommand._replace_building(buildings, zones, misc, changed_index, rubble)
			zones[changed_index] &= 0x0f
			flags[changed_index] &= FLAG_CLEAR_AFTER_STRUCTURE
			_release_overlay(text_overlays, labels, microsims, changed_index)
			indices.append(changed_index)
			changed_points.append(Vector2i(x, y))
	if tile_id == SUBWAY_STATION or (tile_id >= 0x6c and tile_id <= 0x70):
		underground[index] = 0
	_retile_after_demolition(
		buildings, terrain, zones, underground, flags, misc, changed_points
	)
	return {"changed": true, "indices": indices}


static func _requires_special_demolition(tile_id: int) -> bool:
	return (
		(tile_id >= SPECIAL_HIGHWAY_FIRST and tile_id <= SPECIAL_HIGHWAY_LAST)
		or (tile_id >= SPECIAL_SHAPED_HIGHWAY_FIRST and tile_id <= SPECIAL_SHAPED_HIGHWAY_LAST)
		or (tile_id >= TUNNEL_FIRST and tile_id <= TUNNEL_LAST)
		or (tile_id >= FIRE_FIRST and tile_id <= FIRE_LAST)
	)


static func _building_area(tile_id: int) -> int:
	if tile_id < 0x70:
		return 1
	if tile_id <= 0x8b:
		return 1
	if tile_id <= 0xad:
		return 2
	if tile_id <= 0xc5:
		return 3
	if tile_id <= 0xc8:
		return 1
	if tile_id <= 0xcf:
		return 4
	if tile_id <= 0xd6:
		return 3
	if tile_id <= 0xda:
		return 4
	if tile_id <= 0xea:
		return 1
	if tile_id <= 0xf7:
		return 2
	if tile_id <= 0xfa:
		return 3
	return 4


static func _find_building_site(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	selected: Vector2i,
	tile_id: int,
	area: int,
	rotation: int
) -> Rect2i:
	if area == 1:
		return Rect2i(selected, Vector2i.ONE)
	for origin_x in range(selected.x - area + 1, selected.x + 1):
		for origin_y in range(selected.y - area + 1, selected.y + 1):
			var site := Rect2i(origin_x, origin_y, area, area)
			if site.position.x < 0 or site.position.y < 0 or site.end.x > 128 or site.end.y > 128:
				continue
			if _site_matches(buildings, zones, site, tile_id, rotation):
				return site
	return Rect2i()


static func _site_matches(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	site: Rect2i,
	tile_id: int,
	rotation: int
) -> bool:
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			if buildings[x * CityState.MAP_SIZE + y] != tile_id:
				return false
	var far := site.end - Vector2i.ONE
	var view := rotation & 3
	return (
		(zones[site.position.x * CityState.MAP_SIZE + site.position.y] & 0xf0) == CORNER_BOTTOM_LEFT[view]
		and (zones[far.x * CityState.MAP_SIZE + site.position.y] & 0xf0) == CORNER_BOTTOM_RIGHT[view]
		and (zones[far.x * CityState.MAP_SIZE + far.y] & 0xf0) == CORNER_TOP_LEFT[view]
		and (zones[site.position.x * CityState.MAP_SIZE + far.y] & 0xf0) == CORNER_TOP_RIGHT[view]
	)


static func _release_overlay(
	text_overlays: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	index: int
) -> void:
	var label_id := int(text_overlays[index])
	if label_id == 0:
		return
	if label_id < 201 or label_id == 250:
		text_overlays[index] = 0
	if label_id >= 1 and label_id <= 50:
		labels[label_id * CityState.LABEL_RECORD_SIZE] = 0
	elif label_id >= DYNAMIC_LABEL_FIRST and label_id <= DYNAMIC_LABEL_LAST:
		var record_id := label_id - MICROSIM_LABEL_BASE
		microsims[record_id * CityState.MICROSIM_RECORD_SIZE] = 0
		labels[label_id * CityState.LABEL_RECORD_SIZE] = 0


static func _retile_after_demolition(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	points: Array[Vector2i]
) -> void:
	for point in points:
		for offset in DIRECTIONS:
			var neighbor: Vector2i = point + offset
			if neighbor.x < 0 or neighbor.x >= 128 or neighbor.y < 0 or neighbor.y >= 128:
				continue
			NetworkCommand._retile_surface(
				buildings, terrain, zones, flags, misc, neighbor, NetworkCommand.MODE_ROAD
			)
			NetworkCommand._retile_surface(
				buildings, terrain, zones, flags, misc, neighbor, NetworkCommand.MODE_RAIL
			)
			NetworkCommand._retile_surface(
				buildings, terrain, zones, flags, misc, neighbor, NetworkCommand.MODE_POWER
			)
		BuildingCommand._retile_neighborhood(underground, terrain, point, false)
		BuildingCommand._retile_neighborhood(underground, terrain, point, true)
