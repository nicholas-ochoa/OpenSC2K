class_name GrowthScan
extends GrowthConstants
# run the growth partition in its original scan and random-call order

@warning_ignore_start("integer_division")


# payload aliases, generators, and counters for one growth partition. the
# per-tile steps are methods here because member reads on self are indexed;
# the same steps as static functions that read a context object cost about 4%
# of the growth benchmark. rci counters change on most tiles, so they are
# typed fields. the counters dictionary holds the rarer maintenance,
# special-zone, and spawn counters that the maintenance helpers update
class TileScan extends GrowthConstants:
	var altitude: PackedByteArray
	var altitudes: PackedInt32Array
	var terrain: PackedByteArray
	var buildings: PackedByteArray
	var zones: PackedByteArray
	var underground: PackedByteArray
	var flags: PackedByteArray
	var text_overlays: PackedByteArray
	var microsims: PackedByteArray
	var things: PackedByteArray
	var traffic: PackedByteArray
	var pollution: PackedByteArray
	var land_value: PackedByteArray
	var crime: PackedByteArray
	var misc: PackedByteArray
	var walking_access: Array[PackedByteArray] = []
	var map_edge: int
	var rotation: int
	var anchor_mask: int
	var random: SimRandom
	var lfsr_random: SimLfsrRandom
	var game_random: GameLcgRandom
	var span: SimulationTimingSpan
	var detailed: bool
	var counters := {
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
	var error := ""
	var scanned_tiles := 0
	var rci_tiles := 0
	var population_added := 0
	var abandoned_population_added := 0
	var started_construction := 0
	var advanced_construction := 0
	var completed_construction := 0
	var abandoned_buildings := 0
	var recovered_buildings := 0
	var churches_built := 0
	var successful_trips := 0
	var failed_trips := 0
	var bus_passengers := 0
	var rail_passengers := 0
	var subway_passengers := 0


	func _init(
		city: CityState,
		payloads: Dictionary,
		scan_random: SimRandom,
		scan_lfsr_random: SimLfsrRandom,
		scan_game_random: GameLcgRandom,
		scan_span: SimulationTimingSpan
	) -> void:
		altitude = payloads.ALTM
		altitudes = city.altitude_words.duplicate()
		terrain = payloads.XTER
		buildings = payloads.XBLD
		zones = payloads.XZON
		underground = payloads.XUND
		flags = payloads.XBIT
		text_overlays = payloads.XTXT
		microsims = payloads.XMIC
		things = payloads.XTHG
		traffic = payloads.XTRF
		pollution = payloads.XPLT
		land_value = payloads.XVAL
		crime = payloads.XCRM
		misc = payloads.MISC
		map_edge = city.map_size
		rotation = city.compass_rotation() & 3
		anchor_mask = ANCHOR_MASKS[rotation]
		random = scan_random
		lfsr_random = scan_lfsr_random
		game_random = scan_game_random
		span = scan_span
		detailed = SimulationTimingSpan.detailed
		_build_walking_access()


	# catchments for this partition: 0 unknown, 1 no destination, 2 destination
	# zone 7 has nowhere to walk; building every table up front was slower
	func _build_walking_access() -> void:
		for unused in 4:
			var access := PackedByteArray()
			access.resize(map_edge * map_edge)
			walking_access.append(access)


	# church placement clears a two-by-two zone footprint. no other growth
	# operation changes a low zone nibble between successive trip searches
	func _invalidate_church_walking_access(tile: Vector2i) -> void:
		for x in range(maxi(0, tile.x - 3), mini(map_edge, tile.x + 5)):
			for y in range(maxi(0, tile.y - 4), mini(map_edge, tile.y + 4)):
				for access in walking_access:
					access[x * map_edge + y] = 0


	# visit every fourth column and row from the partition origin. each tile gets
	# its zone-class work and then subway maintenance. returns false and sets
	# error when a trip search fails
	func scan_tiles(slice: SimulationSliceBudget, step: int, substep: int) -> bool:
		var tile_count := 0

		for x in range(step, map_edge, 4):
			if slice != null:
				slice.checkpoint()

			for y in range(substep, map_edge, 4):
				tile_count += 1

				# the scanned-tile count also strides the worker checkpoint. one
				# clock read per tile costs more than the parking it enables
				if slice != null and (tile_count & CHECKPOINT_TILE_MASK) == 0:
					slice.checkpoint()

				var index := x * map_edge + y
				var zone_byte := int(zones[index])
				var zone := zone_byte & 0x0f
				var tile := Vector2i(x, y)

				if zone == 0:
					_process_unzoned_tile(tile, index)
				elif zone > 6:
					_process_special_zone_tile(tile)
				elif not _process_rci_tile(tile, index, zone_byte, zone):
					return false

				if detailed:
					span.mark_index(TimingStep.SUBWAY)

				GrowthMaintenance._process_subway_maintenance(
					terrain, buildings, zones, flags, text_overlays, underground, misc,
					tile, random, lfsr_random, counters, map_edge
				)

				if detailed:
					span.mark_index(TimingStep.SCAN)

		scanned_tiles = tile_count

		return true


	# surface network decay and facility microsimulation for a tile without a zone
	func _process_unzoned_tile(tile: Vector2i, index: int) -> void:
		var maintenance_tile := int(buildings[index])

		if detailed:
			span.mark_index(TimingStep.SURFACE)

		GrowthMaintenance._process_surface_maintenance(
			altitude, altitudes, terrain, buildings, zones,
			underground, flags, misc, tile, random, lfsr_random,
			counters, map_edge
		)

		if detailed:
			span.mark_index(TimingStep.FACILITIES)

		GrowthMaintenance._process_microsim_growth(
			buildings, zones, flags, text_overlays, microsims,
			things, land_value, crime, pollution, misc, tile,
			maintenance_tile, game_random, lfsr_random, counters, map_edge
		)


	# airport, seaport, and military zone growth
	func _process_special_zone_tile(tile: Vector2i) -> void:
		if detailed:
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
			tile,
			random,
			rotation,
			counters, map_edge,
		)


	# residential, commercial, and industrial growth: trip, population and
	# abandonment, construction completion or recovery, then density growth
	# tiles that are not rci anchors, or that grow without a nearby network,
	# return early. returns false and sets error when the trip search fails
	func _process_rci_tile(
		tile: Vector2i, index: int, zone_byte: int, zone: int
	) -> bool:
		var building := int(buildings[index])
		var density := 0
		var status := STATUS_NORMAL

		if building < 0x70:
			if building >= 0x1d or not TransportTrip.has_nearby_transport(buildings, tile, map_edge):
				return true
		else:
			if building > 0xc5 or zone_byte & anchor_mask == 0:
				return true

			density = GrowthDevelopment.density(building)
			status = GrowthDevelopment._status(building)

		rci_tiles += 1
		var growth_pressure := 0

		if GrowthDevelopment._has_power(flags, tile.x, tile.y, map_edge):
			if detailed:
				span.mark_index(TimingStep.TRIPS)

			var trip := TransportTripSearch.trace(
				buildings,
				zones,
				underground,
				text_overlays,
				altitudes,
				traffic,
				tile,
				zone,
				density,
				random,
				100, map_edge, false, -1, walking_access[(zone + 1) / 2],
			)

			if not trip.ok:
				error = trip.error

				return false

			growth_pressure = _record_trip(trip, zone, density)

		if detailed:
			span.mark_index(TimingStep.POPULATION)

		if density > 0 and status == STATUS_NORMAL:
			if _count_population_or_abandon(tile, zone, density, 4000 - growth_pressure):
				return true

		if detailed:
			span.mark_index(TimingStep.COMPLETION)

		if status == STATUS_CONSTRUCTION:
			if _try_complete_construction(tile, zone, density):
				return true
		elif status == STATUS_ABANDONED:
			_try_recover_abandoned(tile, zone, density, growth_pressure)

			return true

		if detailed:
			span.mark_index(TimingStep.DENSITY)

		_try_advance_density(tile, zone_byte, zone, density, growth_pressure)

		return true


	# count the trip outcome and its passengers. a completed trip returns the
	# zone class demand plus 2000 as growth pressure; a failed trip returns 0
	func _record_trip(trip: Dictionary, zone: int, density: int) -> int:
		if not trip.reached_destination:
			failed_trips += 1

			return 0

		successful_trips += 1

		if trip.used_bus:
			bus_passengers += density

		if trip.used_rail:
			rail_passengers += density

		if trip.used_subway:
			subway_passengers += density

		return GrowthState._read_i32(misc, MISC_DEMAND + int((zone - 1) / 2) * 4) + 2000


	# add a developed building's population, then roll for abandonment
	# returns true when the building was abandoned
	func _count_population_or_abandon(
		tile: Vector2i, zone: int, density: int, decline_pressure: int
	) -> bool:
		var population: int = POPULATION_BY_DENSITY[density]
		GrowthState._add_i32(misc, MISC_ZONE_POPULATIONS + zone * 4, population)
		population_added += population

		if random.next_u15() >= int(decline_pressure / density):
			return false

		GrowthDevelopment._abandon(
			buildings,
			zones,
			flags,
			misc,
			tile,
			density,
			random.next_u15() & 1,
			random,
			rotation,
			land_value, map_edge,
		)
		abandoned_buildings += 1

		return true


	# roll to finish a construction site as a zone building, or as a church when
	# the population outgrows the existing churches. returns true when finished
	func _try_complete_construction(
		tile: Vector2i, zone: int, density: int
	) -> bool:
		if random.next_u15() >= int((0x4000) / density):
			return false

		if (
			GrowthState._read_u32(misc, MISC_NORMAL_POPULATION)
			> GrowthState._read_u32(misc, MISC_TILE_COUNTS + CHURCH_TILE * 4) * 2500
			and (density & 2) != 0
			and zone < 3
		):
			GrowthDevelopment._place_church(
				buildings, zones, flags, misc, tile, rotation, map_edge
			)
			_invalidate_church_walking_access(tile)
			churches_built += 1
		else:
			GrowthDevelopment.place_zone(
				buildings,
				zones,
				flags,
				misc,
				land_value,
				tile,
				density,
				int((zone - 1) / 2),
				random,
				rotation, map_edge,
			)

		completed_construction += 1

		return true


	# count an abandoned building's population, then roll to reoccupy it
	func _try_recover_abandoned(
		tile: Vector2i, zone: int, density: int, growth_pressure: int
	) -> void:
		if detailed:
			span.mark_index(TimingStep.RECOVERY)

		var abandoned_population: int = POPULATION_BY_DENSITY[density]
		GrowthState._add_i32(misc, MISC_ZONE_POPULATIONS + 7 * 4, abandoned_population)
		abandoned_population_added += abandoned_population

		if random.next_u15() >= int((growth_pressure * 15) / density):
			return

		GrowthDevelopment.place_zone(
			buildings,
			zones,
			flags,
			misc,
			land_value,
			tile,
			density,
			int((zone - 1) / 2),
			random,
			rotation, map_edge,
		)
		recovered_buildings += 1


	# roll to start construction on an empty zone or raise an existing density
	func _try_advance_density(
		tile: Vector2i, zone_byte: int, zone: int, density: int, growth_pressure: int
	) -> void:
		if not GrowthConstruction.can_advance_density(
			zone_byte, zone, density, land_value, tile.x, tile.y, map_edge
		):
			return

		if random.next_u15() >= int((growth_pressure * 3) / (density + 1)):
			return

		var advanced := GrowthConstruction._advance_construction(
			buildings,
			zones,
			flags,
			misc,
			land_value,
			altitudes,
			tile,
			density,
			zone,
			random,
			rotation, map_edge,
		)

		if not advanced:
			return

		if density == 0:
			started_construction += 1
		else:
			advanced_construction += 1


	func result() -> GrowthResult:
		var growth := GrowthResult.new()
		growth.ok = true
		growth.rci_complete = true
		growth.scanned_tiles = scanned_tiles
		growth.rci_tiles = rci_tiles
		growth.population_added = population_added
		growth.abandoned_population_added = abandoned_population_added
		growth.started_construction = started_construction
		growth.advanced_construction = advanced_construction
		growth.completed_construction = completed_construction
		growth.abandoned_buildings = abandoned_buildings
		growth.recovered_buildings = recovered_buildings
		growth.churches_built = churches_built
		growth.successful_trips = successful_trips
		growth.failed_trips = failed_trips
		growth.bus_passengers = bus_passengers
		growth.rail_passengers = rail_passengers
		growth.subway_passengers = subway_passengers
		growth.decayed_roads = counters.decayed_roads
		growth.decayed_rails = counters.decayed_rails
		growth.decayed_highway_tiles = counters.decayed_highway_tiles
		growth.decayed_subway_tiles = counters.decayed_subway_tiles
		growth.collapsed_bridges = counters.collapsed_bridges
		growth.removed_subway_stations = counters.removed_subway_stations
		growth.deferred_bridge_collapses = counters.deferred_bridge_collapses
		growth.deferred_bridge_effects = counters.deferred_bridge_effects
		growth.deferred_station_removals = counters.deferred_station_removals
		growth.special_growth_attempts = counters.special_growth_attempts
		growth.special_tiles_placed = counters.special_tiles_placed
		growth.arcologies_updated = counters.arcologies_updated
		growth.spawned_airplanes = counters.spawned_airplanes
		growth.spawned_helicopters = counters.spawned_helicopters
		growth.spawned_ships = counters.spawned_ships
		growth.spawned_sailboats = counters.spawned_sailboats
		growth.spawned_trains = counters.spawned_trains
		growth.bridge_effects = counters.bridge_effects
		growth.news_items = counters.news_items
		growth.sound_events = counters.sound_events
		growth.view_center_requests = counters.view_center_requests
		growth.ship_home_found = counters.has("ship_home")
		growth.ship_home = counters.get("ship_home", Vector2i(-1, -1))
		growth.timing = span.finish()

		return growth


