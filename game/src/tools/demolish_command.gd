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
const FLAG_FLIPPED := 0x02
const FLAG_WATER := 0x04
const HIGHWAY_STRAIGHT_FIRST := 0x49
const HIGHWAY_STRAIGHT_LAST := 0x50
const BRIDGE_FIRST := 0x51
const BRIDGE_LAST := 0x5c
const HIGHWAY_SHAPED_FIRST := 0x61
const HIGHWAY_SHAPED_LAST := 0x69
const REINFORCED_BRIDGE_FIRST := 0x6a
const REINFORCED_BRIDGE_LAST := 0x6b
const TUNNEL_FIRST := 0x3f
const TUNNEL_LAST := 0x42
const RUNWAY_FIRST := 0xdd
const RUNWAY_LAST := 0xde
const PIER_FIRST := 0xdf
const PIER_LAST := 0xe0
const SUBWAY_STATION := 0xe9
const TUNNEL_MASK := 0x7c00

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
	var altitude_chunk := city.document.find_chunk("ALTM")
	if altitude_chunk == null or altitude_chunk.decoded_payload.size() != CityState.TILE_COUNT * 2:
		return {"ok": false, "error": "required altitude data is missing or invalid"}
	old_payloads.ALTM = altitude_chunk.decoded_payload.duplicate()
	var changed_payloads := BuildingCommand._duplicate_payloads(old_payloads)
	var altitude: PackedByteArray = changed_payloads.ALTM
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
			altitude,
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
			return {"ok": false, "error": "reinforced-bridge or malformed-network demolition is not implemented"}
		return {"ok": false, "error": "no eligible tiles changed"}
	BuildingCommand._write_u32_be(misc, BuildingCommand.MISC_FUNDS, city.funds() - total_cost)

	var changed_ids := PackedStringArray()
	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)
	if not BuildingCommand._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		random.state = random_state_before
		return {"ok": false, "error": "cannot store demolition changes"}
	_refresh_altitude(city, changed_payloads.ALTM)
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
	_refresh_altitude(city, old_payloads.ALTM)
	random.state = int(command.random_state_before)
	var indices: PackedInt32Array = command.get("tile_indices", PackedInt32Array())
	return {"ok": true, "restored_tiles": indices.size(), "error": ""}


static func _demolish_point(
	city: CityState,
	altitude: PackedByteArray,
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
	if tile_id >= TUNNEL_FIRST and tile_id <= TUNNEL_LAST:
		return _demolish_tunnel(
			altitude, buildings, terrain, zones, flags, misc, point, tile_id
		)
	if tile_id >= BRIDGE_FIRST and tile_id <= BRIDGE_LAST:
		return _demolish_bridge(
			altitude, buildings, terrain, zones, underground, flags, misc, point
		)
	if tile_id >= RUNWAY_FIRST and tile_id <= PIER_LAST:
		return _demolish_transport_component(
			buildings, terrain, zones, underground, flags, misc, point, tile_id, random
		)
	if _is_highway_tile(tile_id):
		return _demolish_highway_section(
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
			random,
			city.compass_rotation()
		)
	if _requires_special_demolition(tile_id):
		return {"changed": false, "specialized": true}
	var had_structure := tile_id >= 0x0d
	var was_water := (flags[index] & FLAG_WATER) != 0
	if tile_id == 0:
		if terrain[index] < 0x30 and not was_water:
			return {"changed": false}
		_remove_surface_water(altitude, buildings, terrain, zones, flags, misc, point)
		return {"changed": true, "indices": PackedInt32Array([index])}

	if tile_id < 0x0d:
		if tile_id >= 0x06 and random.next_u15() % 20 == 0:
			return {"changed": true, "easter_event": true, "indices": PackedInt32Array()}
		NetworkCommand._replace_building(buildings, zones, misc, index, 0)
		if terrain[index] >= 0x30 or was_water:
			_remove_surface_water(altitude, buildings, terrain, zones, flags, misc, point)
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
	if terrain[index] >= 0x30 or was_water:
		if had_structure and was_water:
			_retile_surface_water(terrain, flags, point, true)
		else:
			_remove_surface_water(altitude, buildings, terrain, zones, flags, misc, point)
	return {"changed": true, "indices": indices}


static func _requires_special_demolition(tile_id: int) -> bool:
	return tile_id >= REINFORCED_BRIDGE_FIRST and tile_id <= REINFORCED_BRIDGE_LAST


static func _is_highway_tile(tile_id: int) -> bool:
	return (
		(tile_id >= HIGHWAY_STRAIGHT_FIRST and tile_id <= HIGHWAY_STRAIGHT_LAST)
		or (tile_id >= HIGHWAY_SHAPED_FIRST and tile_id <= HIGHWAY_SHAPED_LAST)
	)


static func _demolish_tunnel(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	start: Vector2i,
	tile_id: int
) -> Dictionary:
	var direction: Vector2i = [
		Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)
	][tile_id - TUNNEL_FIRST]
	var points: Array[Vector2i] = [start]
	var current := start + direction
	while current.x >= 0 and current.x < 128 and current.y >= 0 and current.y < 128:
		points.append(current)
		var current_id := int(buildings[current.x * CityState.MAP_SIZE + current.y])
		if current_id >= TUNNEL_FIRST and current_id <= TUNNEL_LAST:
			break
		current += direction
	if points.size() < 2 or current.x < 0 or current.x >= 128 or current.y < 0 or current.y >= 128:
		return {"changed": false, "specialized": true}

	for point in points:
		var index := point.x * CityState.MAP_SIZE + point.y
		_clear_tunnel_level(altitude, index)
	for entrance in [points[0], points[-1]]:
		var entrance_index: int = entrance.x * CityState.MAP_SIZE + entrance.y
		NetworkCommand._replace_building(buildings, zones, misc, entrance_index, 0)
		zones[entrance_index] &= 0x0f
		_retile_adjacent_roads(buildings, terrain, zones, flags, misc, entrance)
	var indices := PackedInt32Array()
	for point in points:
		indices.append(point.x * CityState.MAP_SIZE + point.y)
	return {"changed": true, "indices": indices}


