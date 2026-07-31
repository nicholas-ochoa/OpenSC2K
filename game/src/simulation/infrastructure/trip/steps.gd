class_name TransportTripSteps
extends TransportTripConstants



static func advance(
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
			if _is_highway_span(tile) and highway_step(buildings, current, next_point, map_edge):
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
			if _is_highway_span(tile) and highway_step(buildings, current, next_point, map_edge):
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
			if _is_highway_span(tile) and highway_step(buildings, current, next_point, map_edge):
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


# lane corners come from coordinate parity; this isn't plain flood fill
static func highway_step(buildings: PackedByteArray, current: Vector2i,
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

	# cross into the return lane only at an unconnected highway endpoint
	for exit_direction in 4:
		var exit_bit := 1 << exit_direction
		if corner != EGRESS_CORNERS[exit_direction] or (ports & next_ports & exit_bit) == 0:
			continue
		var forward: Vector2i = current + DIRECTIONS[exit_direction]
		var forward_index := _index(forward, map_edge)
		var forward_ports := int(HIGHWAY_PORTS.get(buildings[forward_index], 0)) if forward_index >= 0 else 0
		if (forward_ports & (1 << ((exit_direction + 2) & 3))) == 0:
			return true

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
