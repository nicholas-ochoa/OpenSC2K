class_name DemolishCommand
extends DemolishConstants



static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_BULLDOZER and subtool_index == SUBTOOL_DEMOLISH


static func structure_area(tile_id: int) -> int:
	return DemolishStructures.structure_area(tile_id)


static func damage_structure_payloads(
	city: CityState, payloads: Dictionary, point: Vector2i, random, emit_effects := false
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
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if not supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool is not the demolish tool"}

	if random == null:
		return {"ok": false, "error": "random state is required"}

	if points.is_empty():
		return {"ok": false, "error": "demolish path is empty"}

	var old_payloads := BuildingCommand._city_payloads(city)

	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}

	var altitude_chunk := city.document.find_chunk("ALTM")

	if altitude_chunk == null or altitude_chunk.decoded_payload.size() != (map_edge * map_edge) * 2:
		return {"ok": false, "error": "required altitude data is missing or invalid"}

	old_payloads.ALTM = altitude_chunk.decoded_payload.duplicate()
	var changed_payloads := BuildingCommand._duplicate_payloads(old_payloads)
	var altitude: PackedByteArray = changed_payloads.ALTM
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var underground: PackedByteArray = changed_payloads.XUND
	var flags: PackedByteArray = changed_payloads.XBIT
	var text_overlays: PackedByteArray = changed_payloads.XTXT
	var labels: PackedByteArray = changed_payloads.XLAB
	var microsims: PackedByteArray = changed_payloads.XMIC
	var misc: PackedByteArray = changed_payloads.MISC
	var listed_cost_per_action := int(
		ToolCatalog.tool(group_index, subtool_index).cost
	)
	var cost_per_action := 0 if scurk_mode else listed_cost_per_action
	var total_cost := 0
	var action_count := 0
	var changed_indices := PackedInt32Array()
	var skipped_specialized := 0
	var skipped_insufficient := 0
	var easter_events := 0
	var news_items: Array[Dictionary] = []
	var effect_events: Array[Dictionary] = []
	var sound_events: Array[int] = []
	var random_state_before := random.state

	for point in points:
		if city.index_of(point.x, point.y) < 0:
			continue

		if city.funds() - total_cost < cost_per_action:
			skipped_insufficient += 1
			continue

		var result := (
			_demolish_underground_point(
				city,
				altitude,
				buildings,
				terrain,
				zones,
				underground,
				flags,
				text_overlays,
				labels,
				microsims,
				misc,
				point,
				random,
				scurk_mode
			)
			if underground_view
			else _demolish_point(
				city,
				altitude,
				buildings,
				terrain,
				zones,
				underground,
				flags,
				text_overlays,
				labels,
				microsims,
				misc,
				point,
				random,
				scurk_mode,
				true,
				not scurk_mode,
				scurk_mode
			)
		)

		if result.get("specialized", false):
			skipped_specialized += 1
			continue

		if not result.get("changed", false):
			continue

		action_count += 1
		total_cost += cost_per_action

		if result.get("easter_event", false):
			easter_events += 1
			var news_result := NewsQueue.insert(misc, NEWS_FOREST_PROTEST, 0)

			if not news_result.ok:
				random.state = random_state_before

				return {"ok": false, "error": "cannot store forest protest news"}

			news_items.append({"type": NEWS_FOREST_PROTEST, "argument": 0})
			sound_events.append(SOUND_FOREST_PROTEST)

		var result_effects: Array = result.get("effect_events", [])
		var effect_offset := parallel_effect_offset(
			point, action_count - 1, random_state_before
		)
		append_effect_sequence(effect_events, result_effects, effect_offset)

		if not result_effects.is_empty() and not sound_events.has(SOUND_EXPLODE):
			sound_events.append(SOUND_EXPLODE)

		for index in result.get("indices", PackedInt32Array()):
			if not changed_indices.has(index):
				changed_indices.append(index)

	if action_count == 0:
		random.state = random_state_before

		if skipped_insufficient > 0:
			return {"ok": false, "error": "insufficient funds", "cost": cost_per_action}

		if skipped_specialized > 0:
			return {"ok": false, "error": "reinforced bridge or network data is malformed"}

		return {"ok": false, "error": "no eligible tiles changed"}

	BuildingCommand._write_u32_be(
		misc, BuildingCommand.MISC_FUNDS, city.funds() - total_cost
	)

	if scurk_mode:
		changed_payloads.XTER = old_payloads.XTER.duplicate()
		changed_payloads.ALTM = old_payloads.ALTM.duplicate()
		var scurk_zones: PackedByteArray = changed_payloads.XZON
		var old_zones: PackedByteArray = old_payloads.XZON
		var scurk_flags: PackedByteArray = changed_payloads.XBIT
		var old_flags: PackedByteArray = old_payloads.XBIT

		for index in (map_edge * map_edge):
			scurk_zones[index] = (
				(scurk_zones[index] & 0xf0) | (old_zones[index] & 0x0f)
			)
			scurk_flags[index] = (
				(scurk_flags[index] & ~FLAG_WATER & 0xff)
				| (old_flags[index] & FLAG_WATER)
			)

	var changed_ids := PackedStringArray()

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not BuildingCommand._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		random.state = random_state_before

		return {"ok": false, "error": "cannot store demolition changes"}

	_refresh_altitude(city, changed_payloads.ALTM)

	return {
		"ok": true,
		"command_type": "demolish",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"underground_view": underground_view,
		"tile_indices": changed_indices,
		"action_count": action_count,
		"cost": total_cost,
		"listed_cost": action_count * listed_cost_per_action,
		"scurk_mode": scurk_mode,
		"skipped_specialized": skipped_specialized,
		"skipped_insufficient": skipped_insufficient,
		"easter_events": easter_events,
		"news_items": news_items,
		"news_queue_updated": easter_events > 0,
		"effect_events": effect_events,
		"sound_events": sound_events,
		"changed_ids": changed_ids,
		"old_payloads": old_payloads,
		"new_payloads": changed_payloads,
		"random_state_before": random_state_before,
		"random_state_after": random.state,
		"error": "",
	}


