class_name TransportTrip
extends RefCounted

const TRAFFIC_MAP_SIZE := 64
const TRAFFIC_VALUE_COUNT := TRAFFIC_MAP_SIZE * TRAFFIC_MAP_SIZE
const CONNECTION_LABEL := 0xfa
const ROAD_MODE := 0
const HIGHWAY_MODE := 1
const ROAD_TUNNEL_MODE := 2
const ROAD_BRIDGE_MODE := 3
const BUS_ROAD_MODE := 4
const BUS_HIGHWAY_MODE := 5
const BUS_TUNNEL_MODE := 6
const BUS_BRIDGE_MODE := 7
const BUS_STOP_MODE := 8
const BUS_RAIL_MODE := 9
const RAIL_STATION_MODE := 10
const SUBWAY_STATION_MODE := 11
const RAIL_MODE := 12
const SUBWAY_MODE := 13
const ADVANCE_BLOCKED := -1
const ADVANCE_SUCCESS := -2
const POINT_INDEX_MASK := 0x3fff

const TRANSPORT_OFFSETS := [
	Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
	Vector2i(0, 2), Vector2i(2, 0), Vector2i(0, -2), Vector2i(-2, 0),
	Vector2i(0, 3), Vector2i(3, 0), Vector2i(0, -3), Vector2i(-3, 0),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	Vector2i(2, 1), Vector2i(-2, 1), Vector2i(2, -1), Vector2i(-2, -1),
	Vector2i(1, 2), Vector2i(-1, 2), Vector2i(1, -2), Vector2i(-1, -2),
]
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const FORWARD_DIRECTION_MASKS := [0x0b, 0x07, 0x0e, 0x0d]
const DESTINATION_ZONE_MASKS := [0xffff, 0xfff8, 0xfff8, 0xffe6, 0xffe6, 0xff9e, 0xff9e, 0]


static func run(
	city: CityState,
	origin: Vector2i,
	zone: int,
	traffic_weight: int,
	random,
	maximum_cost := 100
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible random generator is required"}

	if zone < 0 or zone >= DESTINATION_ZONE_MASKS.size():
		return {"ok": false, "error": "zone is outside the supported range"}

	if traffic_weight < 0:
		return {"ok": false, "error": "traffic weight cannot be negative"}

	var traffic_chunk := city.document.find_chunk("XTRF")

	if traffic_chunk == null or traffic_chunk.decoded_payload.size() != city.document.decoded_size("XTRF"):
		return {"ok": false, "error": "XTRF is missing or has the wrong size"}

	var traffic: PackedByteArray = traffic_chunk.decoded_payload.duplicate()
	var result := trace(
		city.buildings,
		city.zones,
		city.underground,
		city.text_overlays,
		city.altitude_words,
		traffic,
		origin,
		zone,
		traffic_weight,
		random,
		maximum_cost, map_edge,
	)

	if not result.ok:
		return result

	if result.reached_destination and not traffic_chunk.set_decoded_payload(traffic):
		return {"ok": false, "error": "cannot store updated XTRF data"}

	return result


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
	random,
	maximum_cost := 100,
	map_edge: int = 128,
	collect_reach := false,
	start_override := -1,
) -> Dictionary:
	if (
		buildings.size() != (map_edge * map_edge)
		or zones.size() != (map_edge * map_edge)
		or underground.size() != (map_edge * map_edge)
		or OverlayData.count(text_overlays) != (map_edge * map_edge)
		or altitudes.size() != (map_edge * map_edge)
		or not CityDataGrid.valid(traffic, map_edge)
	):
		return {"ok": false, "error": "transport input maps have the wrong size"}

	if random == null or not random.has_method("next_u15"):
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
		limit -= int(IntegerMath.div_trunc(limit, 4))

	# positive edge costs and the best cost for each mode/heading prevent cycles
	# cost buckets are a bounded dijkstra queue. reaching the limit discards one
	# candidate, not the remaining search. equal-cost choices still use the rng
	var turn_direction := 1 if random.next_u15() & 1 else 3
	var start_index := start & (POINT_INDEX_MASK if map_edge == 128 else 0x3ffff)
	var points: Array[Vector2i] = [Vector2i(IntegerMath.div_trunc(start_index, map_edge), start_index % map_edge)]
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
			var mode := modes[state_index]
			var heading := headings[state_index]
			var key := _state_key(_index(point, map_edge), mode, heading)

			if int(best[key]) != cost:
				continue

			expanded += 1

			if collect_reach:
				reachable.append({"point": point, "mode": mode, "cost": cost})
				if not endpoints.has(point):
					endpoints[point] = {"exit": false, "destination": false, "limited": false}

			# a station's walking catchment must work at both ends of a trip
			var walk_destinations := _station_destinations(zones, point, mode, zone, map_edge)

			if not walk_destinations.is_empty():
				if collect_reach:
					endpoints[point].destination = true
				for target in walk_destinations:
					destinations[target] = mini(int(destinations.get(target, cost)), cost)

				if winner < 0:
					winner = state_index

				if not collect_reach:
					break

			var direction: int = random.next_u15() & 3

			for unused in 4:
				direction = (direction + turn_direction) & 3

				if heading < 4 and direction != heading:
					continue

				var next_point: Vector2i = point + DIRECTIONS[direction]
				var advance := _advance(buildings, zones, underground, text_overlays,
					altitudes, point, next_point, mode, zone, map_edge)

				if advance == ADVANCE_SUCCESS:
					if collect_reach:
						endpoints[point].destination = true
					destinations[next_point] = mini(int(destinations.get(next_point, cost)), cost)

					if winner < 0:
						winner = state_index

					if not collect_reach:
						break

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
				var next_heading := direction if next_mode in [ROAD_BRIDGE_MODE,
					BUS_BRIDGE_MODE, ROAD_TUNNEL_MODE, BUS_TUNNEL_MODE] else 4
				var next_index := _index(next_point, map_edge)
				var next_key := _state_key(next_index, next_mode, next_heading)

				if collect_reach:
					var link_key := Vector2i(_index(point, map_edge) * 14 + mode, next_index * 14 + next_mode)

					if not link_keys.has(link_key):
						link_keys[link_key] = true
						links.append({"from": point, "to": next_point, "mode": next_mode, "cost": next_cost})

				if next_cost >= int(best.get(next_key, limit)):
					continue

				best[next_key] = next_cost

				if not pending.has(next_cost):
					pending[next_cost] = []

				pending[next_cost].append(points.size())
				points.append(next_point)
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


