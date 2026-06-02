class_name NetworkCommand
extends NetworkConstants



static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return NetworkRules.supports_tool(group_index, subtool_index)


static func route(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	return NetworkRoutes.route(start, finish)


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	finish: Vector2i,
	bridge_type := BRIDGE_UNSELECTED,
	connection_choice := CONNECTION_UNSELECTED,
	free_mode := false
) -> Dictionary:
	return NetworkDragCommand.apply(city, group_index, subtool_index, start, finish, bridge_type, connection_choice, free_mode, false)


static func apply_segment(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	finish: Vector2i,
	bridge_type := BRIDGE_UNSELECTED,
	connection_choice := CONNECTION_UNSELECTED,
	free_mode := false
) -> Dictionary:
	return NetworkEdit.apply_segment(city, group_index, subtool_index, start, finish, bridge_type, connection_choice, free_mode)


static func bridge_type_name(bridge_type: int) -> String:
	return NetworkBridges.bridge_type_name(bridge_type)


static func undo(city: CityState, command: Dictionary) -> Dictionary:
	return NetworkEdit.undo(city, command)


static func _is_bridge_wrapper_tile(
	terrain: PackedByteArray, flags: PackedByteArray, point: Vector2i,
	map_edge: int = 128,
) -> bool:
	return NetworkBridges._is_bridge_wrapper_tile(terrain, flags, point, map_edge)


static func _plan_bridge_from_start(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	start: Vector2i,
	view_rotation: int,
	map_edge: int = 128,
) -> Dictionary:
	return NetworkBridges._plan_bridge_from_start(buildings, terrain, start, view_rotation, map_edge)


static func _scan_bridge(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	start: Vector2i,
	direction: int,
	require_direction: bool,
	map_edge: int = 128,
) -> Dictionary:
	return NetworkBridges._scan_bridge(buildings, terrain, start, direction, require_direction, map_edge)


static func _route_exit_direction(
	planned: Array[Vector2i], start: Vector2i, finish: Vector2i
) -> int:
	return NetworkRoutes._route_exit_direction(planned, start, finish)


static func _connection_cost(mode: int) -> int:
	return NetworkRules._connection_cost(mode)


static func _is_connection_exit(
	planned: Array[Vector2i], start: Vector2i, finish: Vector2i,
	map_edge: int = 128,
) -> bool:
	return NetworkRoutes._is_connection_exit(planned, start, finish, map_edge)


static func _point_is_edge(point: Vector2i, map_edge: int = 128) -> bool:
	return NetworkRules._point_is_edge(point, map_edge)


static func _point_is_in_bounds(point: Vector2i, map_edge: int = 128) -> bool:
	return NetworkRules._point_is_in_bounds(point, map_edge)


static func _direction_index(offset: Vector2i) -> int:
	return NetworkRules._direction_index(offset)


static func _bridge_choices(span_length: int, mode: int) -> Array[Dictionary]:
	return NetworkBridges._bridge_choices(span_length, mode)


static func _bridge_choice_exists(choices: Array[Dictionary], bridge_type: int) -> bool:
	return NetworkBridges._bridge_choice_exists(choices, bridge_type)


static func _place_bridge(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	plan: Dictionary,
	bridge_type: int,
	map_edge: int = 128,
) -> Array[Vector2i]:
	return NetworkBridges._place_bridge(altitude, buildings, terrain, zones, flags, misc, plan, bridge_type, map_edge)


static func _place_bridge_bank(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	direction: int,
	bridge_type: int,
	first: bool,
	map_edge: int = 128,
) -> void:
	NetworkBridges._place_bridge_bank(
		altitude, buildings, terrain, zones, flags, misc, point, direction, bridge_type, first, map_edge
	)


static func _bridge_tile(
	bridge_type: int, span_length: int, span_index: int, direction: int
) -> int:
	return NetworkBridges._bridge_tile(bridge_type, span_length, span_index, direction)


static func _land_altitude(altitude: PackedByteArray, index: int) -> int:
	return NetworkRules._land_altitude(altitude, index)


static func _set_land_altitude(
	altitude: PackedByteArray, index: int, value: int
) -> void:
	NetworkRules._set_land_altitude(altitude, index, value)


static func _plan_route(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	start: Vector2i,
	finish: Vector2i,
	mode: int,
	map_edge: int = 128,
	planned_directions: Array[int] = [],
) -> Array[Vector2i]:
	return NetworkRoutes._plan_route(
		buildings, terrain, zones, underground, flags, altitude, start, finish, mode, map_edge, planned_directions
	)


