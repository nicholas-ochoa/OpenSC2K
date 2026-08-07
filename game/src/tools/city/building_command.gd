class_name BuildingCommand
extends BuildingConstants
# tool command api that application dispatch calls, in parallel with
# networkcommand and highwaycommand. implementations are in building/


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
	return BuildingEdit.apply(city, group_index, subtool_index, selected, lfsr_random, process_random, australian_locale)


static func undo(
	city: CityState,
	command: BuildingEditResult,
	lfsr_random: SimLfsrRandom,
	process_random: SimRandom
) -> EditCommandResult:
	return BuildingEdit.undo(city, command, lfsr_random, process_random)
