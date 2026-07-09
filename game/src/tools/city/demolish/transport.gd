class_name DemolishTransport
extends DemolishConstants



static func _is_highway_tile(tile_id: int) -> bool:
	return (
		(tile_id >= HIGHWAY_STRAIGHT_FIRST and tile_id <= HIGHWAY_STRAIGHT_LAST)
		or (tile_id >= HIGHWAY_SHAPED_FIRST and tile_id <= HIGHWAY_SHAPED_LAST)
	)


static func _demolish_tunnel(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	start: Vector2i,
	tile_id: int,
	random: SimRandom,
	emit_effects: bool,
	scurk_mode := false,
	map_edge: int = 128,
) -> Dictionary:
	var direction: Vector2i = [
		Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)
	][tile_id - TUNNEL_FIRST]
	var points: Array[Vector2i] = [start]
	var current := start + direction

	while current.x >= 0 and current.x < map_edge and current.y >= 0 and current.y < map_edge:
		points.append(current)
		var current_id := int(buildings[current.x * map_edge + current.y])

		if current_id >= TUNNEL_FIRST and current_id <= TUNNEL_LAST:
			break

		current += direction

	if points.size() < 2 or current.x < 0 or current.x >= map_edge or current.y < 0 or current.y >= map_edge:
		return {"changed": false, "specialized": true}

	var effect_events: Array[Dictionary] = []

	if emit_effects:
		for endpoint in [points[0], points[-1]]:
			var entrance: Vector2i = endpoint
			var entrance_index: int = entrance.x * map_edge + entrance.y
			effect_events.append(DemolishEffectsSites._dust_effect(
				entrance, DemolishTerrain._land_altitude(altitude, entrance_index), random, 0, Vector2i.ZERO
			))

	for point in points:
		var index := point.x * map_edge + point.y
		DemolishTerrain._clear_tunnel_level(altitude, index)

	for entrance in [points[0], points[-1]]:
		var entrance_index: int = entrance.x * map_edge + entrance.y
		NetworkCommand._replace_building(buildings, zones, misc, entrance_index, 0)
		zones[entrance_index] &= 0x0f
		DemolishTerrain._retile_adjacent_roads(buildings, terrain, zones, flags, misc, entrance, map_edge)

	var indices := PackedInt32Array()

	for point in points:
		indices.append(point.x * map_edge + point.y)

	return {"changed": true, "indices": indices, "effect_events": effect_events}


static func _demolish_transport_component(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	start: Vector2i,
	tile_id: int,
	random: SimRandom,
	emit_effects: bool,
	scurk_mode := false,
	map_edge: int = 128,
) -> Dictionary:
	var first := RUNWAY_FIRST if tile_id <= RUNWAY_LAST else PIER_FIRST
	var last := RUNWAY_LAST if tile_id <= RUNWAY_LAST else PIER_LAST
	var make_rubble := first == RUNWAY_FIRST
	var stack: Array[Vector2i] = [start]
	var visited := {}
	var component: Array[Vector2i] = []

	while not stack.is_empty():
		var point: Vector2i = stack.pop_back()

		if visited.has(point):
			continue

		visited[point] = true
		var index := point.x * map_edge + point.y
		var current_id := int(buildings[index])

		if current_id < first or current_id > last:
			continue

		component.append(point)

		for offset in DIRECTIONS:
			var neighbor: Vector2i = point + offset

			if neighbor.x >= 0 and neighbor.x < map_edge and neighbor.y >= 0 and neighbor.y < map_edge:
				stack.append(neighbor)

	var indices := PackedInt32Array()
	var effect_events: Array[Dictionary] = []

	for point in component:
		var index := point.x * map_edge + point.y
		var replacement := 0

		if make_rubble and not scurk_mode:
			replacement = 1 + (random.next_u15() & 3)

		if emit_effects:
			var effect_altitude := (
				DemolishTerrain._land_altitude(altitude, index)
				if make_rubble
				else DemolishEffectsSites._effect_altitude(altitude, flags, index)
			)
			effect_events.append(DemolishEffectsSites._dust_effect(
				point, effect_altitude, random, 0, Vector2i.ZERO
			))

		NetworkCommand._replace_building(buildings, zones, misc, index, replacement)
		zones[index] &= 0x0f
		flags[index] &= FLAG_CLEAR_AFTER_STRUCTURE
		indices.append(index)

	DemolishTerrain._retile_after_demolition(buildings, terrain, zones, underground, flags, misc, component, PackedByteArray(), map_edge)

	return {
		"changed": not component.is_empty(),
		"indices": indices,
		"effect_events": effect_events,
	}


static func _demolish_highway_section(
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
	selected: Vector2i,
	random: SimRandom,
	rotation: int,
	emit_effects: bool,
	scurk_mode := false,
	map_edge: int = 128,
) -> Dictionary:
	var anchor := Vector2i(selected.x & ~1, selected.y & ~1)

	if not HighwayCommand._anchor_is_in_bounds(anchor, map_edge):
		return {"changed": false, "specialized": true}

	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset

		if not _is_highway_tile(buildings[point.x * map_edge + point.y]):
			return {"changed": false, "specialized": true}

	var points: Array[Vector2i] = []
	var indices := PackedInt32Array()
	var effect_events: Array[Dictionary] = []

	if emit_effects:
		effect_events = DemolishEffectsSites._structure_effects(
			altitude, flags, Rect2i(anchor, Vector2i(2, 2)), 2, random, map_edge
		)

	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * map_edge + point.y
		var replacement := 0

		if not scurk_mode and terrain[index] == 0:
			replacement = 1 + (random.next_u15() & 3)

		NetworkCommand._replace_building(buildings, zones, misc, index, replacement)
		zones[index] &= 0x0f
		flags[index] &= FLAG_CLEAR_AFTER_STRUCTURE
		DemolishEffectsSites._release_overlay(text_overlays, labels, microsims, index)
		points.append(point)
		indices.append(index)

	DemolishTerrain._retile_after_demolition(buildings, terrain, zones, underground, flags, misc, points, PackedByteArray(), map_edge)

	var adjacent_sections: Array[Vector2i] = []

	for direction in DIRECTIONS:
		var adjacent: Vector2i = anchor + direction * 2

		if (
			HighwayCommand._anchor_is_in_bounds(adjacent, map_edge)
			and HighwayCommand._section_kind(buildings, zones, flags, adjacent, map_edge) > 1
		):
			adjacent_sections.append(adjacent)

	if not adjacent_sections.is_empty():
		HighwayCommand._retile_affected_sections(
			buildings,
			terrain,
			zones,
			flags,
			altitude,
			misc,
			adjacent_sections,
			rotation,
			text_overlays, {}, map_edge
		)

	return {"changed": true, "indices": indices, "effect_events": effect_events}
