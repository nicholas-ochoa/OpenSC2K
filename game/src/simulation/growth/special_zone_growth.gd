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
	counters: Dictionary,
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

				var parking_count := int(SpecialZoneState._special_tile_count(misc, 0xef, true, map_edge) / 4)
				selected_tile = 0xef

				if int(SpecialZoneState._special_tile_count(misc, 0xe8, true, map_edge) / 12) < parking_count:
					selected_tile = 0xe8

				fallback_tile = 0xe8
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
				fallback_tile = 0xe3
			5:
				if current_tile != 0xf9:
					selected_tile = 0xf9
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
		fallback_tile = 0xe3
	else:
		return

	if selected_tile < 0:
		return

	counters.special_growth_attempts += 1
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

	counters.special_tiles_placed += int(placed.get("changed_tiles", 0))