static func _demolish_transport_component(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	start: Vector2i,
	tile_id: int,
	random: SimRandom
) -> Dictionary:
	var first := RUNWAY_FIRST if tile_id <= RUNWAY_LAST else PIER_FIRST
	var last := RUNWAY_LAST if tile_id <= RUNWAY_LAST else PIER_LAST
	var make_rubble := first == RUNWAY_FIRST
	var stack: Array[Vector2i] = [start]
	var visited := {}
	var component: Array[Vector2i] = []
	while not stack.is_empty():
		var point: Vector2i = stack.pop_back()
		if visited.has(point):
			continue
		visited[point] = true
		var index := point.x * CityState.MAP_SIZE + point.y
		var current_id := int(buildings[index])
		if current_id < first or current_id > last:
			continue
		component.append(point)
		for offset in DIRECTIONS:
			var neighbor: Vector2i = point + offset
			if neighbor.x >= 0 and neighbor.x < 128 and neighbor.y >= 0 and neighbor.y < 128:
				stack.append(neighbor)

	var indices := PackedInt32Array()
	for point in component:
		var index := point.x * CityState.MAP_SIZE + point.y
		var replacement := 1 + (random.next_u15() & 3) if make_rubble else 0
		NetworkCommand._replace_building(buildings, zones, misc, index, replacement)
		zones[index] &= 0x0f
		flags[index] &= FLAG_CLEAR_AFTER_STRUCTURE
		indices.append(index)
	_retile_after_demolition(buildings, terrain, zones, underground, flags, misc, component)
	return {"changed": not component.is_empty(), "indices": indices}


static func _demolish_highway_section(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	misc: PackedByteArray,
	selected: Vector2i,
	random: SimRandom,
	rotation: int
) -> Dictionary:
	var anchor := Vector2i(selected.x & ~1, selected.y & ~1)
	if not HighwayCommand._anchor_is_in_bounds(anchor):
		return {"changed": false, "specialized": true}
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		if not _is_highway_tile(buildings[point.x * CityState.MAP_SIZE + point.y]):
			return {"changed": false, "specialized": true}

	var points: Array[Vector2i] = []
	var indices := PackedInt32Array()
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * CityState.MAP_SIZE + point.y
		var replacement := 1 + (random.next_u15() & 3) if terrain[index] == 0 else 0
		NetworkCommand._replace_building(buildings, zones, misc, index, replacement)
		zones[index] &= 0x0f
		flags[index] &= FLAG_CLEAR_AFTER_STRUCTURE
		_release_overlay(text_overlays, labels, microsims, index)
		points.append(point)
		indices.append(index)
	_retile_after_demolition(buildings, terrain, zones, underground, flags, misc, points)

	var adjacent_sections: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var adjacent: Vector2i = anchor + direction * 2
		if HighwayCommand._anchor_is_in_bounds(adjacent) and HighwayCommand._section_exists(buildings, adjacent):
			adjacent_sections.append(adjacent)
	if not adjacent_sections.is_empty():
		HighwayCommand._retile_affected_sections(buildings, zones, misc, adjacent_sections, rotation)
	return {"changed": true, "indices": indices}


