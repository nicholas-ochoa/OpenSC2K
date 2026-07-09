class_name BuildingFacilities
extends BuildingConstants



static func stadium_team_choices(city: CityState) -> PackedInt32Array:
	var result := PackedInt32Array()

	if city == null or not city.is_valid():
		return result

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != 4800:
		return result

	var used_mask := BuildingState._read_u32_be(
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
	command: Dictionary,
	team_index: int,
	team_name: String
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if (
		not command.get("ok", false)
		or command.get("command_type", "") != "building"
		or int(command.get("tile_id", 0)) != STADIUM
		or not command.get("stadium_team_selection_required", false)
	):
		return {"ok": false, "error": "stadium building command is invalid"}

	if not stadium_team_choices(city).has(team_index):
		return {"ok": false, "error": "stadium team is not available"}

	var overlay_id := int(command.get("overlay_id", 0))
	var record_id := OverlayData.facility_record(overlay_id)

	if record_id < MICROSIM_DYNAMIC_FIRST or record_id >= city.microsim_count():
		return {"ok": false, "error": "stadium microsimulation link is invalid"}

	var current_payloads := BuildingState._city_payloads(city)

	if current_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}

	var expected_payloads: Dictionary = command.get("new_payloads", {})
	var command_ids: PackedStringArray = command.get(
		"changed_ids", PackedStringArray()
	)

	for chunk_id in command_ids:
		if (
			not expected_payloads.has(chunk_id)
			or current_payloads[chunk_id] != expected_payloads[chunk_id]
		):
			return {"ok": false, "error": "city changed after stadium placement"}

	var changed_payloads := BuildingState._duplicate_payloads(current_payloads)
	var microsims: PackedByteArray = changed_payloads.XMIC
	var record_offset := record_id * CityState.MICROSIM_RECORD_SIZE

	if microsims[record_offset] != STADIUM:
		return {"ok": false, "error": "stadium microsimulation record is missing"}

	BuildingState._write_u16_be(microsims, record_offset + 4, team_index)
	BuildingState._write_u16_be(
		microsims,
		record_offset + 6,
		STADIUM_TEAM_LABEL_BASE + team_index,
	)
	_write_label(
		changed_payloads.XLAB,
		STADIUM_TEAM_LABEL_BASE + team_index,
		team_name,
	)
	var misc: PackedByteArray = changed_payloads.MISC
	BuildingState._write_u32_be(
		misc,
		MISC_STADIUM_TEAMS,
		BuildingState._read_u32_be(misc, MISC_STADIUM_TEAMS) | (1 << team_index),
	)
	var team_chunk_ids := PackedStringArray(["XLAB", "XMIC", "MISC"])

	if not BuildingState._apply_payloads(
		city, team_chunk_ids, changed_payloads, current_payloads
	):
		return {"ok": false, "error": "cannot store stadium team"}

	var updated_command := command.duplicate(true)
	var updated_payloads: Dictionary = updated_command.new_payloads

	for chunk_id in team_chunk_ids:
		updated_payloads[chunk_id] = changed_payloads[chunk_id].duplicate()

		if not command_ids.has(chunk_id):
			command_ids.append(chunk_id)

	updated_command["changed_ids"] = command_ids
	updated_command["new_payloads"] = updated_payloads
	updated_command["stadium_team_selection_required"] = false
	updated_command["stadium_team_index"] = team_index
	updated_command["stadium_team_label"] = STADIUM_TEAM_LABEL_BASE + team_index

	return {
		"ok": true,
		"command": updated_command,
		"team_index": team_index,
		"team_label": STADIUM_TEAM_LABEL_BASE + team_index,
		"team_name": team_name.left(23),
		"error": "",
	}


