class_name OnrampCommand
extends RefCounted
# Highway on-ramps between a highway and a road. The native simulation library
# checks and places the ramp; see native/simulation/src/sim/tools/commands/onramp.rs.

const GROUP_ROADS := CityToolIds.Group.ROADS
const SUBTOOL_ONRAMP := CityToolIds.Roads.ONRAMP
const PAYLOAD_IDS: PackedStringArray = ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_ROADS and subtool_index == SUBTOOL_ONRAMP


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	point: Vector2i,
	free_mode := false,
	preview_only := false
) -> OnrampEditResult:
	if city == null or not city.is_valid():
		return OnrampEditResult.rejected("city is invalid")

	if not supports_tool(group_index, subtool_index):
		return OnrampEditResult.rejected("tool is not an on-ramp")

	var args := NativeToolEdit.tool_args(group_index, subtool_index, free_mode)
	args.point = point
	args.preview_only = preview_only

	# a preview changes nothing and keeps no payloads
	if preview_only:
		return NativeSimulationBridge.run("tool.onramp", city, null, null, null, args).result

	return NativeToolEdit.run("tool.onramp", city, args, PAYLOAD_IDS)


static func undo(city: CityState, command: OnrampEditResult) -> EditCommandResult:
	return NativeToolEdit.undo(city, command, "onramp", "on-ramp", 2)
