class_name ToolEditState
extends RefCounted

const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const Zones = preload("res://src/tools/city/zone_command.gd")
const Landscapes = preload("res://src/tools/landscape/landscape_command.gd")
const Buildings = preload("res://src/tools/city/building_command.gd")
const Networks = preload("res://src/tools/city/network_command.gd")
const Hydro = preload("res://src/tools/city/hydro_command.gd")
const SubwayToRail = preload("res://src/tools/city/subway_to_rail_command.gd")
const Onramps = preload("res://src/tools/city/onramp_command.gd")
const Tunnels = preload("res://src/tools/city/tunnel_command.gd")
const Highways = preload("res://src/tools/city/highway_command.gd")
const Demolish = preload("res://src/tools/city/demolish_command.gd")
const TerrainTools = preload("res://src/tools/landscape/terrain_command.gd")
const Dispatch = preload("res://src/tools/city/dispatch_command.gd")
const ScurkPlace = preload("res://src/tools/scurk/scurk_place_command.gd")


static func scurk_object(
	city: CityState, overlay_mode: CityViewMode.Mode, tile_id: int
) -> Result:
	var area := ScurkPlace.footprint(tile_id, Vector2i(8, 8)).size.x
	var can_place := (
		city != null
		and overlay_mode == CityViewMode.Mode.CITY
		and ScurkPlace.is_placeable_tile(tile_id)
	)

	var result := Result.new()
	result.available = can_place
	result.enabled = can_place
	result.selection = "point"
	result.area = area
	result.landscape = false
	result.show_status = true
	result.status_text = "SCURK Tile %d" % tile_id if can_place else "SCURK Place"
	result.status_detail = (
		"SCURK tile %d selected. Click its anchor tile to place a %d by %d object."
		% [tile_id, area, area]
		if can_place
		else "Select a SCURK object to place."
	)

	return result


# a Place & Print edit tool selects, previews, and repeats as its city tool
# does. availability and funds do not apply
static func scurk_tool(city: CityState, overlay_mode: CityViewMode.Mode, tool: ScurkEditTool) -> Result:
	if tool == null:
		return normal(null, overlay_mode, -1, -1)

	var result := normal(city, overlay_mode, tool.group, tool.subtool, true)
	result.status_text = "SCURK %s" % tool.name
	result.status_detail = (
		"%s is active in Place & Print. Click or drag on the city. City funds and development gates do not apply."
		% tool.name
	)

	return result


static func normal(
	city: CityState, overlay_mode: CityViewMode.Mode, group_index: int, subtool_index: int, free := false
) -> Result:
	var available := city != null and (free or ToolAvailability.is_available(
		city, group_index, subtool_index
	))
	var is_zone := Zones.supports_tool(group_index, subtool_index)
	var is_landscape := Landscapes.supports_tool(group_index, subtool_index)
	var is_building := Buildings.supports_tool(group_index, subtool_index)
	var is_network := Networks.supports_tool(group_index, subtool_index)
	var is_hydro := Hydro.supports_tool(group_index, subtool_index)
	var is_subway_to_rail := SubwayToRail.supports_tool(group_index, subtool_index)
	var is_onramp := Onramps.supports_tool(group_index, subtool_index)
	var is_tunnel := Tunnels.supports_tool(group_index, subtool_index)
	var is_highway := Highways.supports_tool(group_index, subtool_index)
	var is_demolish := Demolish.supports_tool(group_index, subtool_index)
	var is_terrain := TerrainTools.supports_tool(group_index, subtool_index)
	var is_dispatch := Dispatch.supports_tool(group_index, subtool_index)
	var is_sign := group_index == CityToolIds.Group.SIGNS
	var is_query := group_index == CityToolIds.Group.QUERY
	var is_center := group_index == CityToolIds.Group.CENTERING

	# runs the click action again each time the held cursor enters another tile.
	# Tools with their own drag loop and Query, Center, and Sign do not repeat.
	var repeats_placement := (
		is_building or is_hydro or is_subway_to_rail or is_onramp or is_tunnel or is_dispatch
	)

	var point_area := (
		Tools.tool(group_index, subtool_index).area
		if is_building else 1
	)

	var is_underground_network := (
		(group_index == CityToolIds.Group.WATER and subtool_index == CityToolIds.Water.PIPES)
		or (group_index == CityToolIds.Group.RAIL and subtool_index == CityToolIds.Rail.SUBWAY)
	)

	var supported := (
		is_zone
		or is_landscape
		or is_building
		or is_network
		or is_hydro
		or is_subway_to_rail
		or is_onramp
		or is_tunnel
		or is_highway
		or is_demolish
		or is_terrain
		or is_dispatch
		or is_sign
		or is_query
		or is_center
	)
	var enabled := (
		available
		and (
			overlay_mode == CityViewMode.Mode.CITY
			or (CityViewMode.is_data(overlay_mode) and (is_query or is_center))
			or (
				overlay_mode == CityViewMode.Mode.UNDERGROUND
				and (is_underground_network or is_demolish or is_query or is_center)
			)
		)
		and supported
	)
	var selection := "point"

	if is_zone or is_demolish:
		selection = "rectangle"
	elif is_landscape or is_network or is_highway or is_terrain:
		selection = "path"

	if group_index == CityToolIds.Group.LANDSCAPE and subtool_index == CityToolIds.Landscape.FOREST:
		selection = "point"
		point_area = 7

	var tool := Tools.tool(group_index, subtool_index)

	var result := Result.new()
	result.available = available
	result.enabled = enabled
	result.selection = selection
	result.area = point_area
	result.landscape = is_landscape
	result.repeat_placement = repeats_placement
	result.show_status = city != null
	result.status_text = tool.name if tool != null else "Tool"
	result.status_detail = _normal_status_detail(city, tool, available, group_index, subtool_index)

	return result


