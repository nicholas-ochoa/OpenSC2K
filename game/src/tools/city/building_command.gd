class_name BuildingCommand
extends BuildingConstants
# Buildings from the tool palette. The native simulation library checks the
# site, places the building, and refreshes power and water; see
# native/core/sim/src/sim/tools/commands/building.rs.

const PAYLOAD_IDS: PackedStringArray = ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return BuildingSites.supports_tool(group_index, subtool_index)


static func preview_error(city: CityState, group: int, subtool: int, point: Vector2i) -> String:
	return BuildingSites.preview_error(city, group, subtool, point)


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	selected: Vector2i,
	lfsr_random: SimLfsrRandom,
	process_random: SimRandom,
	australian_locale := false
) -> BuildingEditResult:
	if city == null or not city.is_valid():
		return BuildingEditResult.rejected("city is invalid")

	if not supports_tool(group_index, subtool_index):
		return BuildingEditResult.rejected("tool does not place a shared building")

	if lfsr_random == null:
		return BuildingEditResult.rejected("LFSR random state is required")

	if process_random == null:
		return BuildingEditResult.rejected("process random state is required")

	var args := BuildingSites.placement_args(city, group_index, subtool_index)
	args.point = selected
	args.australian_locale = australian_locale
	var result: BuildingEditResult = NativeToolEdit.run("tool.building", city, args, PAYLOAD_IDS, process_random, lfsr_random)

	# a stadium keeps every payload until its team joins the undo
	if result.ok and not result.stadium_team_selection_required:
		result.retain_changed_payloads()

	return result


static func undo(
	city: CityState,
	command: BuildingEditResult,
	lfsr_random: SimLfsrRandom,
	process_random: SimRandom
) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != "building":
		return EditCommandResult.failure("building command is invalid")

	if lfsr_random == null:
		return EditCommandResult.failure("LFSR random state is required")

	if process_random == null:
		return EditCommandResult.failure("process random state is required")

	if lfsr_random.state != command.lfsr_state_after:
		return EditCommandResult.failure("LFSR state changed after this building command")

	if process_random.state != command.random_state_after:
		return EditCommandResult.failure("process random state changed after this building command")

	var error := NativeToolEdit.restore(city, command, "building")

	if not error.is_empty():
		return EditCommandResult.failure(error)

	lfsr_random.state = command.lfsr_state_before
	process_random.state = command.random_state_before

	return EditCommandResult.undone(command.tile_indices.size())
