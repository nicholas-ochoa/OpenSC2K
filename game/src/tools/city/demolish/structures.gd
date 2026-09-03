class_name DemolishStructures
extends DemolishConstants



static func structure_area(tile_id: int) -> int:
	return DemolishEffectsSites._building_area(tile_id)


static func damage_structure_payloads(
	city: CityState, payloads: Dictionary, point: Vector2i, random: SimRandom, emit_effects := false
) -> DemolishPointResult:
	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if not payloads.has(chunk_id):
			var result := DemolishPointResult.new()
			result.changed = false
			result.error = "%s payload is missing" % chunk_id

			return result

	var index := city.index_of(point.x, point.y)

	if index < 0 or int(payloads.XBLD[index]) < 6:
		var result := DemolishPointResult.new()
		result.changed = false

		return result

	return _demolish_point(
		city,
		payloads.ALTM,
		payloads.XBLD,
		payloads.XTER,
		payloads.XZON,
		payloads.XUND,
		payloads.XBIT,
		payloads.XTXT,
		payloads.XLAB,
		payloads.XMIC,
		payloads.MISC,
		point,
		random,
		true,
		false,
		emit_effects
	)


static func _demolish_point(
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
	point: Vector2i,
	random: SimRandom,
	force_damage := false,
	retile_neighbors := true,
	emit_effects := true,
	scurk_mode := false
) -> DemolishPointResult:
	var map_edge: int = city.map_size if city != null else 128
	var index := point.x * map_edge + point.y
	var tile_id := int(buildings[index])

	if not force_damage and ((zones[index] & 0x0f) == MILITARY_ZONE or tile_id == RADIOACTIVITY):
		var result := DemolishPointResult.new()
		result.changed = false

		return result

	if not force_damage and OverlayData.read(text_overlays, index) == PROTECTED_CONNECTION_LABEL:
		var result := DemolishPointResult.new()
		result.changed = false

		return result

	if tile_id >= TUNNEL_FIRST and tile_id <= TUNNEL_LAST:
		return DemolishTransport._demolish_tunnel(
			altitude, buildings, terrain, zones, flags, misc, point, tile_id,
			random, emit_effects, false, map_edge
		)

	if tile_id >= BRIDGE_FIRST and tile_id <= BRIDGE_LAST:
		return DemolishBridges._demolish_bridge(
			altitude, buildings, terrain, zones, underground, flags, misc,
			point, random, emit_effects, map_edge
		)

	if tile_id >= REINFORCED_BRIDGE_FIRST and tile_id <= REINFORCED_BRIDGE_LAST:
		return DemolishBridges._demolish_reinforced_bridge(
			altitude, buildings, terrain, zones, underground, flags, misc,
			point, random, emit_effects, map_edge
		)

	if tile_id >= RUNWAY_FIRST and tile_id <= PIER_LAST:
		return DemolishTransport._demolish_transport_component(
			altitude, buildings, terrain, zones, underground, flags, misc,
			point, tile_id, random, emit_effects, scurk_mode, map_edge
		)

	if DemolishTransport._is_highway_tile(tile_id):
		return DemolishTransport._demolish_highway_section(
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
			city.compass_rotation(),
			emit_effects,
			scurk_mode, map_edge
		)

	var was_water := (flags[index] & FLAG_WATER) != 0

	if tile_id == 0:
		if scurk_mode:
			var result := DemolishPointResult.new()
			result.changed = false

			return result

		if terrain[index] < 0x30:
			var result := DemolishPointResult.new()
			result.changed = false

			return result

		DemolishTerrain._remove_surface_water(altitude, buildings, terrain, zones, flags, misc, point, map_edge)

		var result := DemolishPointResult.new()
		result.changed = true
		result.indices = PackedInt32Array([index])

		return result

	if tile_id < 0x0d:
		if not scurk_mode and tile_id >= 0x06 and random.next_u15() % 20 == 0:
			var result := DemolishPointResult.new()
			result.changed = true
			result.easter_event = true
			result.indices = PackedInt32Array()

			return result

		var network_effects: Array[Dictionary] = []

		if tile_id >= 0x06 and emit_effects:
			network_effects.append(DemolishEffectsSites._dust_effect(
				point, DemolishEffectsSites._effect_altitude(altitude, flags, index), random, 0, Vector2i.ZERO
			))

		NetworkState.replace_building(buildings, zones, misc, index, 0)

		if terrain[index] >= 0x30:
			DemolishTerrain._remove_surface_water(altitude, buildings, terrain, zones, flags, misc, point, map_edge)

		DemolishTerrain._retile_after_demolition(
			buildings, terrain, zones, underground, flags, misc, [point], text_overlays, map_edge
		)

		var result := DemolishPointResult.new()
		result.changed = true
		result.indices = PackedInt32Array([index])
		result.effect_events = network_effects

		return result

	var area := DemolishEffectsSites._building_area(tile_id)
	var site := DemolishEffectsSites._find_building_site(buildings, zones, point, tile_id, area, city.compass_rotation(), map_edge)

	if site.size == Vector2i.ZERO:
		var result := DemolishPointResult.new()
		result.changed = false

		return result

	var effect_events: Array[Dictionary] = []

	if emit_effects:
		effect_events = DemolishEffectsSites._structure_effects(altitude, flags, site, area, random, map_edge)

	var indices := PackedInt32Array()
	var changed_points: Array[Vector2i] = []

	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var changed_index := x * map_edge + y
			var rubble := 0

			if not scurk_mode and terrain[changed_index] == 0:
				rubble = 1 + (random.next_u15() & 3)

			NetworkState.replace_building(buildings, zones, misc, changed_index, rubble)
			zones[changed_index] &= 0x0f
			flags[changed_index] &= FLAG_CLEAR_AFTER_STRUCTURE
			DemolishEffectsSites._release_overlay(text_overlays, labels, microsims, changed_index)
			indices.append(changed_index)
			changed_points.append(Vector2i(x, y))

	if tile_id == SUBWAY_STATION or (tile_id >= 0x6c and tile_id <= 0x70):
		BuildingUnderground._replace_underground(
			underground, zones, misc, index, 0
		)

	if REWARD_BIT_BY_TILE.has(tile_id):
		var reward_mask := BuildingState.read_u32_be(misc, MISC_GRANTED_REWARDS)
		BuildingState._write_u32_be(
			misc,
			MISC_GRANTED_REWARDS,
			reward_mask | (1 << int(REWARD_BIT_BY_TILE[tile_id]))
		)

	if retile_neighbors:
		DemolishTerrain._retile_after_demolition(
			buildings,
			terrain,
			zones,
			underground,
			flags,
			misc,
			changed_points,
			text_overlays, map_edge
		)

	if terrain[index] >= 0x30:
		if was_water:
			DemolishTerrain._retile_surface_water(terrain, flags, point, true, map_edge)
		else:
			DemolishTerrain._remove_surface_water(altitude, buildings, terrain, zones, flags, misc, point, map_edge)

	var result := DemolishPointResult.new()
	result.changed = true
	result.indices = indices
	result.effect_events = effect_events

	return result


