class_name HighwayEdit
extends HighwayConstants


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
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if not HighwayGeometry.supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool is not a highway"}

	var start := HighwayGeometry.snap_anchor(selected_start)
	var finish := HighwayGeometry.snap_anchor(selected_finish)

	if not HighwayGeometry._anchor_is_in_bounds(start, map_edge) or not HighwayGeometry._anchor_is_in_bounds(finish, map_edge):
		return {"ok": false, "error": "highway is outside the city"}

	var old_payloads := NetworkCommand._city_payloads(city)

	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}

	var text_chunk := city.document.find_chunk("XTXT")

	if text_chunk == null or text_chunk.decoded_payload.size() != city.document.decoded_size("XTXT"):
		return {"ok": false, "error": "required city data is missing or invalid"}

	old_payloads["XTXT"] = text_chunk.decoded_payload.duplicate()
	var buildings: PackedByteArray = old_payloads.XBLD
	var terrain: PackedByteArray = old_payloads.XTER
	var flags: PackedByteArray = old_payloads.XBIT
	var altitude: PackedByteArray = old_payloads.ALTM
	var text_overlays: PackedByteArray = old_payloads.XTXT
	var sections := HighwayRoutes._plan_flat_route(
		buildings, terrain, flags, altitude, start, finish, map_edge
	)
	var bridge_plan := {}
	var bridge_attempted := false

	if sections.is_empty() and HighwayGeometry._section_has_water(flags, start, map_edge):
		bridge_attempted = true
		bridge_plan = HighwayBridges.plan_bridge_from_start(
			buildings, terrain, altitude, start, city.compass_rotation(), map_edge
		)
	elif not sections.is_empty():
		var exit_direction := HighwayGeometry._section_direction(sections, sections.size() - 1, finish)
		var bridge_start: Vector2i = sections[-1] + DIRECTIONS[exit_direction] * 2

		if HighwayGeometry._section_has_water(flags, bridge_start, map_edge):
			bridge_attempted = true
			bridge_plan = HighwayBridges._scan_bridge(
				buildings, terrain, altitude, bridge_start, exit_direction, map_edge
			)

	if sections.is_empty() and not bridge_plan.get("ok", false):
		if bridge_attempted:
			return {
				"ok": false,
				"error": bridge_plan.get("error", "highway bridge is invalid"),
			}

		return {"ok": false, "error": "highway cannot start on this section"}

	var new_sections := 0

	for section in sections:
		if not HighwayGeometry._section_is_existing_highway(buildings, section, map_edge):
			new_sections += 1

	var listed_route_cost := (
		new_sections * int(ToolCatalog.tool(group_index, subtool_index).cost)
	)
	var route_cost := 0 if free_mode else listed_route_cost

	if city.funds() < route_cost:
		return {"ok": false, "error": "insufficient funds", "cost": route_cost}

	var selected_bridge := bridge_type
	var bridge_choices: Array[Dictionary] = []

	if bridge_plan.get("ok", false):
		bridge_choices = HighwayBridges._bridge_choices(bridge_plan)

		if selected_bridge == BRIDGE_UNSELECTED:
			return {
				"ok": false,
				"bridge_selection_required": true,
				"bridge_choices": bridge_choices,
				"bridge_span_length": int(bridge_plan.span_length),
				"route_cost": route_cost,
				"listed_route_cost": listed_route_cost,
				"free_mode": free_mode,
				"dry_sections": sections,
				"error": "highway bridge type selection is required",
			}

		if selected_bridge >= 0 and not HighwayBridges._bridge_choice_exists(
			bridge_choices, selected_bridge
		):
			return {"ok": false, "error": "selected highway bridge is not available"}
	elif selected_bridge >= 0:
		return {"ok": false, "error": "highway bridge is not available"}

	if (
		bridge_plan.get("ok", false)
		and selected_bridge == BRIDGE_CANCELLED
		and sections.is_empty()
	):
		return {"ok": false, "cancelled": true, "error": "bridge selection canceled"}

	var listed_bridge_cost := 0
	var bridge_cost := 0
	var bridge_built := false
	var bridge_error := ""

	if bridge_plan.get("ok", false) and selected_bridge >= 0:
		listed_bridge_cost = (
			int(bridge_plan.span_length) * int(BRIDGE_COSTS[selected_bridge])
		)
		bridge_cost = 0 if free_mode else listed_bridge_cost

		if not free_mode and city.funds() - route_cost < bridge_cost:
			bridge_error = "insufficient funds for the highway bridge"

			if sections.is_empty():
				return {"ok": false, "error": "insufficient funds", "cost": bridge_cost}
		else:
			bridge_built = true

	var connection_anchor: Vector2i = sections[-1] if not sections.is_empty() else start
	var connection_available := (
		not bridge_attempted
		and not sections.is_empty()
		and HighwayGeometry._is_connection_exit(sections, finish, map_edge)
		and OverlayData.read(text_overlays, start.x * map_edge + start.y) != CONNECTION_LABEL
	)
	var connection_affordable := (
		free_mode or city.funds() - route_cost >= CONNECTION_COST
	)
	var connection_cost := 0 if free_mode else CONNECTION_COST

	if (
		connection_available
		and connection_affordable
		and connection_choice == CONNECTION_UNSELECTED
	):
		return {
			"ok": false,
			"connection_selection_required": true,
			"connection_anchor": connection_anchor,
			"connection_cost": connection_cost,
			"listed_connection_cost": CONNECTION_COST,
			"route_cost": route_cost,
			"listed_route_cost": listed_route_cost,
			"free_mode": free_mode,
			"sections": sections,
			"error": "neighbor connection confirmation is required",
		}

	if connection_choice == CONNECTION_CONFIRMED:
		if not connection_available:
			return {"ok": false, "error": "neighbor connection is not available"}

		if not connection_affordable:
			return {
				"ok": false,
				"error": "insufficient funds",
				"cost": route_cost + CONNECTION_COST,
			}

	var connection_built := connection_choice == CONNECTION_CONFIRMED
	var cost := (
		route_cost
		+ (bridge_cost if bridge_built else 0)
		+ (connection_cost if connection_built else 0)
	)

	var changed_payloads := NetworkCommand._duplicate_payloads(old_payloads)
	buildings = changed_payloads.XBLD
	terrain = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	flags = changed_payloads.XBIT
	altitude = changed_payloads.ALTM
	text_overlays = changed_payloads.XTXT
	var misc: PackedByteArray = changed_payloads.MISC
	var graded_sections := 0
	var route_directions := {}

	for section_index in sections.size():
		var direction := HighwayGeometry._section_direction(sections, section_index, finish)
		var section := sections[section_index]
		route_directions[section] = direction

		if HighwayGeometry._section_is_existing_highway(buildings, section, map_edge):
			continue

		var placement := HighwayPlacement._place_section(
			buildings,
			terrain,
			zones,
			flags,
			altitude,
			text_overlays,
			misc,
			section,
			direction,
			city.compass_rotation(), map_edge
		)

		if not placement.ok:
			return placement

		if placement.graded:
			graded_sections += 1

	if connection_built:
		OverlayData.write(text_overlays,
			connection_anchor.x * map_edge + connection_anchor.y
		, CONNECTION_LABEL)

	HighwayPlacement._retile_affected_sections(
		buildings,
		terrain,
		zones,
		flags,
		altitude,
		misc,
		sections,
		city.compass_rotation(),
		text_overlays,
		route_directions, map_edge
	)
	var bridge_sections: Array[Vector2i] = []
	var bridge_endpoint_sections: Array[Vector2i] = []

	if bridge_built:
		var bridge_result := HighwayBridges._place_bridge(
			buildings,
			terrain,
			zones,
			flags,
			altitude,
			misc,
			bridge_plan,
			selected_bridge,
			city.compass_rotation(), map_edge
		)
		bridge_sections = bridge_result.sections
		bridge_endpoint_sections = bridge_result.endpoint_sections

	BuildingCommand._write_u32_be(misc, BuildingCommand.MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XBIT", "XTXT", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not NetworkCommand._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		return {"ok": false, "error": "cannot store highway changes"}

	var tile_indices := PackedInt32Array()
	var affected_sections: Array[Vector2i] = sections.duplicate()

	for anchor in bridge_sections + bridge_endpoint_sections:
		if not affected_sections.has(anchor):
			affected_sections.append(anchor)

	for anchor in affected_sections:
		for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var point: Vector2i = anchor + offset
			tile_indices.append(point.x * map_edge + point.y)

	return {
		"ok": true,
		"command_type": "highway",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"start": start,
		"finish": finish,
		"sections": sections,
		"tile_indices": tile_indices,
		"cost": cost,
		"route_cost": route_cost,
		"listed_cost": (
			listed_route_cost
			+ (listed_bridge_cost if bridge_built else 0)
			+ (CONNECTION_COST if connection_built else 0)
		),
		"listed_route_cost": listed_route_cost,
		"free_mode": free_mode,
		"bridge_built": bridge_built,
		"bridge_exit": bridge_plan.start + DIRECTIONS[int(bridge_plan.direction)] * int(bridge_plan.span_length) * 2 if bridge_built else Vector2i(-1, -1),
		"bridge_cancelled": (
			bridge_plan.get("ok", false) and selected_bridge == BRIDGE_CANCELLED
		),
		"bridge_type": selected_bridge if bridge_built else BRIDGE_UNSELECTED,
		"bridge_name": HighwayBridges.bridge_type_name(selected_bridge) if bridge_built else "",
		"bridge_sections": bridge_sections,
		"bridge_endpoint_sections": bridge_endpoint_sections,
		"bridge_span_length": int(bridge_plan.get("span_length", 0)),
		"bridge_cost": bridge_cost if bridge_built else 0,
		"listed_bridge_cost": listed_bridge_cost if bridge_built else 0,
		"bridge_error": bridge_error if bridge_attempted else "",
		"connection_built": connection_built,
		"connection_cancelled": (
			connection_available and connection_choice == CONNECTION_CANCELLED
		),
		"connection_anchor": connection_anchor,
		"connection_cost": connection_cost if connection_built else 0,
		"listed_connection_cost": CONNECTION_COST if connection_built else 0,
		"graded_sections": graded_sections,
		"connection_error": (
			"insufficient funds for the neighbor connection"
			if connection_available and not connection_affordable
			else ""
		),
		"stopped_early": (
			not bridge_built
			and (sections.is_empty() or sections[-1] != finish)
		),
		"changed_ids": changed_ids,
		"old_payloads": old_payloads,
		"new_payloads": changed_payloads,
		"error": "",
	}


static func undo(city: CityState, command: Dictionary) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if not command.get("ok", false) or command.get("command_type", "") != "highway":
		return {"ok": false, "error": "highway command is invalid"}

	var changed_ids: PackedStringArray = command.get("changed_ids", PackedStringArray())
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})

	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return {"ok": false, "error": "city changed after this highway command"}

	if not NetworkCommand._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore highway changes"}

	var tile_indices: PackedInt32Array = command.get("tile_indices", PackedInt32Array())

	return {"ok": true, "restored_tiles": tile_indices.size(), "error": ""}


