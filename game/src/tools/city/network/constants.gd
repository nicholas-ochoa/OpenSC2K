class_name NetworkConstants
extends RefCounted
## Network tool modes, bridge types, and connection choices. The route rules
## run in the native simulation library; see native/core/sim/src/sim/tools/commands.

const MODE_ROAD := 0
const MODE_RAIL := 1
const MODE_POWER := 2
const MODE_SUBWAY := 3
const MODE_PIPE := 4
const BRIDGE_CANCELLED := -2
const BRIDGE_UNSELECTED := -1
const BRIDGE_WIRE := 0
const BRIDGE_RAIL := 1
const BRIDGE_ROAD_CAUSEWAY := 2
const BRIDGE_ROAD_RAISING := 3
const BRIDGE_ROAD_SUSPENSION := 4
const CONNECTION_UNSELECTED := -1
const CONNECTION_CANCELLED := 0
const CONNECTION_CONFIRMED := 1
# the tool slot of each network mode: group * ToolCatalog.MAX_SLOTS_PER_GROUP + subtool
const NETWORK_TOOLS := {
	36: MODE_POWER,
	48: MODE_PIPE,
	72: MODE_ROAD,
	84: MODE_RAIL,
	85: MODE_SUBWAY,
}
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
# the network tile offset of each slope shape, for the bridge dialog preview
const NETWORK_SLOPE_SHAPES := [0, 2, 3, 4, 5]
