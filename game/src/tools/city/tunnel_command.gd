class_name TunnelCommand
extends RefCounted
# Road tunnels through a hill. The native simulation library checks and digs
# the tunnel; see native/simulation/src/sim/tools/commands/tunnel.rs.

const GROUP_ROADS := CityToolIds.Group.ROADS
const SUBTOOL_TUNNEL := CityToolIds.Roads.TUNNEL
const CONFIRMATION_UNSELECTED := -1
const CONFIRMATION_CANCELLED := 0
const CONFIRMATION_CONFIRMED := 1
const PAYLOAD_IDS: PackedStringArray = ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "MISC"]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_ROADS and subtool_index == SUBTOOL_TUNNEL


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	confirmation_choice := CONFIRMATION_UNSELECTED,
	free_mode := false
) -> TunnelEditResult:
	if city == null or not city.is_valid():
		return TunnelEditResult.rejected("city is invalid")

	if not supports_tool(group_index, subtool_index):
		return TunnelEditResult.rejected("tool is not a tunnel")

	var args := NativeToolEdit.tool_args(group_index, subtool_index, free_mode)
	args.point = start
	args.confirmation = confirmation_choice

	return NativeToolEdit.run("tool.tunnel", city, args, PAYLOAD_IDS)


static func undo(city: CityState, command: TunnelEditResult) -> EditCommandResult:
	return NativeToolEdit.undo(city, command, "tunnel", "tunnel", command.points.size() if command != null else 0)
