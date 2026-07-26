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
		match SpecialZoneState._read_u32(misc, MISC_MILITARY_BASE_TYPE) & 0xff:
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
	var placed := SpecialZoneSelection._grow_special_zone(
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
		placed = SpecialZoneSelection._grow_special_zone(
			buildings, zones, underground, flags, terrain, altitudes, misc,
			point, fallback_tile, zone, rotation, map_edge
		)

	counters.special_tiles_placed += int(placed.get("changed_tiles", 0))


static func _airport_growth_selection(
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	things: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	current_tile: int,
	military: bool,
	rotation: int,
	random: SimRandom,
	counters: Dictionary,
	map_edge: int = 128,
) -> int:
	return SpecialZoneSelection._airport_growth_selection(
		flags, text_overlays, things, misc, point, current_tile, military, rotation, random, counters, map_edge
	)


static func _seaport_growth_selection(
	terrain: PackedByteArray,
	text_overlays: PackedByteArray,
	things: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	current_tile: int,
	military: bool,
	random: SimRandom,
	counters: Dictionary,
	map_edge: int = 128,
) -> int:
	return SpecialZoneSelection._seaport_growth_selection(
		terrain, text_overlays, things, misc, point, current_tile, military, random, counters, map_edge
	)


static func _grow_special_zone(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	terrain: PackedByteArray,
	altitudes: PackedInt32Array,
	misc: PackedByteArray,
	point: Vector2i,
	tile: int,
	zone: int,
	rotation: int,
	map_edge: int = 128,
) -> Dictionary:
	return SpecialZoneSelection._grow_special_zone(
		buildings, zones, underground, flags, terrain, altitudes, misc, point, tile, zone, rotation, map_edge
	)


static func _place_runway(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	zone: int,
	rotation: int,
	map_edge: int = 128,
	terrain: PackedByteArray = PackedByteArray(),
	underground: PackedByteArray = PackedByteArray(),
) -> Dictionary:
	return SpecialZonePlacement._place_runway(
		buildings, zones, flags, misc, point, zone, rotation, map_edge, terrain, underground
	)


static func _place_crane_and_pier(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	terrain: PackedByteArray,
	altitudes: PackedInt32Array,
	misc: PackedByteArray,
	point: Vector2i,
	zone: int,
	rotation: int,
	map_edge: int = 128,
) -> Dictionary:
	return SpecialZonePlacement._place_crane_and_pier(
		buildings, zones, flags, terrain, altitudes, misc, point, zone, rotation, map_edge
	)


static func _place_special_two_by_two(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	terrain: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	tile: int,
	zone: int,
	rotation: int,
	map_edge: int = 128,
	underground: PackedByteArray = PackedByteArray(),
) -> Dictionary:
	return SpecialZonePlacement._place_special_two_by_two(
		buildings, zones, flags, terrain, misc, point, tile, zone, rotation, map_edge, underground
	)


static func _place_special_item(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	terrain: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	tile: int,
	area: int,
	zone: int,
	rotation: int,
	map_edge: int = 128,
) -> bool:
	return SpecialZonePlacement._place_special_item(
		buildings, zones, flags, terrain, misc, anchor, tile, area, zone, rotation, map_edge
	)


static func _place_missile_silo(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	zone: int,
	rotation: int,
	map_edge: int = 128,
) -> Dictionary:
	return SpecialZonePlacement._place_missile_silo(buildings, zones, underground, misc, point, zone, rotation, map_edge)


static func _clear_special_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	SpecialZonePlacement._clear_special_building(buildings, zones, flags, misc, point, map_edge)


static func replace_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	SpecialZoneState.replace_building(buildings, zones, misc, index, new_tile)


static func _replace_special_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	SpecialZoneState._replace_special_building(buildings, zones, misc, index, new_tile)


static func tile_count(misc: PackedByteArray, tile: int, military: bool, map_edge: int = 128) -> int:
	return SpecialZoneState.tile_count(misc, tile, military, map_edge)


static func _special_tile_count(misc: PackedByteArray, tile: int, military: bool, map_edge: int = 128) -> int:
	return SpecialZoneState._special_tile_count(misc, tile, military, map_edge)


static func _special_count_offset(tile: int, military: bool) -> int:
	return SpecialZoneState._special_count_offset(tile, military)


static func _special_axis_is_flipped(x_delta: int, rotation: int) -> bool:
	return SpecialZoneState._special_axis_is_flipped(x_delta, rotation)


static func _is_subway_tile(tile: int) -> bool:
	return SpecialZoneState._is_subway_tile(tile)


static func _replace_underground(
	underground: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	SpecialZoneState._replace_underground(underground, zones, misc, index, new_tile)


# The zone and building corner flags share one byte.
static func _set_corners(
	zones: PackedByteArray, position: Vector2i, area: int, rotation: int,
	map_edge: int = 128,
) -> void:
	SpecialZoneState._set_corners(zones, position, area, rotation, map_edge)


static func _has_power(flags: PackedByteArray, x: int, y: int, map_edge: int = 128) -> bool:
	return SpecialZoneState._has_power(flags, x, y, map_edge)


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	return SpecialZoneState._index(point, map_edge)


static func _read_u32(data: PackedByteArray, offset: int) -> int:
	return SpecialZoneState._read_u32(data, offset)


static func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	SpecialZoneState._write_u32(data, offset, value)
