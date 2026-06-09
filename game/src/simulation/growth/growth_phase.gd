class_name GrowthPhase
extends GrowthConstants



static func run(
	city: CityState,
	random,
	step: int,
	substep: int,
	lfsr_random = null,
	game_random = null
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible random generator is required"}

	if lfsr_random == null:
		lfsr_random = SimLfsrRandom.new(1)

	if (
		not lfsr_random.has_method("next_mask")
		or not lfsr_random.has_method("next_mod")
	):
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	if game_random == null:
		game_random = GameLcgRandom.new(1)

	if not game_random.has_method("next_mod"):
		return {"ok": false, "error": "a compatible game random generator is required"}

	if step < 0 or step > 3 or substep < 0 or substep > 3:
		return {"ok": false, "error": "growth partition is outside the supported range"}

	var span := SimulationTimingSpan.new(city.simulation_slice, TIMING_LABELS)
	span.mark_index(TimingStep.PREPARE)
	var payloads := _payloads(city)

	if payloads.is_empty():
		return {"ok": false, "error": "growth input chunks are missing or have the wrong size"}

	var original := _duplicate_payloads(payloads)
	var altitude: PackedByteArray = payloads.ALTM
	var altitudes := city.altitude_words.duplicate()
	var terrain: PackedByteArray = payloads.XTER
	var buildings: PackedByteArray = payloads.XBLD
	var zones: PackedByteArray = payloads.XZON
	var underground: PackedByteArray = payloads.XUND
	var flags: PackedByteArray = payloads.XBIT
	var text_overlays: PackedByteArray = payloads.XTXT
	var microsims: PackedByteArray = payloads.XMIC
	var things: PackedByteArray = payloads.XTHG
	var traffic: PackedByteArray = payloads.XTRF
	var pollution: PackedByteArray = payloads.XPLT
	var land_value: PackedByteArray = payloads.XVAL
	var crime: PackedByteArray = payloads.XCRM
	var misc: PackedByteArray = payloads.MISC
	var rotation := city.compass_rotation() & 3
	var anchor_mask: int = ANCHOR_MASKS[rotation]
	var counters := {
		"scanned_tiles": 0,
		"rci_tiles": 0,
		"population_added": 0,
		"abandoned_population_added": 0,
		"started_construction": 0,
		"advanced_construction": 0,
		"completed_construction": 0,
		"abandoned_buildings": 0,
		"recovered_buildings": 0,
		"churches_built": 0,
		"successful_trips": 0,
		"failed_trips": 0,
		"bus_passengers": 0,
		"rail_passengers": 0,
		"subway_passengers": 0,
		"decayed_roads": 0,
		"decayed_rails": 0,
		"decayed_highway_tiles": 0,
		"decayed_subway_tiles": 0,
		"collapsed_bridges": 0,
		"removed_subway_stations": 0,
		"deferred_bridge_collapses": 0,
		"deferred_bridge_effects": 0,
		"bridge_effects": [],
		"view_center_requests": [],
		"news_items": [],
		"sound_events": [],
		"deferred_station_removals": 0,
		"special_growth_attempts": 0,
		"special_tiles_placed": 0,
		"arcologies_updated": 0,
		"spawned_airplanes": 0,
		"spawned_helicopters": 0,
		"spawned_ships": 0,
		"spawned_sailboats": 0,
		"spawned_trains": 0,
	}

	span.mark_index(TimingStep.SCAN)
	for x in range(step, map_edge, 4):
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y in range(substep, map_edge, 4):
			if city.simulation_slice != null:
				city.simulation_slice.checkpoint()

			counters.scanned_tiles += 1
			var index := x * map_edge + y
			var zone_byte := int(zones[index])
			var zone := zone_byte & 0x0f

			if zone == 0:
				var maintenance_tile := int(buildings[index])
				span.mark_index(TimingStep.SURFACE)
				_process_surface_maintenance(
					altitude, altitudes, terrain, buildings, zones, underground, flags,
					misc, Vector2i(x, y), random, lfsr_random, counters, map_edge
				)
				span.mark_index(TimingStep.FACILITIES)
				_process_microsim_growth(
					buildings, zones, flags, text_overlays, microsims, things,
					land_value, crime, pollution, misc, Vector2i(x, y), maintenance_tile,
					game_random, lfsr_random, counters, map_edge
				)
				span.mark_index(TimingStep.SUBWAY)
				_process_subway_maintenance(
					terrain, buildings, zones, flags, text_overlays, underground, misc,
					Vector2i(x, y), random, lfsr_random, counters, map_edge
				)
				span.mark_index(TimingStep.SCAN)
				continue

			if zone > 6:
				span.mark_index(TimingStep.SPECIAL_ZONES)
				SpecialZoneGrowth.process(
					buildings,
					zones,
					underground,
					flags,
					terrain,
					altitudes,
					text_overlays,
					things,
					misc,
					Vector2i(x, y),
					random,
					rotation,
					counters, map_edge,
				)
				span.mark_index(TimingStep.SUBWAY)
				_process_subway_maintenance(
					terrain, buildings, zones, flags, text_overlays, underground, misc,
					Vector2i(x, y), random, lfsr_random, counters, map_edge
				)
				span.mark_index(TimingStep.SCAN)
				continue

			var building := int(buildings[index])
			var density := 0
			var status := STATUS_NORMAL

			if building < 0x70:
				if building >= 0x1d or not TransportTrip.has_nearby_transport(buildings, Vector2i(x, y), map_edge):
					span.mark_index(TimingStep.SUBWAY)
					_process_subway_maintenance(
						terrain, buildings, zones, flags, text_overlays, underground, misc,
						Vector2i(x, y), random, lfsr_random, counters, map_edge
					)
					span.mark_index(TimingStep.SCAN)
					continue
			else:
				if building > 0xc5 or zone_byte & anchor_mask == 0:
					span.mark_index(TimingStep.SUBWAY)
					_process_subway_maintenance(
						terrain, buildings, zones, flags, text_overlays, underground, misc,
						Vector2i(x, y), random, lfsr_random, counters, map_edge
					)
					span.mark_index(TimingStep.SCAN)
					continue

				density = _density(building)
				status = _status(building)

			counters.rci_tiles += 1

			var growth_pressure := 0
			var decline_pressure := 4000

			if _has_power(flags, x, y, map_edge):
				span.mark_index(TimingStep.TRIPS)
				var trip := TransportTrip.trace(
					buildings,
					zones,
					underground,
					text_overlays,
					altitudes,
					traffic,
					Vector2i(x, y),
					zone,
					density,
					random,
					100, map_edge,
				)

				if not trip.ok:
					return trip

				if trip.reached_destination:
					counters.successful_trips += 1

					if trip.used_bus:
						counters.bus_passengers += density

					if trip.used_rail:
						counters.rail_passengers += density

					if trip.used_subway:
						counters.subway_passengers += density

					growth_pressure = _read_i32(
						misc, MISC_DEMAND + int(IntegerMath.div_trunc((zone - 1), 2)) * 4
					) + 2000
					decline_pressure = 4000 - growth_pressure
				else:
					counters.failed_trips += 1

			span.mark_index(TimingStep.POPULATION)
			if density > 0 and status == STATUS_NORMAL:
				var population: int = POPULATION_BY_DENSITY[density]
				_add_i32(misc, MISC_ZONE_POPULATIONS + zone * 4, population)
				counters.population_added += population

				if random.next_u15() < int(IntegerMath.div_trunc(decline_pressure, density)):
					_abandon(
						buildings,
						zones,
						flags,
						misc,
						Vector2i(x, y),
						density,
						random.next_u15() & 1,
						random,
						rotation,
						land_value, map_edge,
					)
					counters.abandoned_buildings += 1
					span.mark_index(TimingStep.SUBWAY)
					_process_subway_maintenance(
						terrain, buildings, zones, flags, text_overlays, underground, misc,
						Vector2i(x, y), random, lfsr_random, counters, map_edge
					)
					span.mark_index(TimingStep.SCAN)
					continue

			span.mark_index(TimingStep.COMPLETION)
			if status == STATUS_CONSTRUCTION:
				if random.next_u15() < int(IntegerMath.div_trunc(0x4000, density)):
					if (
						_read_u32(misc, MISC_NORMAL_POPULATION)
						> _read_u32(misc, MISC_TILE_COUNTS + CHURCH_TILE * 4) * 2500
						and (density & 2) != 0
						and zone < 3
					):
						_place_church(buildings, zones, flags, misc, Vector2i(x, y), rotation, map_edge)
						counters.churches_built += 1
					else:
						_place_zone(
							buildings,
							zones,
							flags,
							misc,
							land_value,
							Vector2i(x, y),
							density,
							int(IntegerMath.div_trunc((zone - 1), 2)),
							random,
							rotation, map_edge,
						)

					counters.completed_construction += 1
					span.mark_index(TimingStep.SUBWAY)
					_process_subway_maintenance(
						terrain, buildings, zones, flags, text_overlays, underground, misc,
						Vector2i(x, y), random, lfsr_random, counters, map_edge
					)
					span.mark_index(TimingStep.SCAN)
					continue
			elif status == STATUS_ABANDONED:
				span.mark_index(TimingStep.RECOVERY)
				var abandoned_population: int = POPULATION_BY_DENSITY[density]
				_add_i32(misc, MISC_ZONE_POPULATIONS + 7 * 4, abandoned_population)
				counters.abandoned_population_added += abandoned_population

				if random.next_u15() < int(IntegerMath.div_trunc(growth_pressure * 15, density)):
					_place_zone(
						buildings,
						zones,
						flags,
						misc,
						land_value,
						Vector2i(x, y),
						density,
						int(IntegerMath.div_trunc((zone - 1), 2)),
						random,
						rotation, map_edge,
					)
					counters.recovered_buildings += 1

				span.mark_index(TimingStep.SUBWAY)
				_process_subway_maintenance(
					terrain, buildings, zones, flags, text_overlays, underground, misc,
					Vector2i(x, y), random, lfsr_random, counters, map_edge
				)
				span.mark_index(TimingStep.SCAN)
				continue

			span.mark_index(TimingStep.DENSITY)
			if _can_advance_density(zone_byte, zone, density, land_value, x, y, map_edge):
				if random.next_u15() < int(IntegerMath.div_trunc(growth_pressure * 3, (density + 1))):
					var advanced := _advance_construction(
						buildings,
						zones,
						flags,
						misc,
						land_value,
						altitudes,
						Vector2i(x, y),
						density,
						zone,
						random,
						rotation, map_edge,
					)

					if advanced:
						if density == 0:
							counters.started_construction += 1
						else:
							counters.advanced_construction += 1

			span.mark_index(TimingStep.SUBWAY)
			_process_subway_maintenance(
				terrain, buildings, zones, flags, text_overlays, underground, misc,
				Vector2i(x, y), random, lfsr_random, counters, map_edge
			)
			span.mark_index(TimingStep.SCAN)

	span.mark_index(TimingStep.CHANGES)
	var changed_ids := PackedStringArray()

	for chunk_id in [
		"ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XMIC", "XTHG",
		"XBIT", "XTRF", "MISC",
	]:
		if payloads[chunk_id] != original[chunk_id]:
			changed_ids.append(chunk_id)

	span.mark_index(TimingStep.STORE)
	if not _apply_payloads(city, changed_ids, payloads, original):
		return {"ok": false, "error": "cannot store growth phase data"}

	counters["ok"] = true
	counters["rci_complete"] = true
	counters["complete"] = true
	counters["error"] = ""
	counters["timing"] = span.finish()

	return counters




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
	random,
	lfsr_random,
	counters: Dictionary,
	map_edge: int = 128,
) -> void:
	GrowthMaintenance._process_surface_maintenance(
		altitude, altitudes, terrain, buildings, zones, underground, flags, misc, point, random, lfsr_random,
		counters, map_edge
	)


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
	game_random,
	lfsr_random,
	counters: Dictionary,
	map_edge: int = 128,
) -> void:
	GrowthMaintenance._process_microsim_growth(
		buildings, zones, flags, text_overlays, microsims, things, land_value, crime, pollution, misc, point, tile,
		game_random, lfsr_random, counters, map_edge
	)


