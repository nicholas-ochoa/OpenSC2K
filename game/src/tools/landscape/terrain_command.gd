class_name TerrainCommand
extends TerrainEditConstants
# The level, raise, and lower tools. The native simulation library plans the
# heights and clears the structures in the way; see
# native/simulation/src/sim/tools/commands/terrain_edit.rs.

const PAYLOAD_IDS: PackedStringArray = ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_BULLDOZER and subtool_index >= SUBTOOL_LEVEL and subtool_index <= SUBTOOL_LOWER


# Without a random generator, a structure in the way skips its tile
static func apply_path(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	points: Array[Vector2i],
	random: SimRandom = null,
	free_mode := false,
	target_override := -1
) -> TerrainEditResult:
	if city == null or not city.is_valid():
		return TerrainEditResult.rejected("city is invalid")

	if not supports_tool(group_index, subtool_index):
		return TerrainEditResult.rejected("tool is not a terrain tool")

	var args := NativeToolEdit.tool_args(group_index, subtool_index, free_mode)
	args.start = start
	args.points = points
	args.target_override = target_override
	args.has_random = random != null

	return NativeToolEdit.run("tool.terrain", city, args, PAYLOAD_IDS, random)


static func undo(city: CityState, command: TerrainEditResult, random: SimRandom = null) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != "terrain":
		return EditCommandResult.failure("terrain command is invalid")

	if command.random_used:
		if random == null:
			return EditCommandResult.failure("random state is required")

		if random.state != command.random_state_after:
			return EditCommandResult.failure("random state changed after this terrain command")

	var error := NativeToolEdit.restore(city, command, "terrain")

	if not error.is_empty():
		return EditCommandResult.failure(error)

	if command.random_used:
		random.state = command.random_state_before

	return EditCommandResult.undone(command.tile_indices.size())