static func _demolish_bridge(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	selected: Vector2i
) -> Dictionary:
	var selected_index := selected.x * CityState.MAP_SIZE + selected.y
	var direction := Vector2i(1, 0) if (flags[selected_index] & FLAG_FLIPPED) != 0 else Vector2i(0, 1)
	var first := selected
	while _point_is_in_bounds(first - direction):
		var previous := first - direction
		var previous_id := int(buildings[previous.x * CityState.MAP_SIZE + previous.y])
		if previous_id < BRIDGE_FIRST or previous_id > BRIDGE_LAST:
			break
		first = previous
	var finish := selected
	while _point_is_in_bounds(finish + direction):
		var next := finish + direction
		var next_id := int(buildings[next.x * CityState.MAP_SIZE + next.y])
		if next_id < BRIDGE_FIRST or next_id > BRIDGE_LAST:
			break
		finish = next

	var points: Array[Vector2i] = []
	var indices := PackedInt32Array()
	var current := first
	while true:
		var index := current.x * CityState.MAP_SIZE + current.y
		NetworkCommand._replace_building(buildings, zones, misc, index, 0)
		zones[index] &= 0x0f
		flags[index] &= ~FLAG_FLIPPED & 0xff
		points.append(current)
		indices.append(index)
		if current == finish:
			break
		current += direction

	for bank in [first - direction, finish + direction]:
		if not _point_is_in_bounds(bank):
			continue
		var bank_index: int = bank.x * CityState.MAP_SIZE + bank.y
		if (flags[bank_index] & FLAG_WATER) != 0:
			continue
		NetworkCommand._replace_building(buildings, zones, misc, bank_index, 0)
		var land := _land_altitude(altitude, bank_index)
		_set_land_altitude(altitude, bank_index, maxi(0, land - 1))
		flags[bank_index] |= FLAG_WATER
		flags[bank_index] &= ~FLAG_FLIPPED & 0xff
		TerrainCommand._retile_region(
			altitude,
			buildings,
			terrain,
			zones,
			flags,
			misc,
			PackedInt32Array([bank_index]),
			BuildingCommand._read_u32_be(misc, 0x0e40) & 0x1f
		)
		points.append(bank)
		indices.append(bank_index)
	_retile_surface_water(terrain, flags, selected, true)
	_retile_after_demolition(buildings, terrain, zones, underground, flags, misc, points)
	return {"changed": true, "indices": indices}


static func _remove_surface_water(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i
) -> void:
	var index := point.x * CityState.MAP_SIZE + point.y
	if terrain[index] == 0x3e:
		TerrainCommand._retile_region(
			altitude,
			buildings,
			terrain,
			zones,
			flags,
			misc,
			PackedInt32Array([index]),
			BuildingCommand._read_u32_be(misc, 0x0e40) & 0x1f
		)
	else:
		terrain[index] = 0
	flags[index] &= ~FLAG_WATER & 0xff
	_retile_surface_water(terrain, flags, point, false)


static func _retile_surface_water(
	terrain: PackedByteArray, flags: PackedByteArray, point: Vector2i, include_center: bool
) -> void:
	for x in range(maxi(0, point.x - 1), mini(128, point.x + 2)):
		for y in range(maxi(0, point.y - 1), mini(128, point.y + 2)):
			if not include_center and x == point.x and y == point.y:
				continue
			var index := x * CityState.MAP_SIZE + y
			if (flags[index] & FLAG_WATER) == 0:
				continue
			var shape := LandscapeCommand._water_shape(flags, x, y)
			var transition := LandscapeCommand._water_transition(terrain[index], shape)
			if not transition.early_return:
				terrain[index] = transition.value


static func _retile_adjacent_roads(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i
) -> void:
	for offset in DIRECTIONS:
		var neighbor: Vector2i = point + offset
		if _point_is_in_bounds(neighbor):
			NetworkCommand._retile_surface(
				buildings, terrain, zones, flags, misc, neighbor, NetworkCommand.MODE_ROAD
			)


static func _clear_tunnel_level(altitude: PackedByteArray, index: int) -> void:
	var offset := index * 2
	var word := (altitude[offset] << 8) | altitude[offset + 1]
	word &= ~TUNNEL_MASK & 0xffff
	altitude[offset] = (word >> 8) & 0xff
	altitude[offset + 1] = word & 0xff


static func _land_altitude(altitude: PackedByteArray, index: int) -> int:
	return altitude[index * 2 + 1] & 0x1f


static func _set_land_altitude(altitude: PackedByteArray, index: int, value: int) -> void:
	var offset := index * 2
	altitude[offset + 1] = (altitude[offset + 1] & 0xe0) | (value & 0x1f)


static func _point_is_in_bounds(point: Vector2i) -> bool:
	return point.x >= 0 and point.x < 128 and point.y >= 0 and point.y < 128


static func _refresh_altitude(city: CityState, altitude: PackedByteArray) -> void:
	for index in CityState.TILE_COUNT:
		city.altitude_words[index] = (altitude[index * 2] << 8) | altitude[index * 2 + 1]


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
