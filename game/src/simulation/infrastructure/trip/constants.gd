class_name TransportTripConstants
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
# modes that reach a zone on foot, as a bit per mode, and the any-rci
# catchment as a bit per zone. both replace per-call array literals
const WALK_ACCESS_MODES := (1 << ROAD_MODE) | (1 << BUS_ROAD_MODE) | (1 << BUS_STOP_MODE) | (1 << BUS_RAIL_MODE)
const ANY_RCI_ZONE_MASK := 0x7e


# independent corrected lane model. port bits: north, east, south, west
# straight sections have one direction per lane. curves connect the ingress
# and egress corners of their two-by-two footprint with right-hand traffic
const HIGHWAY_PORTS := {0x49: 5, 0x4a: 10, 0x4b: 5, 0x4c: 10,
	0x4d: 5, 0x4e: 10, 0x4f: 5, 0x50: 10,
	0x61: 10, 0x62: 5, 0x63: 10, 0x64: 5,
	0x65: 3, 0x66: 6, 0x67: 12, 0x68: 9, 0x69: 15}
const LANE_CORNERS := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]
const INGRESS_CORNERS := [0, 3, 2, 1]
const EGRESS_CORNERS := [3, 2, 1, 0]
