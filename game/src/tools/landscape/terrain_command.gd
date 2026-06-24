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
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if not supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool is not a terrain tool"}

	if city.index_of(start.x, start.y) < 0 or points.is_empty():
		return {"ok": false, "error": "terrain path is outside the city"}

	var old_payloads := BuildingCommand._city_payloads(city)

	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}

	var altitude_chunk := city.document.find_chunk("ALTM")

	if altitude_chunk == null or altitude_chunk.decoded_payload.size() != (map_edge * map_edge) * 2:
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
	var old_funds := city.funds()
	var funds := 0x7fffffff if free_mode else old_funds
	var target_altitude := (
		target_override if target_override >= 0
		else TerrainEditHeights._land_altitude(altitude, city.index_of(start.x, start.y))
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
			var current_altitude := TerrainEditHeights._land_altitude(altitude, index)

			if current_altitude < target_altitude:
				operation = SUBTOOL_RAISE
			elif current_altitude > target_altitude:
				operation = SUBTOOL_LOWER
			else:
				continue

		var heights := TerrainEditHeights._decode_heights(altitude, map_edge)
		var trial := {}

		if operation == SUBTOOL_RAISE:
			trial = TerrainEditHeights._plan_raise(heights, zones, buildings, point, funds, map_edge)
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
		TerrainEditSurface._retile_region(
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
			return {"ok": false, "error": "insufficient funds", "cost": 25}

		if skipped_conflicts > 0:
			return {"ok": false, "error": "terrain conflict demolition needs random state"}

		return {"ok": false, "error": "no terrain height changed"}

	BuildingCommand._write_u32_be(
		misc, BuildingCommand.MISC_FUNDS, old_funds if free_mode else funds
	)

	var changed_ids := PackedStringArray()

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not NetworkCommand._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		if random != null:
			random.state = random_state_before

		return {"ok": false, "error": "cannot store terrain changes"}

	return {
		"ok": true,
		"command_type": "terrain",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"target_altitude": target_altitude,
		"tile_indices": changed_indices,
		"action_count": action_count,
		"cost": total_cost,
		"listed_cost": listed_cost,
		"free_mode": free_mode,
		"skipped_conflicts": skipped_conflicts,
		"skipped_insufficient": skipped_insufficient,
		"effect_events": effect_events,
		"sound_events": sound_events,
		"changed_ids": changed_ids,
		"old_payloads": old_payloads,
		"new_payloads": changed_payloads,
		"random_used": random_used,
		"random_state_before": random_state_before,
		"random_state_after": random.state if random != null else random_state_before,
		"error": "",
	}


static func undo(city: CityState, command: Dictionary, random: SimRandom = null) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if not command.get("ok", false) or command.get("command_type", "") != "terrain":
		return {"ok": false, "error": "terrain command is invalid"}

	if command.get("random_used", false):
		if random == null:
			return {"ok": false, "error": "random state is required"}

		if random.state != int(command.get("random_state_after", -1)):
			return {"ok": false, "error": "random state changed after this terrain command"}

	var changed_ids: PackedStringArray = command.get("changed_ids", PackedStringArray())
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})

	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return {"ok": false, "error": "city changed after this terrain command"}

	if not NetworkCommand._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore terrain changes"}

	if command.get("random_used", false):
		random.state = int(command.random_state_before)

	var indices: PackedInt32Array = command.get("tile_indices", PackedInt32Array())

	return {"ok": true, "restored_tiles": indices.size(), "error": ""}


static func _plan_raise(
	heights: PackedInt32Array,
	zones: PackedByteArray,
	buildings: PackedByteArray,
	start: Vector2i,
	funds: int,
	map_edge: int = 128,
) -> Dictionary:
	return TerrainEditHeights._plan_raise(heights, zones, buildings, start, funds, map_edge)


static func _collect_raise_dependencies(
	heights: PackedInt32Array,
	zones: PackedByteArray,
	point: Vector2i,
	visiting: Dictionary,
	visited: Dictionary,
	postorder: Array[Vector2i],
	map_edge: int = 128,
) -> bool:
	return TerrainEditHeights._collect_raise_dependencies(heights, zones, point, visiting, visited, postorder, map_edge)


static func _normalize_cardinal_slopes(
	heights: PackedInt32Array,
	buildings: PackedByteArray,
	point: Vector2i,
	modified: PackedInt32Array,
	map_edge: int = 128,
) -> void:
	TerrainEditHeights._normalize_cardinal_slopes(heights, buildings, point, modified, map_edge)


static func _plan_lower(
	heights: PackedInt32Array, start: Vector2i, funds: int,
	map_edge: int = 128,
) -> Dictionary:
	return TerrainEditHeights._plan_lower(heights, start, funds, map_edge)


static func _expanded_indices(indices: PackedInt32Array, map_edge: int = 128) -> PackedInt32Array:
	return TerrainEditSurface._expanded_indices(indices, map_edge)


static func _clear_terrain_conflicts(
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
	indices: PackedInt32Array,
	random: SimRandom
) -> Dictionary:
	return TerrainEditSurface._clear_terrain_conflicts(
		city, altitude, buildings, terrain, zones, underground, flags, text_overlays, labels, microsims, misc,
		indices, random
	)


static func _terrain_conflict_needs_random(
	buildings: PackedByteArray, indices: PackedInt32Array
) -> bool:
	return TerrainEditSurface._terrain_conflict_needs_random(buildings, indices)


static func _append_effect_sequence(
	destination: Array[Dictionary], source: Array, first_frame: int
) -> int:
	return TerrainEditSurface._append_effect_sequence(destination, source, first_frame)


static func _retile_region(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	indices: PackedInt32Array,
	sea_level: int,
	map_edge: int = 128,
) -> void:
	TerrainEditSurface._retile_region(altitude, buildings, terrain, zones, flags, misc, indices, sea_level, map_edge)


static func _decode_heights(altitude: PackedByteArray, map_edge: int = 128) -> PackedInt32Array:
	return TerrainEditHeights._decode_heights(altitude, map_edge)


static func _write_heights(
	altitude: PackedByteArray, heights: PackedInt32Array, indices: PackedInt32Array
) -> void:
	TerrainEditHeights._write_heights(altitude, heights, indices)


static func _land_altitude(altitude: PackedByteArray, index: int) -> int:
	return TerrainEditHeights._land_altitude(altitude, index)


static func _set_land_altitude(altitude: PackedByteArray, index: int, value: int) -> void:
	TerrainEditHeights._set_land_altitude(altitude, index, value)


static func _set_water_altitude(altitude: PackedByteArray, index: int, value: int) -> void:
	TerrainEditHeights._set_water_altitude(altitude, index, value)


static func _point_is_in_bounds(point: Vector2i, map_edge: int = 128) -> bool:
	return TerrainEditHeights._point_is_in_bounds(point, map_edge)