static func preview_valid(city: CityState, selected: Vector2i) -> bool:
	var map_edge: int = city.map_size if city != null else 128
	var anchor := HighwayGeometry.snap_anchor(selected)

	if city == null or not HighwayGeometry._anchor_is_in_bounds(anchor, map_edge):
		return false

	var altitude: PackedByteArray = city.document.find_chunk("ALTM").decoded_payload
	var sections := HighwayRoutes._plan_flat_route(city.buildings, city.terrain, city.tile_flags, altitude, anchor, anchor, map_edge)

	if not sections.is_empty():
		return HighwayGeometry._section_is_existing_highway(city.buildings, anchor, map_edge) or city.funds() >= 100

	if HighwayGeometry._section_has_water(city.tile_flags, anchor, map_edge):
		var bridge := HighwayBridges.plan_bridge_from_start(city.buildings, city.terrain, altitude, anchor, city.compass_rotation(), map_edge)

		if bridge.get("ok", false):
			for choice in HighwayBridges._bridge_choices(bridge):
				if city.funds() >= int(choice.get("cost", 0)):
					return true

	return false


static func preview_error(city: CityState, selected: Vector2i) -> String:
	var map_edge: int = city.map_size if city != null else 128

	if preview_valid(city, selected):
		return ""

	var anchor := HighwayGeometry.snap_anchor(selected)

	if city == null or not HighwayGeometry._anchor_is_in_bounds(anchor, map_edge):
		return "The 2 by 2 highway section extends outside the map."

	if HighwayGeometry._section_has_water(city.tile_flags, anchor, map_edge):
		var altitude: PackedByteArray = city.document.find_chunk("ALTM").decoded_payload
		var bridge := HighwayBridges.plan_bridge_from_start(city.buildings, city.terrain, altitude, anchor, city.compass_rotation(), map_edge)

		if not bridge.get("ok", false):
			return String(bridge.get("error", "This shore cannot start a highway bridge."))

		return "Insufficient funds for this highway bridge."

	if city.funds() < 100:
		return "Insufficient funds for this highway section."

	var direction := HighwayGeometry._primary_direction(anchor, anchor)

	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var tile_id := city.building_id(point.x, point.y)

		if not HighwayGeometry._building_is_allowed(tile_id):
			return "Clear the structure in the highway footprint first."

		if tile_id > 0x0e and not HighwayGeometry._is_highway_tile(tile_id) and not HighwayGeometry._network_can_cross(tile_id, direction):
			return "The existing network cannot cross a highway in this direction."

	return "The 2 by 2 highway section has incompatible elevations or slopes."
