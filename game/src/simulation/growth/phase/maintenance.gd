class_name GrowthMaintenance
extends GrowthConstants


@warning_ignore_start("integer_division")


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
	counters: Dictionary,
	map_edge: int = 128,
) -> void:
	var index := GrowthState._index(point, map_edge)
	var tile := int(buildings[index])

	if tile < 0x1d or lfsr_random.next_mask(0x7f) != 0:
		return

	if _is_road_budget_tile(tile):
		if _maintenance_fails(misc, 10, random, 100):
			GrowthState.replace_building(buildings, zones, misc, index, 1 + (random.next_u15() & 3))
			flags[index] &= 0x7f
			counters.decayed_roads += 1

		return

	if _is_rail_budget_tile(tile):
		if _maintenance_fails(misc, 13, random, 100):
			GrowthState.replace_building(buildings, zones, misc, index, 1 + (random.next_u15() & 3))
			flags[index] &= 0x7f
			counters.decayed_rails += 1

		return

	if _is_bridge_budget_tile(tile):
		var wind := GrowthState._read_u32(misc, 0x0064) & 0xff

		if _maintenance_fails(misc, 12, random, 50, wind):
			var result: Dictionary

			if tile == 0x6a or tile == 0x6b:
				result = DemolishBridges._demolish_reinforced_bridge(
					altitude, buildings, terrain, zones, underground, flags, misc,
					point, random, true, map_edge
				)
			else:
				result = DemolishBridges._demolish_bridge(
					altitude, buildings, terrain, zones, underground, flags, misc,
					point, random, true, map_edge
				)

			if not result.get("changed", false):
				counters.deferred_bridge_collapses += 1

				return

			GrowthState._sync_altitudes(altitude, altitudes, map_edge)
			counters.collapsed_bridges += 1
			counters.bridge_effects.append_array(result.get("effect_events", []))
			counters.view_center_requests.append(point)
			counters.news_items.append({
				"type": NEWSPAPER_BRIDGE_COLLAPSE,
				"argument": 0,
			})
			counters.sound_events.append(SOUND_EXPLODE)

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
			var replacement := 0

			if flags[highway_index] & 0x04 == 0:
				replacement = 1 + (random.next_u15() & 3)

			GrowthState.replace_building(buildings, zones, misc, highway_index, replacement)
			counters.decayed_highway_tiles += 1


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
	counters: Dictionary,
	map_edge: int = 128,
) -> void:
	var index := GrowthState._index(point, map_edge)

	if tile == 0xed:
		if flags[index] & 0x40 == 0 or lfsr_random.next_mask(3) != 0:
			return

		var train_limit := int(SpecialZoneState.tile_count(misc, 0xed, false, map_edge) / 4)

		if MovingThings.count_type(things, MovingThings.TYPE_TRAIN_ENGINE) < train_limit:
			if MovingThings.spawn_train(
				buildings, things, text_overlays, point, game_random, lfsr_random, map_edge
			):
				counters.spawned_trains += 1

		return

	if tile == 0xf8:
		if flags[index] & 0x40 == 0 or lfsr_random.next_mask(3) != 0:
			return

		var sailboat_limit := int(SpecialZoneState.tile_count(misc, 0xf8, false, map_edge) / 9)

		if MovingThings.count_type(things, MovingThings.TYPE_SAILBOAT) < sailboat_limit:
			counters.spawned_sailboats += MovingThings.spawn_sailboats(
				buildings, flags, things, text_overlays, point, lfsr_random, map_edge
			)

		return

	if tile < 0xfb or tile > 0xfe or zones[index] & 0xf0 != 0x80:
		return

	var label := int(OverlayData.read(text_overlays, index))

	if not OverlayData.is_facility(label):
		return

	var record_offset := OverlayData.facility_record(label) * CityState.MICROSIM_RECORD_SIZE

	if microsims[record_offset] < 0xfb or microsims[record_offset] > 0xfe:
		return

	var coarse_index := CityDataGrid.index(land_value, map_edge, point.x, point.y)
	var value := (
		int(land_value[coarse_index] >> 5)
		- int(crime[coarse_index] >> 5)
		- int(pollution[coarse_index] >> 5)
		+ 12
	)

	if flags[index] & 0x40 == 0:
		value = int(value / 2.0)

	if flags[index] & 0x10 == 0:
		value = int(value / 2.0)

	microsims[record_offset + 1] = clampi(value, 0, 12)
	counters.arcologies_updated += 1


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
	counters: Dictionary,
	map_edge: int = 128,
) -> void:
	if lfsr_random.next_mask(0x7f) != 0:
		return

	var index := GrowthState._index(point, map_edge)
	var old_tile := int(underground[index])

	if not _is_subway_tile(old_tile):
		return

	if not _maintenance_fails(misc, 14, random, 100):
		return

	var replacement := 0

	if old_tile == 0x1f:
		replacement = 0x11
	elif old_tile == 0x20:
		replacement = 0x10
	elif old_tile == 0x23:
		if buildings[index] != 0xe9:
			counters.deferred_station_removals += 1

			return

		var surface_replacement := 0

		if terrain[index] == 0:
			surface_replacement = 1 + (random.next_u15() & 3)

		GrowthState.replace_building(buildings, zones, misc, index, surface_replacement)
		zones[index] &= 0x0f
		flags[index] &= 0x3d
		var overlay := int(OverlayData.read(text_overlays, index))

		if not OverlayData.blocks_thing(overlay) or overlay == 0xfa:
			OverlayData.write(text_overlays, index, 0)

		_replace_underground(underground, zones, misc, index, 0)
		counters.removed_subway_stations += 1
		counters.decayed_subway_tiles += 1

		return

	_replace_underground(underground, zones, misc, index, replacement)
	counters.decayed_subway_tiles += 1