static func _demolish_underground_point(
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
	point: Vector2i,
	random: SimRandom,
	scurk_mode := false
) -> DemolishPointResult:
	var map_edge: int = city.map_size if city != null else 128
	var index := point.x * map_edge + point.y

	if not scurk_mode and (zones[index] & 0x0f) == MILITARY_ZONE:
		var result := DemolishPointResult.new()
		result.changed = false

		return result

	if not scurk_mode and OverlayData.read(text_overlays, index) == PROTECTED_CONNECTION_LABEL:
		var result := DemolishPointResult.new()
		result.changed = false

		return result

	var altitude_offset := index * 2
	var altitude_word := (
		(altitude[altitude_offset] << 8) | altitude[altitude_offset + 1]
	)
	var tunnel_level := (altitude_word & TUNNEL_MASK) >> 10
	var underground_tile := int(underground[index])

	if (
		underground_tile == 0
		and tunnel_level != 1
		and (flags[index] & BuildingCommand.FLAG_PIPED) == 0
	):
		var result := DemolishPointResult.new()
		result.changed = false

		return result

	if buildings[index] < 0x70:
		flags[index] &= ~BuildingCommand.FLAG_PIPED & 0xff

	var indices := PackedInt32Array([index])
	var effect_events: Array[Dictionary] = []

	if tunnel_level == 1 or underground_tile == 0x23:
		var surface_result := _demolish_point(
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

		for changed_index in surface_result.indices:
			if not indices.has(changed_index):
				indices.append(changed_index)

		effect_events = surface_result.effect_events

	BuildingUnderground._replace_underground(underground, zones, misc, index, 0)
	DemolishTerrain._retile_after_demolition(
		buildings, terrain, zones, underground, flags, misc, [point], text_overlays, map_edge
	)

	var result := DemolishPointResult.new()
	result.changed = true
	result.indices = indices
	result.effect_events = effect_events

	return result
