class_name ToolEditState
extends RefCounted

const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
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


static func is_tool_chooser(group_index: int, subtool_index: int) -> bool:
	return false


static func is_tool_variant(group_index: int, subtool_index: int) -> bool:
	return false


static func scurk_object(
	city: CityState, overlay_mode: String, tile_id: int
) -> Dictionary:
	var area := ScurkPlace.footprint(tile_id, Vector2i(8, 8)).size.x
	var can_place := (
		city != null
		and overlay_mode == "city"
		and ScurkPlace.is_placeable_tile(tile_id)
	)

	return {
		"available": can_place,
		"enabled": can_place,
		"selection": "point",
		"area": area,
		"landscape": false,
		"show_status": true,
		"status_text": "SCURK Tile %d" % tile_id if can_place else "SCURK Place",
		"status_detail": (
			"SCURK tile %d selected. Click its anchor tile to place a %d by %d object."
			% [tile_id, area, area]
			if can_place
			else "Select a SCURK object to place."
		),
	}


static func scurk_tool(city: CityState, tool: Dictionary) -> Dictionary:
	var can_edit := city != null and not tool.is_empty()
	var group_index := int(tool.get("group", -1))
	var subtool_index := int(tool.get("subtool", -1))
	var is_zone := int(tool.get("zone", -1)) >= 0
	var is_demolish := Demolish.supports_tool(group_index, subtool_index)
	var is_landscape := Landscapes.supports_tool(group_index, subtool_index)
	var is_network := Networks.supports_tool(group_index, subtool_index)
	var is_highway := Highways.supports_tool(group_index, subtool_index)
	var is_terrain := TerrainTools.supports_tool(group_index, subtool_index)
	var selection := "point"

	if is_zone or is_demolish:
		selection = "rectangle"
	elif is_landscape or is_network or is_highway or is_terrain:
		selection = "path"

	var tool_name := String(tool.get("name", "Edit Tool"))

	return {
		"available": can_edit,
		"enabled": can_edit,
		"selection": selection,
		"area": 1,
		"landscape": is_landscape,
		"show_status": true,
		"status_text": "SCURK %s" % tool_name,
		"status_detail": (
			"%s is active in Place & Print. Click or drag on the city. City funds and development gates do not apply."
			% tool_name
		),
	}


static func normal(
	city: CityState, overlay_mode: String, group_index: int, subtool_index: int
) -> Dictionary:
	var available := city != null and ToolAvailability.is_available(
		city, group_index, subtool_index
	)
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
	var is_sign := group_index == 15
	var is_query := group_index == 16
	var is_center := group_index == 17
	var point_area := (
		int(Tools.tool(group_index, subtool_index).get("area", 1))
		if is_building else 1
	)
	var is_underground_network := (
		(group_index == 4 and subtool_index == 0)
		or (group_index == 7 and subtool_index == 1)
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
			overlay_mode == "city"
			or (CityDataView.MODES.has(overlay_mode) and (is_query or is_center))
			or (
				overlay_mode == "underground"
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

	if group_index == 1 and subtool_index == 3:
		selection = "point"
		point_area = 7

	var tool := Tools.tool(group_index, subtool_index)

	return {
		"available": available,
		"enabled": enabled,
		"selection": selection,
		"area": point_area,
		"landscape": is_landscape,
		"show_status": city != null,
		"status_text": str(tool.get("name", "Tool")),
		"status_detail": _normal_status_detail(
			city,
			tool,
			available,
			group_index,
			subtool_index,
			is_zone,
			is_landscape,
			is_building,
			is_network,
			is_hydro,
			is_subway_to_rail,
			is_onramp,
			is_tunnel,
			is_highway,
			is_demolish,
			is_terrain,
			is_dispatch,
			is_sign,
			is_query,
			is_center,
		),
	}


static func _normal_status_detail(
	city: CityState,
	tool: Dictionary,
	available: bool,
	group_index: int,
	subtool_index: int,
	is_zone: bool,
	is_landscape: bool,
	is_building: bool,
	is_network: bool,
	is_hydro: bool,
	is_subway_to_rail: bool,
	is_onramp: bool,
	is_tunnel: bool,
	is_highway: bool,
	is_demolish: bool,
	is_terrain: bool,
	is_dispatch: bool,
	is_sign: bool,
	is_query: bool,
	is_center: bool,
) -> String:
	if city == null:
		return ""

	var tool_name := str(tool.get("name", "Tool"))

	if not available:
		return "%s is not available in this city." % tool_name

	if is_tool_chooser(group_index, subtool_index):
		return "%s selected. Select an available type from the choice window." % tool_name

	if is_zone:
		return "%s selected. Drag on the city map to zone. Use the mouse wheel to zoom and the right or middle button to pan." % tool_name

	if group_index == 1 and subtool_index == 3:
		return "Place Forest selected. Hold to scatter trees in a seven-tile brush. Each tree placement costs $3. Hold Shift to Query."

	if is_landscape:
		return "%s selected. Drag to fill an area. Hold Shift to draw a line." % tool_name

	if is_building:
		return "%s selected. Click a clear city site to build it." % tool_name

	if is_network:
		return "%s selected. Drag between city tiles to build a route." % tool_name

	if is_hydro:
		return "Hydroelectric Power Plant selected. Click an unused waterfall tile."

	if is_subway_to_rail:
		return "Subway-to-Rail Connection selected. Click beside a rail or subway."

	if is_onramp:
		return "On-ramp selected. Click on clear terrain between a highway and a perpendicular road."

	if is_tunnel:
		return "Tunnel selected. Click a cardinal slope that faces through a hill."

	if is_highway:
		return "Highway selected. Drag between city tiles to build a two-tile-wide route."

	if is_demolish:
		return "Demolish selected. Drag to paint. Hold Shift before dragging to demolish a box."

	if is_terrain:
		return "%s selected. Click or drag across terrain." % tool_name

	if is_dispatch:
		var inspected := Dispatch.availability(city)
		var count := 0

		if inspected.ok:
			count = [inspected.police, inspected.fire, inspected.military][subtool_index]

		return "%s selected. Click dry, unlabeled terrain to deploy one of %d available units." % [tool_name, count]

	if is_sign:
		return "Place Sign selected. Click a city tile to add, edit, or remove a user sign."

	if is_query and subtool_index == 1:
		return "Trip Query selected. Click a zone or network tile to show potential routes, trip cost, and growth access."

	if is_query and subtool_index == 2:
		return "Service Query selected. Click a police or fire station to show its coverage. Shift-click shows all stations of that type."

	if is_query:
		return "Query selected. Click a city tile to inspect it."

	if is_center:
		return "Center View selected. Click a city tile to center the map on it."

	return "%s is in the original tool catalog. Its command is not implemented yet." % tool_name
