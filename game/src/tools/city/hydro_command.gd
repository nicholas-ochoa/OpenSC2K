class_name HydroCommand
extends RefCounted
# Hydroelectric dams on waterfalls. The native simulation library places the
# dam and refreshes power; see native/simulation/src/sim/tools/commands/hydro.rs.

const GROUP_POWER := CityToolIds.Group.POWER
const SUBTOOL_HYDRO := CityToolIds.Power.HYDRO
const PAYLOAD_IDS: PackedStringArray = ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_POWER and subtool_index == SUBTOOL_HYDRO


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	point: Vector2i,
	process_random: SimRandom
) -> HydroEditResult:
	if city == null or not city.is_valid():
		return HydroEditResult.rejected("city is invalid")

	if not supports_tool(group_index, subtool_index):
		return HydroEditResult.rejected("tool is not hydroelectric power")

	if process_random == null:
		return HydroEditResult.rejected("process random state is required")

	var args := NativeToolEdit.tool_args(group_index, subtool_index)
	args.point = point

	return NativeToolEdit.run("tool.hydro", city, args, PAYLOAD_IDS, process_random)


static func undo(city: CityState, command: HydroEditResult, process_random: SimRandom) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != "hydro":
		return EditCommandResult.failure("hydroelectric command is invalid")

	if process_random == null:
		return EditCommandResult.failure("process random state is required")

	if process_random.state != command.random_state_after:
		return EditCommandResult.failure("process random state changed after this hydroelectric command")

	var error := NativeToolEdit.restore(city, command, "hydroelectric")

	if not error.is_empty():
		return EditCommandResult.failure(error)

	process_random.state = command.random_state_before

	return EditCommandResult.undone(1)
