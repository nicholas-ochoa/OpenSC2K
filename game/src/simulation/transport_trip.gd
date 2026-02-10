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

	var start := _find_transport(buildings, origin, map_edge)
	if start < 0:
		return _result(false, 0, 0, false, false, false)
	var limit := maxi(maximum_cost, 0)
	if traffic_weight == 1:
		limit -= int(limit / 4)
	var turn_direction := 1 if random.next_u15() & 1 else 3
	var start_index := start & (POINT_INDEX_MASK if map_edge == 128 else 0x3ffff)
	var state_points: Array[Vector2i] = [
		Vector2i(int(start_index / map_edge), start_index % map_edge)
	]
	var state_modes := PackedInt32Array([start >> (14 if map_edge == 128 else 18)])
	var state_costs := PackedInt32Array([0])
	var state_directions := PackedInt32Array([0x0f])
	var reached_destination := false
	var used_bus := false
	var used_rail := false
	var used_subway := false
	var final_cost := 0

	while not state_points.is_empty() and state_costs[-1] < limit:
		var state_index := state_points.size() - 1
		var point := state_points[state_index]
		var mode := state_modes[state_index]
		var cost := state_costs[state_index]
		var direction: int = random.next_u15() & 3
		var moved := false
		for unused in 4:
			direction = (direction + turn_direction) & 3
			var bit: int = 1 << direction
			if state_directions[state_index] & bit == 0:
				continue
			state_directions[state_index] &= ~bit
			var next_point: Vector2i = point + DIRECTIONS[direction]
			var advance := _advance(
				buildings,
				zones,
				underground,
				text_overlays,
				altitudes,
				point,
				next_point,
				mode,
				zone, map_edge,
			)
			if advance == ADVANCE_SUCCESS:
				reached_destination = true
				final_cost = cost
				moved = true
				break
			if advance == ADVANCE_BLOCKED:
				continue
			var next_cost := cost + (advance & 0xff)
			var next_mode := advance >> 8
			var next_directions: int
			if next_mode == ROAD_BRIDGE_MODE or next_mode == BUS_BRIDGE_MODE:
				next_directions = bit
			elif next_mode == SUBWAY_STATION_MODE:
				next_directions = 0x0f
			else:
				next_directions = FORWARD_DIRECTION_MASKS[direction]
			state_points.append(next_point)
			state_modes.append(next_mode)
			state_costs.append(next_cost)
			state_directions.append(next_directions)
			final_cost = next_cost
			moved = true
			break
		if reached_destination:
			break
		if moved:
			continue
		state_points.pop_back()
		state_modes.resize(state_modes.size() - 1)
		state_costs.resize(state_costs.size() - 1)
		state_directions.resize(state_directions.size() - 1)
		while not state_points.is_empty() and state_directions[-1] == 0:
			state_points.pop_back()
			state_modes.resize(state_modes.size() - 1)
			state_costs.resize(state_costs.size() - 1)
			state_directions.resize(state_directions.size() - 1)

	if reached_destination and traffic_weight > 0:
		for index in state_points.size():
			var mode := state_modes[index]
			if mode == SUBWAY_STATION_MODE:
				used_subway = true
			elif mode == RAIL_STATION_MODE:
				used_rail = true
			elif mode == BUS_STOP_MODE:
				used_bus = true
			if mode == ROAD_MODE or mode == HIGHWAY_MODE or mode == ROAD_BRIDGE_MODE:
				var point := state_points[index]
				var traffic_index := CityDataGrid.index(traffic, map_edge, point.x, point.y)
				traffic[traffic_index] = mini(int(traffic[traffic_index]) + traffic_weight, 0xff)
	return _result(
		reached_destination,
		final_cost,
		state_points.size() if reached_destination else 0,
		used_bus,
		used_rail,
		used_subway,
	)


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
			if destination:
				return ADVANCE_SUCCESS
			if tile >= 0x3f and tile <= 0x42:
				return _move(HIGHWAY_MODE, 3)
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
			if _is_highway_span(tile):
				return _move(HIGHWAY_MODE, 1)
			if tile >= 0x5d and tile <= 0x60:
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
			if _is_highway_span(tile):
				return _move(BUS_HIGHWAY_MODE, 1)
			if tile >= 0x5d and tile <= 0x60:
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
	return (tile >= 0x61 and tile <= 0x6b) or (tile >= 0x49 and tile <= 0x50)


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
