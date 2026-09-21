class_name HighwayEdit
extends HighwayConstants



class SegmentPlan:
	var city: CityState
	var map_edge: int
	var group_index: int
	var subtool_index: int
	var start: Vector2i
	var finish: Vector2i
	var free_mode: bool
	var old_payloads: Dictionary
	var sections: Array[Vector2i] = []
	var bridge_plan: HighwayBridges.Plan
	var bridge_attempted := false
	var listed_route_cost := 0
	var route_cost := 0
	var selected_bridge := BRIDGE_UNSELECTED
	var listed_bridge_cost := 0
	var bridge_cost := 0
	var bridge_built := false
	var bridge_error := ""
	var connection_choice := CONNECTION_UNSELECTED
	var connection_anchor := Vector2i.ZERO
	var connection_available := false
	var connection_affordable := false
	var connection_cost := 0
	var connection_built := false
	var cost := 0
	var changed_payloads: Dictionary
	var graded_sections := 0
	var bridge_sections: Array[Vector2i] = []
	var bridge_endpoint_sections: Array[Vector2i] = []


	func has_bridge() -> bool:
		return bridge_plan != null and bridge_plan.ok


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
	if city == null or not city.is_valid():
		return RouteEditResult.rejected("city is invalid")

	if not HighwayGeometry.supports_tool(group_index, subtool_index):
		return RouteEditResult.rejected("tool is not a highway")

	var plan := SegmentPlan.new()
	plan.city = city
	plan.map_edge = city.map_size
	plan.group_index = group_index
	plan.subtool_index = subtool_index
	plan.start = HighwayGeometry.snap_anchor(selected_start)
	plan.finish = HighwayGeometry.snap_anchor(selected_finish)
	plan.selected_bridge = bridge_type
	plan.connection_choice = connection_choice
	plan.free_mode = free_mode

	if (
		not HighwayGeometry._anchor_is_in_bounds(plan.start, plan.map_edge)
		or not HighwayGeometry._anchor_is_in_bounds(plan.finish, plan.map_edge)
	):
		return RouteEditResult.rejected("highway is outside the city")

	var rejection := _plan_route(plan)

	if rejection == null:
		rejection = _validate_route_cost(plan)

	if rejection == null:
		rejection = _validate_bridge_choice(plan)

	if rejection == null:
		rejection = _validate_connection_choice(plan)

	if rejection == null:
		rejection = _apply_to_payload_copies(plan)

	if rejection != null:
		return rejection

	var changed_ids := PackedStringArray()

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XBIT", "XTXT", "MISC"]:
		if plan.changed_payloads[chunk_id] != plan.old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not NetworkState._apply_payloads(city, changed_ids, plan.changed_payloads, plan.old_payloads):
		return RouteEditResult.rejected("cannot store highway changes")

	return _undo_record(plan, changed_ids)


# plan the flat 2 by 2 sections from start toward finish, and a bridge where
# the route starts on or reaches water. returns a rejection when neither exists
static func _plan_route(plan: SegmentPlan) -> RouteEditResult:
	var city := plan.city
	var map_edge := plan.map_edge
	var old_payloads := NetworkState.city_payloads(city)

	if old_payloads.is_empty():
		return RouteEditResult.rejected("required city data is missing or invalid")

	var text_chunk := city.document.find_chunk("XTXT")

	if text_chunk == null or text_chunk.decoded_payload.size() != city.document.decoded_size("XTXT"):
		return RouteEditResult.rejected("required city data is missing or invalid")

	old_payloads["XTXT"] = text_chunk.decoded_payload.duplicate()
	plan.old_payloads = old_payloads
	var buildings: PackedByteArray = old_payloads.XBLD
	var terrain: PackedByteArray = old_payloads.XTER
	var flags: PackedByteArray = old_payloads.XBIT
	var altitude: PackedByteArray = old_payloads.ALTM
	var start := plan.start
	var finish := plan.finish
	var sections := HighwayRoutes._plan_flat_route(
		buildings, terrain, flags, altitude, start, finish, map_edge
	)
	plan.sections = sections

	if sections.is_empty() and HighwayGeometry._section_has_water(flags, start, map_edge):
		plan.bridge_attempted = true
		plan.bridge_plan = HighwayBridges.plan_bridge_from_start(
			buildings, terrain, altitude, start, city.compass_rotation(), map_edge
		)
	elif not sections.is_empty():
		var exit_direction := HighwayGeometry._section_direction(sections, sections.size() - 1, finish)
		var bridge_start: Vector2i = sections[-1] + DIRECTIONS[exit_direction] * 2

		if HighwayGeometry._section_has_water(flags, bridge_start, map_edge):
			plan.bridge_attempted = true
			plan.bridge_plan = HighwayBridges._scan_bridge(
				buildings, terrain, altitude, bridge_start, exit_direction, map_edge
			)

	if sections.is_empty() and not plan.has_bridge():
		if plan.bridge_attempted:
			return RouteEditResult.rejected(plan.bridge_plan.error)

		return RouteEditResult.rejected("highway cannot start on this section")

	return null


