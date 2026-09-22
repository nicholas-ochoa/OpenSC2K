class_name GrowthMaintenance
extends GrowthConstants


@warning_ignore_start("integer_division")


const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")

static func _process_surface_maintenance(
	altitude: PackedByteArray,
	altitudes: PackedInt32Array,
	terrain: PackedByteArray,
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	counters: GrowthMaintenanceResult,
	map_edge: int = 128,
) -> void:
	var index := GrowthState._index(point, map_edge)
	var tile := int(buildings[index])

	if tile < Tiles.FIRST_ROAD or lfsr_random.next_mask(0x7f) != 0:
		return

	if NetworkTileMembership.surface_road(tile):
		if _maintenance_fails(misc, 10, random, 100):
			GrowthState.replace_building(buildings, zones, misc, index, Tiles.RUBBLE_FIRST + (random.next_u15() & 3))
			flags[index] &= ~Sc2TileFlags.POWERABLE & 0xff
			counters.metrics.decayed_roads += 1

		return

	if NetworkTileMembership.rail(tile):
		if _maintenance_fails(misc, 13, random, 100):
			GrowthState.replace_building(buildings, zones, misc, index, Tiles.RUBBLE_FIRST + (random.next_u15() & 3))
			flags[index] &= ~Sc2TileFlags.POWERABLE & 0xff
			counters.metrics.decayed_rails += 1

		return

	if _is_bridge_budget_tile(tile):
		var wind := BinaryData.read_u32_be(misc, Sc2MiscLayout.WEATHER_WIND) & 0xff

		if _maintenance_fails(misc, 12, random, 50, wind):
			var result: DemolishPointResult

			if tile == Tiles.HIGHWAY_BRIDGE or tile == Tiles.REINFORCED_HIGHWAY_BRIDGE:
				result = DemolishBridges._demolish_reinforced_bridge(
					altitude, buildings, terrain, zones, underground, flags, misc,
					point, random, true, map_edge
				)
			else:
				result = DemolishBridges._demolish_bridge(
					altitude, buildings, terrain, zones, underground, flags, misc,
					point, random, true, map_edge
				)

			if not result.changed:
				counters.metrics.deferred_bridge_collapses += 1

				return

			GrowthState._sync_altitudes(altitude, altitudes, map_edge)
			counters.metrics.collapsed_bridges += 1
			counters.bridge_effects.append_array(result.effect_events)
			counters.view_center_requests.append(point)
			counters.news_items.append(NewsEvent.new(NEWSPAPER_BRIDGE_COLLAPSE, 0))
			counters.sound_events.append(SoundEvent.new(SOUND_EXPLODE))

		return

	if _is_highway_budget_tile(tile):
		if point.x & 1 or point.y & 1:
			return

		if not _maintenance_fails(misc, 11, random, 100):
			return

		for highway_point in [
			point,
			point + Vector2i(1, 0),
			point + Vector2i(0, 1),
			point + Vector2i(1, 1),
		]:
			var highway_index := GrowthState._index(highway_point, map_edge)
			var replacement := Tiles.EMPTY

			if flags[highway_index] & Sc2TileFlags.WATER == 0:
				replacement = Tiles.RUBBLE_FIRST + (random.next_u15() & 3)

			GrowthState.replace_building(buildings, zones, misc, highway_index, replacement)
			counters.metrics.decayed_highway_tiles += 1


static func _process_microsim_growth(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	microsims: PackedByteArray,
	things: PackedByteArray,
	land_value: PackedByteArray,
	crime: PackedByteArray,
	pollution: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	tile: int,
	game_random: GameLcgRandom,
	lfsr_random: SimLfsrRandom,
	counters: GrowthMaintenanceResult,
	map_edge: int = 128,
) -> void:
	var index := GrowthState._index(point, map_edge)

	if tile == Tiles.RAIL_STATION:
		if flags[index] & Sc2TileFlags.POWERED == 0 or lfsr_random.next_mask(3) != 0:
			return

		var train_limit := int(SpecialZoneState.tile_count(misc, Tiles.RAIL_STATION, false, map_edge) / 4)

		if MovingThings.count_type(things, MovingThings.TYPE_TRAIN_ENGINE) < train_limit:
			if MovingThings.spawn_train(
				buildings, things, text_overlays, point, game_random, lfsr_random, map_edge
			):
				counters.metrics.spawned_trains += 1

		return

	if tile == Tiles.MARINA:
		if flags[index] & Sc2TileFlags.POWERED == 0 or lfsr_random.next_mask(3) != 0:
			return

		var sailboat_limit := int(SpecialZoneState.tile_count(misc, Tiles.MARINA, false, map_edge) / 9)

		if MovingThings.count_type(things, MovingThings.TYPE_SAILBOAT) < sailboat_limit:
			counters.metrics.spawned_sailboats += MovingThings.spawn_sailboats(
				buildings, flags, things, text_overlays, point, lfsr_random, map_edge
			)

		return

	if tile < Tiles.PLYMOUTH_ARCOLOGY or tile > Tiles.LAUNCH_ARCOLOGY or zones[index] & ZONE_CORNERS_MASK != CORNER_TOP_RIGHT[0]:
		return

	var label := int(OverlayData.read(text_overlays, index))

	if not OverlayData.is_facility(label):
		return

	var record_offset := OverlayData.facility_record(label) * CityState.MICROSIM_RECORD_SIZE

	if microsims[record_offset] < Tiles.PLYMOUTH_ARCOLOGY or microsims[record_offset] > Tiles.LAUNCH_ARCOLOGY:
		return

	var coarse_index := CityDataGrid.index(land_value, map_edge, point.x, point.y)
	var value := (
		int(land_value[coarse_index] >> 5)
		- int(crime[coarse_index] >> 5)
		- int(pollution[coarse_index] >> 5)
		+ 12
	)

	if flags[index] & Sc2TileFlags.POWERED == 0:
		value = int(value / 2.0)

	if flags[index] & Sc2TileFlags.WATERED == 0:
		value = int(value / 2.0)

	microsims[record_offset + 1] = clampi(value, 0, 12)
	counters.metrics.arcologies_updated += 1


