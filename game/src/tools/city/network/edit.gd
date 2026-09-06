class_name NetworkEdit
extends NetworkConstants




class SegmentPlan:
	var city: CityState
	var map_edge: int
	var group_index: int
	var subtool_index: int
	var start: Vector2i
	var finish: Vector2i
	var free_mode: bool
	var mode: int
	var surface_mode: bool
	var old_payloads: Dictionary
	var changed_payloads: Dictionary
	var planned: Array[Vector2i] = []
	var planned_directions: Array[int] = []
	var bridge_plan: NetworkBridges.Plan
	var graded_tiles := 0
	var listed_dry_cost := 0
	var dry_cost := 0
	var selected_bridge := BRIDGE_UNSELECTED
	var listed_bridge_cost := 0
	var bridge_cost := 0
	var bridge_built := false
	var bridge_error := ""
	var bridge_points: Array[Vector2i] = []
	var connection_choice := CONNECTION_UNSELECTED
	var connection_anchor := Vector2i.ZERO
	var listed_connection_cost := 0
	var connection_cost := 0
	var connection_available := false
	var connection_affordable := false
	var connection_built := false
	var connection_error := ""
	var cost := 0


	func has_bridge() -> bool:
		return bridge_plan != null and bridge_plan.ok


static func apply_segment(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	finish: Vector2i,
	bridge_type := BRIDGE_UNSELECTED,
	connection_choice := CONNECTION_UNSELECTED,
	free_mode := false
) -> RouteEditResult:
	if city == null or not city.is_valid():
		return RouteEditResult.rejected("city is invalid")

	if not NetworkRules.supports_tool(group_index, subtool_index):
		return RouteEditResult.rejected("tool is not a linear network tool")

	if city.index_of(start.x, start.y) < 0 or city.index_of(finish.x, finish.y) < 0:
		return RouteEditResult.rejected("network path is outside the city")

	var old_payloads := NetworkState.city_payloads(city)

	if old_payloads.is_empty():
		return RouteEditResult.rejected("required city data is missing or invalid")

	var plan := SegmentPlan.new()
	plan.city = city
	plan.map_edge = city.map_size
	plan.group_index = group_index
	plan.subtool_index = subtool_index
	plan.start = start
	plan.finish = finish
	plan.selected_bridge = bridge_type
	plan.connection_choice = connection_choice
	plan.free_mode = free_mode
	plan.mode = int(NETWORK_TOOLS[group_index * ToolCatalog.MAX_SLOTS_PER_GROUP + subtool_index])
	plan.surface_mode = plan.mode == MODE_ROAD or plan.mode == MODE_RAIL or plan.mode == MODE_POWER
	plan.old_payloads = old_payloads
	plan.changed_payloads = NetworkState._duplicate_payloads(old_payloads)

	var rejection := _plan_route(plan)

	if rejection == null:
		rejection = _validate_dry_cost(plan)

	if rejection == null:
		rejection = _validate_bridge_choice(plan)

	if rejection == null:
		rejection = _validate_connection_choice(plan)

	if rejection != null:
		return rejection

	_apply_to_payload_copies(plan)
	var changed_ids := PackedStringArray()

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "MISC"]:
		if plan.changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not NetworkState._apply_payloads(city, changed_ids, plan.changed_payloads, old_payloads):
		return RouteEditResult.rejected("cannot store network changes")

	return _undo_record(plan, changed_ids)


