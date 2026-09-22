class_name TransportTripSteps
extends TransportTripConstants



# the search passes checked flat indices. a next index of -1 means a map exit
# keep the points for highway lane geometry
const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

static func advance(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	text_overlays: PackedByteArray,
	altitudes: PackedInt32Array,
	current: Vector2i,
	next_point: Vector2i,
	current_index: int,
	index: int,
	mode: int,
	origin_zone: int,
	map_edge: int = 128,
) -> int:
	if index < 0:
		if current_index >= 0 and OverlayData.read(text_overlays, current_index) == CONNECTION_LABEL:
			return ADVANCE_SUCCESS

		return ADVANCE_BLOCKED

	var tile := int(buildings[index])
	var destination: bool = (
		DESTINATION_ZONE_MASKS[origin_zone] & (1 << (zones[index] & Sc2ZoneLayout.TYPE_MASK))
	) != 0

	match mode:
		ROAD_MODE:
			if _is_highway_span(tile) and highway_step(buildings, current, next_point, map_edge):
				var current_tile := int(buildings[current_index])
				if current_tile >= Tiles.ONRAMP_FIRST and current_tile <= Tiles.ONRAMP_LAST:
					return _move(HIGHWAY_MODE, 1)

			if destination:
				return ADVANCE_SUCCESS

			if tile >= Tiles.TUNNEL_FIRST and tile <= Tiles.TUNNEL_LAST:
				return _move(ROAD_TUNNEL_MODE, 3)

			if _is_road_bridge(tile):
				return _move(ROAD_BRIDGE_MODE, 3)

			if tile >= Tiles.ONRAMP_FIRST and tile <= Tiles.ONRAMP_LAST:
				return _move(HIGHWAY_MODE, 2)

			if NetworkTileMembership.surface_road(tile):
				return _move(ROAD_MODE, 3)

			if tile == Tiles.BUS_DEPOT:
				return _move(BUS_STOP_MODE, 4)

			if tile == Tiles.RAIL_STATION:
				return _move(RAIL_STATION_MODE, 4)

			if tile == Tiles.SUBWAY_STATION:
				return _move(SUBWAY_STATION_MODE, 4)
		HIGHWAY_MODE:
			if _is_highway_span(tile) and highway_step(buildings, current, next_point, map_edge):
				return _move(HIGHWAY_MODE, 1)

			if tile >= Tiles.ONRAMP_FIRST and tile <= Tiles.ONRAMP_LAST and _highway_exit(buildings, current, next_point, map_edge):
				return _move(ROAD_MODE, 1)
		ROAD_TUNNEL_MODE:
			if altitudes[index] & Sc2AltitudeLayout.TUNNEL_FIELD_MASK:
				return _move(ROAD_TUNNEL_MODE, 3)

			if NetworkTileMembership.surface_road(tile):
				return _move(ROAD_MODE, 3)
		ROAD_BRIDGE_MODE:
			if _is_road_bridge(tile):
				return _move(ROAD_BRIDGE_MODE, 3)

			if NetworkTileMembership.surface_road(tile):
				return _move(ROAD_MODE, 3)
		BUS_ROAD_MODE:
			if destination:
				return ADVANCE_SUCCESS

			if tile >= Tiles.TUNNEL_FIRST and tile <= Tiles.TUNNEL_LAST:
				return _move(BUS_TUNNEL_MODE, 2)

			if _is_road_bridge(tile):
				return _move(BUS_BRIDGE_MODE, 2)

			if tile >= Tiles.ONRAMP_FIRST and tile <= Tiles.ONRAMP_LAST:
				return _move(BUS_HIGHWAY_MODE, 2)

			if NetworkTileMembership.surface_road(tile):
				return _move(BUS_ROAD_MODE, 2)

			if tile == Tiles.BUS_DEPOT:
				return _move(BUS_RAIL_MODE, 4)

			if tile == Tiles.RAIL_STATION:
				return _move(RAIL_STATION_MODE, 4)

			if tile == Tiles.SUBWAY_STATION:
				return _move(SUBWAY_STATION_MODE, 4)
		BUS_HIGHWAY_MODE:
			if _is_highway_span(tile) and highway_step(buildings, current, next_point, map_edge):
				return _move(BUS_HIGHWAY_MODE, 1)

			if tile >= Tiles.ONRAMP_FIRST and tile <= Tiles.ONRAMP_LAST and _highway_exit(buildings, current, next_point, map_edge):
				return _move(BUS_ROAD_MODE, 1)
		BUS_TUNNEL_MODE:
			if altitudes[index] & Sc2AltitudeLayout.TUNNEL_FIELD_MASK:
				return _move(BUS_TUNNEL_MODE, 2)

			if NetworkTileMembership.surface_road(tile):
				return _move(BUS_ROAD_MODE, 2)
		BUS_BRIDGE_MODE:
			if _is_road_bridge(tile):
				return _move(BUS_BRIDGE_MODE, 2)

			if NetworkTileMembership.surface_road(tile):
				return _move(BUS_ROAD_MODE, 2)
		BUS_STOP_MODE:
			if destination:
				return ADVANCE_SUCCESS

			if tile == Tiles.BUS_DEPOT:
				return _move(BUS_STOP_MODE, 4)

			if NetworkTileMembership.surface_road(tile):
				return _move(BUS_ROAD_MODE, 2)
		BUS_RAIL_MODE:
			if destination:
				return ADVANCE_SUCCESS

			if tile == Tiles.BUS_DEPOT or tile == Tiles.RAIL_STATION:
				return _move(BUS_RAIL_MODE, 4)

			if NetworkTileMembership.surface_road(tile):
				return _move(ROAD_MODE, 3)
		RAIL_STATION_MODE:
			if tile == Tiles.RAIL_STATION:
				return _move(RAIL_STATION_MODE, 4)

			if NetworkTileMembership.rail(tile):
				return _move(RAIL_MODE, 1)
		SUBWAY_STATION_MODE:
			if NetworkTileMembership.subway(int(underground[index])):
				return _move(SUBWAY_MODE, 1)
		RAIL_MODE:
			if tile == Tiles.RAIL_STATION:
				return _move(BUS_RAIL_MODE, 4)

			if NetworkTileMembership.rail(tile):
				return _move(RAIL_MODE, 1)

			if tile > Tiles.DESALINIZATION:
				return ADVANCE_SUCCESS
		SUBWAY_MODE:
			if tile == Tiles.SUBWAY_STATION:
				return _move(BUS_RAIL_MODE, 4)

			if NetworkTileMembership.subway(int(underground[index])):
				return _move(SUBWAY_MODE, 1)

	return ADVANCE_BLOCKED


static func _move(mode: int, cost: int) -> int:
	return (mode << 8) | cost


static func _is_road_bridge(tile: int) -> bool:
	return (tile >= Tiles.SUSPENSION_BRIDGE_1 and tile <= Tiles.POWER_BRIDGE) or tile == Tiles.HIGHWAY_BRIDGE or tile == Tiles.REINFORCED_HIGHWAY_BRIDGE


static func _is_highway_span(tile: int) -> bool:
	return (tile >= Tiles.HIGHWAY_SLOPE_FIRST and tile <= Tiles.HIGHWAY_INTERSECTION) or (tile >= Tiles.HIGHWAY_STRAIGHT_1 and tile <= Tiles.HIGHWAY_POWER_CROSSING_2)


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

	if tile >= Tiles.ONRAMP_FIRST and tile <= Tiles.ONRAMP_LAST:
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
