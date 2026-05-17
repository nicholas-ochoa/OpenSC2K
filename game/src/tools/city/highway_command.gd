class_name HighwayCommand
extends HighwayConstants



static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return HighwayGeometry.supports_tool(group_index, subtool_index)


static func snap_anchor(point: Vector2i) -> Vector2i:
	return HighwayGeometry.snap_anchor(point)


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	selected_start: Vector2i,
	selected_finish: Vector2i,
	connection_choice := CONNECTION_UNSELECTED,
	bridge_type := BRIDGE_UNSELECTED,
	free_mode := false
) -> Dictionary:
	return NetworkDragCommand.apply(city, group_index, subtool_index, selected_start, selected_finish, bridge_type, connection_choice, free_mode, true)


static func apply_segment(
	city: CityState,
	group_index: int,
	subtool_index: int,
	selected_start: Vector2i,
	selected_finish: Vector2i,
	connection_choice := CONNECTION_UNSELECTED,
	bridge_type := BRIDGE_UNSELECTED,
	free_mode := false
) -> Dictionary:
	return HighwayEdit.apply_segment(
		city, group_index, subtool_index, selected_start, selected_finish, connection_choice, bridge_type,
		free_mode
	)


static func undo(city: CityState, command: Dictionary) -> Dictionary:
	return HighwayEdit.undo(city, command)


static func bridge_type_name(bridge_type: int) -> String:
	return HighwayBridges.bridge_type_name(bridge_type)


static func _plan_bridge_from_start(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	start: Vector2i,
	view_rotation: int,
	map_edge: int = 128,
) -> Dictionary:
	return HighwayBridges._plan_bridge_from_start(buildings, terrain, altitude, start, view_rotation, map_edge)


static func _scan_bridge(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	start: Vector2i,
	direction: int,
	map_edge: int = 128,
) -> Dictionary:
	return HighwayBridges._scan_bridge(buildings, terrain, altitude, start, direction, map_edge)


static func _bridge_choices(plan: Dictionary) -> Array[Dictionary]:
	return HighwayBridges._bridge_choices(plan)


static func _bridge_choice_exists(
	choices: Array[Dictionary], bridge_type: int
) -> bool:
	return HighwayBridges._bridge_choice_exists(choices, bridge_type)


static func _reinforced_bridge_is_allowed(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	start: Vector2i,
	direction: int,
	span_length: int,
	map_edge: int = 128,
) -> bool:
	return HighwayBridges._reinforced_bridge_is_allowed(buildings, terrain, altitude, start, direction, span_length, map_edge)


static func _bridge_endpoint_is_allowed(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	anchor: Vector2i,
	bridge_height: int,
	required_slope_direction: int,
	map_edge: int = 128,
) -> bool:
	return HighwayBridges._bridge_endpoint_is_allowed(
		buildings, terrain, altitude, anchor, bridge_height, required_slope_direction, map_edge
	)


static func _section_is_bridge_clear(
	buildings: PackedByteArray, anchor: Vector2i,
	map_edge: int = 128,
) -> bool:
	return HighwayBridges._section_is_bridge_clear(buildings, anchor, map_edge)


static func _bridge_terrain_code(
	terrain: PackedByteArray, anchor: Vector2i,
	map_edge: int = 128,
) -> int:
	return HighwayBridges._bridge_terrain_code(terrain, anchor, map_edge)


static func _bridge_terrain_weight(terrain_id: int) -> int:
	return HighwayBridges._bridge_terrain_weight(terrain_id)


static func _place_bridge(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	misc: PackedByteArray,
	plan: Dictionary,
	bridge_type: int,
	rotation: int,
	map_edge: int = 128,
) -> Dictionary:
	return HighwayBridges._place_bridge(buildings, terrain, zones, flags, altitude, misc, plan, bridge_type, rotation, map_edge)


static func _write_bridge_endpoint(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	altitude: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	kind: int,
	rotation: int,
	map_edge: int = 128,
) -> void:
	HighwayBridges._write_bridge_endpoint(buildings, terrain, zones, altitude, misc, anchor, kind, rotation, map_edge)


static func _write_normal_bridge_section(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	direction: int,
	map_edge: int = 128,
) -> void:
	HighwayBridges._write_normal_bridge_section(buildings, zones, misc, anchor, direction, map_edge)