# plan the dry route from start toward finish, and a bridge where a surface
# route starts on or reaches water. returns a rejection when neither exists
static func _plan_route(plan: SegmentPlan) -> RouteEditResult:
	var map_edge := plan.map_edge
	var start := plan.start
	var buildings: PackedByteArray = plan.changed_payloads.XBLD
	var terrain: PackedByteArray = plan.changed_payloads.XTER
	var flags: PackedByteArray = plan.changed_payloads.XBIT
	var planned := NetworkRoutes.plan_route(
		buildings, terrain, plan.changed_payloads.XZON, plan.changed_payloads.XUND, flags,
		plan.changed_payloads.ALTM, start, plan.finish, plan.mode, map_edge, plan.planned_directions
	)
	plan.planned = planned

	if plan.surface_mode:
		if planned.is_empty() and NetworkBridges._is_bridge_wrapper_tile(terrain, flags, start, map_edge):
			plan.bridge_plan = NetworkBridges._plan_bridge_from_start(
				buildings, terrain, start, plan.city.compass_rotation(), map_edge
			)
		elif not planned.is_empty():
			var exit_direction := NetworkRoutes._route_exit_direction(planned, start, plan.finish)
			var bridge_start: Vector2i = planned[-1] + DIRECTIONS[exit_direction]

			if NetworkBridges._is_bridge_wrapper_tile(terrain, flags, bridge_start, map_edge):
				plan.bridge_plan = NetworkBridges._scan_bridge(
					buildings, terrain, bridge_start, exit_direction, false, map_edge
				)

	if planned.is_empty() and not plan.has_bridge():
		return RouteEditResult.rejected(plan.bridge_plan.error if plan.bridge_plan != null else "network cannot start on this tile")

	return null


# price the new dry tiles and the grading they need. reused tiles are free
static func _validate_dry_cost(plan: SegmentPlan) -> RouteEditResult:
	var map_edge := plan.map_edge
	var buildings: PackedByteArray = plan.changed_payloads.XBLD
	var terrain: PackedByteArray = plan.changed_payloads.XTER
	var underground: PackedByteArray = plan.changed_payloads.XUND
	var tool := ToolCatalog.tool(plan.group_index, plan.subtool_index)
	var new_tiles := plan.planned.size()

	for point in plan.planned:
		var index := point.x * map_edge + point.y
		var reused := (NetworkRules._reuses_surface(buildings[index], plan.mode) if plan.surface_mode
				else NetworkRules._reuses_underground(underground[index], plan.mode))

		if reused:
			new_tiles -= 1
			continue

		var terrain_id := int(terrain[index])

		if terrain_id < 0x30 and TERRAIN_REQUIRES_GRADING[terrain_id & 0x0f]:
			plan.graded_tiles += 1

	plan.listed_dry_cost = new_tiles * int(tool.cost) + plan.graded_tiles * 25
	plan.dry_cost = 0 if plan.free_mode else plan.listed_dry_cost

	if plan.city.funds() < plan.dry_cost:
		return RouteEditResult.rejected("insufficient funds", plan.dry_cost)

	return null


# ask for a road bridge type, fix the rail and power bridge types, check the
# chosen type, and decide whether the funds cover it. a bridge the city cannot
# afford is skipped unless it is the whole segment
static func _validate_bridge_choice(plan: SegmentPlan) -> RouteEditResult:
	var mode := plan.mode

	if plan.has_bridge():
		var bridge_choices := NetworkBridges.bridge_choices(int(plan.bridge_plan.span_length), mode)

		if mode == MODE_ROAD and plan.selected_bridge == BRIDGE_UNSELECTED:
			var choice := RouteEditResult.rejected("bridge type selection is required")
			choice.bridge_selection_required = true
			choice.bridge_choices = bridge_choices
			choice.bridge_span_length = plan.bridge_plan.span_length
			choice.dry_cost = plan.dry_cost
			choice.listed_dry_cost = plan.listed_dry_cost
			choice.free_mode = plan.free_mode
			choice.dry_points = plan.planned

			return choice

		if mode == MODE_RAIL:
			plan.selected_bridge = BRIDGE_RAIL
		elif mode == MODE_POWER:
			plan.selected_bridge = BRIDGE_WIRE

		if plan.selected_bridge >= 0 and not NetworkBridges._bridge_choice_exists(
			bridge_choices, plan.selected_bridge
		):
			return RouteEditResult.rejected("selected bridge type is not available")

	if (
		plan.has_bridge()
		and plan.selected_bridge == BRIDGE_CANCELLED
		and plan.planned.is_empty()
	):
		var cancelled := RouteEditResult.rejected("bridge selection canceled")
		cancelled.cancelled = true

		return cancelled

	if plan.has_bridge() and plan.selected_bridge >= 0:
		plan.listed_bridge_cost = (
			int(plan.bridge_plan.span_length) * int(BRIDGE_COSTS[plan.selected_bridge])
		)
		plan.bridge_cost = 0 if plan.free_mode else plan.listed_bridge_cost

		if not plan.free_mode and plan.city.funds() - plan.dry_cost < plan.bridge_cost:
			plan.bridge_error = "insufficient funds for the bridge"

			if plan.planned.is_empty():
				return RouteEditResult.rejected("insufficient funds", plan.bridge_cost)
		else:
			plan.bridge_built = true

	return null


