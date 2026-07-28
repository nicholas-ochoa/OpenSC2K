class_name NetworkCommand
extends NetworkConstants
# tool command api that application dispatch calls, in parallel with
# highwaycommand and buildingcommand. implementations are in network/


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return NetworkRules.supports_tool(group_index, subtool_index)


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	finish: Vector2i,
	bridge_type := BRIDGE_UNSELECTED,
	connection_choice := CONNECTION_UNSELECTED,
	free_mode := false
) -> Dictionary:
	return NetworkDragCommand.apply(city, group_index, subtool_index, start, finish, bridge_type, connection_choice, free_mode, false)


static func undo(city: CityState, command: Dictionary) -> Dictionary:
	return NetworkEdit.undo(city, command)