# price the new sections. existing highway sections are free
static func _validate_route_cost(plan: SegmentPlan) -> RouteEditResult:
	var new_sections := 0

	for section in plan.sections:
		if not HighwayGeometry._section_is_existing_highway(plan.old_payloads.XBLD, section, plan.map_edge):
			new_sections += 1

	plan.listed_route_cost = (
		new_sections * int(ToolCatalog.tool(plan.group_index, plan.subtool_index).cost)
	)
	plan.route_cost = 0 if plan.free_mode else plan.listed_route_cost

	if plan.city.funds() < plan.route_cost:
		return RouteEditResult.rejected("insufficient funds", plan.route_cost)

	return null


# ask for a bridge type when one is needed, check the chosen type, and decide
# whether the funds cover it. a bridge the city cannot afford is skipped
# unless it is the whole segment
static func _validate_bridge_choice(plan: SegmentPlan) -> RouteEditResult:
	var selected_bridge := plan.selected_bridge

	if plan.has_bridge():
		var bridge_choices := HighwayBridges._bridge_choices(plan.bridge_plan)

		if selected_bridge == BRIDGE_UNSELECTED:
			var choice := RouteEditResult.rejected("highway bridge type selection is required")
			choice.bridge_selection_required = true
			choice.bridge_choices = bridge_choices
			choice.bridge_span_length = int(plan.bridge_plan.span_length)
			choice.route_cost = plan.route_cost
			choice.listed_route_cost = plan.listed_route_cost
			choice.free_mode = plan.free_mode
			choice.sections = plan.sections

			return choice

		if selected_bridge >= 0 and not HighwayBridges._bridge_choice_exists(
			bridge_choices, selected_bridge
		):
			return RouteEditResult.rejected("selected highway bridge is not available")
	elif selected_bridge >= 0:
		return RouteEditResult.rejected("highway bridge is not available")

	if (
		plan.has_bridge()
		and selected_bridge == BRIDGE_CANCELLED
		and plan.sections.is_empty()
	):
		var cancelled := RouteEditResult.rejected("bridge selection canceled")
		cancelled.cancelled = true

		return cancelled

	if plan.has_bridge() and selected_bridge >= 0:
		plan.listed_bridge_cost = (
			int(plan.bridge_plan.span_length) * int(BRIDGE_COSTS[selected_bridge])
		)
		plan.bridge_cost = 0 if plan.free_mode else plan.listed_bridge_cost

		if not plan.free_mode and plan.city.funds() - plan.route_cost < plan.bridge_cost:
			plan.bridge_error = "insufficient funds for the highway bridge"

			if plan.sections.is_empty():
				return RouteEditResult.rejected("insufficient funds", plan.bridge_cost)
		else:
			plan.bridge_built = true

	return null


# offer a neighbor connection when the route leaves the map edge, and check
# a confirmed connection. then total the segment cost
static func _validate_connection_choice(plan: SegmentPlan) -> RouteEditResult:
	var sections := plan.sections
	var start := plan.start
	var map_edge := plan.map_edge
	var free_mode := plan.free_mode
	plan.connection_anchor = sections[-1] if not sections.is_empty() else start
	plan.connection_available = (
		not plan.bridge_attempted
		and not sections.is_empty()
		and HighwayGeometry._is_connection_exit(sections, plan.finish, map_edge)
		and OverlayData.read(plan.old_payloads.XTXT, start.x * map_edge + start.y) != CONNECTION_LABEL
	)
	plan.connection_affordable = (
		free_mode or plan.city.funds() - plan.route_cost >= CONNECTION_COST
	)
	plan.connection_cost = 0 if free_mode else CONNECTION_COST

	if (
		plan.connection_available
		and plan.connection_affordable
		and plan.connection_choice == CONNECTION_UNSELECTED
	):
		var confirmation := RouteEditResult.rejected("neighbor connection confirmation is required")
		confirmation.connection_selection_required = true
		confirmation.connection_anchor = plan.connection_anchor
		confirmation.connection_cost = plan.connection_cost
		confirmation.listed_connection_cost = CONNECTION_COST
		confirmation.route_cost = plan.route_cost
		confirmation.listed_route_cost = plan.listed_route_cost
		confirmation.free_mode = free_mode
		confirmation.sections = sections

		return confirmation

	if plan.connection_choice == CONNECTION_CONFIRMED:
		if not plan.connection_available:
			return RouteEditResult.rejected("neighbor connection is not available")

		if not plan.connection_affordable:
			return RouteEditResult.rejected("insufficient funds", plan.route_cost + CONNECTION_COST)

	plan.connection_built = plan.connection_choice == CONNECTION_CONFIRMED
	plan.cost = (
		plan.route_cost
		+ (plan.bridge_cost if plan.bridge_built else 0)
		+ (plan.connection_cost if plan.connection_built else 0)
	)

	return null