# offer a neighbor connection when the route leaves the map edge, and check
# a confirmed connection. then total the segment cost
static func _validate_connection_choice(plan: SegmentPlan) -> RouteEditResult:
	var planned := plan.planned
	var map_edge := plan.map_edge
	var free_mode := plan.free_mode
	plan.cost = plan.dry_cost + (plan.bridge_cost if plan.bridge_built else 0)
	plan.connection_anchor = planned[-1] if not planned.is_empty() else plan.start
	plan.listed_connection_cost = NetworkRules._connection_cost(plan.mode)
	plan.connection_cost = 0 if free_mode else plan.listed_connection_cost
	plan.connection_available = (
		not plan.has_bridge()
		and not planned.is_empty()
		and plan.listed_connection_cost > 0
		and NetworkRoutes._is_connection_exit(planned, plan.start, plan.finish, map_edge)
		and OverlayData.read(plan.changed_payloads.XTXT,
			plan.connection_anchor.x * map_edge + plan.connection_anchor.y
		) != CONNECTION_LABEL
	)
	plan.connection_affordable = (
		free_mode or plan.city.funds() - plan.dry_cost >= plan.connection_cost
	)

	if (
		plan.connection_available
		and plan.connection_affordable
		and plan.connection_choice == CONNECTION_UNSELECTED
	):
		var confirmation := RouteEditResult.rejected("neighbor connection confirmation is required")
		confirmation.connection_selection_required = true
		confirmation.connection_anchor = plan.connection_anchor
		confirmation.connection_cost = plan.connection_cost
		confirmation.listed_connection_cost = plan.listed_connection_cost
		confirmation.dry_cost = plan.dry_cost
		confirmation.listed_dry_cost = plan.listed_dry_cost
		confirmation.free_mode = free_mode
		confirmation.dry_points = planned

		return confirmation

	if plan.connection_choice == CONNECTION_CONFIRMED:
		if not plan.connection_available:
			return RouteEditResult.rejected("neighbor connection is not available")

		if not plan.connection_affordable:
			return RouteEditResult.rejected("insufficient funds", plan.dry_cost + plan.connection_cost)

	plan.connection_built = plan.connection_choice == CONNECTION_CONFIRMED

	if plan.connection_available and not plan.connection_affordable:
		plan.connection_error = "insufficient funds for the neighbor connection"

	plan.cost += plan.connection_cost if plan.connection_built else 0

	return null


