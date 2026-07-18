class_name DemolishCommand
extends DemolishConstants



static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return DemolishEdit.supports_tool(group_index, subtool_index)


static func structure_area(tile_id: int) -> int:
	return DemolishStructures.structure_area(tile_id)


static func damage_structure_payloads(
	city: CityState, payloads: Dictionary, point: Vector2i, random: SimRandom, emit_effects := false
) -> Dictionary:
	return DemolishStructures.damage_structure_payloads(city, payloads, point, random, emit_effects)


static func append_effect_sequence(
	destination: Array[Dictionary], source: Array, first_frame: int
) -> int:
	return DemolishEffectsSites.append_effect_sequence(destination, source, first_frame)


static func parallel_effect_offset(
	point: Vector2i, action_index: int, random_seed: int
) -> int:
	return DemolishEffectsSites.parallel_effect_offset(point, action_index, random_seed)


static func apply_path(
	city: CityState,
	group_index: int,
	subtool_index: int,
	points: Array[Vector2i],
	random: SimRandom,
	underground_view := false,
	scurk_mode := false
) -> Dictionary:
	return DemolishEdit.apply_path(city, group_index, subtool_index, points, random, underground_view, scurk_mode)


static func undo(city: CityState, command: Dictionary, random: SimRandom) -> Dictionary:
	return DemolishEdit.undo(city, command, random)


static func _demolish_point(
	city: CityState,
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	random: SimRandom,
	force_damage := false,
	retile_neighbors := true,
	emit_effects := true,
	scurk_mode := false
) -> Dictionary:
	return DemolishStructures._demolish_point(
		city, altitude, buildings, terrain, zones, underground, flags, text_overlays, labels, microsims, misc,
		point, random, force_damage, retile_neighbors, emit_effects, scurk_mode
	)


static func _demolish_underground_point(
	city: CityState,
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	random: SimRandom,
	scurk_mode := false
) -> Dictionary:
	return DemolishStructures._demolish_underground_point(
		city, altitude, buildings, terrain, zones, underground, flags, text_overlays, labels, microsims, misc,
		point, random, scurk_mode
	)


static func _is_highway_tile(tile_id: int) -> bool:
	return DemolishTransport._is_highway_tile(tile_id)


static func _demolish_tunnel(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	start: Vector2i,
	tile_id: int,
	random: SimRandom,
	emit_effects: bool,
	scurk_mode := false,
	map_edge: int = 128,
) -> Dictionary:
	return DemolishTransport._demolish_tunnel(
		altitude, buildings, terrain, zones, flags, misc, start, tile_id, random, emit_effects, scurk_mode,
		map_edge
	)


static func _demolish_transport_component(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	start: Vector2i,
	tile_id: int,
	random: SimRandom,
	emit_effects: bool,
	scurk_mode := false,
	map_edge: int = 128,
) -> Dictionary:
	return DemolishTransport._demolish_transport_component(
		altitude, buildings, terrain, zones, underground, flags, misc, start, tile_id, random, emit_effects,
		scurk_mode, map_edge
	)


static func _demolish_highway_section(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	misc: PackedByteArray,
	selected: Vector2i,
	random: SimRandom,
	rotation: int,
	emit_effects: bool,
	scurk_mode := false,
	map_edge: int = 128,
) -> Dictionary:
	return DemolishTransport._demolish_highway_section(
		altitude, buildings, terrain, zones, underground, flags, text_overlays, labels, microsims, misc, selected,
		random, rotation, emit_effects, scurk_mode, map_edge
	)


static func _demolish_bridge(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	selected: Vector2i,
	random: SimRandom = null,
	emit_effects := false,
	map_edge: int = 128,
) -> Dictionary:
	return DemolishBridges._demolish_bridge(
		altitude, buildings, terrain, zones, underground, flags, misc, selected, random, emit_effects, map_edge
	)


static func _demolish_reinforced_bridge(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	selected: Vector2i,
	random: SimRandom = null,
	emit_effects := false,
	map_edge: int = 128,
) -> Dictionary:
	return DemolishBridges._demolish_reinforced_bridge(
		altitude, buildings, terrain, zones, underground, flags, misc, selected, random, emit_effects, map_edge
	)


static func _reinforced_section_is_valid(
	buildings: PackedByteArray, anchor: Vector2i,
	map_edge: int = 128,
) -> bool:
	return DemolishBridges._reinforced_section_is_valid(buildings, anchor, map_edge)


static func _remove_surface_water(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	DemolishTerrain._remove_surface_water(altitude, buildings, terrain, zones, flags, misc, point, map_edge)


static func _retile_surface_water(
	terrain: PackedByteArray, flags: PackedByteArray, point: Vector2i, include_center: bool,
	map_edge: int = 128,
) -> void:
	DemolishTerrain._retile_surface_water(terrain, flags, point, include_center, map_edge)


static func _retile_adjacent_roads(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	DemolishTerrain._retile_adjacent_roads(buildings, terrain, zones, flags, misc, point, map_edge)


static func _clear_tunnel_level(altitude: PackedByteArray, index: int) -> void:
	DemolishTerrain._clear_tunnel_level(altitude, index)


static func _land_altitude(altitude: PackedByteArray, index: int) -> int:
	return DemolishTerrain._land_altitude(altitude, index)


static func _water_altitude(altitude: PackedByteArray, index: int) -> int:
	return DemolishTerrain._water_altitude(altitude, index)


static func _effect_altitude(
	altitude: PackedByteArray, flags: PackedByteArray, index: int
) -> int:
	return DemolishEffectsSites._effect_altitude(altitude, flags, index)


static func _dust_effect(
	point: Vector2i, effect_altitude: int, random: SimRandom, frame: int, screen_offset: Vector2i
) -> Dictionary:
	return DemolishEffectsSites._dust_effect(point, effect_altitude, random, frame, screen_offset)


static func _structure_effects(
	altitude: PackedByteArray,
	flags: PackedByteArray,
	site: Rect2i,
	area: int,
	random: SimRandom,
	map_edge: int = 128,
) -> Array[Dictionary]:
	return DemolishEffectsSites._structure_effects(altitude, flags, site, area, random, map_edge)


static func _set_land_altitude(altitude: PackedByteArray, index: int, value: int) -> void:
	DemolishTerrain._set_land_altitude(altitude, index, value)


static func _point_is_in_bounds(point: Vector2i, map_edge: int = 128) -> bool:
	return DemolishTerrain._point_is_in_bounds(point, map_edge)


static func _building_area(tile_id: int) -> int:
	return DemolishEffectsSites._building_area(tile_id)


static func _find_building_site(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	selected: Vector2i,
	tile_id: int,
	area: int,
	rotation: int,
	map_edge: int = 128,
) -> Rect2i:
	return DemolishEffectsSites._find_building_site(buildings, zones, selected, tile_id, area, rotation, map_edge)


static func _site_matches(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	site: Rect2i,
	tile_id: int,
	rotation: int,
	map_edge: int = 128,
) -> bool:
	return DemolishEffectsSites._site_matches(buildings, zones, site, tile_id, rotation, map_edge)


static func _release_overlay(
	text_overlays: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	index: int
) -> void:
	DemolishEffectsSites._release_overlay(text_overlays, labels, microsims, index)


static func _retile_after_demolition(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	points: Array[Vector2i],
	text_overlays := PackedByteArray(),
	map_edge: int = 128,
) -> void:
	DemolishTerrain._retile_after_demolition(
		buildings, terrain, zones, underground, flags, misc, points, text_overlays, map_edge
	)
