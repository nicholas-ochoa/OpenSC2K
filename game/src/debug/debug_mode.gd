class_name DebugMode
extends RefCounted
## Debug mode shows the Debug menu and the debug query tools. The Debug window
## sets it, and the application preferences keep it. Tool catalogs and palettes
## read it here because they have no application reference.

static var enabled := false


# true for the query tools that only debug mode offers
static func is_debug_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == CityToolIds.Group.QUERY and subtool_index in [
		CityToolIds.Query.TRIP_REACH, CityToolIds.Query.TILE_INSPECTOR,
	]


static func allows_tool(group_index: int, subtool_index: int) -> bool:
	return enabled or not is_debug_tool(group_index, subtool_index)