static func _process_subway_maintenance(
	terrain: PackedByteArray,
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	underground: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	random,
	lfsr_random,
	counters: Dictionary,
	map_edge: int = 128,
) -> void:
	GrowthMaintenance._process_subway_maintenance(
		terrain, buildings, zones, flags, text_overlays, underground, misc, point, random, lfsr_random, counters,
		map_edge
	)


static func _maintenance_fails(
	misc: PackedByteArray,
	budget_index: int,
	random,
	random_range: int,
	additional_value := 0
) -> bool:
	return GrowthMaintenance._maintenance_fails(misc, budget_index, random, random_range, additional_value)


static func _is_road_budget_tile(tile: int) -> bool:
	return GrowthMaintenance._is_road_budget_tile(tile)


static func _is_rail_budget_tile(tile: int) -> bool:
	return GrowthMaintenance._is_rail_budget_tile(tile)


static func _is_bridge_budget_tile(tile: int) -> bool:
	return GrowthMaintenance._is_bridge_budget_tile(tile)


static func _is_highway_budget_tile(tile: int) -> bool:
	return GrowthMaintenance._is_highway_budget_tile(tile)


static func _is_subway_tile(tile: int) -> bool:
	return GrowthMaintenance._is_subway_tile(tile)


static func _replace_underground(
	underground: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	GrowthMaintenance._replace_underground(underground, zones, misc, index, new_tile)


static func _can_advance_density(
	zone_byte: int,
	zone: int,
	density: int,
	land_value: PackedByteArray,
	x: int,
	y: int,
	map_edge: int = 128,
) -> bool:
	return GrowthConstruction._can_advance_density(zone_byte, zone, density, land_value, x, y, map_edge)


static func _advance_construction(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	land_value: PackedByteArray,
	altitudes: PackedInt32Array,
	point: Vector2i,
	density: int,
	zone: int,
	random,
	rotation: int,
	map_edge: int = 128,
) -> bool:
	return GrowthConstruction._advance_construction(
		buildings, zones, flags, misc, land_value, altitudes, point, density, zone, random, rotation, map_edge
	)


static func _advance_to_density_four(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	land_value: PackedByteArray,
	altitudes: PackedInt32Array,
	point: Vector2i,
	zone: int,
	random,
	rotation: int,
	map_edge: int = 128,
) -> bool:
	return GrowthConstruction._advance_to_density_four(
		buildings, zones, flags, misc, land_value, altitudes, point, zone, random, rotation, map_edge
	)


static func _has_density_four_road(buildings: PackedByteArray, anchor: Vector2i, map_edge: int = 128) -> bool:
	return GrowthConstruction._has_density_four_road(buildings, anchor, map_edge)


static func _clear_growth_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	land_value: PackedByteArray,
	point: Vector2i,
	random,
	rotation: int,
	map_edge: int = 128,
) -> void:
	GrowthConstruction._clear_growth_building(buildings, zones, flags, misc, land_value, point, random, rotation, map_edge)


