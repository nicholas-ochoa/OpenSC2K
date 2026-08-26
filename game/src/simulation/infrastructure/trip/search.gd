class_name TransportTripSearch
extends TransportTripConstants


@warning_ignore_start("integer_division")


static func trace(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	text_overlays: PackedByteArray,
	altitudes: PackedInt32Array,
	traffic: PackedByteArray,
	origin: Vector2i,
	zone: int,
	traffic_weight: int,
	random: SimRandom,
	maximum_cost := 100,
	map_edge: int = 128,
	collect_reach := false,
	start_override := -1,
	walking_access := PackedByteArray(),
) -> Dictionary:
	# the map sizes are invariant across a caller's tile loop. callers check them
	# once with valid_inputs(). only the per-tile arguments are checked here
	if random == null:
		return {"ok": false, "error": "a compatible random generator is required"}

	if zone < 0 or zone >= DESTINATION_ZONE_MASKS.size():
		return {"ok": false, "error": "zone is outside the supported range"}

	if traffic_weight < 0:
		return {"ok": false, "error": "traffic weight cannot be negative"}

	var start := start_override if start_override >= 0 else _find_transport(buildings, origin, map_edge)

	if start < 0:
		return _result(false, 0, 0, false, false, false)

	var limit := maxi(maximum_cost, 0)

	if traffic_weight == 1:
		limit -= int(limit / 4)

	# positive edge costs and the best cost for each mode/heading prevent cycles
	# cost buckets are a bounded dijkstra queue. reaching the limit discards one
	# candidate, not the remaining search. equal-cost choices still use the rng
	var turn_direction := 1 if random.next_u15() & 1 else 3
	var start_index := start & (POINT_INDEX_MASK if map_edge == 128 else 0x3ffff)
	var points: Array[Vector2i] = [Vector2i(start_index / map_edge, start_index % map_edge)]
	# the flat index of each state, kept beside points so expansion never has to
	# recompute it from the vector2i. points still carries directions arithmetic,
	# the traffic write, and the collect_reach outputs
	var indices := PackedInt32Array([start_index])
	var modes := PackedInt32Array([start >> (14 if map_edge == 128 else 18)])
	var costs := PackedInt32Array([0])
	var headings := PackedInt32Array([4])
	var parents := PackedInt32Array([-1])
	var pending := {0: [0]}
	var best := {_state_key(start_index, modes[0], 4): 0}
	var reachable: Array[Dictionary] = []
	var links: Array[Dictionary] = []
	var destinations: Dictionary = {}
	var link_keys: Dictionary = {}
	var endpoints: Dictionary = {}
	var winner := -1
	var expanded := 0

	for cost in limit:
		if not pending.has(cost):
			continue

		for state_index: int in pending[cost]:
			var point := points[state_index]
			var point_index := indices[state_index]
			var mode := modes[state_index]
			var heading := headings[state_index]
			var key := _state_key(point_index, mode, heading)

			if int(best[key]) != cost:
				continue

			expanded += 1

			if collect_reach:
				reachable.append({"point": point, "mode": mode, "cost": cost})
				if not endpoints.has(point):
					endpoints[point] = {"exit": false, "destination": false, "limited": false}

			# fill the partition's selected mask table on first use. a zone write
			# invalidates affected entries before the next trip reads them
			if not collect_reach and not walking_access.is_empty() and (WALK_ACCESS_MODES >> mode) & 1 != 0:
				if walking_access[point_index] == 0:
					walking_access[point_index] = 1 + int(_has_walking_destination(zones, point, mode, zone, map_edge))

			if collect_reach:
				var walk_destinations := _walking_destinations(zones, point, mode, zone, map_edge, zone == 7)

				if not walk_destinations.is_empty():
					endpoints[point].destination = true

					for target in walk_destinations:
						destinations[target] = mini(int(destinations.get(target, cost)), cost)

					if winner < 0:
						winner = state_index
			elif ((WALK_ACCESS_MODES >> mode) & 1 != 0 and walking_access[point_index] == 2
				if not walking_access.is_empty() else _has_walking_destination(zones, point, mode, zone, map_edge)):
				if winner < 0:
					winner = state_index

				break

			var direction: int = random.next_u15() & 3

			for unused in 4:
				direction = (direction + turn_direction) & 3

				if heading < 4 and direction != heading:
					continue

				var next_point: Vector2i = point + DIRECTIONS[direction]
				var next_index := next_point.x * map_edge + next_point.y if (
					next_point.x >= 0 and next_point.x < map_edge
					and next_point.y >= 0 and next_point.y < map_edge
				) else -1
				var advance := TransportTripSteps.advance(buildings, zones, underground, text_overlays,
					altitudes, point, next_point, point_index, next_index, mode, zone, map_edge)

				if advance == ADVANCE_SUCCESS:
					if winner < 0:
						winner = state_index

					if not collect_reach:
						break

					endpoints[point].destination = true
					destinations[next_point] = mini(int(destinations.get(next_point, cost)), cost)

					continue

				if advance == ADVANCE_BLOCKED:
					continue

				var next_cost := cost + (advance & 0xff)

				if next_cost >= limit:
					if collect_reach:
						endpoints[point].limited = true
					continue

				if collect_reach and (parents[state_index] < 0 or next_point != points[parents[state_index]]):
					endpoints[point].exit = true

				var next_mode := advance >> 8
				var next_heading := direction if (STRAIGHT_HEADING_MODES >> next_mode) & 1 else 4
				var next_key := _state_key(next_index, next_mode, next_heading)

				if collect_reach:
					var link_key := Vector2i(point_index * 14 + mode, next_index * 14 + next_mode)

					if not link_keys.has(link_key):
						link_keys[link_key] = true
						links.append({"from": point, "to": next_point, "from_mode": mode, "mode": next_mode, "cost": next_cost})

				if next_cost >= int(best.get(next_key, limit)):
					continue

				best[next_key] = next_cost

				if not pending.has(next_cost):
					pending[next_cost] = []

				pending[next_cost].append(points.size())
				points.append(next_point)
				indices.append(next_index)
				modes.append(next_mode)
				costs.append(next_cost)
				headings.append(next_heading)
				parents.append(state_index)

			if winner >= 0 and not collect_reach:
				break

		if winner >= 0 and not collect_reach:
			break

	var path: Array[int] = []
	var cursor := winner

	while cursor >= 0:
		path.push_front(cursor)
		cursor = parents[cursor]

	var used_bus := false
	var used_rail := false
	var used_subway := false

	if winner >= 0 and traffic_weight > 0:
		for index in path:
			var mode := modes[index]
			used_bus = used_bus or mode == BUS_STOP_MODE
			used_rail = used_rail or mode == RAIL_STATION_MODE
			used_subway = used_subway or mode == SUBWAY_STATION_MODE

			if not collect_reach and mode in [ROAD_MODE, HIGHWAY_MODE, ROAD_BRIDGE_MODE]:
				var point := points[index]
				var traffic_index := CityDataGrid.index(traffic, map_edge, point.x, point.y)
				traffic[traffic_index] = mini(int(traffic[traffic_index]) + traffic_weight, 0xff)

	var result := _result(winner >= 0, costs[winner] if winner >= 0 else 0,
		path.size(), used_bus, used_rail, used_subway)
	result["expanded_states"] = expanded

	if collect_reach:
		var limit_points := {}
		for point: Vector2i in endpoints:
			var endpoint: Dictionary = endpoints[point]
			if endpoint.limited and not endpoint.exit and not endpoint.destination:
				limit_points[point] = "Trip limit reached"
		result["limit_points"] = limit_points
		result.merge({"reachable": reachable, "links": links, "destinations": destinations,
			"limit": limit, "start": points[0], "origin": origin})

	return result


