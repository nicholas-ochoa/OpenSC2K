class_name TerrainCommand
extends TerrainEditConstants



static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_BULLDOZER and subtool_index >= SUBTOOL_LEVEL and subtool_index <= SUBTOOL_LOWER


static func apply_path(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	points: Array[Vector2i],
	random: SimRandom = null,
	free_mode := false,
	target_override := -1
) -> TerrainEditResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return TerrainEditResult.rejected("city is invalid")

	if not supports_tool(group_index, subtool_index):
		return TerrainEditResult.rejected("tool is not a terrain tool")

	if city.index_of(start.x, start.y) < 0 or points.is_empty():
		return TerrainEditResult.rejected("terrain path is outside the city")

	var old_payloads := BuildingState._city_payloads(city)

	if old_payloads.is_empty():
		return TerrainEditResult.rejected("required city data is missing or invalid")

	var altitude_chunk := city.document.find_chunk("ALTM")

	if altitude_chunk == null or altitude_chunk.decoded_payload.size() != (map_edge * map_edge) * 2:
		return TerrainEditResult.rejected("required altitude data is missing or invalid")

	old_payloads.ALTM = altitude_chunk.decoded_payload.duplicate()
	var changed_payloads := BuildingState._duplicate_payloads(old_payloads)
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
	var old_funds := city.funds()
	var funds := 0x7fffffff if free_mode else old_funds
	var target_altitude := (
		target_override if target_override >= 0
		else TerrainEditHeights.land_altitude(altitude, city.index_of(start.x, start.y))
	)
	var action_count := 0
	var total_cost := 0
	var listed_cost := 0
	var changed_indices := PackedInt32Array()
	var skipped_conflicts := 0
	var skipped_insufficient := 0
	var effect_events: Array[Dictionary] = []
	var sound_events: Array[int] = []
	var next_effect_frame := 0
	var random_state_before := random.state if random != null else 0
	var random_used := false

	for point in points:
		var index := city.index_of(point.x, point.y)

		if index < 0:
			continue

		var operation := subtool_index

		if operation == SUBTOOL_LEVEL:
			var current_altitude := TerrainEditHeights.land_altitude(altitude, index)

			if current_altitude < target_altitude:
				operation = SUBTOOL_RAISE
			elif current_altitude > target_altitude:
				operation = SUBTOOL_LOWER
			else:
				continue

		var heights := TerrainEditHeights._decode_heights(altitude, map_edge)
		var trial := {}

		if operation == SUBTOOL_RAISE:
			trial = TerrainEditHeights.plan_raise(heights, zones, buildings, point, funds, map_edge)
		else:
			trial = TerrainEditHeights._plan_lower(heights, point, funds, map_edge)

		if not trial.get("valid", false):
			if trial.get("insufficient", false):
				skipped_insufficient += 1

			continue

		var modified: PackedInt32Array = trial.modified
		var retile_indices := TerrainEditSurface._expanded_indices(modified, map_edge)

		if random == null and TerrainEditSurface._terrain_conflict_needs_random(buildings, retile_indices):
			skipped_conflicts += 1
			continue

		TerrainEditHeights._write_heights(altitude, trial.heights, modified)

		for changed_index in trial.zone_indices:
			zones[changed_index] &= 0xf0

		var action_random_state := random.state if random != null else 0
		var cleared := TerrainEditSurface._clear_terrain_conflicts(
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
			retile_indices,
			random
		)

		if not cleared.ok:
			if random != null:
				random.state = action_random_state

			skipped_conflicts += 1
			continue

		random_used = random_used or bool(cleared.random_used)
		funds = int(trial.funds)
		listed_cost += int(trial.cost)

		if not free_mode:
			total_cost += int(trial.cost)

		action_count += 1
		TerrainRetile.retile_region(
			altitude, buildings, terrain, zones, flags, misc, retile_indices,
			city.document.misc_u32(0x0e40), map_edge
		)

		for changed_index in modified:
			if not changed_indices.has(changed_index):
				changed_indices.append(changed_index)

		for changed_index in retile_indices:
			if not changed_indices.has(changed_index):
				changed_indices.append(changed_index)

		for changed_index in cleared.indices:
			if not changed_indices.has(changed_index):
				changed_indices.append(changed_index)

		next_effect_frame = TerrainEditSurface._append_effect_sequence(
			effect_events, cleared.effect_events, next_effect_frame
		)

		for sound_id in cleared.sound_events:
			sound_events.append(sound_id)

	if action_count == 0:
		if random != null:
			random.state = random_state_before

		if skipped_insufficient > 0:
			return TerrainEditResult.rejected("insufficient funds", 25)

		if skipped_conflicts > 0:
			return TerrainEditResult.rejected("terrain conflict demolition needs random state")

		return TerrainEditResult.rejected("no terrain height changed")

	BuildingState._write_u32_be(
		misc, BuildingCommand.MISC_FUNDS, old_funds if free_mode else funds
	)

	var changed_ids := PackedStringArray()

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not NetworkState._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		if random != null:
			random.state = random_state_before

		return TerrainEditResult.rejected("cannot store terrain changes")

	var command := TerrainEditResult.new()
	command.ok = true
	command.command_type = "terrain"
	command.group_index = group_index
	command.subtool_index = subtool_index
	command.target_altitude = target_altitude
	command.tile_indices = changed_indices
	command.action_count = action_count
	command.cost = total_cost
	command.listed_cost = listed_cost
	command.free_mode = free_mode
	command.skipped_conflicts = skipped_conflicts
	command.skipped_insufficient = skipped_insufficient
	command.effect_events = effect_events
	command.sound_events = sound_events
	command.changed_ids = changed_ids
	command.old_payloads = old_payloads
	command.new_payloads = changed_payloads
	command.random_used = random_used
	command.tracks_random = true
	command.random_state_before = random_state_before
	command.random_state_after = random.state if random != null else random_state_before

	return command


static func undo(city: CityState, command: TerrainEditResult, random: SimRandom = null) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != "terrain":
		return EditCommandResult.failure("terrain command is invalid")

	if command.random_used:
		if random == null:
			return EditCommandResult.failure("random state is required")

		if random.state != command.random_state_after:
			return EditCommandResult.failure("random state changed after this terrain command")

	var changed_ids := command.changed_ids
	var old_payloads := command.old_payloads
	var new_payloads := command.new_payloads

	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return EditCommandResult.failure("city changed after this terrain command")

	if not NetworkState._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return EditCommandResult.failure("cannot restore terrain changes")

	if command.random_used:
		random.state = command.random_state_before

	return EditCommandResult.undone(command.tile_indices.size())
