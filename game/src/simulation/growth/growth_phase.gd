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
	return GrowthScan.run(city, random, step, substep, lfsr_random, game_random)


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