static func _can_build_site(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	altitudes: PackedInt32Array,
	point: Vector2i,
	height: int,
	zone: int,
	maximum_building: int,
	map_edge: int = 128,
) -> bool:
	return GrowthConstruction._can_build_site(buildings, zones, altitudes, point, height, zone, maximum_building, map_edge)


static func _is_surface_network(tile: int) -> bool:
	return GrowthConstruction._is_surface_network(tile)


static func _abandon(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	density: int,
	pattern: int,
	random,
	rotation: int,
	land_value: PackedByteArray,
	map_edge: int = 128,
) -> void:
	GrowthDevelopment._abandon(buildings, zones, flags, misc, point, density, pattern, random, rotation, land_value, map_edge)


static func _place_zone(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	land_value: PackedByteArray,
	anchor: Vector2i,
	density: int,
	building_class: int,
	random,
	rotation: int,
	map_edge: int = 128,
) -> bool:
	return GrowthDevelopment._place_zone(
		buildings, zones, flags, misc, land_value, anchor, density, building_class, random, rotation, map_edge
	)


static func _place_church(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	rotation: int,
	map_edge: int = 128,
) -> bool:
	return GrowthDevelopment._place_church(buildings, zones, flags, misc, anchor, rotation, map_edge)


# The zone and building corner flags share one byte.
static func _set_corners(
	zones: PackedByteArray, position: Vector2i, area: int, rotation: int,
	map_edge: int = 128,
) -> void:
	GrowthDevelopment._set_corners(zones, position, area, rotation, map_edge)


