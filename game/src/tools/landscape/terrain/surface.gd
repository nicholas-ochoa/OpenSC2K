class_name TerrainEditSurface
extends TerrainEditConstants


@warning_ignore_start("integer_division")


static func _expanded_indices(indices: PackedInt32Array, map_edge: int = 128) -> PackedInt32Array:
	var result := PackedInt32Array()

	for index in indices:
		var point := Vector2i(int(index / map_edge), index % map_edge)

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
	var changed_indices := PackedInt32Array()
	var effect_events: Array[Dictionary] = []
	var sound_events: Array[int] = []
	var next_effect_frame := 0
	var random_used := false

	for index in indices:
		var point := Vector2i(int(index / map_edge), index % map_edge)
		var old_building := int(buildings[index])

		if old_building >= 0x0d:
			if random == null:
				return {"ok": false}

			var demolished: Dictionary = DemolishStructures._demolish_point(
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
			NetworkState.replace_building(buildings, zones, misc, index, 0)

			if not changed_indices.has(index):
				changed_indices.append(index)

		if underground[index] != 0:
			BuildingUnderground._replace_underground(underground, zones, misc, index, 0)

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