static func _state_key(index: int, mode: int, heading: int) -> int:
	return (index * 14 + mode) * 5 + heading


static func _station_destinations(zones: PackedByteArray, point: Vector2i,
	mode: int, origin_zone: int, map_edge: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if mode != BUS_RAIL_MODE:
		return result

	for offset in TRANSPORT_OFFSETS:
		var target: Vector2i = point + offset
		var index := _index(target, map_edge)

		if index >= 0 and (DESTINATION_ZONE_MASKS[origin_zone] & (1 << (zones[index] & 15))) != 0:
			result.append(target)

	return result


static func has_nearby_transport(buildings: PackedByteArray, origin: Vector2i, map_edge: int = 128) -> bool:
	return _find_transport(buildings, origin, map_edge) >= 0


static func _find_transport(buildings: PackedByteArray, origin: Vector2i, map_edge: int = 128) -> int:
	if buildings.size() != (map_edge * map_edge):
		return -1

	for offset in TRANSPORT_OFFSETS:
		var point: Vector2i = origin + offset
		var index := _index(point, map_edge)

		if index < 0:
			continue

		var tile := int(buildings[index])

		if _is_surface_road(tile):
			return (ROAD_MODE << (14 if map_edge == 128 else 18)) | index

		if tile == 0xec:
			return (BUS_STOP_MODE << (14 if map_edge == 128 else 18)) | index

		if tile == 0xed:
			return (RAIL_STATION_MODE << (14 if map_edge == 128 else 18)) | index

		if tile == 0xe9:
			return (SUBWAY_STATION_MODE << (14 if map_edge == 128 else 18)) | index

	return -1


static func _advance(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	text_overlays: PackedByteArray,
	altitudes: PackedInt32Array,
	current: Vector2i,
	next_point: Vector2i,
	mode: int,
	origin_zone: int,
	map_edge: int = 128,
) -> int:
	var index := _index(next_point, map_edge)

	if index < 0:
		var current_index := _index(current, map_edge)

		if current_index >= 0 and OverlayData.read(text_overlays, current_index) == CONNECTION_LABEL:
			return ADVANCE_SUCCESS

		return ADVANCE_BLOCKED

	var tile := int(buildings[index])
	var destination: bool = (
		DESTINATION_ZONE_MASKS[origin_zone] & (1 << (zones[index] & 0x0f))
	) != 0

	match mode:
		ROAD_MODE:
			if _is_highway_span(tile) and _highway_step(buildings, current, next_point, map_edge):
				var current_tile := int(buildings[_index(current, map_edge)])
				if current_tile >= 0x5d and current_tile <= 0x60:
					return _move(HIGHWAY_MODE, 1)

			if destination:
				return ADVANCE_SUCCESS

			if tile >= 0x3f and tile <= 0x42:
				return _move(ROAD_TUNNEL_MODE, 3)

			if _is_road_bridge(tile):
				return _move(ROAD_BRIDGE_MODE, 3)

			if tile >= 0x5d and tile <= 0x60:
				return _move(HIGHWAY_MODE, 2)

			if _is_surface_road(tile):
				return _move(ROAD_MODE, 3)

			if tile == 0xec:
				return _move(BUS_STOP_MODE, 4)

			if tile == 0xed:
				return _move(RAIL_STATION_MODE, 4)

			if tile == 0xe9:
				return _move(SUBWAY_STATION_MODE, 4)
		HIGHWAY_MODE:
			if _is_highway_span(tile) and _highway_step(buildings, current, next_point, map_edge):
				return _move(HIGHWAY_MODE, 1)

			if tile >= 0x5d and tile <= 0x60 and _highway_exit(buildings, current, next_point, map_edge):
				return _move(ROAD_MODE, 1)
		ROAD_TUNNEL_MODE:
			if altitudes[index] & 0xfc00:
				return _move(ROAD_TUNNEL_MODE, 3)

			if _is_surface_road(tile):
				return _move(ROAD_MODE, 3)
		ROAD_BRIDGE_MODE:
			if _is_road_bridge(tile):
				return _move(ROAD_BRIDGE_MODE, 3)

			if _is_surface_road(tile):
				return _move(ROAD_MODE, 3)
		BUS_ROAD_MODE:
			if destination:
				return ADVANCE_SUCCESS

			if tile >= 0x3f and tile <= 0x42:
				return _move(BUS_TUNNEL_MODE, 2)

			if _is_road_bridge(tile):
				return _move(BUS_BRIDGE_MODE, 2)

			if tile >= 0x5d and tile <= 0x60:
				return _move(BUS_HIGHWAY_MODE, 2)

			if _is_surface_road(tile):
				return _move(BUS_ROAD_MODE, 2)

			if tile == 0xec:
				return _move(BUS_RAIL_MODE, 4)

			if tile == 0xed:
				return _move(RAIL_STATION_MODE, 4)

			if tile == 0xe9:
				return _move(SUBWAY_STATION_MODE, 4)
		BUS_HIGHWAY_MODE:
			if _is_highway_span(tile) and _highway_step(buildings, current, next_point, map_edge):
				return _move(BUS_HIGHWAY_MODE, 1)

			if tile >= 0x5d and tile <= 0x60 and _highway_exit(buildings, current, next_point, map_edge):
				return _move(BUS_ROAD_MODE, 1)
		BUS_TUNNEL_MODE:
			if altitudes[index] & 0xfc00:
				return _move(BUS_TUNNEL_MODE, 2)

			if _is_surface_road(tile):
				return _move(BUS_ROAD_MODE, 2)
		BUS_BRIDGE_MODE:
			if _is_road_bridge(tile):
				return _move(BUS_BRIDGE_MODE, 2)

			if _is_surface_road(tile):
				return _move(BUS_ROAD_MODE, 2)
		BUS_STOP_MODE:
			if destination:
				return ADVANCE_SUCCESS

			if tile == 0xec:
				return _move(BUS_STOP_MODE, 4)

			if _is_surface_road(tile):
				return _move(BUS_ROAD_MODE, 2)
		BUS_RAIL_MODE:
			if destination:
				return ADVANCE_SUCCESS

			if tile == 0xec or tile == 0xed:
				return _move(BUS_RAIL_MODE, 4)

			if _is_surface_road(tile):
				return _move(ROAD_MODE, 3)
		RAIL_STATION_MODE:
			if tile == 0xed:
				return _move(RAIL_STATION_MODE, 4)

			if _is_rail(tile):
				return _move(RAIL_MODE, 1)
		SUBWAY_STATION_MODE:
			if _is_subway(int(underground[index])):
				return _move(SUBWAY_MODE, 1)
		RAIL_MODE:
			if tile == 0xed:
				return _move(BUS_RAIL_MODE, 4)

			if _is_rail(tile):
				return _move(RAIL_MODE, 1)

			if tile > 0xfa:
				return ADVANCE_SUCCESS
		SUBWAY_MODE:
			if tile == 0xe9:
				return _move(BUS_RAIL_MODE, 4)

			if _is_subway(int(underground[index])):
				return _move(SUBWAY_MODE, 1)

	return ADVANCE_BLOCKED


static func _move(mode: int, cost: int) -> int:
	return (mode << 8) | cost


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


static func _is_surface_road(tile: int) -> bool:
	return (
		(tile >= 0x1d and tile <= 0x2b)
		or (tile >= 0x3f and tile <= 0x46)
		or tile == 0x4b
		or tile == 0x4c
		or (tile >= 0x5d and tile <= 0x60)
	)


static func _is_road_bridge(tile: int) -> bool:
	return (tile >= 0x51 and tile <= 0x5c) or tile == 0x6a or tile == 0x6b


static func _is_highway_span(tile: int) -> bool:
	return (tile >= 0x61 and tile <= 0x69) or (tile >= 0x49 and tile <= 0x50)


static func _is_rail(tile: int) -> bool:
	return (
		(tile >= 0x2c and tile <= 0x3e)
		or (tile >= 0x45 and tile <= 0x48)
		or (tile >= 0x6c and tile <= 0x6f)
		or tile == 0x4d
		or tile == 0x4e
	)


static func _is_subway(tile: int) -> bool:
	return (
		(tile > 0 and tile < 0x10)
		or tile == 0x1f
		or tile == 0x20
		or tile == 0x22
		or tile == 0x23
	)


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.x >= map_edge or point.y < 0 or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y


# independent corrected lane model. port bits: north, east, south, west
# straight sections have one direction per lane. curves connect the ingress
# and egress corners of their two-by-two footprint with right-hand traffic
const HIGHWAY_PORTS := {0x49: 5, 0x4a: 10, 0x4b: 10, 0x4c: 5,
	0x4d: 5, 0x4e: 10, 0x4f: 5, 0x50: 10,
	0x61: 10, 0x62: 5, 0x63: 10, 0x64: 5,
	0x65: 3, 0x66: 6, 0x67: 12, 0x68: 9, 0x69: 15}
const LANE_CORNERS := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]
const INGRESS_CORNERS := [0, 3, 2, 1]
const EGRESS_CORNERS := [3, 2, 1, 0]


