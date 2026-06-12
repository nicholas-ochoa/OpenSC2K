class_name BuildingEdit
extends BuildingConstants



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

	if not BuildingSites.supports_tool(group_index, subtool_index):
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
	var site := BuildingSites.footprint(selected, area)

	var old_payloads := BuildingState._city_payloads(city)

	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}

	var changed_payloads := BuildingState._duplicate_payloads(old_payloads)
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var flags: PackedByteArray = changed_payloads.XBIT
	var underground: PackedByteArray = changed_payloads.XUND
	var text_overlays: PackedByteArray = changed_payloads.XTXT
	var labels: PackedByteArray = changed_payloads.XLAB
	var microsims: PackedByteArray = changed_payloads.XMIC
	var misc: PackedByteArray = changed_payloads.MISC
	var tile_id := BuildingSites.tile_for_tool(group_index, subtool_index)

	var lfsr_state_before := lfsr_random.state
	var process_random_state_before := process_random.state

	if NUISANCE_TILES.has(tile_id):
		var residential_tiles := BuildingSites._count_nearby_residential(zones, selected, area, map_edge)

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

	if not BuildingSites._footprint_is_in_bounds(site, area, map_edge):
		return {
			"ok": false,
			"error": "building does not fit inside the map",
			"cost": cost,
			"lfsr_advanced": lfsr_random.state != lfsr_state_before,
		}

	var site_check := BuildingSites._check_site(buildings, terrain, zones, flags, site, tile_id, map_edge)

	if not site_check.ok:
		return {
			"ok": false,
			"error": site_check.error,
			"cost": cost,
			"lfsr_advanced": lfsr_random.state != lfsr_state_before,
		}

	var overlay_id := BuildingFacilities._provision_microsim(
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
			BuildingState._update_building_count(misc, zones[index] & 0x0f, buildings[index], tile_id, map_edge)
			buildings[index] = tile_id
			zones[index] = 0
			flags[index] = (flags[index] & 0x1f) | placed_flags

			if overlay_id != 0:
				OverlayData.write(text_overlays, index, overlay_id)

			tile_indices.append(index)

	BuildingSites._set_corners(zones, site, area, city.compass_rotation(), map_edge)

	if tile_id == STATUE:
		flags[selected.x * map_edge + selected.y] &= ~FLAG_POWERABLE & 0xff
	elif tile_id == WATER_PUMP:
		BuildingUnderground._place_pipe(underground, terrain, zones, flags, misc, selected, map_edge)
	elif tile_id == SUBWAY_STATION:
		BuildingUnderground._place_subway_station(underground, terrain, zones, flags, misc, selected, map_edge)

	if BUDGET_CURRENT.has(tile_id):
		var budget_offset: int = MISC_BUDGETS + int(BUDGET_CURRENT[tile_id]) * BUDGET_RECORD_SIZE
		BuildingState._write_u32_be(misc, budget_offset, BuildingState._read_u32_be(misc, budget_offset) + 1)

	if group_index == 5 and subtool_index < 4:
		var reward_mask := Availability.rebuild_reward_mask(misc)
		BuildingState._write_u32_be(
			misc,
			Availability.MISC_GRANTED_REWARDS,
			reward_mask & ~(1 << subtool_index)
		)

	BuildingState._write_u32_be(misc, MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()

	for chunk_id in ["XBLD", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not BuildingState._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		lfsr_random.state = lfsr_state_before
		process_random.state = process_random_state_before

		return {"ok": false, "error": "cannot store building changes"}

	var immediate_power_refresh := false
	var immediate_water_refresh := false

	if BuildingState._read_u32_be(misc, MISC_NORMAL_POPULATION) < IMMEDIATE_UTILITY_POPULATION_LIMIT:
		var selected_index := city.index_of(selected.x, selected.y)

		if selected_index >= 0 and city.tile_flags[selected_index] & FLAG_POWERABLE:
			var power_result := Power.run(city, process_random)

			if not power_result.ok:
				BuildingState._restore_payloads(city, old_payloads)
				lfsr_random.state = lfsr_state_before
				process_random.state = process_random_state_before

				return {"ok": false, "error": "cannot refresh power after placement"}

			immediate_power_refresh = true

		if selected_index >= 0 and city.tile_flags[selected_index] & FLAG_PIPED:
			var water_result := Water.run(city)

			if not water_result.ok:
				BuildingState._restore_payloads(city, old_payloads)
				lfsr_random.state = lfsr_state_before
				process_random.state = process_random_state_before

				return {"ok": false, "error": "cannot refresh water after placement"}

			immediate_water_refresh = true

	if immediate_power_refresh or immediate_water_refresh:
		changed_payloads = BuildingState._city_payloads(city)

		if changed_payloads.is_empty():
			BuildingState._restore_payloads(city, old_payloads)
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

	if not BuildingState._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore building changes"}

	lfsr_random.state = int(command.lfsr_state_before)
	process_random.state = int(command.process_random_state_before)
	var indices: PackedInt32Array = command.get("tile_indices", PackedInt32Array())

	return {"ok": true, "restored_tiles": indices.size(), "error": ""}