static func _provision_microsim(
	microsims: PackedByteArray,
	labels: PackedByteArray,
	text_overlays: PackedByteArray,
	tile_id: int,
	current_year: int,
	process_random: SimRandom,
	misc := PackedByteArray(),
	australian_locale := false,
	scurk_place_mode := false
) -> int:
	var microsim_type := int(MICROSIM_TYPE_BY_TILE.get(tile_id, 0))

	if microsim_type == 0:
		return 0

	var record_id := -1

	if microsim_type <= 16:
		for checked_id in range(MICROSIM_DYNAMIC_FIRST, IntegerMath.div_trunc(microsims.size(), CityState.MICROSIM_RECORD_SIZE)):
			if microsims[checked_id * CityState.MICROSIM_RECORD_SIZE] == 0:
				record_id = checked_id
				break
	else:
		record_id = microsim_type - 16

	if record_id < 0 and tile_id >= 0xfb:
		for checked_id in range(MICROSIM_DYNAMIC_FIRST, IntegerMath.div_trunc(microsims.size(), CityState.MICROSIM_RECORD_SIZE)):
			if microsims[checked_id * CityState.MICROSIM_RECORD_SIZE] < 0xfb:
				record_id = checked_id
				var old_overlay_id := OverlayData.facility_id(checked_id)

				for index in OverlayData.count(text_overlays):
					if OverlayData.read(text_overlays, index) == old_overlay_id:
						OverlayData.write(text_overlays, index, 0)

				break

	if record_id < 0:
		return 0

	var record_offset := record_id * CityState.MICROSIM_RECORD_SIZE

	if microsim_type <= 16:
		for offset in CityState.MICROSIM_RECORD_SIZE:
			microsims[record_offset + offset] = 0

	microsims[record_offset] = tile_id
	_initialize_microsim(
		microsims,
		misc,
		record_id,
		tile_id,
		current_year,
		process_random,
		australian_locale,
		scurk_place_mode,
		int(sqrt(OverlayData.count(text_overlays)))
	)

	var label_id := OverlayData.facility_id(record_id)
	var label_offset := label_id * CityState.LABEL_RECORD_SIZE

	if microsim_type <= 16 or labels[label_offset] == 0:
		_write_label(labels, label_id, str(DEFAULT_MICROSIM_LABELS.get(tile_id, "")))

	return label_id


