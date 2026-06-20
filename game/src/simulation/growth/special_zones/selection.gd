class_name SpecialZoneSelection
extends SpecialZoneConstants



static func _airport_growth_selection(
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	things: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	current_tile: int,
	military: bool,
	rotation: int,
	random,
	counters: Dictionary,
	map_edge: int = 128,
) -> int:
	if random.next_u15() & 3:
		if military or current_tile != 0xdd or random.next_u15() % 30 != 0:
			return -1

		if flags[SpecialZoneState._index(point, map_edge)] & 0x40 == 0:
			return -1

		if random.next_u15() % 10 < 4:
			var helicopter := MovingThings.spawn_helicopter(
				things, text_overlays, point, random, map_edge
			)

			if helicopter.spawned:
				counters.spawned_helicopters += 1
		else:
			var runway_axis := 2 if bool(flags[SpecialZoneState._index(point, map_edge)] & 0x02) != bool(rotation & 1) else 0
			var airplane := MovingThings.spawn_airplane(
				things, text_overlays, point, runway_axis, random, map_edge
			)

			if airplane.spawned:
				counters.spawned_airplanes += 1

		return -1

	var runway_groups := int(
		IntegerMath.div_trunc((SpecialZoneState._special_tile_count(misc, 0xdd, military, map_edge) + SpecialZoneState._special_tile_count(misc, 0xde, military, map_edge)), 5)
	)
	var parking_tile := 0xef if military else 0xee

	if int(IntegerMath.div_trunc(SpecialZoneState._special_tile_count(misc, parking_tile, military, map_edge), 4)) >= runway_groups:
		return 0xdd

	var selected := 0xe2 if military else 0xe1

	if SpecialZoneState._special_tile_count(misc, selected, military, map_edge) * 2 < runway_groups:
		return selected

	selected = 0xea

	if SpecialZoneState._special_tile_count(misc, selected, military, map_edge) * 2 < runway_groups:
		return selected

	selected = 0xe7 if military else 0xe6

	if SpecialZoneState._special_tile_count(misc, selected, military, map_edge) < runway_groups:
		return selected

	selected = 0xe4

	if int(IntegerMath.div_trunc(SpecialZoneState._special_tile_count(misc, selected, military, map_edge), 2)) < runway_groups:
		return selected

	selected = 0xe5

	if int(IntegerMath.div_trunc(SpecialZoneState._special_tile_count(misc, selected, military, map_edge), 2)) < runway_groups:
		return selected

	if int(IntegerMath.div_trunc(SpecialZoneState._special_tile_count(misc, 0xf6, military, map_edge), 4)) < runway_groups:
		return 0xf6

	return parking_tile


static func _seaport_growth_selection(
	terrain: PackedByteArray,
	text_overlays: PackedByteArray,
	things: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	current_tile: int,
	military: bool,
	random,
	counters: Dictionary,
	map_edge: int = 128,
) -> int:
	if random.next_u15() & 3:
		if not military and current_tile == 0xe0 and random.next_u15() & 3 == 0:
			var ship := MovingThings.spawn_ship(
				terrain, things, text_overlays, point, random, map_edge
			)

			if ship.spawned:
				counters.spawned_ships += 1
				counters["ship_home"] = ship.point
				counters.sound_events.append({
					"sound_id": SOUND_SHIP,
					"thing_type": 3,
					"record": int(ship.record),
					"point": ship.point,
				})

		return -1

	var crane_count := SpecialZoneState._special_tile_count(misc, 0xe0, military, map_edge)

	if int(IntegerMath.div_trunc(SpecialZoneState._special_tile_count(misc, 0xf2, military, map_edge), 4)) >= crane_count:
		return 0xe0

	var second_tile := 0xf1 if military else 0xf0

	if int(IntegerMath.div_trunc(SpecialZoneState._special_tile_count(misc, second_tile, military, map_edge), 4)) < crane_count:
		return second_tile

	if int(IntegerMath.div_trunc(SpecialZoneState._special_tile_count(misc, 0xe3, military, map_edge), 3)) < crane_count:
		return 0xe3

	return 0xf2


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
	if zone != 7 and not SpecialZoneState._has_power(flags, point.x, point.y, map_edge):
		return {"ok": false, "changed_tiles": 0}

	if tile == 0xdd:
		return SpecialZonePlacement._place_runway(
			buildings, zones, flags, misc, point, zone, rotation, map_edge, terrain, underground
		)

	if tile == 0xe0:
		return SpecialZonePlacement._place_crane_and_pier(
			buildings, zones, flags, terrain, altitudes,
			misc, point, zone, rotation, map_edge
		)

	if SPECIAL_SIMPLE_TILES.has(tile):
		var before := int(buildings[SpecialZoneState._index(point, map_edge)])

		if before < 0x0d:
			SpecialZonePlacement._place_special_item(
				buildings, zones, flags, terrain, misc, point, tile, 1, zone, rotation, map_edge
			)

		zones[SpecialZoneState._index(point, map_edge)] = (zones[SpecialZoneState._index(point, map_edge)] & 0xf0) | zone

		if zone == 7:
			flags[SpecialZoneState._index(point, map_edge)] &= 0x0f

		return {"ok": true, "changed_tiles": int(buildings[SpecialZoneState._index(point, map_edge)] != before)}

	if SPECIAL_TWO_BY_TWO_TILES.has(tile):
		return SpecialZonePlacement._place_special_two_by_two(
			buildings, zones, flags, terrain, misc, point, tile, zone, rotation, map_edge, underground
		)

	if tile == 0xf9:
		return SpecialZonePlacement._place_missile_silo(
			buildings, zones, underground, misc, point, zone, rotation, map_edge
		)

	return {"ok": true, "changed_tiles": 0}
