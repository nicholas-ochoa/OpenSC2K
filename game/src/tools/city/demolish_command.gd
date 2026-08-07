class_name DemolishCommand
extends DemolishConstants
# tool command api that edit flow dispatch calls. implementations are in
# demolish/


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return DemolishEdit.supports_tool(group_index, subtool_index)


static func apply_path(
	city: CityState,
	group_index: int,
	subtool_index: int,
	points: Array[Vector2i],
	random: SimRandom,
	underground_view := false,
	scurk_mode := false
) -> DemolishEditResult:
	return DemolishEdit.apply_path(city, group_index, subtool_index, points, random, underground_view, scurk_mode)


static func undo(city: CityState, command: DemolishEditResult, random: SimRandom) -> EditCommandResult:
	return DemolishEdit.undo(city, command, random)