static func _initialize_microsim(
	microsims: PackedByteArray,
	misc: PackedByteArray,
	record_id: int,
	tile_id: int,
	current_year: int,
	process_random: SimRandom,
	australian_locale: bool,
	scurk_place_mode: bool,
	map_edge: int = 128
) -> void:
	var offset := record_id * CityState.MICROSIM_RECORD_SIZE

	match tile_id:
		0xc6, 0xc7:
			BuildingState._write_u16_be(microsims, offset + 2, BuildingState._read_u16_be(microsims, offset + 2) + 1)
			BuildingState._write_u16_be(microsims, offset + 4, BuildingState._read_u16_be(microsims, offset + 4) + 20)
		0xc8:
			BuildingState._write_u16_be(microsims, offset + 2, BuildingState._read_u16_be(microsims, offset + 2) + 1)
			BuildingState._write_u16_be(microsims, offset + 4, BuildingState._read_u16_be(microsims, offset + 4) + 4)
		0xc9, 0xcc:
			BuildingState._write_u16_be(microsims, offset + 2, 50)
		0xca:
			BuildingState._write_u16_be(microsims, offset + 2, 220)
		0xcb:
			BuildingState._write_u16_be(microsims, offset + 2, 500)
		0xcd:
			BuildingState._write_u16_be(microsims, offset + 2, 1600)
		0xce:
			BuildingState._write_u16_be(microsims, offset + 2, 2500)
		0xcf:
			BuildingState._write_u16_be(microsims, offset + 2, 200)
		0xd0:
			BuildingState._write_u16_be(
				microsims,
				offset + 2,
				0 if scurk_place_mode else _population_cap(misc, 200, 900, map_edge)
			)
			BuildingState._write_u16_be(microsims, offset + 4, current_year)
		0xd1, 0xd6, 0xd9:
			microsims[offset + 1] = 6
		0xd2:
			var police_funding := (
				0
				if scurk_place_mode
				else BuildingState._read_i32_be(misc, MISC_BUDGETS + 5 * BUDGET_RECORD_SIZE + 4)
			)
			BuildingState._write_u16_be(
				microsims,
				offset + 2,
				(
					0
					if scurk_place_mode
					else _population_cap(misc, _to_i16(police_funding * 2), 90, map_edge)
				)
			)
		0xd3:
			var fire_funding := (
				0
				if scurk_place_mode
				else BuildingState._read_i32_be(misc, MISC_BUDGETS + 6 * BUDGET_RECORD_SIZE + 4)
			)
			BuildingState._write_u16_be(
				microsims,
				offset + 2,
				(
					0
					if scurk_place_mode
					else _population_cap(
						misc, _to_i16(_divide_toward_zero(fire_funding, 2)), 70, map_edge
					)
				)
			)
			BuildingState._write_u16_be(microsims, offset + 4, 4)
		0xd4:
			microsims[offset + 1] = 100
		0xd5:
			BuildingState._write_u16_be(microsims, offset + 4, BuildingState._read_u16_be(microsims, offset + 4) + 9)
		0xdb:
			BuildingState._write_u16_be(microsims, offset + 2, current_year)
		0xe9, 0xec, 0xed:
			BuildingState._write_u16_be(microsims, offset + 2, BuildingState._read_u16_be(microsims, offset + 2) + 1)
		0xf3:
			BuildingState._write_u16_be(microsims, offset + 2, current_year)
			BuildingState._write_u16_be(microsims, offset + 4, process_random.next_u15() % 30 + 10)
			BuildingState._write_u16_be(microsims, offset + 6, process_random.next_u15() % 60)
		0xfb:
			microsims[offset + 1] = 5
			BuildingState._write_u16_be(microsims, offset + 2, 55)
			BuildingState._write_u16_be(microsims, offset + 6, current_year)
		0xfc:
			microsims[offset + 1] = 5
			BuildingState._write_u16_be(microsims, offset + 2, 30)
			BuildingState._write_u16_be(microsims, offset + 6, current_year)
		0xfd:
			microsims[offset + 1] = 5
			BuildingState._write_u16_be(microsims, offset + 2, 45)
			BuildingState._write_u16_be(microsims, offset + 6, current_year)
		0xfe:
			microsims[offset + 1] = 5
			BuildingState._write_u16_be(microsims, offset + 2, 65)
			BuildingState._write_u16_be(microsims, offset + 6, current_year)
		0xff:
			BuildingState._write_u16_be(
				microsims,
				offset + 6,
				current_year if australian_locale else process_random.next_u15() & 0x3f
			)


static func _population_cap(misc: PackedByteArray, maximum: int, divisor: int, map_edge: int = 128) -> int:
	if divisor == 0:
		divisor = 100

	var arcology_count := 0

	for tile_id in range(0xfb, 0xff):
		var count := BuildingState._read_u32_be(misc, MISC_TILE_COUNTS + tile_id * 4)
		arcology_count += _to_i16(count) if map_edge == 128 else count

	arcology_count = _divide_toward_zero(arcology_count, 16)
	var arcology_adjustment := 0

	if arcology_count >= 141:
		arcology_adjustment = arcology_count * 20000 - 2800000

	var total_population := (
		arcology_adjustment
		+ BuildingState._read_u32_be(misc, MISC_ARCOLOGY_POPULATION)
		+ BuildingState._read_u32_be(misc, MISC_NORMAL_POPULATION)
	)
	var available := _divide_toward_zero(total_population, divisor) & (0xffff if map_edge == 128 else 0xffffffff)
	var signed_maximum := _to_i16(maximum)

	return signed_maximum if signed_maximum <= available else available


static func _divide_toward_zero(value: int, divisor: int) -> int:
	return int(value / float(divisor))


static func _to_i16(value: int) -> int:
	var wrapped := value & 0xffff

	return wrapped - 0x10000 if wrapped >= 0x8000 else wrapped


static func _write_label(labels: PackedByteArray, label_id: int, value: String) -> void:
	var encoded := value.to_ascii_buffer()

	if encoded.size() > 23:
		encoded = encoded.slice(0, 23)

	var offset := label_id * CityState.LABEL_RECORD_SIZE

	for record_byte in CityState.LABEL_RECORD_SIZE:
		labels[offset + record_byte] = 0

	labels[offset] = encoded.size()

	for index in encoded.size():
		labels[offset + 1 + index] = encoded[index]
