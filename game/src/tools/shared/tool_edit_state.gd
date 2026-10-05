class_name ToolEditState
extends RefCounted
## What a selected tool does in the current view.

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


# the state of a catalog tool in the current view. The native simulation
# library holds the rules; see native/core/sim/src/sim/tools/edit_state.rs
static func normal(
	city: CityState, overlay_mode: CityViewMode.Mode, group_index: int, subtool_index: int, free := false
) -> Result:
	var available := city != null and (free or ToolAvailability.is_available(
		city, group_index, subtool_index
	))
	var dispatch_units := 0

	if city != null and available and Dispatch.supports_tool(group_index, subtool_index):
		var inspected := Dispatch.availability(city)

		if inspected.ok:
			dispatch_units = inspected.counts()[subtool_index]

	var fields := NativeCityTools.edit_state(
		city != null, available, _view(overlay_mode), group_index, subtool_index, dispatch_units
	)
	var result := Result.new()

	for field: String in fields:
		result.set(field, fields[field])

	return result


static func _view(overlay_mode: CityViewMode.Mode) -> String:
	if overlay_mode == CityViewMode.Mode.CITY:
		return "city"

	if overlay_mode == CityViewMode.Mode.UNDERGROUND:
		return "underground"

	return "data" if CityViewMode.is_data(overlay_mode) else "other"


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
