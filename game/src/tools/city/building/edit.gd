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
) -> BuildingEditResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return BuildingEditResult.rejected("city is invalid")

	if not BuildingSites.supports_tool(group_index, subtool_index):
		return BuildingEditResult.rejected("tool does not place a shared building")

	if not Availability.is_available(city, group_index, subtool_index):
		return BuildingEditResult.rejected("tool is not available in this city")

	if lfsr_random == null:
		return BuildingEditResult.rejected("LFSR random state is required")

	if process_random == null:
		return BuildingEditResult.rejected("process random state is required")

	var tool := ToolCatalog.tool(group_index, subtool_index)
	var cost := int(tool.cost)

	if cost != 0 and city.funds() < cost:
		return BuildingEditResult.rejected("insufficient funds", cost)

	var area := int(tool.area)
	var site := BuildingSites.footprint(selected, area)

	var old_payloads := BuildingState._city_payloads(city)

	if old_payloads.is_empty():
		return BuildingEditResult.rejected("required city data is missing or invalid")

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
			var objection := BuildingEditResult.rejected("residents rejected this site", cost)
			objection.residential_tiles = residential_tiles
			objection.resident_objection = true
			objection.lfsr_advanced = lfsr_random.state != lfsr_state_before
			objection.sound_events = [SOUND_NUISANCE]
			objection.notice_bitmap_id = NUISANCE_BITMAP_ID
			objection.notice_string_id = NUISANCE_STRING_ID

			return objection

	if not BuildingSites._footprint_is_in_bounds(site, area, map_edge):
		var outside := BuildingEditResult.rejected("building does not fit inside the map", cost)
		outside.lfsr_advanced = lfsr_random.state != lfsr_state_before

		return outside

	var site_error := BuildingSites._site_error(buildings, terrain, zones, flags, site, tile_id, map_edge)

	if not site_error.is_empty():
		var blocked := BuildingEditResult.rejected(site_error, cost)
		blocked.lfsr_advanced = lfsr_random.state != lfsr_state_before

		return blocked

	var overlay_id := BuildingFacilities.provision_microsim(
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
			BuildingState.update_building_count(misc, zones[index] & Sc2ZoneLayout.TYPE_MASK, buildings[index], tile_id, map_edge)
			buildings[index] = tile_id
			zones[index] = 0
			flags[index] = (flags[index] & ~Sc2TileFlags.STRUCTURE_MASK & 0xff) | placed_flags

			if overlay_id != 0:
				OverlayData.write(text_overlays, index, overlay_id)

			tile_indices.append(index)

	BuildingSites.set_corners(zones, site, area, city.compass_rotation(), map_edge)

	if tile_id == STATUE:
		flags[selected.x * map_edge + selected.y] &= ~FLAG_POWERABLE & 0xff
	elif tile_id == WATER_PUMP:
		BuildingUnderground._place_pipe(underground, terrain, zones, flags, misc, selected, map_edge)
	elif tile_id == SUBWAY_STATION:
		BuildingUnderground._place_subway_station(underground, terrain, zones, flags, misc, selected, map_edge)

	if BUDGET_CATEGORY_BY_TILE.has(tile_id):
		var budget_offset: int = MISC_BUDGETS + int(BUDGET_CATEGORY_BY_TILE[tile_id]) * BUDGET_RECORD_SIZE
		BinaryData.write_u32_be(misc, budget_offset, BinaryData.read_u32_be(misc, budget_offset) + 1)

	if group_index == CityToolIds.Group.REWARDS and subtool_index < CityToolIds.Rewards.ARCOLOGIES:
		var reward_mask := Availability.rebuild_reward_mask(misc)
		BinaryData.write_u32_be(
			misc,
			Availability.MISC_GRANTED_REWARDS,
			reward_mask & ~(1 << subtool_index)
		)

	BinaryData.write_u32_be(misc, MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()

	for chunk_id in ["XBLD", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not BuildingState._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		lfsr_random.state = lfsr_state_before
		process_random.state = process_random_state_before

		return BuildingEditResult.rejected("cannot store building changes")

	var immediate_power_refresh := false
	var immediate_water_refresh := false

	if BinaryData.read_u32_be(misc, MISC_NORMAL_POPULATION) < IMMEDIATE_UTILITY_POPULATION_LIMIT:
		var selected_index := city.index_of(selected.x, selected.y)

		if selected_index >= 0 and city.tile_flags[selected_index] & FLAG_POWERABLE:
			var power_result := Power.run(city, process_random)

			if not power_result.ok:
				BuildingState._restore_payloads(city, old_payloads)
				lfsr_random.state = lfsr_state_before
				process_random.state = process_random_state_before

				return BuildingEditResult.rejected("cannot refresh power after placement")

			immediate_power_refresh = true

		if selected_index >= 0 and city.tile_flags[selected_index] & FLAG_PIPED:
			var water_result := Water.run(city)

			if not water_result.ok:
				BuildingState._restore_payloads(city, old_payloads)
				lfsr_random.state = lfsr_state_before
				process_random.state = process_random_state_before

				return BuildingEditResult.rejected("cannot refresh water after placement")

			immediate_water_refresh = true

	if immediate_power_refresh or immediate_water_refresh:
		changed_payloads = BuildingState._city_payloads(city)

		if changed_payloads.is_empty():
			BuildingState._restore_payloads(city, old_payloads)
			lfsr_random.state = lfsr_state_before
			process_random.state = process_random_state_before

			return BuildingEditResult.rejected("cannot capture utility changes")

		changed_ids.clear()

		for chunk_id in changed_payloads:
			if changed_payloads[chunk_id] != old_payloads[chunk_id]:
				changed_ids.append(chunk_id)

	var result := BuildingEditResult.new()
	result.ok = true
	result.command_type = "building"
	result.group_index = group_index
	result.subtool_index = subtool_index
	result.tile_id = tile_id
	result.site = site
	result.tile_indices = tile_indices
	result.cost = cost
	result.overlay_id = overlay_id
	result.changed_ids = changed_ids
	result.old_payloads = old_payloads
	result.new_payloads = changed_payloads
	result.lfsr_state_before = lfsr_state_before
	result.lfsr_state_after = lfsr_random.state
	result.tracks_random = true
	result.random_state_before = process_random_state_before
	result.random_state_after = process_random.state
	result.immediate_power_refresh = immediate_power_refresh
	result.immediate_water_refresh = immediate_water_refresh
	result.stadium_team_selection_required = tile_id == STADIUM and overlay_id != 0

	if not result.stadium_team_selection_required:
		result.retain_changed_payloads()

	return result


static func undo(
	city: CityState,
	command: BuildingEditResult,
	lfsr_random: SimLfsrRandom,
	process_random: SimRandom
) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != "building":
		return EditCommandResult.failure("building command is invalid")

	if lfsr_random == null:
		return EditCommandResult.failure("LFSR random state is required")

	if process_random == null:
		return EditCommandResult.failure("process random state is required")

	if lfsr_random.state != command.lfsr_state_after:
		return EditCommandResult.failure("LFSR state changed after this building command")

	if process_random.state != command.random_state_after:
		return EditCommandResult.failure("process random state changed after this building command")

	var changed_ids := command.changed_ids
	var old_payloads := command.old_payloads
	var new_payloads := command.new_payloads

	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return EditCommandResult.failure("city changed after this building command")

	if not BuildingState._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return EditCommandResult.failure("cannot restore building changes")

	lfsr_random.state = command.lfsr_state_before
	process_random.state = command.random_state_before

	return EditCommandResult.undone(command.tile_indices.size())
