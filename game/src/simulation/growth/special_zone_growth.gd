class_name SpecialZoneGrowth
extends SpecialZoneConstants


@warning_ignore_start("integer_division")


static func process(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	terrain: PackedByteArray,
	altitudes: PackedInt32Array,
	text_overlays: PackedByteArray,
	things: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	random: SimRandom,
	rotation: int,
	counters: GrowthMaintenanceResult,
	map_edge: int = 128,
) -> void:
	var index := SpecialZoneState._index(point, map_edge)
	var zone := int(zones[index]) & 0x0f
	var current_tile := int(buildings[index])
	var selected_tile := -1
	var fallback_tile := -1

	if zone == 7:
		match SpecialZoneState.read_u32(misc, MISC_MILITARY_BASE_TYPE) & 0xff:
			2:
				if random.next_u15() & 3:
					return

				var parking_count := int(SpecialZoneState._special_tile_count(misc, Tiles.PARKING_LOT_2, true, map_edge) / 4)
				selected_tile = Tiles.PARKING_LOT_2

				if int(SpecialZoneState._special_tile_count(misc, Tiles.HANGAR_1, true, map_edge) / 12) < parking_count:
					selected_tile = Tiles.HANGAR_1

				fallback_tile = Tiles.HANGAR_1
			3:
				selected_tile = SpecialZoneSelection._airport_growth_selection(
					flags, text_overlays, things, misc, point, current_tile,
					true, rotation, random, counters, map_edge
				)
			4:
				selected_tile = SpecialZoneSelection._seaport_growth_selection(
					terrain, text_overlays, things, misc, point, current_tile,
					true, random, counters, map_edge
				)
				fallback_tile = Tiles.SEAPORT_WAREHOUSE
			5:
				if current_tile != Tiles.MISSILE_SILO:
					selected_tile = Tiles.MISSILE_SILO
			_:
				return
	elif zone == 8:
		selected_tile = SpecialZoneSelection._airport_growth_selection(
			flags, text_overlays, things, misc, point, current_tile,
			false, rotation, random, counters, map_edge
		)
	elif zone == 9:
		selected_tile = SpecialZoneSelection._seaport_growth_selection(
			terrain, text_overlays, things, misc, point, current_tile,
			false, random, counters, map_edge
		)
		fallback_tile = Tiles.SEAPORT_WAREHOUSE
	else:
		return

	if selected_tile < 0:
		return

	counters.metrics.special_growth_attempts += 1
	var placed := SpecialZoneSelection.grow_special_zone(
		buildings,
		zones,
		underground,
		flags,
		terrain,
		altitudes,
		misc,
		point,
		selected_tile,
		zone,
		rotation, map_edge,
	)

	if not placed.ok and fallback_tile >= 0:
		placed = SpecialZoneSelection.grow_special_zone(
			buildings, zones, underground, flags, terrain, altitudes, misc,
			point, fallback_tile, zone, rotation, map_edge
		)

	counters.metrics.special_tiles_placed += placed.changed_tiles
