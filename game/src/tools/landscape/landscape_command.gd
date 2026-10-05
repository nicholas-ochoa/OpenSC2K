class_name LandscapeCommand
extends RefCounted
# Trees, forests, and water. The native simulation library plants and floods
# the tiles; see native/core/sim/src/sim/tools/commands/landscape.rs.

const GROUP_NATURE := CityToolIds.Group.LANDSCAPE
const SUBTOOL_TREES := CityToolIds.Landscape.TREES
const SUBTOOL_WATER := CityToolIds.Landscape.WATER
const PAYLOAD_IDS: PackedStringArray = ["XBLD", "XTER", "XZON", "XBIT", "ALTM", "MISC"]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_NATURE and (
		subtool_index in [SUBTOOL_TREES, SUBTOOL_WATER, CityToolIds.Landscape.FOREST]
	)


static func apply_path(
	city: CityState,
	group_index: int,
	subtool_index: int,
	points: Array[Vector2i],
	random: SimRandom,
	free_mode := false,
	use_brush_points := false
) -> LandscapeEditResult:
	if city == null or not city.is_valid():
		return LandscapeEditResult.rejected("city is invalid")

	if not supports_tool(group_index, subtool_index):
		return LandscapeEditResult.rejected("tool is not a landscape tool")

	if random == null:
		return LandscapeEditResult.rejected("random state is required")

	var args := NativeToolEdit.tool_args(group_index, subtool_index, free_mode)
	args.points = points
	args.use_brush_points = use_brush_points

	return NativeToolEdit.run("tool.landscape", city, args, PAYLOAD_IDS, random)


static func undo(city: CityState, command: LandscapeEditResult, random: SimRandom) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != "landscape":
		return EditCommandResult.failure("landscape command is invalid")

	if random == null:
		return EditCommandResult.failure("random state is required")

	if random.state != command.random_state_after:
		return EditCommandResult.failure("random state changed after this landscape command")

	var error := NativeToolEdit.restore(city, command, "landscape")

	if not error.is_empty():
		return EditCommandResult.failure(error)

	random.state = command.random_state_before

	return EditCommandResult.undone(command.tile_indices.size())