static func valid_inputs(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	text_overlays: PackedByteArray,
	altitudes: PackedInt32Array,
	traffic: PackedByteArray,
	map_edge: int,
) -> bool:
	var cells := map_edge * map_edge

	return (
		buildings.size() == cells
		and zones.size() == cells
		and underground.size() == cells
		and OverlayData.count(text_overlays) == cells
		and altitudes.size() == cells
		and CityDataGrid.valid(traffic, map_edge)
	)


static func _state_key(index: int, mode: int, heading: int) -> int:
	return (index * 14 + mode) * 5 + heading


static func _walking_destinations(zones: PackedByteArray, point: Vector2i,
	mode: int, origin_zone: int, map_edge: int, any_rci := false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	if (WALK_ACCESS_MODES >> mode) & 1 == 0:
		return result

	# the catchment test is one mask for the whole scan, and the bounds test and
	# index arithmetic are inline. this runs once per expansion over 24 offsets
	var zone_mask: int = ANY_RCI_ZONE_MASK if any_rci else DESTINATION_ZONE_MASKS[origin_zone]

	for offset: Vector2i in TRANSPORT_OFFSETS:
		var target: Vector2i = point + offset

		if target.x < 0 or target.x >= map_edge or target.y < 0 or target.y >= map_edge:
			continue

		if (zone_mask & (1 << (int(zones[target.x * map_edge + target.y]) & 15))) != 0:
			result.append(target)

	return result


# the same catchment as _walking_destinations, stopping at the first match
# the growth scan only asks whether the tile has walking access
static func _has_walking_destination(zones: PackedByteArray, point: Vector2i,
	mode: int, origin_zone: int, map_edge: int) -> bool:
	if (WALK_ACCESS_MODES >> mode) & 1 == 0:
		return false

	var zone_mask: int = DESTINATION_ZONE_MASKS[origin_zone]

	for offset: Vector2i in TRANSPORT_OFFSETS:
		var target: Vector2i = point + offset

		if target.x < 0 or target.x >= map_edge or target.y < 0 or target.y >= map_edge:
			continue

		if (zone_mask & (1 << (int(zones[target.x * map_edge + target.y]) & 15))) != 0:
			return true

	return false


static func _find_transport(buildings: PackedByteArray, origin: Vector2i, map_edge: int = 128) -> int:
	if buildings.size() != (map_edge * map_edge):
		return -1

	for offset in TRANSPORT_OFFSETS:
		var point: Vector2i = origin + offset
		var index := TransportTripSteps._index(point, map_edge)

		if index < 0:
			continue

		var tile := int(buildings[index])

		if TransportTripSteps._is_surface_road(tile):
			return (ROAD_MODE << (14 if map_edge == 128 else 18)) | index

		if tile == 0xec:
			return (BUS_STOP_MODE << (14 if map_edge == 128 else 18)) | index

		if tile == 0xed:
			return (RAIL_STATION_MODE << (14 if map_edge == 128 else 18)) | index

		if tile == 0xe9:
			return (SUBWAY_STATION_MODE << (14 if map_edge == 128 else 18)) | index

	return -1


static func _result(
	reached_destination: bool,
	cost: int,
	path_length: int,
	used_bus: bool,
	used_rail: bool,
	used_subway: bool
) -> Dictionary:
	return {
		"ok": true,
		"reached_destination": reached_destination,
		"cost": cost,
		"path_length": path_length,
		"used_bus": used_bus,
		"used_rail": used_rail,
		"used_subway": used_subway,
		"error": "",
	}