static func run(
	city: CityState,
	random: SimRandom,
	step: int,
	substep: int,
	lfsr_random: SimLfsrRandom = null,
	game_random: GameLcgRandom = null
) -> GrowthResult:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if random == null:
		return _failed("a compatible random generator is required")

	if lfsr_random == null:
		lfsr_random = SimLfsrRandom.new(1)

	if game_random == null:
		game_random = GameLcgRandom.new(1)

	if step < 0 or step > 3 or substep < 0 or substep > 3:
		return _failed("growth partition is outside the supported range")

	var span := SimulationTimingSpan.new(city.simulation_slice, TIMING_LABELS)
	span.mark_index(TimingStep.PREPARE)
	var payloads := GrowthState.payloads(city)

	if payloads.is_empty():
		return _failed("growth input chunks are missing or have the wrong size")

	var original := GrowthState.duplicate_payloads(payloads)
	var scan := TileScan.new(city, payloads, random, lfsr_random, game_random, span)

	# the trip search reads these maps for every powered rci tile. their sizes
	# are invariant across the scan, so check them once here
	if not TransportTripSearch.valid_inputs(scan.buildings, scan.zones, scan.underground,
		scan.text_overlays, scan.altitudes, scan.traffic, scan.map_edge):
		return _failed("transport input maps have the wrong size")

	span.mark_index(TimingStep.SCAN if scan.detailed else TimingStep.TILES)

	if not scan.scan_tiles(city.simulation_slice, step, substep):
		return _failed(scan.error)

	span.mark_index(TimingStep.CHANGES)
	var changed_ids := PackedStringArray()

	for chunk_id in [
		"ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XMIC", "XTHG",
		"XBIT", "XTRF", "MISC",
	]:
		if payloads[chunk_id] != original[chunk_id]:
			changed_ids.append(chunk_id)

	span.mark_index(TimingStep.STORE)
	if not GrowthState._apply_payloads(city, changed_ids, payloads, original):
		return _failed("cannot store growth phase data")

	return scan.result()


static func _failed(message: String) -> GrowthResult:
	var result := GrowthResult.new()
	result.error = message

	return result