static func _has_power(flags: PackedByteArray, x: int, y: int, map_edge: int = 128) -> bool:
	return GrowthDevelopment._has_power(flags, x, y, map_edge)


static func _density(tile: int) -> int:
	return GrowthDevelopment._density(tile)


static func _status(tile: int) -> int:
	return GrowthDevelopment._status(tile)


static func _replace_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	GrowthState._replace_building(buildings, zones, misc, index, new_tile)


static func _payloads(city: CityState) -> Dictionary:
	return GrowthState._payloads(city)


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary:
	return GrowthState._duplicate_payloads(payloads)


static func _apply_payloads(
	city: CityState,
	chunk_ids: PackedStringArray,
	payloads: Dictionary,
	rollback: Dictionary
) -> bool:
	return GrowthState._apply_payloads(city, chunk_ids, payloads, rollback)


static func _refresh_city(city: CityState) -> void:
	GrowthState._refresh_city(city)


static func _sync_altitudes(altitude: PackedByteArray, altitudes: PackedInt32Array, map_edge: int = 128) -> void:
	GrowthState._sync_altitudes(altitude, altitudes, map_edge)


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	return GrowthState._index(point, map_edge)


static func _add_i32(data: PackedByteArray, offset: int, value: int) -> void:
	GrowthState._add_i32(data, offset, value)


static func _read_i32(data: PackedByteArray, offset: int) -> int:
	return GrowthState._read_i32(data, offset)


static func _read_u32(data: PackedByteArray, offset: int) -> int:
	return GrowthState._read_u32(data, offset)


static func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	GrowthState._write_u32(data, offset, value)
