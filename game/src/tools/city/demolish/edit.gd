class_name DemolishEdit
extends DemolishConstants
# apply and undo demolition transactions and random state


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_BULLDOZER and subtool_index == SUBTOOL_DEMOLISH


static func apply_path(
	city: CityState,
	group_index: int,
	subtool_index: int,
	points: Array[Vector2i],
	random: SimRandom,
	underground_view := false,
	scurk_mode := false
) -> DemolishEditResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return DemolishEditResult.rejected("city is invalid")

	if not supports_tool(group_index, subtool_index):
		return DemolishEditResult.rejected("tool is not the demolish tool")

	if random == null:
		return DemolishEditResult.rejected("random state is required")

	if points.is_empty():
		return DemolishEditResult.rejected("demolish path is empty")

	var old_payloads := BuildingState._city_payloads(city)

	if old_payloads.is_empty():
		return DemolishEditResult.rejected("required city data is missing or invalid")

	var altitude_chunk := city.document.find_chunk("ALTM")

	if altitude_chunk == null or altitude_chunk.decoded_payload.size() != (map_edge * map_edge) * 2:
		return DemolishEditResult.rejected("required altitude data is missing or invalid")

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
	var listed_cost_per_action := int(
		ToolCatalog.tool(group_index, subtool_index).cost
	)
	var cost_per_action := 0 if scurk_mode else listed_cost_per_action
	var total_cost := 0
	var action_count := 0
	var changed_indices := PackedInt32Array()
	var skipped_specialized := 0
	var skipped_insufficient := 0
	var easter_events := 0
	var news_items: Array[NewsEvent] = []
	var effect_events: Array[EffectEvent] = []
	var sound_events: Array[int] = []
	var random_state_before := random.state

	for point in points:
		if city.index_of(point.x, point.y) < 0:
			continue

		if city.funds() - total_cost < cost_per_action:
			skipped_insufficient += 1
			continue

		var result := (
			DemolishStructures._demolish_underground_point(
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
				random,
				scurk_mode
			)
			if underground_view
			else DemolishStructures._demolish_point(
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
				random,
				scurk_mode,
				true,
				not scurk_mode,
				scurk_mode
			)
		)

		if result.specialized:
			skipped_specialized += 1
			continue

		if not result.changed:
			continue

		action_count += 1
		total_cost += cost_per_action

		if result.easter_event:
			easter_events += 1
			var news_result := NewsQueue.insert(misc, NEWS_FOREST_PROTEST, 0)

			if not news_result.ok:
				random.state = random_state_before

				return DemolishEditResult.rejected("cannot store forest protest news")

			news_items.append(NewsEvent.new(NEWS_FOREST_PROTEST, 0))
			sound_events.append(SOUND_FOREST_PROTEST)

		var result_effects: Array[EffectEvent] = result.effect_events
		var effect_offset := DemolishEffectsSites.parallel_effect_offset(
			point, action_count - 1, random_state_before
		)
		DemolishEffectsSites.append_effect_sequence(effect_events, result_effects, effect_offset)

		if not result_effects.is_empty() and not sound_events.has(SOUND_EXPLODE):
			sound_events.append(SOUND_EXPLODE)

		for index in result.indices:
			if not changed_indices.has(index):
				changed_indices.append(index)

	if action_count == 0:
		random.state = random_state_before

		if skipped_insufficient > 0:
			return DemolishEditResult.rejected("insufficient funds", cost_per_action)

		if skipped_specialized > 0:
			return DemolishEditResult.rejected("reinforced bridge or network data is malformed")

		return DemolishEditResult.rejected("no eligible tiles changed")

	BinaryData.write_u32_be(
		misc, BuildingCommand.MISC_FUNDS, city.funds() - total_cost
	)

	if scurk_mode:
		changed_payloads.XTER = old_payloads.XTER.duplicate()
		changed_payloads.ALTM = old_payloads.ALTM.duplicate()
		var scurk_zones: PackedByteArray = changed_payloads.XZON
		var old_zones: PackedByteArray = old_payloads.XZON
		var scurk_flags: PackedByteArray = changed_payloads.XBIT
		var old_flags: PackedByteArray = old_payloads.XBIT

		for index in (map_edge * map_edge):
			scurk_zones[index] = (
				(scurk_zones[index] & Sc2ZoneLayout.CORNERS_MASK) | (old_zones[index] & Sc2ZoneLayout.TYPE_MASK)
			)
			scurk_flags[index] = (
				(scurk_flags[index] & ~FLAG_WATER & 0xff)
				| (old_flags[index] & FLAG_WATER)
			)

	var changed_ids := PackedStringArray()

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not BuildingState._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		random.state = random_state_before

		return DemolishEditResult.rejected("cannot store demolition changes")

	var command := DemolishEditResult.new()
	command.ok = true
	command.command_type = "demolish"
	command.group_index = group_index
	command.subtool_index = subtool_index
	command.underground_view = underground_view
	command.tile_indices = changed_indices
	command.action_count = action_count
	command.cost = total_cost
	command.listed_cost = action_count * listed_cost_per_action
	command.scurk_mode = scurk_mode
	command.skipped_specialized = skipped_specialized
	command.skipped_insufficient = skipped_insufficient
	command.easter_events = easter_events
	command.news_items = news_items
	command.news_queue_updated = easter_events > 0
	command.effect_events = effect_events
	command.sound_events = sound_events
	command.changed_ids = changed_ids
	command.old_payloads = old_payloads
	command.new_payloads = changed_payloads
	command.tracks_random = true
	command.random_state_before = random_state_before
	command.random_state_after = random.state

	return command


static func undo(city: CityState, command: DemolishEditResult, random: SimRandom) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != "demolish":
		return EditCommandResult.failure("demolish command is invalid")

	if random == null:
		return EditCommandResult.failure("random state is required")

	if random.state != command.random_state_after:
		return EditCommandResult.failure("random state changed after this demolish command")

	var changed_ids := command.changed_ids
	var old_payloads := command.old_payloads
	var new_payloads := command.new_payloads

	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return EditCommandResult.failure("city changed after this demolish command")

	if not BuildingState._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return EditCommandResult.failure("cannot restore demolition changes")

	random.state = command.random_state_before

	return EditCommandResult.undone(command.tile_indices.size())