static func _normal_status_detail(
	city: CityState, tool: ToolCatalog.Tool, available: bool, group_index: int, subtool_index: int
) -> String:
	if city == null:
		return ""

	var tool_name := tool.name if tool != null else "Tool"

	if not available:
		return "%s is not available in this city." % tool_name

	if Zones.supports_tool(group_index, subtool_index):
		return "%s selected. Drag on the city map to zone. Use the mouse wheel to zoom and the right or middle button to pan." % tool_name

	if group_index == CityToolIds.Group.LANDSCAPE and subtool_index == CityToolIds.Landscape.FOREST:
		return "Place Forest selected. Hold to scatter trees in a seven-tile brush. Each tree placement costs $3. Hold Shift to Query."

	if Landscapes.supports_tool(group_index, subtool_index):
		return "%s selected. Drag to fill an area. Hold Shift to draw a line." % tool_name

	if Buildings.supports_tool(group_index, subtool_index):
		return "%s selected. Click a clear city site to build it. Drag to build more." % tool_name

	if Networks.supports_tool(group_index, subtool_index):
		return "%s selected. Drag between city tiles to build a route." % tool_name

	if Hydro.supports_tool(group_index, subtool_index):
		return "Hydroelectric Power Plant selected. Click an unused waterfall tile."

	if SubwayToRail.supports_tool(group_index, subtool_index):
		return "Subway-to-Rail Connection selected. Click beside a rail or subway."

	if Onramps.supports_tool(group_index, subtool_index):
		return "On-ramp selected. Click on clear terrain between a highway and a perpendicular road."

	if Tunnels.supports_tool(group_index, subtool_index):
		return "Tunnel selected. Click a cardinal slope that faces through a hill."

	if Highways.supports_tool(group_index, subtool_index):
		return "Highway selected. Drag between city tiles to build a two-tile-wide route."

	if Demolish.supports_tool(group_index, subtool_index):
		return "Demolish selected. Drag to paint. Hold Shift before dragging to demolish a box."

	if TerrainTools.supports_tool(group_index, subtool_index):
		return "%s selected. Click or drag across terrain." % tool_name

	if Dispatch.supports_tool(group_index, subtool_index):
		var inspected := Dispatch.availability(city)
		var count := 0

		if inspected.ok:
			count = [inspected.police, inspected.fire, inspected.military][subtool_index]

		return "%s selected. Click dry, unlabeled terrain to deploy one of %d available units." % [tool_name, count]

	if group_index == CityToolIds.Group.SIGNS:
		return "Place Sign selected. Click a city tile to add, edit, or remove a user sign."

	if group_index == CityToolIds.Group.QUERY and subtool_index == CityToolIds.Query.TRIP_REACH:
		return "Trip Query selected. Click a zone or network tile to show potential routes, trip cost, and growth access."

	if group_index == CityToolIds.Group.QUERY and subtool_index == CityToolIds.Query.TILE_INSPECTOR:
		return "Tile Inspector selected. Point at a tile to read its stored values. Click to keep the panel on that tile."

	if group_index == CityToolIds.Group.QUERY:
		return "Query selected. Click a city tile to inspect it."

	if group_index == CityToolIds.Group.CENTERING:
		return "Center View selected. Click a city tile to center the map on it."

	return "%s is in the original tool catalog. Its command is not implemented yet." % tool_name


class Result extends RefCounted:
	var available: bool = false
	var enabled: bool = false
	var selection: String = "point"
	var area: int = 1
	var landscape: bool = false
	var repeat_placement: bool = false
	var show_status: bool = false
	var status_text: String = ""
	var status_detail: String = ""