static func _step_is_eligible(
	buildings: PackedByteArray, terrain: PackedByteArray, zones: PackedByteArray,
	underground: PackedByteArray, flags: PackedByteArray, altitude: PackedByteArray,
	current: Vector2i, next: Vector2i, mode: int, direction: int,
	keep_straight: bool, map_edge: int,
) -> bool:
	return NetworkRoutes._step_is_eligible(
		buildings, terrain, zones, underground, flags, altitude, current, next, mode, direction, keep_straight,
		map_edge
	)


# some tiles force the incoming direction before we can turn toward the pointer
static func _route_keeps_direction(buildings: PackedByteArray, terrain: PackedByteArray, underground: PackedByteArray, point: Vector2i, mode: int, direction: int, edge: int) -> bool:
	return NetworkRoutes._route_keeps_direction(buildings, terrain, underground, point, mode, direction, edge)


static func _primary_direction(current: Vector2i, finish: Vector2i) -> int:
	return NetworkRoutes._primary_direction(current, finish)


static func _alternate_direction(current: Vector2i, finish: Vector2i, primary: int) -> int:
	return NetworkRoutes._alternate_direction(current, finish, primary)


static func _route_direction(points: Array[Vector2i], index: int) -> int:
	return NetworkRoutes._route_direction(points, index)


static func _tile_is_eligible(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	point: Vector2i,
	mode: int,
	direction: int,
	map_edge: int = 128,
) -> bool:
	return NetworkRules._tile_is_eligible(
		buildings, terrain, zones, underground, flags, altitude, point, mode, direction, map_edge
	)


static func _surface_fixed_axis(tile_id: int, mode: int) -> int:
	return NetworkRules._surface_fixed_axis(tile_id, mode)


static func _reuses_surface(tile_id: int, mode: int) -> bool:
	return NetworkRules._reuses_surface(tile_id, mode)


static func _place_surface(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	mode: int,
	direction: int,
	text_overlays := PackedByteArray(),
	map_edge: int = 128,
) -> void:
	NetworkTiles._place_surface(buildings, terrain, zones, flags, misc, point, mode, direction, text_overlays, map_edge)


static func _grade_surface_terrain(
	terrain: PackedByteArray, flags: PackedByteArray, point: Vector2i, direction: int,
	map_edge: int = 128,
) -> void:
	NetworkTiles._grade_surface_terrain(terrain, flags, point, direction, map_edge)


static func _surface_replacement(old_tile: int, mode: int) -> int:
	return NetworkTiles._surface_replacement(old_tile, mode)


static func _retile_surface_neighborhood(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	mode: int,
	text_overlays := PackedByteArray(),
	map_edge: int = 128,
) -> void:
	NetworkTiles._retile_surface_neighborhood(buildings, terrain, zones, flags, misc, point, mode, text_overlays, map_edge)


static func _retile_surface(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	mode: int,
	text_overlays := PackedByteArray(),
	map_edge: int = 128,
) -> void:
	NetworkTiles._retile_surface(buildings, terrain, zones, flags, misc, point, mode, text_overlays, map_edge)


static func _road_connects(tile_id: int) -> bool:
	return NetworkRules._road_connects(tile_id)


static func _rail_connects(tile_id: int) -> bool:
	return NetworkRules._rail_connects(tile_id)


static func _reuses_underground(tile_id: int, mode: int) -> bool:
	return NetworkRules._reuses_underground(tile_id, mode)


static func _place_underground(
	underground: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	pipes: bool,
	direction := 0,
	map_edge: int = 128,
) -> void:
	NetworkTiles._place_underground(underground, terrain, zones, flags, misc, point, pipes, direction, map_edge)


static func _retile_underground_neighborhood(
	underground: PackedByteArray, terrain: PackedByteArray, point: Vector2i, pipes: bool,
	map_edge: int = 128,
) -> void:
	NetworkTiles._retile_underground_neighborhood(underground, terrain, point, pipes, map_edge)


static func _replace_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	NetworkState._replace_building(buildings, zones, misc, index, new_tile)


static func _city_payloads(city: CityState) -> Dictionary:
	return NetworkState._city_payloads(city)


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary:
	return NetworkState._duplicate_payloads(payloads)


static func _apply_payloads(
	city: CityState, chunk_ids: PackedStringArray, payloads: Dictionary, rollback: Dictionary
) -> bool:
	return NetworkState._apply_payloads(city, chunk_ids, payloads, rollback)


static func _refresh_city_arrays(city: CityState, refresh_altitude := true) -> void:
	NetworkState._refresh_city_arrays(city, refresh_altitude)


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return NetworkState._read_u32_be(data, offset)


static func _write_u32_be(data: PackedByteArray, offset: int, value: int) -> void:
	NetworkState._write_u32_be(data, offset, value)
