class_name BuildingFacilities
extends BuildingConstants
## Stadium teams. New facility records are made in the native simulation
## library; see native/core/sim/src/sim/tools/commands/facilities.rs.


@warning_ignore_start("integer_division")


static func stadium_team_choices(city: CityState) -> PackedInt32Array:
	var result := PackedInt32Array()

	if city == null or not city.is_valid():
		return result

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != 4800:
		return result

	var used_mask := BinaryData.read_u32_be(
		misc_chunk.decoded_payload, MISC_STADIUM_TEAMS
	) & 0x1f

	for team_index in STADIUM_TEAM_COUNT:
		if used_mask == 0x1f or (used_mask & (1 << team_index)) == 0:
			result.append(team_index)

	return result


static func stadium_team_name(city: CityState, team_index: int) -> String:
	if city == null or team_index < 0 or team_index >= STADIUM_TEAM_COUNT:
		return ""

	var saved_name := city.label(STADIUM_TEAM_LABEL_BASE + team_index)

	return (
		saved_name
		if not saved_name.is_empty()
		else DEFAULT_STADIUM_TEAM_NAMES[team_index]
	)


static func assign_stadium_team(
	city: CityState,
	command: BuildingEditResult,
	team_index: int,
	team_name: String
) -> BuildingEditResult:
	if city == null or not city.is_valid():
		return BuildingEditResult.rejected("city is invalid")

	if (
		command == null
		or not command.ok
		or command.command_type != "building"
		or command.tile_id != STADIUM
		or not command.stadium_team_selection_required
	):
		return BuildingEditResult.rejected("stadium building command is invalid")

	if not stadium_team_choices(city).has(team_index):
		return BuildingEditResult.rejected("stadium team is not available")

	var overlay_id := command.overlay_id
	var record_id := OverlayData.facility_record(overlay_id)

	if record_id < MICROSIM_DYNAMIC_FIRST or record_id >= city.microsim_count():
		return BuildingEditResult.rejected("stadium microsimulation link is invalid")

	var current_payloads := BuildingState._city_payloads(city)

	if current_payloads.is_empty():
		return BuildingEditResult.rejected("required city data is missing or invalid")

	var expected_payloads := command.new_payloads
	var command_ids := command.changed_ids.duplicate()

	for chunk_id in command_ids:
		if (
			not expected_payloads.has(chunk_id)
			or current_payloads[chunk_id] != expected_payloads[chunk_id]
		):
			return BuildingEditResult.rejected("city changed after stadium placement")

	var changed_payloads := BuildingState._duplicate_payloads(current_payloads)
	var microsims: PackedByteArray = changed_payloads.XMIC
	var record_offset := record_id * CityState.MICROSIM_RECORD_SIZE

	if microsims[record_offset] != STADIUM:
		return BuildingEditResult.rejected("stadium microsimulation record is missing")

	BinaryData.write_u16_be(microsims, record_offset + 4, team_index)
	BinaryData.write_u16_be(
		microsims,
		record_offset + 6,
		STADIUM_TEAM_LABEL_BASE + team_index,
	)
	write_label(
		changed_payloads.XLAB,
		STADIUM_TEAM_LABEL_BASE + team_index,
		team_name,
	)
	var misc: PackedByteArray = changed_payloads.MISC
	BinaryData.write_u32_be(
		misc,
		MISC_STADIUM_TEAMS,
		BinaryData.read_u32_be(misc, MISC_STADIUM_TEAMS) | (1 << team_index),
	)
	var team_chunk_ids := PackedStringArray(["XLAB", "XMIC", "MISC"])

	if not BuildingState._apply_payloads(
		city, team_chunk_ids, changed_payloads, current_payloads
	):
		return BuildingEditResult.rejected("cannot store stadium team")

	# the placement and the team become one undo transaction
	var updated_command := command.copy() as BuildingEditResult

	for chunk_id in team_chunk_ids:
		updated_command.new_payloads[chunk_id] = changed_payloads[chunk_id]

		if not command_ids.has(chunk_id):
			command_ids.append(chunk_id)

	updated_command.changed_ids = command_ids
	updated_command.stadium_team_selection_required = false
	updated_command.stadium_team_index = team_index
	updated_command.stadium_team_label = STADIUM_TEAM_LABEL_BASE + team_index
	updated_command.stadium_team_name = team_name.left(city.document.name_limit())

	updated_command.retain_changed_payloads()

	return updated_command


static func write_label(labels: PackedByteArray, label_id: int, value: String) -> void:
	Sc2LabelLayout.write(labels, label_id, value)
