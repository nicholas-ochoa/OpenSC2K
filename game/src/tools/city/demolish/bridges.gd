class_name DemolishBridges
extends DemolishConstants



static func _demolish_bridge(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	selected: Vector2i,
	random: SimRandom = null,
	emit_effects := false,
	map_edge: int = 128,
) -> DemolishPointResult:
	var selected_index := selected.x * map_edge + selected.y
	var direction := Vector2i(1, 0) if (flags[selected_index] & FLAG_FLIPPED) != 0 else Vector2i(0, 1)
	var first := selected

	while DemolishTerrain._point_is_in_bounds(first - direction, map_edge):
		var previous := first - direction
		var previous_id := int(buildings[previous.x * map_edge + previous.y])

		if previous_id < BRIDGE_FIRST or previous_id > BRIDGE_LAST:
			break

		first = previous

	var finish := selected

	while DemolishTerrain._point_is_in_bounds(finish + direction, map_edge):
		var next := finish + direction
		var next_id := int(buildings[next.x * map_edge + next.y])

		if next_id < BRIDGE_FIRST or next_id > BRIDGE_LAST:
			break

		finish = next

	var points: Array[Vector2i] = []
	var indices := PackedInt32Array()
	var effect_events: Array[EffectEvent] = []
	var current := first

	while true:
		var index := current.x * map_edge + current.y

		if emit_effects and random != null:
			effect_events.append(EffectEvent.new(current, BRIDGE_DEBRIS_SPRITE + (random.next_u15() & 3),
				Vector2i.ZERO, (random.next_u15() & 1) != 0, 0, DemolishTerrain._water_altitude(altitude, index)))

		NetworkState.replace_building(buildings, zones, misc, index, Tiles.EMPTY)
		zones[index] &= 0x0f
		flags[index] &= ~FLAG_FLIPPED & 0xff
		points.append(current)
		indices.append(index)

		if current == finish:
			break

		current += direction

	for bank in [first - direction, finish + direction]:
		if not DemolishTerrain._point_is_in_bounds(bank, map_edge):
			continue

		var bank_index: int = bank.x * map_edge + bank.y

		if (flags[bank_index] & FLAG_WATER) != 0:
			continue

		NetworkState.replace_building(buildings, zones, misc, bank_index, Tiles.EMPTY)
		var land := DemolishTerrain._land_altitude(altitude, bank_index)
		DemolishTerrain._set_land_altitude(altitude, bank_index, maxi(0, land - 1))
		flags[bank_index] |= FLAG_WATER
		flags[bank_index] &= ~FLAG_FLIPPED & 0xff
		TerrainRetile.retile_region(
			altitude,
			buildings,
			terrain,
			zones,
			flags,
			misc,
			PackedInt32Array([bank_index]),
			BinaryData.read_u32_be(misc, 0x0e40) & 0x1f, map_edge
		)
		points.append(bank)
		indices.append(bank_index)

	DemolishTerrain._retile_surface_water(terrain, flags, selected, true, map_edge)
	DemolishTerrain._retile_after_demolition(buildings, terrain, zones, underground, flags, misc, points, PackedByteArray(), map_edge)

	var result := DemolishPointResult.new()
	result.changed = true
	result.indices = indices
	result.effect_events = effect_events

	return result


static func _demolish_reinforced_bridge(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	selected: Vector2i,
	random: SimRandom = null,
	emit_effects := false,
	map_edge: int = 128,
) -> DemolishPointResult:
	var anchor := Vector2i(selected.x & ~1, selected.y & ~1)

	if not reinforced_section_is_valid(buildings, anchor, map_edge):
		var result := DemolishPointResult.new()
		result.changed = false
		result.specialized = true

		return result

	var anchor_tile := int(buildings[anchor.x * map_edge + anchor.y])
	# the executable selects the span axis from the section's tile kind
	# this makes 0x6b advance on x and 0x6a advance on y
	var direction := Vector2i(2, 0) if anchor_tile == REINFORCED_BRIDGE_LAST else Vector2i(0, 2)
	var first := anchor

	while reinforced_section_is_valid(buildings, first - direction, map_edge):
		first -= direction

	var finish := anchor

	while reinforced_section_is_valid(buildings, finish + direction, map_edge):
		finish += direction

	var points: Array[Vector2i] = []
	var indices := PackedInt32Array()
	var effect_events: Array[EffectEvent] = []
	var current := first

	while true:
		if emit_effects and random != null:
			var effect_sprite: int = BRIDGE_DEBRIS_SPRITE + (random.next_u15() & 3)
			var current_index := current.x * map_edge + current.y

			for screen_offset in [
				Vector2i(0, 0), Vector2i(16, -8),
				Vector2i(32, 0), Vector2i(32, 8),
			]:
				effect_events.append(EffectEvent.new(current, effect_sprite,
					screen_offset, (random.next_u15() & 1) != 0, 0, DemolishTerrain._water_altitude(altitude, current_index)))

		for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var point: Vector2i = current + offset
			var index := point.x * map_edge + point.y
			NetworkState.replace_building(buildings, zones, misc, index, Tiles.EMPTY)
			zones[index] &= 0x0f
			flags[index] &= ~FLAG_FLIPPED & 0xff
			points.append(point)
			indices.append(index)

		if current == finish:
			break

		current += direction

	# The original changes only the origin cell of the forward bank section
	# on a two-wide bridge. It leaves the bank behind the span alone.
	var bank := finish + direction

	if DemolishTerrain._point_is_in_bounds(bank, map_edge):
		var bank_index := bank.x * map_edge + bank.y

		if (flags[bank_index] & FLAG_WATER) == 0:
			NetworkState.replace_building(buildings, zones, misc, bank_index, Tiles.EMPTY)
			var land := DemolishTerrain._land_altitude(altitude, bank_index)
			DemolishTerrain._set_land_altitude(altitude, bank_index, maxi(0, land - 1))
			flags[bank_index] |= FLAG_WATER
			flags[bank_index] &= ~FLAG_FLIPPED & 0xff
			TerrainRetile.retile_region(
				altitude,
				buildings,
				terrain,
				zones,
				flags,
				misc,
				PackedInt32Array([bank_index]),
				BinaryData.read_u32_be(misc, 0x0e40) & 0x1f, map_edge
			)
			points.append(bank)
			indices.append(bank_index)

	DemolishTerrain._retile_surface_water(terrain, flags, selected, true, map_edge)
	DemolishTerrain._retile_after_demolition(buildings, terrain, zones, underground, flags, misc, points, PackedByteArray(), map_edge)

	var result := DemolishPointResult.new()
	result.changed = true
	result.indices = indices
	result.effect_events = effect_events

	return result


static func reinforced_section_is_valid(
	buildings: PackedByteArray, anchor: Vector2i,
	map_edge: int = 128,
) -> bool:
	if anchor.x < 0 or anchor.y < 0 or anchor.x > map_edge - 2 or anchor.y > map_edge - 2:
		return false

	var tile := int(buildings[anchor.x * map_edge + anchor.y])

	if tile < REINFORCED_BRIDGE_FIRST or tile > REINFORCED_BRIDGE_LAST:
		return false

	for offset in [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset

		if buildings[point.x * map_edge + point.y] != tile:
			return false

	return true
