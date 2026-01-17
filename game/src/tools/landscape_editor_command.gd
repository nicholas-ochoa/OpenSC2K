class_name LandscapeEditorCommand
extends RefCounted

# editor-only operations. work on a private document and publish one undo unit
static func supports_tool(group: int, subtool: int) -> bool:
	return (group == 0 and subtool in [5, 6, 7]) or (group == 1 and subtool in [2, 3])


static func apply(city: CityState, group: int, subtool: int, point: Vector2i, random: SimRandom, stretch_levels := 1) -> Dictionary:
	if city == null or not supports_tool(group, subtool) or city.index_of(point.x, point.y) < 0:
		return {"ok": false, "error": "invalid landscape edit"}
	var staged := CityState.from_document(city.document.duplicate_document())
	var staged_random := SimRandom.new(random.state)
	var before := random.state
	if group == 0 and subtool == 5:
		for step in mini(31, absi(stretch_levels)):
			var result := TerrainCommand.apply_path(staged, 0, 2 if stretch_levels > 0 else 3, point, [point], staged_random, true)
			if not result.ok:
				break
	elif group == 1 and subtool == 3:
		var points: Array[Vector2i] = []
		for x in range(-3, 4):
			for y in range(-3, 4):
				if x * x + y * y <= 10:
					points.append(point + Vector2i(x + 3, y + 3))
		for pass_index in 3:
			LandscapeCommand.apply_path(staged, 1, 0, points, staged_random, true)
	else:
		var payloads := {}
		for id in ["ALTM", "XBLD", "XTER", "XZON", "XBIT", "XTXT", "MISC"]:
			payloads[id] = staged.document.find_chunk(id).decoded_payload.duplicate()
		if group == 1:
			NewCityTerrain._make_stream(payloads.ALTM, payloads.XBLD, payloads.XTER, payloads.XZON, payloads.XBIT, payloads.XTXT, payloads.MISC, point, 128, staged_random)
		else:
			var sea := clampi(staged.document.misc_u32(0x0e40) + (1 if subtool == 6 else -1), 0, 31)
			BuildingCommand._write_u32_be(payloads.MISC, 0x0e40, sea)
			var indices := PackedInt32Array()
			for index in CityState.TILE_COUNT:
				indices.append(index)
			TerrainCommand._retile_region(payloads.ALTM, payloads.XBLD, payloads.XTER, payloads.XZON, payloads.XBIT, payloads.MISC, indices, sea)
		for id in payloads:
			staged.document.find_chunk(id).set_decoded_payload(payloads[id])
	var old_payloads := {}
	var new_payloads := {}
	var changed := PackedStringArray()
	for chunk in city.document.chunks:
		var next := staged.document.find_chunk(chunk.chunk_id)
		if next != null and chunk.decoded_payload != next.decoded_payload:
			changed.append(chunk.chunk_id)
			old_payloads[chunk.chunk_id] = chunk.decoded_payload.duplicate()
			new_payloads[chunk.chunk_id] = next.decoded_payload.duplicate()
	if changed.is_empty():
		return {"ok": false, "error": "no eligible terrain changed"}
	if not NetworkCommand._apply_payloads(city, changed, new_payloads, old_payloads):
		return {"ok": false, "error": "cannot store landscape edit"}
	random.state = staged_random.state
	var indices := PackedInt32Array()
	for index in CityState.TILE_COUNT:
		indices.append(index)
	return {"ok": true, "command_type": "terrain", "group_index": group, "subtool_index": subtool, "tile_indices": indices, "action_count": 1, "cost": 0, "listed_cost": 0, "skipped_conflicts": 0, "skipped_insufficient": 0, "free_mode": true, "changed_ids": changed, "old_payloads": old_payloads, "new_payloads": new_payloads, "random_used": before != random.state, "random_state_before": before, "random_state_after": random.state, "error": ""}
