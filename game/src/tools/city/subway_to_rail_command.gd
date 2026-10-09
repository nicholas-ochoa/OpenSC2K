class_name SubwayToRailCommand
extends RefCounted
# Subway-to-rail connections. The native simulation library checks and places
# the connector; see native/core/sim/src/sim/tools/commands/subway_to_rail.rs.

const GROUP_RAIL := CityToolIds.Group.RAIL
const SUBTOOL_CONNECTION := CityToolIds.Rail.SUBWAY_TO_RAIL
const PAYLOAD_IDS: PackedStringArray = ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_RAIL and subtool_index == SUBTOOL_CONNECTION


static func apply(
	city: CityState, group_index: int, subtool_index: int, point: Vector2i, preview_only := false
) -> SubwayToRailEditResult:
	if city == null or not city.is_valid():
		return SubwayToRailEditResult.rejected("city is invalid")

	if not supports_tool(group_index, subtool_index):
		return SubwayToRailEditResult.rejected("tool is not a subway-to-rail connection")

	var args := NativeToolEdit.tool_args(group_index, subtool_index)
	args.point = point
	args.preview_only = preview_only

	# a preview changes nothing and keeps no payloads
	if preview_only:
		return NativeSimulationBridge.run("tool.subway_to_rail", city, null, null, null, args).result

	return NativeToolEdit.run("tool.subway_to_rail", city, args, PAYLOAD_IDS)


static func undo(city: CityState, command: SubwayToRailEditResult) -> EditCommandResult:
	return NativeToolEdit.undo(city, command, "subway_to_rail", "subway-to-rail", 1)
