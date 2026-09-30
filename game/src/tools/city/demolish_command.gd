class_name DemolishCommand
extends DemolishConstants
# Bulldozer paths. The native simulation library demolishes each point; see
# native/simulation/src/sim/tools/commands/demolish.rs.


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_BULLDOZER and subtool_index == SUBTOOL_DEMOLISH


static func apply_path(
	city: CityState,
	group_index: int,
	subtool_index: int,
	points: Array[Vector2i],
	random: SimRandom,
	underground_view := false,
	scurk_mode := false
) -> DemolishEditResult:
	if city == null or not city.is_valid():
		return DemolishEditResult.rejected("city is invalid")

	if not supports_tool(group_index, subtool_index):
		return DemolishEditResult.rejected("tool is not the demolish tool")

	if random == null:
		return DemolishEditResult.rejected("random state is required")

	var args := NativeToolEdit.tool_args(group_index, subtool_index)
	args.points = points
	args.underground_view = underground_view
	args.scurk_mode = scurk_mode

	return NativeToolEdit.run("tool.demolish", city, args, PAYLOAD_IDS, random)


static func undo(city: CityState, command: DemolishEditResult, random: SimRandom) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != "demolish":
		return EditCommandResult.failure("demolish command is invalid")

	if random == null:
		return EditCommandResult.failure("random state is required")

	if random.state != command.random_state_after:
		return EditCommandResult.failure("random state changed after this demolish command")

	var error := NativeToolEdit.restore(city, command, "demolish")

	if not error.is_empty():
		return EditCommandResult.failure(error)

	random.state = command.random_state_before

	return EditCommandResult.undone(command.tile_indices.size())
