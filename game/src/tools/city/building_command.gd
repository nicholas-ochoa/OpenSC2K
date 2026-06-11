class_name BuildingCommand
extends BuildingConstants



static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return BuildingSites.supports_tool(group_index, subtool_index)


static func tile_for_tool(group_index: int, subtool_index: int) -> int:
	return BuildingSites.tile_for_tool(group_index, subtool_index)


# the pointer isn't the footprint origin for the bigger buildings
static func footprint(selected: Vector2i, area: int) -> Rect2i:
	return BuildingSites.footprint(selected, area)


static func preview_valid(city: CityState, group: int, subtool: int, point: Vector2i) -> bool:
	return BuildingSites.preview_valid(city, group, subtool, point)


static func preview_error(city: CityState, group: int, subtool: int, point: Vector2i) -> String:
	return BuildingSites.preview_error(city, group, subtool, point)


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	selected: Vector2i,
	lfsr_random: SimLfsrRandom,
	process_random: SimRandom,
	australian_locale := false
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if not supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool does not place a shared building"}

	if not Availability.is_available(city, group_index, subtool_index):
		return {"ok": false, "error": "tool is not available in this city"}

	if lfsr_random == null:
		return {"ok": false, "error": "LFSR random state is required"}

	if process_random == null:
		return {"ok": false, "error": "process random state is required"}

	var tool := ToolCatalog.tool(group_index, subtool_index)
	var cost := int(tool.cost)

	if cost != 0 and city.funds() < cost:
		return {"ok": false, "error": "insufficient funds", "cost": cost}

	var area := int(tool.area)
	var site := footprint(selected, area)

	var old_payloads := _city_payloads(city)

	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}

	var changed_payloads := _duplicate_payloads(old_payloads)
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var flags: PackedByteArray = changed_payloads.XBIT
	var underground: PackedByteArray = changed_payloads.XUND
	var text_overlays: PackedByteArray = changed_payloads.XTXT
	var labels: PackedByteArray = changed_payloads.XLAB
	var microsims: PackedByteArray = changed_payloads.XMIC
	var misc: PackedByteArray = changed_payloads.MISC
	var tile_id := tile_for_tool(group_index, subtool_index)

	var lfsr_state_before := lfsr_random.state
	var process_random_state_before := process_random.state

	if NUISANCE_TILES.has(tile_id):
		var residential_tiles := _count_nearby_residential(zones, selected, area, map_edge)

		if lfsr_random.next_mod(200) < residential_tiles:
			return {
				"ok": false,
				"error": "residents rejected this site",
				"cost": cost,
				"residential_tiles": residential_tiles,
				"resident_objection": true,
				"lfsr_advanced": lfsr_random.state != lfsr_state_before,
				"sound_events": [SOUND_NUISANCE],
				"notice_bitmap_id": NUISANCE_BITMAP_ID,
				"notice_string_id": NUISANCE_STRING_ID,
			}

	if not _footprint_is_in_bounds(site, area, map_edge):
		return {
			"ok": false,
			"error": "building does not fit inside the map",
			"cost": cost,
			"lfsr_advanced": lfsr_random.state != lfsr_state_before,
		}

	var site_check := _check_site(buildings, terrain, zones, flags, site, tile_id, map_edge)

	if not site_check.ok:
		return {
			"ok": false,
			"error": site_check.error,
			"cost": cost,
			"lfsr_advanced": lfsr_random.state != lfsr_state_before,
		}

	var overlay_id := _provision_microsim(
		microsims,
		labels,
		text_overlays,
		tile_id,
		city.current_year(),
		process_random,
		misc,
		australian_locale
	)

	var placed_flags := FLAG_PIPED if tile_id == SMALL_PARK or tile_id == BIG_PARK else STRUCTURE_FLAGS
	var tile_indices := PackedInt32Array()

	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var index := x * map_edge + y
			_update_building_count(misc, zones[index] & 0x0f, buildings[index], tile_id, map_edge)
			buildings[index] = tile_id
			zones[index] = 0
			flags[index] = (flags[index] & 0x1f) | placed_flags

			if overlay_id != 0:
				OverlayData.write(text_overlays, index, overlay_id)

			tile_indices.append(index)

	_set_corners(zones, site, area, city.compass_rotation(), map_edge)

	if tile_id == STATUE:
		flags[selected.x * map_edge + selected.y] &= ~FLAG_POWERABLE & 0xff
	elif tile_id == WATER_PUMP:
		_place_pipe(underground, terrain, zones, flags, misc, selected, map_edge)
	elif tile_id == SUBWAY_STATION:
		_place_subway_station(underground, terrain, zones, flags, misc, selected, map_edge)

	if BUDGET_CURRENT.has(tile_id):
		var budget_offset: int = MISC_BUDGETS + int(BUDGET_CURRENT[tile_id]) * BUDGET_RECORD_SIZE
		_write_u32_be(misc, budget_offset, _read_u32_be(misc, budget_offset) + 1)

	if group_index == 5 and subtool_index < 4:
		var reward_mask := Availability.rebuild_reward_mask(misc)
		_write_u32_be(
			misc,
			Availability.MISC_GRANTED_REWARDS,
			reward_mask & ~(1 << subtool_index)
		)

	_write_u32_be(misc, MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()

	for chunk_id in ["XBLD", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not _apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		lfsr_random.state = lfsr_state_before
		process_random.state = process_random_state_before

		return {"ok": false, "error": "cannot store building changes"}

	var immediate_power_refresh := false
	var immediate_water_refresh := false

	if _read_u32_be(misc, MISC_NORMAL_POPULATION) < IMMEDIATE_UTILITY_POPULATION_LIMIT:
		var selected_index := city.index_of(selected.x, selected.y)

		if selected_index >= 0 and city.tile_flags[selected_index] & FLAG_POWERABLE:
			var power_result := Power.run(city, process_random)

			if not power_result.ok:
				_restore_payloads(city, old_payloads)
				lfsr_random.state = lfsr_state_before
				process_random.state = process_random_state_before

				return {"ok": false, "error": "cannot refresh power after placement"}

			immediate_power_refresh = true

		if selected_index >= 0 and city.tile_flags[selected_index] & FLAG_PIPED:
			var water_result := Water.run(city)

			if not water_result.ok:
				_restore_payloads(city, old_payloads)
				lfsr_random.state = lfsr_state_before
				process_random.state = process_random_state_before

				return {"ok": false, "error": "cannot refresh water after placement"}

			immediate_water_refresh = true

	if immediate_power_refresh or immediate_water_refresh:
		changed_payloads = _city_payloads(city)

		if changed_payloads.is_empty():
			_restore_payloads(city, old_payloads)
			lfsr_random.state = lfsr_state_before
			process_random.state = process_random_state_before

			return {"ok": false, "error": "cannot capture utility changes"}

		changed_ids.clear()

		for chunk_id in changed_payloads:
			if changed_payloads[chunk_id] != old_payloads[chunk_id]:
				changed_ids.append(chunk_id)

	return {
		"ok": true,
		"command_type": "building",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"tile_id": tile_id,
		"site": site,
		"tile_indices": tile_indices,
		"cost": cost,
		"overlay_id": overlay_id,
		"changed_ids": changed_ids,
		"old_payloads": old_payloads,
		"new_payloads": changed_payloads,
		"lfsr_state_before": lfsr_state_before,
		"lfsr_state_after": lfsr_random.state,
		"process_random_state_before": process_random_state_before,
		"process_random_state_after": process_random.state,
		"immediate_power_refresh": immediate_power_refresh,
		"immediate_water_refresh": immediate_water_refresh,
		"stadium_team_selection_required": tile_id == STADIUM and overlay_id != 0,
		"error": "",
	}


static func stadium_team_choices(city: CityState) -> PackedInt32Array:
	return BuildingFacilities.stadium_team_choices(city)


static func stadium_team_name(city: CityState, team_index: int) -> String:
	return BuildingFacilities.stadium_team_name(city, team_index)


static func assign_stadium_team(
	city: CityState,
	command: Dictionary,
	team_index: int,
	team_name: String
) -> Dictionary:
	return BuildingFacilities.assign_stadium_team(city, command, team_index, team_name)


static func undo(
	city: CityState,
	command: Dictionary,
	lfsr_random: SimLfsrRandom,
	process_random: SimRandom
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if not command.get("ok", false) or command.get("command_type", "") != "building":
		return {"ok": false, "error": "building command is invalid"}

	if lfsr_random == null:
		return {"ok": false, "error": "LFSR random state is required"}

	if process_random == null:
		return {"ok": false, "error": "process random state is required"}

	if lfsr_random.state != int(command.get("lfsr_state_after", -1)):
		return {"ok": false, "error": "LFSR state changed after this building command"}

	if process_random.state != int(command.get("process_random_state_after", -1)):
		return {"ok": false, "error": "process random state changed after this building command"}

	var changed_ids: PackedStringArray = command.get("changed_ids", PackedStringArray())
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})

	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return {"ok": false, "error": "city changed after this building command"}

	if not _apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore building changes"}

	lfsr_random.state = int(command.lfsr_state_before)
	process_random.state = int(command.process_random_state_before)
	var indices: PackedInt32Array = command.get("tile_indices", PackedInt32Array())

	return {"ok": true, "restored_tiles": indices.size(), "error": ""}


static func _footprint_is_in_bounds(site: Rect2i, area: int, map_edge: int = 128) -> bool:
	return BuildingSites._footprint_is_in_bounds(site, area, map_edge)


static func _check_site(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	site: Rect2i,
	tile_id: int,
	map_edge: int = 128,
) -> Dictionary:
	return BuildingSites._check_site(buildings, terrain, zones, flags, site, tile_id, map_edge)


static func _count_nearby_residential(
	zones: PackedByteArray, selected: Vector2i, area: int,
	map_edge: int = 128,
) -> int:
	return BuildingSites._count_nearby_residential(zones, selected, area, map_edge)


static func _provision_microsim(
	microsims: PackedByteArray,
	labels: PackedByteArray,
	text_overlays: PackedByteArray,
	tile_id: int,
	current_year: int,
	process_random,
	misc := PackedByteArray(),
	australian_locale := false,
	scurk_place_mode := false
) -> int:
	return BuildingFacilities._provision_microsim(
		microsims, labels, text_overlays, tile_id, current_year, process_random, misc, australian_locale,
		scurk_place_mode
	)


static func _initialize_microsim(
	microsims: PackedByteArray,
	misc: PackedByteArray,
	record_id: int,
	tile_id: int,
	current_year: int,
	process_random,
	australian_locale: bool,
	scurk_place_mode: bool,
	map_edge: int = 128
) -> void:
	BuildingFacilities._initialize_microsim(
		microsims, misc, record_id, tile_id, current_year, process_random, australian_locale, scurk_place_mode,
		map_edge
	)


static func _population_cap(misc: PackedByteArray, maximum: int, divisor: int, map_edge: int = 128) -> int:
	return BuildingFacilities._population_cap(misc, maximum, divisor, map_edge)


static func _divide_toward_zero(value: int, divisor: int) -> int:
	return BuildingFacilities._divide_toward_zero(value, divisor)


static func _to_i16(value: int) -> int:
	return BuildingFacilities._to_i16(value)


static func _write_label(labels: PackedByteArray, label_id: int, value: String) -> void:
	BuildingFacilities._write_label(labels, label_id, value)


static func _read_u16_be(data: PackedByteArray, offset: int) -> int:
	return BuildingState._read_u16_be(data, offset)


static func _write_u16_be(data: PackedByteArray, offset: int, value: int) -> void:
	BuildingState._write_u16_be(data, offset, value)


# The zone and building corner flags share one byte.
static func _set_corners(zones: PackedByteArray, site: Rect2i, area: int, rotation: int, map_edge: int = 128) -> void:
	BuildingSites._set_corners(zones, site, area, rotation, map_edge)


static func _place_pipe(
	underground: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	var index := point.x * map_edge + point.y
	var old_tile := int(underground[index])

	if (old_tile >= UNDER_PIPE_FIRST and old_tile <= UNDER_PIPE_LAST) or old_tile == UNDER_PIPE_SUBWAY_LR or old_tile == UNDER_PIPE_SUBWAY_TB:
		return

	var new_tile := -1

	if old_tile == 0:
		new_tile = UNDER_PIPE_FIRST
	elif old_tile == 1:
		new_tile = UNDER_PIPE_SUBWAY_LR
	elif old_tile == 2:
		new_tile = UNDER_PIPE_SUBWAY_TB
	else:
		return

	_replace_underground(underground, zones, misc, index, new_tile)
	flags[index] |= FLAG_PIPED
	_retile_neighborhood(underground, terrain, point, true, map_edge)


# connect and retile the subway before replacing the center with the station
static func _place_subway_station(
	underground: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	var index := point.x * map_edge + point.y
	var old_tile := int(underground[index])
	var inserted_tile := -1

	if old_tile == 0:
		inserted_tile = UNDER_SUBWAY_FIRST
	elif old_tile == UNDER_PIPE_FIRST:
		inserted_tile = UNDER_PIPE_SUBWAY_TB
	elif old_tile == UNDER_PIPE_FIRST + 1:
		inserted_tile = UNDER_PIPE_SUBWAY_LR

	if inserted_tile >= 0:
		_replace_underground(underground, zones, misc, index, inserted_tile)
		_retile_neighborhood(underground, terrain, point, false, map_edge)

	_replace_underground(underground, zones, misc, index, UNDER_SUBWAY_ENTRANCE)
	flags[index] &= ~FLAG_PIPED & 0xff


static func _replace_underground(
	underground: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	var old_tile := int(underground[index])

	if old_tile == new_tile:
		return

	if (zones[index] & 0x0f) != MILITARY_ZONE:
		var count := _read_u32_be(misc, MISC_SUBWAY_COUNT)

		if _is_subway_tile(old_tile):
			count = (count - 1) & (0xffff if underground.size() == 16384 else 0xffffffff)

		if _is_subway_tile(new_tile):
			count = (count + 1) & (0xffff if underground.size() == 16384 else 0xffffffff)

		_write_u32_be(misc, MISC_SUBWAY_COUNT, count)

	underground[index] = new_tile


static func _is_subway_tile(tile_id: int) -> bool:
	return (
		(tile_id > 0 and tile_id < UNDER_PIPE_FIRST)
		or tile_id == UNDER_PIPE_SUBWAY_LR
		or tile_id == UNDER_PIPE_SUBWAY_TB
		or tile_id == UNDER_UNKNOWN
		or tile_id == UNDER_SUBWAY_ENTRANCE
	)


static func _retile_neighborhood(
	underground: PackedByteArray, terrain: PackedByteArray, point: Vector2i, pipes: bool,
	map_edge: int = 128,
) -> void:
	_retile_underground(underground, terrain, point, pipes, map_edge)

	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var near: Vector2i = point + offset

		if near.x >= 0 and near.x < map_edge and near.y >= 0 and near.y < map_edge:
			_retile_underground(underground, terrain, near, pipes, map_edge)


static func _retile_underground(
	underground: PackedByteArray, terrain: PackedByteArray, point: Vector2i, pipes: bool,
	map_edge: int = 128,
) -> void:
	var index := point.x * map_edge + point.y
	var current := int(underground[index])

	if pipes:
		if current < UNDER_PIPE_FIRST or current > UNDER_PIPE_LAST:
			return
	else:
		if current < UNDER_SUBWAY_FIRST or current > UNDER_SUBWAY_LAST:
			return

	var terrain_shape := int(terrain[index]) & 0x0f if terrain[index] <= 0x30 else 0
	var base := UNDER_PIPE_FIRST if pipes else UNDER_SUBWAY_FIRST

	if FORCED_TERRAIN_MASKS.has(terrain_shape):
		underground[index] = base + FORCED_TERRAIN_SHAPES[terrain_shape]

		return

	var connections := 0

	if point.x > 0:
		var west_index := (point.x - 1) * map_edge + point.y

		if _underground_connects(underground[west_index], pipes) and _allows_horizontal(terrain[west_index]):
			connections |= 8

	if point.x < (map_edge - 1):
		var east_index := (point.x + 1) * map_edge + point.y

		if _underground_connects(underground[east_index], pipes) and _allows_horizontal(terrain[east_index]):
			connections |= 2

	if point.y > 0:
		var north_index := point.x * map_edge + point.y - 1

		if _underground_connects(underground[north_index], pipes) and _allows_vertical(terrain[north_index]):
			connections |= 1

	if point.y < (map_edge - 1):
		var south_index := point.x * map_edge + point.y + 1

		if _underground_connects(underground[south_index], pipes) and _allows_vertical(terrain[south_index]):
			connections |= 4

	if pipes and connections == 0:
		connections = 15

	underground[index] = base + NETWORK_SHAPES[connections]


static func _underground_connects(tile_id: int, pipes: bool) -> bool:
	if pipes:
		return (
			(tile_id >= UNDER_PIPE_FIRST and tile_id <= UNDER_PIPE_LAST)
			or tile_id == UNDER_PIPE_SUBWAY_LR
			or tile_id == UNDER_PIPE_SUBWAY_TB
		)

	return (
		(tile_id >= UNDER_SUBWAY_FIRST and tile_id <= UNDER_SUBWAY_LAST)
		or tile_id == UNDER_SUBWAY_ENTRANCE
		or tile_id == UNDER_PIPE_SUBWAY_LR
		or tile_id == UNDER_PIPE_SUBWAY_TB
		or tile_id == UNDER_UNKNOWN
	)


static func _allows_vertical(terrain_id: int) -> bool:
	return NetworkTerrainRules.allows_connection(terrain_id, 0)


static func _allows_horizontal(terrain_id: int) -> bool:
	return NetworkTerrainRules.allows_connection(terrain_id, 1)


static func _update_building_count(
	misc: PackedByteArray, zone: int, old_building: int, new_building: int, map_edge: int = 128
) -> void:
	BuildingState._update_building_count(misc, zone, old_building, new_building, map_edge)


static func _city_payloads(city: CityState) -> Dictionary:
	return BuildingState._city_payloads(city)


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary:
	return BuildingState._duplicate_payloads(payloads)


static func _restore_payloads(city: CityState, old_payloads: Dictionary) -> bool:
	return BuildingState._restore_payloads(city, old_payloads)


static func _apply_payloads(
	city: CityState, chunk_ids: PackedStringArray, payloads: Dictionary, rollback: Dictionary
) -> bool:
	return BuildingState._apply_payloads(city, chunk_ids, payloads, rollback)


static func _refresh_city_arrays(city: CityState) -> void:
	BuildingState._refresh_city_arrays(city)


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return BuildingState._read_u32_be(data, offset)


static func _read_i32_be(data: PackedByteArray, offset: int) -> int:
	return BuildingState._read_i32_be(data, offset)


static func _write_u32_be(data: PackedByteArray, offset: int, value: int) -> void:
	BuildingState._write_u32_be(data, offset, value)
