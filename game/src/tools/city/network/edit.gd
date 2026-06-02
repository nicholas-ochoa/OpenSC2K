class_name NetworkEdit
extends NetworkConstants



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
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if not NetworkRules.supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool is not a linear network tool"}

	if city.index_of(start.x, start.y) < 0 or city.index_of(finish.x, finish.y) < 0:
		return {"ok": false, "error": "network path is outside the city"}

	var old_payloads := NetworkState._city_payloads(city)

	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}

	var changed_payloads := NetworkState._duplicate_payloads(old_payloads)
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var underground: PackedByteArray = changed_payloads.XUND
	var flags: PackedByteArray = changed_payloads.XBIT
	var text_overlays: PackedByteArray = changed_payloads.XTXT
	var misc: PackedByteArray = changed_payloads.MISC
	var altitude: PackedByteArray = changed_payloads.ALTM
	var mode := int(NETWORK_TOOLS[group_index * ToolCatalog.MAX_SLOTS_PER_GROUP + subtool_index])

	var planned_directions: Array[int] = []
	var planned := NetworkRoutes._plan_route(
		buildings, terrain, zones, underground, flags, altitude,
		start, finish, mode, map_edge, planned_directions
	)
	var bridge_plan := {}
	var surface_mode := mode == MODE_ROAD or mode == MODE_RAIL or mode == MODE_POWER

	if surface_mode:
		if planned.is_empty() and NetworkBridges._is_bridge_wrapper_tile(terrain, flags, start, map_edge):
			bridge_plan = NetworkBridges._plan_bridge_from_start(
				buildings, terrain, start, city.compass_rotation(), map_edge
			)
		elif not planned.is_empty():
			var exit_direction := NetworkRoutes._route_exit_direction(planned, start, finish)
			var bridge_start: Vector2i = planned[-1] + DIRECTIONS[exit_direction]

			if NetworkBridges._is_bridge_wrapper_tile(terrain, flags, bridge_start, map_edge):
				bridge_plan = NetworkBridges._scan_bridge(
					buildings, terrain, bridge_start, exit_direction, false, map_edge
				)

	if planned.is_empty() and not bridge_plan.get("ok", false):
		return {
			"ok": false,
			"error": bridge_plan.get("error", "network cannot start on this tile"),
		}

	var tool := ToolCatalog.tool(group_index, subtool_index)
	var graded_tiles := 0
	var new_tiles := planned.size()

	for point in planned:
		var index := point.x * map_edge + point.y
		var reused := NetworkRules._reuses_surface(buildings[index], mode) if surface_mode else NetworkRules._reuses_underground(underground[index], mode)

		if reused:
			new_tiles -= 1
			continue

		var terrain_id := int(terrain[index])

		if terrain_id < 0x30 and TERRAIN_REQUIRES_GRADING[terrain_id & 0x0f]:
			graded_tiles += 1

	var listed_dry_cost := new_tiles * int(tool.cost) + graded_tiles * 25
	var dry_cost := 0 if free_mode else listed_dry_cost

	if city.funds() < dry_cost:
		return {"ok": false, "error": "insufficient funds", "cost": dry_cost}

	var selected_bridge := bridge_type
	var bridge_choices: Array[Dictionary] = []

	if bridge_plan.get("ok", false):
		bridge_choices = NetworkBridges._bridge_choices(int(bridge_plan.span_length), mode)

		if mode == MODE_ROAD and selected_bridge == BRIDGE_UNSELECTED:
			return {
				"ok": false,
				"bridge_selection_required": true,
				"bridge_choices": bridge_choices,
				"bridge_span_length": bridge_plan.span_length,
				"dry_cost": dry_cost,
				"listed_dry_cost": listed_dry_cost,
				"free_mode": free_mode,
				"dry_points": planned,
				"error": "bridge type selection is required",
			}

		if mode == MODE_RAIL:
			selected_bridge = BRIDGE_RAIL
		elif mode == MODE_POWER:
			selected_bridge = BRIDGE_WIRE

		if selected_bridge >= 0 and not NetworkBridges._bridge_choice_exists(
			bridge_choices, selected_bridge
		):
			return {"ok": false, "error": "selected bridge type is not available"}

	if (
		bridge_plan.get("ok", false)
		and selected_bridge == BRIDGE_CANCELLED
		and planned.is_empty()
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

		if not free_mode and city.funds() - dry_cost < bridge_cost:
			bridge_error = "insufficient funds for the bridge"

			if planned.is_empty():
				return {
					"ok": false,
					"error": "insufficient funds",
					"cost": bridge_cost,
				}
		else:
			bridge_built = true

	var cost := dry_cost + (bridge_cost if bridge_built else 0)
	var connection_anchor: Vector2i = planned[-1] if not planned.is_empty() else start
	var listed_connection_cost := NetworkRules._connection_cost(mode)
	var connection_cost := 0 if free_mode else listed_connection_cost
	var connection_available: bool = (
		not bridge_plan.get("ok", false)
		and not planned.is_empty()
		and listed_connection_cost > 0
		and NetworkRoutes._is_connection_exit(planned, start, finish, map_edge)
		and OverlayData.read(text_overlays,
			connection_anchor.x * map_edge + connection_anchor.y
		) != CONNECTION_LABEL
	)
	var connection_affordable: bool = (
		free_mode or city.funds() - dry_cost >= connection_cost
	)

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
			"listed_connection_cost": listed_connection_cost,
			"dry_cost": dry_cost,
			"listed_dry_cost": listed_dry_cost,
			"free_mode": free_mode,
			"dry_points": planned,
			"error": "neighbor connection confirmation is required",
		}

	if connection_choice == CONNECTION_CONFIRMED:
		if not connection_available:
			return {"ok": false, "error": "neighbor connection is not available"}

		if not connection_affordable:
			return {
				"ok": false,
				"error": "insufficient funds",
				"cost": dry_cost + connection_cost,
			}

	var connection_built := connection_choice == CONNECTION_CONFIRMED
	var connection_error := ""

	if connection_available and not connection_affordable:
		connection_error = "insufficient funds for the neighbor connection"

	cost += connection_cost if connection_built else 0

	for point_index in planned.size():
		var point := planned[point_index]
		var direction := planned_directions[point_index]

		match mode:
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

	var bridge_points: Array[Vector2i] = []

	if bridge_built:
		bridge_points = NetworkBridges._place_bridge(
			altitude,
			buildings,
			terrain,
			zones,
			flags,
			misc,
			bridge_plan,
			selected_bridge, map_edge
		)

	if connection_built:
		OverlayData.write(text_overlays,
			connection_anchor.x * map_edge + connection_anchor.y
		, CONNECTION_LABEL)
		NetworkTiles._retile_surface_neighborhood(
			buildings,
			terrain,
			zones,
			flags,
			misc,
			connection_anchor,
			mode,
			text_overlays, map_edge
		)

	NetworkState._write_u32_be(misc, MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not NetworkState._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		return {"ok": false, "error": "cannot store network changes"}

	var all_points: Array[Vector2i] = planned.duplicate()
	all_points.append_array(bridge_points)

	return {
		"ok": true,
		"command_type": "network",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"mode": mode,
		"points": all_points,
		"dry_points": planned,
		"bridge_points": bridge_points,
		"bridge_built": bridge_built,
		"bridge_exit": bridge_plan.start + DIRECTIONS[int(bridge_plan.direction)] * int(bridge_plan.span_length) if bridge_built else Vector2i(-1, -1),
		"bridge_type": selected_bridge if bridge_built else BRIDGE_UNSELECTED,
		"bridge_name": NetworkBridges.bridge_type_name(selected_bridge) if bridge_built else "",
		"bridge_cancelled": (
			bridge_plan.get("ok", false) and selected_bridge == BRIDGE_CANCELLED
		),
		"bridge_span_length": bridge_plan.get("span_length", 0),
		"bridge_cost": bridge_cost if bridge_built else 0,
		"listed_bridge_cost": listed_bridge_cost if bridge_built else 0,
		"bridge_error": bridge_error,
		"connection_anchor": connection_anchor,
		"connection_built": connection_built,
		"connection_cancelled": (
			connection_available and connection_choice == CONNECTION_CANCELLED
		),
		"connection_cost": connection_cost if connection_built else 0,
		"listed_connection_cost": (
			listed_connection_cost if connection_built else 0
		),
		"connection_error": connection_error,
		"cost": cost,
		"dry_cost": dry_cost,
		"listed_cost": (
			listed_dry_cost
			+ (listed_bridge_cost if bridge_built else 0)
			+ (listed_connection_cost if connection_built else 0)
		),
		"listed_dry_cost": listed_dry_cost,
		"free_mode": free_mode,
		"graded_tiles": graded_tiles,
		"stopped_early": not bridge_built and planned[-1] != finish,
		"changed_ids": changed_ids,
		"old_payloads": old_payloads,
		"new_payloads": changed_payloads,
		"error": "",
	}


static func undo(city: CityState, command: Dictionary) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if not command.get("ok", false) or command.get("command_type", "") != "network":
		return {"ok": false, "error": "network command is invalid"}

	var changed_ids: PackedStringArray = command.get("changed_ids", PackedStringArray())
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})

	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return {"ok": false, "error": "city changed after this network command"}

	if not NetworkState._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore network changes"}

	var points: Array = command.get("points", [])

	return {"ok": true, "restored_tiles": points.size(), "error": ""}