static func _write_reinforced_bridge_section(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	kind: int,
	direction: int,
	rotation: int,
	map_edge: int = 128,
) -> void:
	HighwayBridges._write_reinforced_bridge_section(buildings, zones, flags, misc, anchor, kind, direction, rotation, map_edge)


static func _plan_flat_route(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	start: Vector2i,
	finish: Vector2i,
	map_edge: int = 128,
) -> Array[Vector2i]:
	return HighwayRoutes._plan_flat_route(buildings, terrain, flags, altitude, start, finish, map_edge)


static func _section_has_straight_crossing(buildings: PackedByteArray, anchor: Vector2i, direction: int, map_edge: int) -> bool:
	return HighwayRoutes._section_has_straight_crossing(buildings, anchor, direction, map_edge)


static func _primary_direction(current: Vector2i, finish: Vector2i) -> int:
	return HighwayGeometry._primary_direction(current, finish)


static func _alternate_direction(current: Vector2i, finish: Vector2i, primary: int) -> int:
	return HighwayRoutes._alternate_direction(current, finish, primary)


static func _section_is_flat_eligible(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	anchor: Vector2i,
	direction: int,
	map_edge: int = 128,
) -> bool:
	return HighwayRoutes._section_is_flat_eligible(buildings, terrain, flags, altitude, anchor, direction, map_edge)


static func _section_follows(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	current: Vector2i,
	candidate: Vector2i,
	direction: int,
	map_edge: int = 128,
) -> bool:
	return HighwayRoutes._section_follows(buildings, terrain, flags, altitude, current, candidate, direction, map_edge)


static func _terrain_section_shape(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	anchor: Vector2i,
	map_edge: int = 128,
) -> int:
	return HighwayGeometry._terrain_section_shape(buildings, terrain, altitude, anchor, map_edge)


static func _terrain_class(terrain_id: int) -> int:
	return HighwayGeometry._terrain_class(terrain_id)


static func _section_altitude(
	terrain: PackedByteArray, altitude: PackedByteArray, anchor: Vector2i,
	map_edge: int = 128,
) -> int:
	return HighwayGeometry._section_altitude(terrain, altitude, anchor, map_edge)


static func _land_altitude(altitude: PackedByteArray, index: int) -> int:
	return HighwayGeometry._land_altitude(altitude, index)


static func _building_is_allowed(tile_id: int) -> bool:
	return HighwayGeometry._building_is_allowed(tile_id)


static func _network_can_cross(tile_id: int, direction: int) -> bool:
	return HighwayGeometry._network_can_cross(tile_id, direction)


static func _place_straight_section(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	orientation: int,
	map_edge: int = 128,
) -> void:
	HighwayPlacement._place_straight_section(buildings, zones, misc, anchor, orientation, map_edge)


static func _straight_replacement(old_tile: int, orientation: int) -> int:
	return HighwayPlacement._straight_replacement(old_tile, orientation)


static func _place_section(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	text_overlays: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	direction: int,
	rotation: int,
	map_edge: int = 128,
) -> Dictionary:
	return HighwayPlacement._place_section(
		buildings, terrain, zones, flags, altitude, text_overlays, misc, anchor, direction, rotation, map_edge
	)


static func _clear_section_zone_types(zones: PackedByteArray, anchor: Vector2i, map_edge: int = 128) -> void:
	HighwayPlacement._clear_section_zone_types(zones, anchor, map_edge)


static func _retile_affected_sections(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	misc: PackedByteArray,
	placed: Array[Vector2i],
	rotation: int,
	text_overlays := PackedByteArray(),
	route_directions := {},
	map_edge: int = 128,
) -> void:
	HighwayPlacement._retile_affected_sections(
		buildings, terrain, zones, flags, altitude, misc, placed, rotation, text_overlays, route_directions,
		map_edge
	)


static func _retile_section(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	text_overlays: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	direction: int,
	rotation: int,
	map_edge: int = 128,
) -> int:
	return HighwayPlacement._retile_section(
		buildings, terrain, zones, flags, altitude, text_overlays, misc, anchor, direction, rotation, map_edge
	)