static func _process_subway_maintenance(
	terrain: PackedByteArray,
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	underground: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	counters: GrowthMaintenanceResult,
	map_edge: int = 128,
) -> void:
	if lfsr_random.next_mask(0x7f) != 0:
		return

	var index := GrowthState._index(point, map_edge)
	var old_tile := int(underground[index])

	if not NetworkTileMembership.subway(old_tile):
		return

	if not _maintenance_fails(misc, 14, random, 100):
		return

	var replacement := UnderTiles.EMPTY

	if old_tile == UnderTiles.PIPE_TB_SUBWAY_LR:
		replacement = UnderTiles.PIPE_TB
	elif old_tile == UnderTiles.PIPE_LR_SUBWAY_TB:
		replacement = UnderTiles.PIPE_LR
	elif old_tile == UnderTiles.SUBWAY_ENTRANCE:
		if buildings[index] != Tiles.SUBWAY_STATION:
			counters.metrics.deferred_station_removals += 1

			return

		var surface_replacement := Tiles.EMPTY

		if terrain[index] == TerrainTileIds.FLAT:
			surface_replacement = Tiles.RUBBLE_FIRST + (random.next_u15() & 3)

		GrowthState.replace_building(buildings, zones, misc, index, surface_replacement)
		zones[index] &= Sc2ZoneLayout.TYPE_MASK
		flags[index] &= ~(Sc2TileFlags.FLIPPED | Sc2TileFlags.POWER_MASK) & 0xff
		var overlay := int(OverlayData.read(text_overlays, index))

		if not OverlayData.blocks_thing(overlay) or overlay == NetworkConstants.CONNECTION_LABEL:
			OverlayData.write(text_overlays, index, 0)

		_replace_underground(underground, zones, misc, index, UnderTiles.EMPTY)
		counters.metrics.removed_subway_stations += 1
		counters.metrics.decayed_subway_tiles += 1

		return

	_replace_underground(underground, zones, misc, index, replacement)
	counters.metrics.decayed_subway_tiles += 1


static func _maintenance_fails(
	misc: PackedByteArray,
	budget_index: int,
	random: SimRandom,
	random_range: int,
	additional_value := 0
) -> bool:
	var funding := BinaryData.read_i32_be(
		misc, MISC_BUDGETS + budget_index * MISC_BUDGET_RECORD_SIZE + 4
	)

	return funding != 100 and additional_value + random.next_u15() % random_range >= funding


static func _is_bridge_budget_tile(tile: int) -> bool:
	return (tile >= Tiles.SUSPENSION_BRIDGE_1 and tile <= Tiles.POWER_BRIDGE) or tile == Tiles.HIGHWAY_BRIDGE or tile == Tiles.REINFORCED_HIGHWAY_BRIDGE


static func _is_highway_budget_tile(tile: int) -> bool:
	return (tile >= Tiles.HIGHWAY_STRAIGHT_1 and tile <= Tiles.HIGHWAY_POWER_CROSSING_2) or (tile >= Tiles.HIGHWAY_SLOPE_FIRST and tile <= Tiles.HIGHWAY_INTERSECTION)


static func _replace_underground(
	underground: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	var old_tile := int(underground[index])

	if old_tile == new_tile:
		return

	if (zones[index] & Sc2ZoneLayout.TYPE_MASK) != 7:
		var count := BinaryData.read_u32_be(misc, MISC_SUBWAY_COUNT)

		if NetworkTileMembership.subway(old_tile):
			count = (count - 1) & (0xffff if underground.size() == 16384 else 0xffffffff)

		if NetworkTileMembership.subway(new_tile):
			count = (count + 1) & (0xffff if underground.size() == 16384 else 0xffffffff)

		BinaryData.write_u32_be(misc, MISC_SUBWAY_COUNT, count)

	underground[index] = new_tile
