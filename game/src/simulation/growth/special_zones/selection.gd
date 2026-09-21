class_name SpecialZoneSelection
extends SpecialZoneConstants


@warning_ignore_start("integer_division")


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
	counters: GrowthMaintenanceResult,
	map_edge: int = 128,
) -> int:
	if random.next_u15() & 3:
		if military or current_tile != Tiles.RUNWAY or random.next_u15() % 30 != 0:
			return -1

		if flags[SpecialZoneState._index(point, map_edge)] & 0x40 == 0:
			return -1

		if random.next_u15() % 10 < 4:
			var helicopter := MovingThings.spawn_helicopter(
				things, text_overlays, point, random, map_edge
			)

			if helicopter.spawned:
				counters.metrics.spawned_helicopters += 1
		else:
			var runway_axis := 2 if bool(flags[SpecialZoneState._index(point, map_edge)] & 0x02) != bool(rotation & 1) else 0
			var airplane := MovingThings.spawn_airplane(
				things, text_overlays, point, runway_axis, random, map_edge
			)

			if airplane.spawned:
				counters.metrics.spawned_airplanes += 1

		return -1

	var runway_groups := int(
		((SpecialZoneState._special_tile_count(misc, Tiles.RUNWAY, military, map_edge) + SpecialZoneState._special_tile_count(misc, Tiles.RUNWAY_CROSSING, military, map_edge)) / 5)
	)
	var parking_tile := Tiles.PARKING_LOT_2 if military else Tiles.PARKING_LOT_1

	if int(SpecialZoneState._special_tile_count(misc, parking_tile, military, map_edge) / 4) >= runway_groups:
		return Tiles.RUNWAY

	var selected := Tiles.CONTROL_TOWER_2 if military else Tiles.CONTROL_TOWER_1

	if SpecialZoneState._special_tile_count(misc, selected, military, map_edge) * 2 < runway_groups:
		return selected

	selected = Tiles.RADAR

	if SpecialZoneState._special_tile_count(misc, selected, military, map_edge) * 2 < runway_groups:
		return selected

	selected = Tiles.FIGHTER_JET if military else Tiles.TARMAC

	if SpecialZoneState._special_tile_count(misc, selected, military, map_edge) < runway_groups:
		return selected

	selected = Tiles.AIRPORT_BUILDING_1

	if int(SpecialZoneState._special_tile_count(misc, selected, military, map_edge) / 2) < runway_groups:
		return selected

	selected = Tiles.AIRPORT_BUILDING_2

	if int(SpecialZoneState._special_tile_count(misc, selected, military, map_edge) / 2) < runway_groups:
		return selected

	if int(SpecialZoneState._special_tile_count(misc, Tiles.HANGAR_2, military, map_edge) / 4) < runway_groups:
		return Tiles.HANGAR_2

	return parking_tile


static func _seaport_growth_selection(
	terrain: PackedByteArray,
	text_overlays: PackedByteArray,
	things: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	current_tile: int,
	military: bool,
	random: SimRandom,
	counters: GrowthMaintenanceResult,
	map_edge: int = 128,
) -> int:
	if random.next_u15() & 3:
		if not military and current_tile == Tiles.CRANE and random.next_u15() & 3 == 0:
			var ship := MovingThings.spawn_ship(
				terrain, things, text_overlays, point, random, map_edge
			)

			if ship.spawned:
				counters.metrics.spawned_ships += 1
				counters.ship_home_found = true
				counters.ship_home = ship.point
				counters.sound_events.append(SoundEvent.for_thing(SOUND_SHIP, 3, int(ship.record),
					ship.point))

		return -1

	var crane_count := SpecialZoneState._special_tile_count(misc, Tiles.CRANE, military, map_edge)

	if int(SpecialZoneState._special_tile_count(misc, Tiles.CARGO_YARD, military, map_edge) / 4) >= crane_count:
		return Tiles.CRANE

	var second_tile := Tiles.TOP_SECRET if military else Tiles.LOADING_BAY

	if int(SpecialZoneState._special_tile_count(misc, second_tile, military, map_edge) / 4) < crane_count:
		return second_tile

	if int(SpecialZoneState._special_tile_count(misc, Tiles.SEAPORT_WAREHOUSE, military, map_edge) / 3) < crane_count:
		return Tiles.SEAPORT_WAREHOUSE

	return Tiles.CARGO_YARD


static func grow_special_zone(
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
) -> SpecialZonePlacement.Result:
	if zone != 7 and not SpecialZoneState._has_power(flags, point.x, point.y, map_edge):
		var result := SpecialZonePlacement.Result.new()
		result.ok = false
		result.changed_tiles = 0

		return result

	if tile == Tiles.RUNWAY:
		return SpecialZonePlacement._place_runway(
			buildings, zones, flags, misc, point, zone, rotation, map_edge, terrain, underground
		)

	if tile == Tiles.CRANE:
		return SpecialZonePlacement._place_crane_and_pier(
			buildings, zones, flags, terrain, altitudes,
			misc, point, zone, rotation, map_edge
		)

	if SPECIAL_SIMPLE_TILES.has(tile):
		var before := int(buildings[SpecialZoneState._index(point, map_edge)])

		if before < 0x0d:
			SpecialZonePlacement.place_special_item(
				buildings, zones, flags, terrain, misc, point, tile, 1, zone, rotation, map_edge
			)

		zones[SpecialZoneState._index(point, map_edge)] = (zones[SpecialZoneState._index(point, map_edge)] & 0xf0) | zone

		if zone == 7:
			flags[SpecialZoneState._index(point, map_edge)] &= 0x0f

		var result := SpecialZonePlacement.Result.new()
		result.ok = true
		result.changed_tiles = int(buildings[SpecialZoneState._index(point, map_edge)] != before)

		return result

	if SPECIAL_TWO_BY_TWO_TILES.has(tile):
		return SpecialZonePlacement._place_special_two_by_two(
			buildings, zones, flags, terrain, misc, point, tile, zone, rotation, map_edge, underground
		)

	if tile == Tiles.MISSILE_SILO:
		return SpecialZonePlacement.place_missile_silo(
			buildings, zones, underground, misc, point, zone, rotation, map_edge
		)

	var result := SpecialZonePlacement.Result.new()
	result.ok = true
	result.changed_tiles = 0

	return result