static func _select_section_kind(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	_text_overlays: PackedByteArray,
	anchor: Vector2i,
	direction: int,
	map_edge: int = 128,
) -> int:
	return HighwayRoutes._select_section_kind(
		buildings, terrain, zones, flags, altitude, _text_overlays, anchor, direction, map_edge
	)


static func _neighbor_connection_flags(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	anchor: Vector2i,
	current_height: int,
	direction_index: int,
	map_edge: int = 128,
) -> int:
	return HighwayRoutes._neighbor_connection_flags(
		buildings, terrain, zones, flags, altitude, anchor, current_height, direction_index, map_edge
	)


static func _neighbor_kind_connects(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	altitude: PackedByteArray,
	neighbor: Vector2i,
	neighbor_kind: int,
	direction_index: int,
	map_edge: int = 128,
) -> bool:
	return HighwayRoutes._neighbor_kind_connects(
		buildings, terrain, altitude, neighbor, neighbor_kind, direction_index, map_edge
	)


static func _section_kind(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	anchor: Vector2i,
	map_edge: int = 128,
) -> int:
	return HighwayGeometry._section_kind(buildings, zones, flags, anchor, map_edge)


static func _is_highway_tile(tile_id: int) -> bool:
	return HighwayGeometry._is_highway_tile(tile_id)


static func _grade_kind_for_shape(terrain_shape: int) -> int:
	return HighwayGeometry._grade_kind_for_shape(terrain_shape)


static func _prepare_flat_terrain(
	terrain: PackedByteArray, altitude: PackedByteArray, anchor: Vector2i,
	map_edge: int = 128,
) -> void:
	HighwayPlacement._prepare_flat_terrain(terrain, altitude, anchor, map_edge)


static func _prepare_shaped_terrain(
	terrain: PackedByteArray, altitude: PackedByteArray, anchor: Vector2i,
	map_edge: int = 128,
) -> void:
	HighwayPlacement._prepare_shaped_terrain(terrain, altitude, anchor, map_edge)


static func _write_section_kind(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	altitude: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	kind: int,
	rotation: int,
	map_edge: int = 128,
) -> void:
	HighwayPlacement._write_section_kind(buildings, terrain, zones, altitude, misc, anchor, kind, rotation, map_edge)


static func _place_graded_section(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	kind: int,
	rotation: int,
	map_edge: int = 128,
) -> void:
	HighwayPlacement._place_graded_section(altitude, buildings, terrain, zones, misc, anchor, kind, rotation, map_edge)


static func _set_land_altitude(
	altitude: PackedByteArray, index: int, value: int
) -> void:
	HighwayPlacement._set_land_altitude(altitude, index, value)


static func _write_shape(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	kind: int,
	rotation: int,
	map_edge: int = 128,
) -> void:
	HighwayPlacement._write_shape(buildings, zones, misc, anchor, kind, rotation, map_edge)


static func _section_direction(
	sections: Array[Vector2i], section_index: int, finish: Vector2i
) -> int:
	return HighwayGeometry._section_direction(sections, section_index, finish)


static func _direction_between(start: Vector2i, finish: Vector2i) -> int:
	return HighwayGeometry._direction_between(start, finish)


static func _anchor_is_in_bounds(anchor: Vector2i, map_edge: int = 128) -> bool:
	return HighwayGeometry._anchor_is_in_bounds(anchor, map_edge)


static func _is_connection_exit(
	sections: Array[Vector2i], finish: Vector2i, map_edge: int = 128
) -> bool:
	return HighwayGeometry._is_connection_exit(sections, finish, map_edge)


static func _anchor_is_on_border(anchor: Vector2i, map_edge: int = 128) -> bool:
	return HighwayGeometry._anchor_is_on_border(anchor, map_edge)


static func _section_has_water(flags: PackedByteArray, anchor: Vector2i, map_edge: int = 128) -> bool:
	return HighwayGeometry._section_has_water(flags, anchor, map_edge)


static func _section_is_existing_highway(buildings: PackedByteArray, anchor: Vector2i, map_edge: int = 128) -> bool:
	return HighwayGeometry._section_is_existing_highway(buildings, anchor, map_edge)


static func preview_valid(city: CityState, selected: Vector2i) -> bool:
	return HighwayEdit.preview_valid(city, selected)


static func preview_error(city: CityState, selected: Vector2i) -> String:
	return HighwayEdit.preview_error(city, selected)
