class_name NetworkCommand
extends NetworkConstants
# Road, rail, power line, subway, and pipe drags. The native simulation library
# plans and places the route; see native/simulation/src/sim/tools/commands/route.rs.

# the chunks that a route checks, in commit order
const PAYLOAD_IDS: PackedStringArray = ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "MISC"]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return NETWORK_TOOLS.has(group_index * ToolCatalog.MAX_SLOTS_PER_GROUP + subtool_index)


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	finish: Vector2i,
	bridge_type := BRIDGE_UNSELECTED,
	connection_choice := CONNECTION_UNSELECTED,
	free_mode := false
) -> RouteEditResult:
	return route(city, group_index, subtool_index, start, finish, bridge_type, connection_choice, free_mode, false)


# A drag joins its bridge-separated segments into one result and one undo
static func route(
	city: CityState, group: int, tool: int, start: Vector2i, finish: Vector2i,
	bridge: int, connection: int, free_mode: bool, highway: bool
) -> RouteEditResult:
	if city == null or not city.is_valid():
		return RouteEditResult.rejected("city is invalid")

	var args := NativeToolEdit.tool_args(group, tool, free_mode)
	args.start = start
	args.finish = finish
	args.bridge = bridge
	args.connection = connection
	args.highway = highway

	return NativeToolEdit.run("tool.route", city, args, PAYLOAD_IDS)


static func undo(city: CityState, command: RouteEditResult) -> EditCommandResult:
	return NativeToolEdit.undo(city, command, "network", "network", command.points.size() if command != null else 0)