# lane corners come from coordinate parity; this isn't plain flood fill
static func _highway_step(buildings: PackedByteArray, current: Vector2i,
	next_point: Vector2i, map_edge: int) -> bool:
	var tile := int(buildings[_index(current, map_edge)])
	var next_tile := int(buildings[_index(next_point, map_edge)])
	var direction := DIRECTIONS.find(next_point - current)
	var ports := int(HIGHWAY_PORTS.get(tile, 0))
	var next_ports := int(HIGHWAY_PORTS.get(next_tile, 0))
	var corner := LANE_CORNERS.find(Vector2i(current.x & 1, current.y & 1))
	var next_corner := LANE_CORNERS.find(Vector2i(next_point.x & 1, next_point.y & 1))

	if tile >= 0x5d and tile <= 0x60:
		# ramps enter the adjacent outside lane; they cannot cross the median
		return _ramp_side(next_point, current, next_ports)

	if (current.x & ~1) != (next_point.x & ~1) or (current.y & ~1) != (next_point.y & ~1):
		return (ports & (1 << direction)) != 0 and (next_ports & (1 << ((direction + 2) & 3))) != 0 and corner == EGRESS_CORNERS[direction]

	if next_corner != (corner + 1) % 4:
		return false

	for entry in 4:
		if (ports & (1 << entry)) == 0:
			continue

		for leave in 4:
			if leave == entry or (ports & (1 << leave)) == 0:
				continue

			var step: int = INGRESS_CORNERS[entry]

			while step != EGRESS_CORNERS[leave]:
				if step == corner:
					return true

				step = (step + 1) % 4

	return false


static func _ramp_side(highway: Vector2i, ramp: Vector2i, ports: int) -> bool:
	var delta := ramp - highway

	if ports == 5:
		return delta == Vector2i(-1 if (highway.x & 1) == 0 else 1, 0)

	if ports == 10:
		return delta == Vector2i(0, -1 if (highway.y & 1) == 0 else 1)

	return false


static func _highway_exit(buildings: PackedByteArray, current: Vector2i,
	next_point: Vector2i, map_edge: int) -> bool:
	return _ramp_side(current, next_point, int(HIGHWAY_PORTS.get(buildings[_index(current, map_edge)], 0)))
