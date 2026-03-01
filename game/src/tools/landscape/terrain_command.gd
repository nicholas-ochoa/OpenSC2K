class_name TerrainCommand
extends RefCounted

const GROUP_BULLDOZER := 0
const SUBTOOL_LEVEL := 1
const SUBTOOL_RAISE := 2
const SUBTOOL_LOWER := 3
const MILITARY_ZONE := 7
const FLAG_WATER := 0x04
const MAX_RAISE_SOURCE := 29

const NEIGHBOR_OFFSETS := [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]
const NEIGHBOR_MASKS := [3, 2, 6, 4, 12, 8, 9, 1]
const CARDINAL_OFFSETS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const RAISE_DEPENDENCY_OFFSETS := [
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1),
]
const TERRAIN_SHAPES := [
	0, 9, 10, 2, 11, 13, 3, 6, 12, 1, 13, 5, 4, 8, 7, 50,
	0, 2, 10, 2, 3, 6, 3, 6, 11, 0, 0, 0, 3, 6, 3, 6,
	4, 13, 13, 13, 13, 13, 13, 13, 4, 13, 13, 13, 7, 13, 7, 50,
	12, 13, 13, 13, 13, 13, 13, 13, 4, 13, 13, 13, 13, 13, 13, 13,
	4, 13, 13, 13, 13, 13, 13, 13, 4, 13, 13, 13, 7, 13, 7, 13,
	1, 5, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
	13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
	1, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
	8, 13, 13, 13, 13, 13, 13, 13, 8, 13, 13, 13, 50, 13, 13, 13,
	9, 2, 2, 2, 13, 13, 13, 6, 13, 13, 13, 13, 13, 13, 13, 6,
	13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
	1, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
	13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
	1, 5, 13, 5, 13, 13, 13, 50, 13, 13, 13, 13, 13, 13, 13, 13,
	13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
	1, 5, 13, 5, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_BULLDOZER and subtool_index >= SUBTOOL_LEVEL and subtool_index <= SUBTOOL_LOWER


static func apply_path(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	points: Array[Vector2i],
	random: SimRandom = null,
	free_mode := false
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
	var target_altitude := _land_altitude(altitude, city.index_of(start.x, start.y))
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
			var current_altitude := _land_altitude(altitude, index)

			if current_altitude < target_altitude:
				operation = SUBTOOL_RAISE
			elif current_altitude > target_altitude:
				operation = SUBTOOL_LOWER
			else:
				continue

		var heights := _decode_heights(altitude, map_edge)
		var trial := {}

		if operation == SUBTOOL_RAISE:
			trial = _plan_raise(heights, zones, buildings, point, funds, map_edge)
		else:
			trial = _plan_lower(heights, point, funds, map_edge)

		if not trial.get("valid", false):
			if trial.get("insufficient", false):
				skipped_insufficient += 1

			continue

		var modified: PackedInt32Array = trial.modified
		var retile_indices := _expanded_indices(modified, map_edge)

		if random == null and _terrain_conflict_needs_random(buildings, retile_indices):
			skipped_conflicts += 1
			continue

		_write_heights(altitude, trial.heights, modified)

		for changed_index in trial.zone_indices:
			zones[changed_index] &= 0xf0

		var action_random_state := random.state if random != null else 0
		var cleared := _clear_terrain_conflicts(
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
		_retile_region(
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

		next_effect_frame = _append_effect_sequence(
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
	var visiting := {}
	var visited := {}
	var postorder: Array[Vector2i] = []

	if not _collect_raise_dependencies(heights, zones, start, visiting, visited, postorder, map_edge):
		return {"valid": false}

	var trial := heights.duplicate()
	var modified := PackedInt32Array()
	var zone_indices := PackedInt32Array()
	var remaining := funds
	var cost := 0

	for point in postorder:
		if remaining < 25:
			continue

		var index := point.x * map_edge + point.y
		trial[index] += 1
		remaining -= 25
		cost += 25
		zone_indices.append(index)

		if not modified.has(index):
			modified.append(index)

		_normalize_cardinal_slopes(trial, buildings, point, modified, map_edge)

	if cost == 0:
		return {"valid": false, "insufficient": true}

	return {
		"valid": true,
		"heights": trial,
		"modified": modified,
		"zone_indices": zone_indices,
		"funds": remaining,
		"cost": cost,
	}


static func _collect_raise_dependencies(
	heights: PackedInt32Array,
	zones: PackedByteArray,
	point: Vector2i,
	visiting: Dictionary,
	visited: Dictionary,
	postorder: Array[Vector2i],
	map_edge: int = 128,
) -> bool:
	var index := point.x * map_edge + point.y

	if visited.has(index):
		return true

	if visiting.has(index):
		return true

	if (zones[index] & 0x0f) == MILITARY_ZONE or heights[index] > MAX_RAISE_SOURCE:
		return false

	for offset in NEIGHBOR_OFFSETS:
		var neighbor: Vector2i = point + offset

		if _point_is_in_bounds(neighbor, map_edge):
			var neighbor_index := neighbor.x * map_edge + neighbor.y

			if (zones[neighbor_index] & 0x0f) == MILITARY_ZONE:
				return false

	visiting[index] = true

	for offset in RAISE_DEPENDENCY_OFFSETS:
		var neighbor: Vector2i = point + offset

		if not _point_is_in_bounds(neighbor, map_edge):
			continue

		var neighbor_index := neighbor.x * map_edge + neighbor.y

		if heights[neighbor_index] < heights[index]:
			if not _collect_raise_dependencies(
				heights, zones, neighbor, visiting, visited, postorder, map_edge
			):
				return false

	visiting.erase(index)
	visited[index] = true
	postorder.append(point)

	return true


static func _normalize_cardinal_slopes(
	heights: PackedInt32Array,
	buildings: PackedByteArray,
	point: Vector2i,
	modified: PackedInt32Array,
	map_edge: int = 128,
) -> void:
	var index := point.x * map_edge + point.y

	for offset in CARDINAL_OFFSETS:
		var neighbor: Vector2i = point + offset

		if not _point_is_in_bounds(neighbor, map_edge):
			continue

		var neighbor_index := neighbor.x * map_edge + neighbor.y

		if buildings[neighbor_index] >= 0x0d:
			continue

		var difference := heights[index] - heights[neighbor_index]

		if difference >= 2:
			heights[neighbor_index] = heights[index] - 1
		elif difference <= -2:
			heights[neighbor_index] = heights[index] + 1
		else:
			continue

		if not modified.has(neighbor_index):
			modified.append(neighbor_index)

		_normalize_cardinal_slopes(heights, buildings, neighbor, modified, map_edge)


static func _plan_lower(
	heights: PackedInt32Array, start: Vector2i, funds: int,
	map_edge: int = 128,
) -> Dictionary:
	if funds < 25:
		return {"valid": false, "insufficient": true}

	var start_index := start.x * map_edge + start.y

	if heights[start_index] == 0:
		return {"valid": false}

	var trial := heights.duplicate()
	var queue: Array[Vector2i] = []
	queue.resize(512)
	var queue_head := 0
	var queue_tail := 1
	queue[0] = start
	var modified := PackedInt32Array([start_index])
	var zone_indices := PackedInt32Array()
	trial[start_index] -= 1
	var decrements := 1

	while queue_head != queue_tail:
		var point := queue[queue_head]
		queue_head = (queue_head + 1) & 0x1ff
		var index := point.x * map_edge + point.y

		if not zone_indices.has(index):
			zone_indices.append(index)

		var higher_mask := 0

		for neighbor_index in 8:
			var neighbor: Vector2i = point + NEIGHBOR_OFFSETS[neighbor_index]

			if _point_is_in_bounds(neighbor, map_edge):
				var checked_index := neighbor.x * map_edge + neighbor.y

				if trial[checked_index] > trial[index]:
					higher_mask |= NEIGHBOR_MASKS[neighbor_index]

		for neighbor_index in 8:
			var neighbor: Vector2i = point + NEIGHBOR_OFFSETS[neighbor_index]

			if not _point_is_in_bounds(neighbor, map_edge):
				continue

			var checked_index := neighbor.x * map_edge + neighbor.y

			if (
				trial[checked_index] > trial[index] + 1
				or (trial[checked_index] > trial[index] and higher_mask == 15)
			):
				trial[checked_index] -= 1
				decrements += 1
				queue[queue_tail] = neighbor
				queue_tail = (queue_tail + 1) & 0x1ff

				if queue_head == queue_tail:
					queue_head = (queue_tail + 1) & 0x1ff

				if not modified.has(checked_index):
					modified.append(checked_index)

	return {
		"valid": true,
		"heights": trial,
		"modified": modified,
		"zone_indices": zone_indices,
		"funds": maxi(0, funds - decrements * 25),
		"cost": mini(funds, decrements * 25),
	}


static func _expanded_indices(indices: PackedInt32Array, map_edge: int = 128) -> PackedInt32Array:
	var result := PackedInt32Array()

	for index in indices:
		var point := Vector2i(int(IntegerMath.div_trunc(index, map_edge)), index % map_edge)

		for x in range(maxi(0, point.x - 1), mini(map_edge, point.x + 2)):
			for y in range(maxi(0, point.y - 1), mini(map_edge, point.y + 2)):
				var checked_index := x * map_edge + y

				if not result.has(checked_index):
					result.append(checked_index)

	return result


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
	var map_edge: int = city.map_size if city != null else 128
	var demolition = load("res://src/tools/city/demolish_command.gd")
	var changed_indices := PackedInt32Array()
	var effect_events: Array[Dictionary] = []
	var sound_events: Array[int] = []
	var next_effect_frame := 0
	var random_used := false

	for index in indices:
		var point := Vector2i(int(IntegerMath.div_trunc(index, map_edge)), index % map_edge)
		var old_building := int(buildings[index])

		if old_building >= 0x0d:
			if random == null:
				return {"ok": false}

			var demolished: Dictionary = demolition._demolish_point(
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
				true,
				false,
				true
			)
			random_used = true

			for changed_index in demolished.get("indices", PackedInt32Array()):
				if not changed_indices.has(changed_index):
					changed_indices.append(changed_index)

			var effects: Array = demolished.get("effect_events", [])
			next_effect_frame = _append_effect_sequence(
				effect_events, effects, next_effect_frame
			)

			if not effects.is_empty():
				sound_events.append(504)

		if old_building != 5:
			NetworkCommand._replace_building(buildings, zones, misc, index, 0)

			if not changed_indices.has(index):
				changed_indices.append(index)

		if underground[index] != 0:
			BuildingCommand._replace_underground(underground, zones, misc, index, 0)

			if not changed_indices.has(index):
				changed_indices.append(index)

	return {
		"ok": true,
		"indices": changed_indices,
		"effect_events": effect_events,
		"sound_events": sound_events,
		"random_used": random_used,
	}


static func _terrain_conflict_needs_random(
	buildings: PackedByteArray, indices: PackedInt32Array
) -> bool:
	for index in indices:
		if buildings[index] >= 0x0d:
			return true

	return false


static func _append_effect_sequence(
	destination: Array[Dictionary], source: Array, first_frame: int
) -> int:
	if source.is_empty():
		return first_frame

	var frame_count := 0

	for source_effect in source:
		var effect: Dictionary = source_effect.duplicate()
		var source_frame := int(effect.get("frame", 0))
		effect["frame"] = first_frame + source_frame
		destination.append(effect)
		frame_count = maxi(frame_count, source_frame + 1)

	return first_frame + frame_count


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
	for index in indices:
		var point := Vector2i(int(IntegerMath.div_trunc(index, map_edge)), index % map_edge)
		var land := _land_altitude(altitude, index)
		var higher_mask := 0

		for neighbor_index in 8:
			var neighbor: Vector2i = point + NEIGHBOR_OFFSETS[neighbor_index]

			if _point_is_in_bounds(neighbor, map_edge):
				var checked_index := neighbor.x * map_edge + neighbor.y

				if _land_altitude(altitude, checked_index) > land:
					higher_mask |= NEIGHBOR_MASKS[neighbor_index]

		var shape := int(TERRAIN_SHAPES[higher_mask])

		if shape != 0:
			zones[index] &= 0xf0

		var raised_basin := shape == 50

		if raised_basin:
			land = mini(31, land + 1)
			_set_land_altitude(altitude, index, land)
			shape = 0

		if land >= sea_level:
			flags[index] &= ~FLAG_WATER & 0xff
			terrain[index] = shape
			continue

		flags[index] |= FLAG_WATER
		_set_water_altitude(altitude, index, sea_level)

		if buildings[index] != 0 and buildings[index] != 5:
			NetworkCommand._replace_building(buildings, zones, misc, index, 0)

		terrain[index] = (
			0x10
			if raised_basin
			else shape + (0x20 if sea_level - land == 1 else 0x10)
		)


static func _decode_heights(altitude: PackedByteArray, map_edge: int = 128) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize((map_edge * map_edge))

	for index in (map_edge * map_edge):
		result[index] = _land_altitude(altitude, index)

	return result


static func _write_heights(
	altitude: PackedByteArray, heights: PackedInt32Array, indices: PackedInt32Array
) -> void:
	for index in indices:
		_set_land_altitude(altitude, index, heights[index])


static func _land_altitude(altitude: PackedByteArray, index: int) -> int:
	return altitude[index * 2 + 1] & 0x1f


static func _set_land_altitude(altitude: PackedByteArray, index: int, value: int) -> void:
	var offset := index * 2
	altitude[offset + 1] = (altitude[offset + 1] & 0xe0) | (value & 0x1f)


static func _set_water_altitude(altitude: PackedByteArray, index: int, value: int) -> void:
	var offset := index * 2
	var word := (altitude[offset] << 8) | altitude[offset + 1]
	word = (word & 0xfc1f) | ((value & 0x1f) << 5)
	altitude[offset] = (word >> 8) & 0xff
	altitude[offset + 1] = word & 0xff


static func _point_is_in_bounds(point: Vector2i, map_edge: int = 128) -> bool:
	return point.x >= 0 and point.x < map_edge and point.y >= 0 and point.y < map_edge
