class_name HighwayConstants
extends RefCounted
## Highway bridge types and connection choices. The highway rules run in the
## native simulation library; see native/simulation/src/sim/tools/commands.

const GROUP_ROADS := CityToolIds.Group.ROADS
const SUBTOOL_HIGHWAY := CityToolIds.Roads.HIGHWAY
const CONNECTION_LABEL := Sc2OverlayLayout.CONNECTION_MARKER
const CONNECTION_COST := 1500
const CONNECTION_UNSELECTED := -1
const CONNECTION_CANCELLED := 0
const CONNECTION_CONFIRMED := 1
const BRIDGE_CANCELLED := -2
const BRIDGE_UNSELECTED := -1
const BRIDGE_HIGHWAY := 5
const BRIDGE_REINFORCED := 6
const BRIDGE_COSTS := { BRIDGE_HIGHWAY: 200, BRIDGE_REINFORCED: 300 }
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