static func _maintenance_fails(
	misc: PackedByteArray,
	budget_index: int,
	random: SimRandom,
	random_range: int,
	additional_value := 0
) -> bool:
	var funding := GrowthState._read_i32(
		misc, MISC_BUDGETS + budget_index * MISC_BUDGET_RECORD_SIZE + 4
	)

	return funding != 100 and additional_value + random.next_u15() % random_range >= funding


static func _is_road_budget_tile(tile: int) -> bool:
	return (
		(tile >= 0x1d and tile <= 0x2b)
		or (tile >= 0x3f and tile <= 0x46)
		or tile == 0x4b
		or tile == 0x4c
		or (tile >= 0x5d and tile <= 0x60)
	)


static func _is_rail_budget_tile(tile: int) -> bool:
	return (
		(tile >= 0x2c and tile <= 0x3e)
		or (tile >= 0x45 and tile <= 0x48)
		or (tile >= 0x6c and tile <= 0x6f)
		or tile == 0x4d
		or tile == 0x4e
	)


static func _is_bridge_budget_tile(tile: int) -> bool:
	return (tile >= 0x51 and tile <= 0x5c) or tile == 0x6a or tile == 0x6b


static func _is_highway_budget_tile(tile: int) -> bool:
	return (tile >= 0x49 and tile <= 0x50) or (tile >= 0x61 and tile <= 0x69)


static func _is_subway_tile(tile: int) -> bool:
	return (
		(tile > 0 and tile < 0x10)
		or tile == 0x1f
		or tile == 0x20
		or tile == 0x22
		or tile == 0x23
	)


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

	if (zones[index] & 0x0f) != 7:
		var count := GrowthState._read_u32(misc, MISC_SUBWAY_COUNT)

		if _is_subway_tile(old_tile):
			count = (count - 1) & (0xffff if underground.size() == 16384 else 0xffffffff)

		if _is_subway_tile(new_tile):
			count = (count + 1) & (0xffff if underground.size() == 16384 else 0xffffffff)

		GrowthState._write_u32(misc, MISC_SUBWAY_COUNT, count)

	underground[index] = new_tile
