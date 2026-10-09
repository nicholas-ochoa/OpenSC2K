class_name BuildingSites
extends BuildingConstants
## The building of each tool and its footprint. The site rules run in the
## native simulation library; see native/core/sim/src/sim/tools/commands/building.rs.


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return TILE_BY_TOOL.has(group_index * ToolCatalog.MAX_SLOTS_PER_GROUP + subtool_index)


static func tile_for_tool(group_index: int, subtool_index: int) -> int:
	return int(TILE_BY_TOOL.get(
		group_index * ToolCatalog.MAX_SLOTS_PER_GROUP + subtool_index, 0
	))


# the pointer isn't the footprint origin for the bigger buildings
static func footprint(selected: Vector2i, area: int) -> Rect2i:
	if area < 1 or area > 4:
		return Rect2i()

	var origin := selected

	if area > 2:
		origin -= Vector2i.ONE

	return Rect2i(origin, Vector2i(area, area))


# checks the site without changing the city or consuming random state
static func preview_valid(city: CityState, group: int, subtool: int, point: Vector2i) -> bool:
	return preview_error(city, group, subtool, point).is_empty()


static func preview_error(city: CityState, group: int, subtool: int, point: Vector2i) -> String:
	if city == null or not supports_tool(group, subtool):
		return "No building tool is selected."

	var args := placement_args(city, group, subtool)
	args.point = point

	return NativeSimulationBridge.run("tool.building_preview", city, null, null, null, args).result


# the tool, its building, and its availability in `city`
static func placement_args(city: CityState, group: int, subtool: int) -> Dictionary:
	var args := NativeToolEdit.tool_args(group, subtool)
	var tool := ToolCatalog.tool(group, subtool)
	args.tile = tile_for_tool(group, subtool)
	args.area = int(tool.area) if tool != null else 1
	args.available = ToolAvailability.is_available(city, group, subtool)

	return args