static func undo(city: CityState, command: Dictionary, random: SimRandom) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if not command.get("ok", false) or command.get("command_type", "") != "demolish":
		return {"ok": false, "error": "demolish command is invalid"}

	if random == null:
		return {"ok": false, "error": "random state is required"}

	if random.state != int(command.get("random_state_after", -1)):
		return {"ok": false, "error": "random state changed after this demolish command"}

	var changed_ids: PackedStringArray = command.get("changed_ids", PackedStringArray())
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})

	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return {"ok": false, "error": "city changed after this demolish command"}

	if not BuildingCommand._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore demolition changes"}

	_refresh_altitude(city, old_payloads.ALTM)
	random.state = int(command.random_state_before)
	var indices: PackedInt32Array = command.get("tile_indices", PackedInt32Array())

	return {"ok": true, "restored_tiles": indices.size(), "error": ""}


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
	random,
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
	random,
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
	random,
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
	random,
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
	random,
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
	random = null,
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
	random = null,
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
	point: Vector2i, effect_altitude: int, random, frame: int, screen_offset: Vector2i
) -> Dictionary:
	return DemolishEffectsSites._dust_effect(point, effect_altitude, random, frame, screen_offset)


static func _structure_effects(
	altitude: PackedByteArray,
	flags: PackedByteArray,
	site: Rect2i,
	area: int,
	random,
	map_edge: int = 128,
) -> Array[Dictionary]:
	return DemolishEffectsSites._structure_effects(altitude, flags, site, area, random, map_edge)


static func _set_land_altitude(altitude: PackedByteArray, index: int, value: int) -> void:
	DemolishTerrain._set_land_altitude(altitude, index, value)


static func _point_is_in_bounds(point: Vector2i, map_edge: int = 128) -> bool:
	return DemolishTerrain._point_is_in_bounds(point, map_edge)


static func _refresh_altitude(city: CityState, altitude: PackedByteArray) -> void:
	DemolishTerrain._refresh_altitude(city, altitude)


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
