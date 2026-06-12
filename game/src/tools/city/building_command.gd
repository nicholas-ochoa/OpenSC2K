class_name BuildingCommand
extends BuildingConstants



static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return BuildingSites.supports_tool(group_index, subtool_index)


static func tile_for_tool(group_index: int, subtool_index: int) -> int:
	return BuildingSites.tile_for_tool(group_index, subtool_index)


# the pointer isn't the footprint origin for the bigger buildings
static func footprint(selected: Vector2i, area: int) -> Rect2i:
	return BuildingSites.footprint(selected, area)


static func preview_valid(city: CityState, group: int, subtool: int, point: Vector2i) -> bool:
	return BuildingSites.preview_valid(city, group, subtool, point)


static func preview_error(city: CityState, group: int, subtool: int, point: Vector2i) -> String:
	return BuildingSites.preview_error(city, group, subtool, point)


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	selected: Vector2i,
	lfsr_random: SimLfsrRandom,
	process_random: SimRandom,
	australian_locale := false
) -> Dictionary:
	return BuildingEdit.apply(city, group_index, subtool_index, selected, lfsr_random, process_random, australian_locale)


static func stadium_team_choices(city: CityState) -> PackedInt32Array:
	return BuildingFacilities.stadium_team_choices(city)


static func stadium_team_name(city: CityState, team_index: int) -> String:
	return BuildingFacilities.stadium_team_name(city, team_index)


static func assign_stadium_team(
	city: CityState,
	command: Dictionary,
	team_index: int,
	team_name: String
) -> Dictionary:
	return BuildingFacilities.assign_stadium_team(city, command, team_index, team_name)


static func undo(
	city: CityState,
	command: Dictionary,
	lfsr_random: SimLfsrRandom,
	process_random: SimRandom
) -> Dictionary:
	return BuildingEdit.undo(city, command, lfsr_random, process_random)


static func _footprint_is_in_bounds(site: Rect2i, area: int, map_edge: int = 128) -> bool:
	return BuildingSites._footprint_is_in_bounds(site, area, map_edge)


static func _check_site(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	site: Rect2i,
	tile_id: int,
	map_edge: int = 128,
) -> Dictionary:
	return BuildingSites._check_site(buildings, terrain, zones, flags, site, tile_id, map_edge)


static func _count_nearby_residential(
	zones: PackedByteArray, selected: Vector2i, area: int,
	map_edge: int = 128,
) -> int:
	return BuildingSites._count_nearby_residential(zones, selected, area, map_edge)


static func _provision_microsim(
	microsims: PackedByteArray,
	labels: PackedByteArray,
	text_overlays: PackedByteArray,
	tile_id: int,
	current_year: int,
	process_random,
	misc := PackedByteArray(),
	australian_locale := false,
	scurk_place_mode := false
) -> int:
	return BuildingFacilities._provision_microsim(
		microsims, labels, text_overlays, tile_id, current_year, process_random, misc, australian_locale,
		scurk_place_mode
	)


static func _initialize_microsim(
	microsims: PackedByteArray,
	misc: PackedByteArray,
	record_id: int,
	tile_id: int,
	current_year: int,
	process_random,
	australian_locale: bool,
	scurk_place_mode: bool,
	map_edge: int = 128
) -> void:
	BuildingFacilities._initialize_microsim(
		microsims, misc, record_id, tile_id, current_year, process_random, australian_locale, scurk_place_mode,
		map_edge
	)


static func _population_cap(misc: PackedByteArray, maximum: int, divisor: int, map_edge: int = 128) -> int:
	return BuildingFacilities._population_cap(misc, maximum, divisor, map_edge)


static func _divide_toward_zero(value: int, divisor: int) -> int:
	return BuildingFacilities._divide_toward_zero(value, divisor)


static func _to_i16(value: int) -> int:
	return BuildingFacilities._to_i16(value)


static func _write_label(labels: PackedByteArray, label_id: int, value: String) -> void:
	BuildingFacilities._write_label(labels, label_id, value)


static func _read_u16_be(data: PackedByteArray, offset: int) -> int:
	return BuildingState._read_u16_be(data, offset)


static func _write_u16_be(data: PackedByteArray, offset: int, value: int) -> void:
	BuildingState._write_u16_be(data, offset, value)


# The zone and building corner flags share one byte.
static func _set_corners(zones: PackedByteArray, site: Rect2i, area: int, rotation: int, map_edge: int = 128) -> void:
	BuildingSites._set_corners(zones, site, area, rotation, map_edge)


static func _place_pipe(
	underground: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	BuildingUnderground._place_pipe(underground, terrain, zones, flags, misc, point, map_edge)


# connect and retile the subway before replacing the center with the station
static func _place_subway_station(
	underground: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	BuildingUnderground._place_subway_station(underground, terrain, zones, flags, misc, point, map_edge)


static func _replace_underground(
	underground: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	BuildingUnderground._replace_underground(underground, zones, misc, index, new_tile)


static func _is_subway_tile(tile_id: int) -> bool:
	return BuildingUnderground._is_subway_tile(tile_id)


static func _retile_neighborhood(
	underground: PackedByteArray, terrain: PackedByteArray, point: Vector2i, pipes: bool,
	map_edge: int = 128,
) -> void:
	BuildingUnderground._retile_neighborhood(underground, terrain, point, pipes, map_edge)


static func _retile_underground(
	underground: PackedByteArray, terrain: PackedByteArray, point: Vector2i, pipes: bool,
	map_edge: int = 128,
) -> void:
	BuildingUnderground._retile_underground(underground, terrain, point, pipes, map_edge)


static func _underground_connects(tile_id: int, pipes: bool) -> bool:
	return BuildingUnderground._underground_connects(tile_id, pipes)


static func _allows_vertical(terrain_id: int) -> bool:
	return BuildingUnderground._allows_vertical(terrain_id)


static func _allows_horizontal(terrain_id: int) -> bool:
	return BuildingUnderground._allows_horizontal(terrain_id)


static func _update_building_count(
	misc: PackedByteArray, zone: int, old_building: int, new_building: int, map_edge: int = 128
) -> void:
	BuildingState._update_building_count(misc, zone, old_building, new_building, map_edge)


static func _city_payloads(city: CityState) -> Dictionary:
	return BuildingState._city_payloads(city)


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary:
	return BuildingState._duplicate_payloads(payloads)


static func _restore_payloads(city: CityState, old_payloads: Dictionary) -> bool:
	return BuildingState._restore_payloads(city, old_payloads)


static func _apply_payloads(
	city: CityState, chunk_ids: PackedStringArray, payloads: Dictionary, rollback: Dictionary
) -> bool:
	return BuildingState._apply_payloads(city, chunk_ids, payloads, rollback)


static func _refresh_city_arrays(city: CityState) -> void:
	BuildingState._refresh_city_arrays(city)


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return BuildingState._read_u32_be(data, offset)


static func _read_i32_be(data: PackedByteArray, offset: int) -> int:
	return BuildingState._read_i32_be(data, offset)


static func _write_u32_be(data: PackedByteArray, offset: int, value: int) -> void:
	BuildingState._write_u32_be(data, offset, value)
