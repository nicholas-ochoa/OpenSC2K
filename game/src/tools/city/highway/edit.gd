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
) -> RouteEditResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return RouteEditResult.rejected("city is invalid")

	if not HighwayGeometry.supports_tool(group_index, subtool_index):
		return RouteEditResult.rejected("tool is not a highway")

	var start := HighwayGeometry.snap_anchor(selected_start)
	var finish := HighwayGeometry.snap_anchor(selected_finish)

	if not HighwayGeometry._anchor_is_in_bounds(start, map_edge) or not HighwayGeometry._anchor_is_in_bounds(finish, map_edge):
		return RouteEditResult.rejected("highway is outside the city")

	var old_payloads := NetworkState.city_payloads(city)

	if old_payloads.is_empty():
		return RouteEditResult.rejected("required city data is missing or invalid")

	var text_chunk := city.document.find_chunk("XTXT")

	if text_chunk == null or text_chunk.decoded_payload.size() != city.document.decoded_size("XTXT"):
		return RouteEditResult.rejected("required city data is missing or invalid")

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
			return RouteEditResult.rejected(bridge_plan.get("error", "highway bridge is invalid"))

		return RouteEditResult.rejected("highway cannot start on this section")

	var new_sections := 0

	for section in sections:
		if not HighwayGeometry._section_is_existing_highway(buildings, section, map_edge):
			new_sections += 1

	var listed_route_cost := (
		new_sections * int(ToolCatalog.tool(group_index, subtool_index).cost)
	)
	var route_cost := 0 if free_mode else listed_route_cost

	if city.funds() < route_cost:
		return RouteEditResult.rejected("insufficient funds", route_cost)

	var selected_bridge := bridge_type
	var bridge_choices: Array[Dictionary] = []

	if bridge_plan.get("ok", false):
		bridge_choices = HighwayBridges._bridge_choices(bridge_plan)

		if selected_bridge == BRIDGE_UNSELECTED:
			var choice := RouteEditResult.rejected("highway bridge type selection is required")
			choice.bridge_selection_required = true
			choice.bridge_choices = bridge_choices
			choice.bridge_span_length = int(bridge_plan.span_length)
			choice.route_cost = route_cost
			choice.listed_route_cost = listed_route_cost
			choice.free_mode = free_mode
			choice.sections = sections

			return choice

		if selected_bridge >= 0 and not HighwayBridges._bridge_choice_exists(
			bridge_choices, selected_bridge
		):
			return RouteEditResult.rejected("selected highway bridge is not available")
	elif selected_bridge >= 0:
		return RouteEditResult.rejected("highway bridge is not available")

	if (
		bridge_plan.get("ok", false)
		and selected_bridge == BRIDGE_CANCELLED
		and sections.is_empty()
	):
		var cancelled := RouteEditResult.rejected("bridge selection canceled")
		cancelled.cancelled = true

		return cancelled

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
				return RouteEditResult.rejected("insufficient funds", bridge_cost)
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
		var confirmation := RouteEditResult.rejected("neighbor connection confirmation is required")
		confirmation.connection_selection_required = true
		confirmation.connection_anchor = connection_anchor
		confirmation.connection_cost = connection_cost
		confirmation.listed_connection_cost = CONNECTION_COST
		confirmation.route_cost = route_cost
		confirmation.listed_route_cost = listed_route_cost
		confirmation.free_mode = free_mode
		confirmation.sections = sections

		return confirmation

	if connection_choice == CONNECTION_CONFIRMED:
		if not connection_available:
			return RouteEditResult.rejected("neighbor connection is not available")

		if not connection_affordable:
			return RouteEditResult.rejected("insufficient funds", route_cost + CONNECTION_COST)

	var connection_built := connection_choice == CONNECTION_CONFIRMED
	var cost := (
		route_cost
		+ (bridge_cost if bridge_built else 0)
		+ (connection_cost if connection_built else 0)
	)

	var changed_payloads := NetworkState._duplicate_payloads(old_payloads)
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
			return RouteEditResult.rejected(placement.error)

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

	BuildingState._write_u32_be(misc, BuildingCommand.MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XBIT", "XTXT", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not NetworkState._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		return RouteEditResult.rejected("cannot store highway changes")

	var tile_indices := PackedInt32Array()
	var affected_sections: Array[Vector2i] = sections.duplicate()

	for anchor in bridge_sections + bridge_endpoint_sections:
		if not affected_sections.has(anchor):
			affected_sections.append(anchor)

	for anchor in affected_sections:
		for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var point: Vector2i = anchor + offset
			tile_indices.append(point.x * map_edge + point.y)

	var result := RouteEditResult.new()
	result.ok = true
	result.command_type = "highway"
	result.group_index = group_index
	result.subtool_index = subtool_index
	result.start = start
	result.finish = finish
	result.sections = sections
	result.tile_indices = tile_indices
	result.cost = cost
	result.route_cost = route_cost
	result.listed_cost = (
		listed_route_cost
		+ (listed_bridge_cost if bridge_built else 0)
		+ (CONNECTION_COST if connection_built else 0)
	)
	result.listed_route_cost = listed_route_cost
	result.free_mode = free_mode
	result.bridge_built = bridge_built

	if bridge_built:
		result.bridge_exit = bridge_plan.start + DIRECTIONS[int(bridge_plan.direction)] * int(bridge_plan.span_length) * 2
		result.bridge_type = selected_bridge
		result.bridge_name = HighwayBridges.bridge_type_name(selected_bridge)
		result.bridge_cost = bridge_cost
		result.listed_bridge_cost = listed_bridge_cost

	result.bridge_cancelled = bridge_plan.get("ok", false) and selected_bridge == BRIDGE_CANCELLED
	result.bridge_sections = bridge_sections
	result.bridge_endpoint_sections = bridge_endpoint_sections
	result.bridge_span_length = int(bridge_plan.get("span_length", 0))
	result.bridge_error = bridge_error if bridge_attempted else ""
	result.connection_built = connection_built
	result.connection_cancelled = connection_available and connection_choice == CONNECTION_CANCELLED
	result.connection_anchor = connection_anchor

	if connection_built:
		result.connection_cost = connection_cost
		result.listed_connection_cost = CONNECTION_COST

	result.graded_sections = graded_sections
	result.connection_error = (
		"insufficient funds for the neighbor connection"
		if connection_available and not connection_affordable
		else ""
	)
	result.stopped_early = not bridge_built and (sections.is_empty() or sections[-1] != finish)
	result.changed_ids = changed_ids
	result.old_payloads = old_payloads
	result.new_payloads = changed_payloads

	return result


static func undo(city: CityState, command: RouteEditResult) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != "highway":
		return EditCommandResult.failure("highway command is invalid")

	var changed_ids := command.changed_ids
	var old_payloads := command.old_payloads
	var new_payloads := command.new_payloads

	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return EditCommandResult.failure("city changed after this highway command")

	if not NetworkState._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return EditCommandResult.failure("cannot restore highway changes")

	return EditCommandResult.undone(command.tile_indices.size())


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