# place the dry tiles, bridge, and connection label in copies of the city
# payloads, and charge the funds
static func _apply_to_payload_copies(plan: SegmentPlan) -> void:
	var map_edge := plan.map_edge
	var changed_payloads := plan.changed_payloads
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var underground: PackedByteArray = changed_payloads.XUND
	var flags: PackedByteArray = changed_payloads.XBIT
	var text_overlays: PackedByteArray = changed_payloads.XTXT
	var misc: PackedByteArray = changed_payloads.MISC
	var altitude: PackedByteArray = changed_payloads.ALTM

	for point_index in plan.planned.size():
		var point := plan.planned[point_index]
		var direction := plan.planned_directions[point_index]

		match plan.mode:
			MODE_ROAD:
				NetworkTiles._place_surface(
					buildings, terrain, zones, flags, misc, point, MODE_ROAD,
					direction, text_overlays, map_edge
				)
			MODE_RAIL:
				NetworkTiles._place_surface(
					buildings, terrain, zones, flags, misc, point, MODE_RAIL,
					direction, text_overlays, map_edge
				)
			MODE_POWER:
				NetworkTiles._place_surface(
					buildings, terrain, zones, flags, misc, point, MODE_POWER,
					direction, text_overlays, map_edge
				)
			MODE_SUBWAY:
				NetworkTiles._place_underground(
					underground, terrain, zones, flags, misc, point, false, direction, map_edge
				)
			MODE_PIPE:
				NetworkTiles._place_underground(
					underground, terrain, zones, flags, misc, point, true, direction, map_edge
				)

	if plan.bridge_built:
		plan.bridge_points = NetworkBridges._place_bridge(
			altitude,
			buildings,
			terrain,
			zones,
			flags,
			misc,
			plan.bridge_plan,
			plan.selected_bridge, map_edge
		)

	if plan.connection_built:
		OverlayData.write(text_overlays,
			plan.connection_anchor.x * map_edge + plan.connection_anchor.y
		, CONNECTION_LABEL)
		NetworkTiles._retile_surface_neighborhood(
			buildings,
			terrain,
			zones,
			flags,
			misc,
			plan.connection_anchor,
			plan.mode,
			text_overlays, map_edge
		)

	NetworkState._write_u32_be(misc, MISC_FUNDS, plan.city.funds() - plan.cost)


# describe the stored segment, with the old and new payloads undo restores
static func _undo_record(plan: SegmentPlan, changed_ids: PackedStringArray) -> RouteEditResult:
	var planned := plan.planned
	var bridge_plan := plan.bridge_plan
	var bridge_built := plan.bridge_built
	var connection_built := plan.connection_built
	var all_points: Array[Vector2i] = planned.duplicate()
	all_points.append_array(plan.bridge_points)

	var result := RouteEditResult.new()
	result.ok = true
	result.command_type = "network"
	result.group_index = plan.group_index
	result.subtool_index = plan.subtool_index
	result.mode = plan.mode
	result.points = all_points
	result.dry_points = planned
	result.bridge_points = plan.bridge_points
	result.bridge_built = bridge_built

	if bridge_built:
		result.bridge_exit = bridge_plan.start + DIRECTIONS[int(bridge_plan.direction)] * int(bridge_plan.span_length)
		result.bridge_type = plan.selected_bridge
		result.bridge_name = NetworkBridges.bridge_type_name(plan.selected_bridge)
		result.bridge_cost = plan.bridge_cost
		result.listed_bridge_cost = plan.listed_bridge_cost

	result.bridge_cancelled = plan.has_bridge() and plan.selected_bridge == BRIDGE_CANCELLED
	result.bridge_span_length = bridge_plan.span_length if bridge_plan != null else 0
	result.bridge_error = plan.bridge_error
	result.connection_anchor = plan.connection_anchor
	result.connection_built = connection_built
	result.connection_cancelled = plan.connection_available and plan.connection_choice == CONNECTION_CANCELLED

	if connection_built:
		result.connection_cost = plan.connection_cost
		result.listed_connection_cost = plan.listed_connection_cost

	result.connection_error = plan.connection_error
	result.cost = plan.cost
	result.dry_cost = plan.dry_cost
	result.listed_cost = (
		plan.listed_dry_cost
		+ (plan.listed_bridge_cost if bridge_built else 0)
		+ (plan.listed_connection_cost if connection_built else 0)
	)
	result.listed_dry_cost = plan.listed_dry_cost
	result.free_mode = plan.free_mode
	result.graded_tiles = plan.graded_tiles
	result.stopped_early = not bridge_built and planned[-1] != plan.finish
	result.changed_ids = changed_ids
	result.old_payloads = plan.old_payloads
	result.new_payloads = plan.changed_payloads

	return result


static func undo(city: CityState, command: RouteEditResult) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != "network":
		return EditCommandResult.failure("network command is invalid")

	var changed_ids := command.changed_ids
	var old_payloads := command.old_payloads
	var new_payloads := command.new_payloads

	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return EditCommandResult.failure("city changed after this network command")

	if not NetworkState._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return EditCommandResult.failure("cannot restore network changes")

	return EditCommandResult.undone(command.points.size())