# place the sections, connection label, and bridge in copies of the city
# payloads, and charge the funds. returns a rejection when a section fails
static func _apply_to_payload_copies(plan: SegmentPlan) -> RouteEditResult:
	var city := plan.city
	var map_edge := plan.map_edge
	var sections := plan.sections
	var changed_payloads := NetworkState._duplicate_payloads(plan.old_payloads)
	plan.changed_payloads = changed_payloads
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var flags: PackedByteArray = changed_payloads.XBIT
	var altitude: PackedByteArray = changed_payloads.ALTM
	var text_overlays: PackedByteArray = changed_payloads.XTXT
	var misc: PackedByteArray = changed_payloads.MISC
	var route_directions := {}

	for section_index in sections.size():
		var direction := HighwayGeometry._section_direction(sections, section_index, plan.finish)
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
			plan.graded_sections += 1

	if plan.connection_built:
		OverlayData.write(text_overlays,
			plan.connection_anchor.x * map_edge + plan.connection_anchor.y
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

	if plan.bridge_built:
		var bridge_result := HighwayBridges._place_bridge(
			buildings,
			terrain,
			zones,
			flags,
			altitude,
			misc,
			plan.bridge_plan,
			plan.selected_bridge,
			city.compass_rotation(), map_edge
		)
		plan.bridge_sections = bridge_result.sections
		plan.bridge_endpoint_sections = bridge_result.endpoint_sections

	BuildingState._write_u32_be(misc, BuildingCommand.MISC_FUNDS, city.funds() - plan.cost)

	return null


# describe the stored segment, with the old and new payloads undo restores
static func _undo_record(plan: SegmentPlan, changed_ids: PackedStringArray) -> RouteEditResult:
	var map_edge := plan.map_edge
	var sections := plan.sections
	var bridge_plan := plan.bridge_plan
	var bridge_built := plan.bridge_built
	var connection_built := plan.connection_built
	var tile_indices := PackedInt32Array()
	var affected_sections: Array[Vector2i] = sections.duplicate()

	for anchor in plan.bridge_sections + plan.bridge_endpoint_sections:
		if not affected_sections.has(anchor):
			affected_sections.append(anchor)

	for anchor in affected_sections:
		for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var point: Vector2i = anchor + offset
			tile_indices.append(point.x * map_edge + point.y)

	var result := RouteEditResult.new()
	result.ok = true
	result.command_type = "highway"
	result.group_index = plan.group_index
	result.subtool_index = plan.subtool_index
	result.start = plan.start
	result.finish = plan.finish
	result.sections = sections
	result.tile_indices = tile_indices
	result.cost = plan.cost
	result.route_cost = plan.route_cost
	result.listed_cost = (
		plan.listed_route_cost
		+ (plan.listed_bridge_cost if bridge_built else 0)
		+ (CONNECTION_COST if connection_built else 0)
	)
	result.listed_route_cost = plan.listed_route_cost
	result.free_mode = plan.free_mode
	result.bridge_built = bridge_built

	if bridge_built:
		result.bridge_exit = bridge_plan.start + DIRECTIONS[int(bridge_plan.direction)] * int(bridge_plan.span_length) * 2
		result.bridge_type = plan.selected_bridge
		result.bridge_name = HighwayBridges.bridge_type_name(plan.selected_bridge)
		result.bridge_cost = plan.bridge_cost
		result.listed_bridge_cost = plan.listed_bridge_cost

	result.bridge_cancelled = plan.has_bridge() and plan.selected_bridge == BRIDGE_CANCELLED
	result.bridge_sections = plan.bridge_sections
	result.bridge_endpoint_sections = plan.bridge_endpoint_sections
	result.bridge_span_length = bridge_plan.span_length if bridge_plan != null else 0
	result.bridge_error = plan.bridge_error if plan.bridge_attempted else ""
	result.connection_built = connection_built
	result.connection_cancelled = plan.connection_available and plan.connection_choice == CONNECTION_CANCELLED
	result.connection_anchor = plan.connection_anchor

	if connection_built:
		result.connection_cost = plan.connection_cost
		result.listed_connection_cost = CONNECTION_COST

	result.graded_sections = plan.graded_sections
	result.connection_error = (
		"insufficient funds for the neighbor connection"
		if plan.connection_available and not plan.connection_affordable
		else ""
	)
	result.stopped_early = not bridge_built and (sections.is_empty() or sections[-1] != plan.finish)
	result.changed_ids = changed_ids
	result.old_payloads = plan.old_payloads
	result.new_payloads = plan.changed_payloads

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

		if bridge.ok:
			for choice in HighwayBridges._bridge_choices(bridge):
				if city.funds() >= int(choice.cost):
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

		if not bridge.ok:
			return bridge.error

		return "Insufficient funds for this highway bridge."

	if city.funds() < 100:
		return "Insufficient funds for this highway section."

	var direction := HighwayGeometry._primary_direction(anchor, anchor)

	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var tile_id := city.building_id(point.x, point.y)

		if not HighwayGeometry._building_is_allowed(tile_id):
			return "Clear the structure in the highway footprint first."

		if tile_id > Tiles.POWER_LINE_STRAIGHT_1 and not HighwayGeometry._is_highway_tile(tile_id) and not HighwayGeometry._network_can_cross(tile_id, direction):
			return "The existing network cannot cross a highway in this direction."

	return "The 2 by 2 highway section has incompatible elevations or slopes."
