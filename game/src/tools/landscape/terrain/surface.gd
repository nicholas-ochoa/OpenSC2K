class_name TerrainEditSurface
extends TerrainEditConstants



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
		var land := TerrainEditHeights._land_altitude(altitude, index)
		var higher_mask := 0

		for neighbor_index in 8:
			var neighbor: Vector2i = point + NEIGHBOR_OFFSETS[neighbor_index]

			if TerrainEditHeights._point_is_in_bounds(neighbor, map_edge):
				var checked_index := neighbor.x * map_edge + neighbor.y

				if TerrainEditHeights._land_altitude(altitude, checked_index) > land:
					higher_mask |= NEIGHBOR_MASKS[neighbor_index]

		var shape := int(TERRAIN_SHAPES[higher_mask])

		if shape != 0:
			zones[index] &= 0xf0

		var raised_basin := shape == 50

		if raised_basin:
			land = mini(31, land + 1)
			TerrainEditHeights._set_land_altitude(altitude, index, land)
			shape = 0

		if land >= sea_level:
			flags[index] &= ~FLAG_WATER & 0xff
			terrain[index] = shape
			continue

		flags[index] |= FLAG_WATER
		TerrainEditHeights._set_water_altitude(altitude, index, sea_level)

		if buildings[index] != 0 and buildings[index] != 5:
			NetworkCommand._replace_building(buildings, zones, misc, index, 0)

		terrain[index] = (
			0x10
			if raised_basin
			else shape + (0x20 if sea_level - land == 1 else 0x10)
		)
