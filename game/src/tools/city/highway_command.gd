class_name HighwayCommand
extends HighwayConstants
# Highway drags of 2 by 2 sections. The native simulation library plans and
# places the sections; see native/core/sim/src/sim/tools/commands/highway_edit.rs.


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_ROADS and subtool_index == SUBTOOL_HIGHWAY


# sections start on even coordinates
static func snap_anchor(point: Vector2i) -> Vector2i:
	return Vector2i(point.x & ~1, point.y & ~1)


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
	if city != null and city.is_valid() and not supports_tool(group_index, subtool_index):
		return RouteEditResult.rejected("tool is not a highway")

	return NetworkCommand.route(
		city, group_index, subtool_index, selected_start, selected_finish, bridge_type, connection_choice, free_mode, true
	)


static func undo(city: CityState, command: RouteEditResult) -> EditCommandResult:
	return NativeToolEdit.undo(city, command, "highway", "highway", command.tile_indices.size() if command != null else 0)


# empty when a click can start a highway at `selected`
static func preview_error(city: CityState, selected: Vector2i) -> String:
	if city == null:
		return "The 2 by 2 highway section extends outside the map."

	return NativeSimulationBridge.run("tool.highway_preview", city, null, null, null, {"point": selected}).result
