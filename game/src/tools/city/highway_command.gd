class_name HighwayCommand
extends HighwayConstants
# tool command api that application dispatch calls, in parallel with
# networkcommand and buildingcommand. implementations are in highway/


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return HighwayGeometry.supports_tool(group_index, subtool_index)


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	selected_start: Vector2i,
	selected_finish: Vector2i,
	connection_choice := CONNECTION_UNSELECTED,
	bridge_type := BRIDGE_UNSELECTED,
	free_mode := false
) -> RouteEditResult:
	return NetworkDragCommand.apply(city, group_index, subtool_index, selected_start, selected_finish, bridge_type, connection_choice, free_mode, true)


static func undo(city: CityState, command: RouteEditResult) -> EditCommandResult:
	return HighwayEdit.undo(city, command)


static func preview_error(city: CityState, selected: Vector2i) -> String:
	return HighwayEdit.preview_error(city, selected)
