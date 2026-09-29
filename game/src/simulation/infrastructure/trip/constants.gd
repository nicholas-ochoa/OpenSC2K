class_name TransportTripConstants
extends RefCounted

const CONNECTION_LABEL := Sc2OverlayLayout.CONNECTION_MARKER
const ROAD_MODE := 0
const HIGHWAY_MODE := 1
const ROAD_TUNNEL_MODE := 2
const BUS_ROAD_MODE := 4
const BUS_HIGHWAY_MODE := 5
const RAIL_MODE := 12
const SUBWAY_MODE := 13
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


# the mode sits above the start index. 128 tile maps keep the original 14 bits
static func point_shift(map_edge: int) -> int:
	return 14 if map_edge == 128 else 20
