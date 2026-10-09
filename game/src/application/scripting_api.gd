class_name ApplicationScriptingApi
extends ScriptingApiBase
## The game functions that scripts call through `__runtime.host(name, ...)`.
## game/assets/scripting/api.js wraps them as the script objects. This file
## holds `game`, `sim`, `tools` and `view`; ScriptingCityApi, ScriptingBudgetApi
## and ScriptingUiApi hold the others. See docs/scripting.md.

const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")

var city_api: ScriptingCityApi
var budget_api: ScriptingBudgetApi
var ui_api: ScriptingUiApi


func _init(application: CityApplication) -> void:
	super(application, {"failure": ""})
	city_api = ScriptingCityApi.new(application, call_state)
	budget_api = ScriptingBudgetApi.new(application, call_state)
	ui_api = ScriptingUiApi.new(application, call_state)


## The message of the failed call, or an empty text. Clears it.
func take_failure() -> String:
	var message: String = call_state.failure
	call_state.failure = ""

	return message


func handlers() -> Dictionary[String, Callable]:
	var result: Dictionary[String, Callable] = {
		"game.version": _game_version,
		"game.events": func(_arguments: Array) -> Variant: return ApplicationScripting.EVENTS,
		"game.status": _game_status,
		"sim.speed": _sim_speed,
		"sim.setSpeed": _sim_set_speed,
		"sim.resume": _sim_resume,
		"sim.step": _sim_step,
		"sim.disaster": _sim_disaster,
		"sim.disasters": _sim_disasters,
		"sim.startDisaster": _sim_start_disaster,
		"sim.endDisaster": _sim_end_disaster,
		"sim.noDisasters": func(_arguments: Array) -> Variant: return need_city() and app.document_state.city.no_disasters_enabled(),
		"sim.setNoDisasters": _sim_set_no_disasters,
		"sim.runUntil": _sim_run_until,
		"tools.list": _tools_list,
		"tools.selected": func(_arguments: Array) -> Variant: return tool_info(app.tool_state.selected_group, app.tool_state.selected_subtool),
		"tools.select": _tools_select,
		"tools.apply": _tools_apply,
		"tools.undo": _tools_undo,
		"view.center": _view_center,
		"view.centerOn": _view_center_on,
		"view.mode": func(_arguments: Array) -> Variant: return CityViewMode.key(app.view_state.overlay_mode),
		"view.setMode": _view_set_mode,
		"view.modes": func(_arguments: Array) -> Variant: return CityViewMode.KEYS,
		"view.zoom": func(_arguments: Array) -> Variant: return app.map_view.zoom_percent() if app.map_view != null else 100,
		"view.zoomIn": _view_zoom.bind(true),
		"view.zoomOut": _view_zoom.bind(false),
		"view.rotation": func(_arguments: Array) -> Variant: return app.document_state.city.compass_rotation() if need_city() else null,
		"view.rotate": _view_rotate,
	}

	for api in [city_api, budget_api, ui_api]:
		result.merge(api.handlers())

	return result


## The script description of a tool: { group, subtool, groupName, name, cost }.
static func tool_info(group: int, subtool: int) -> Dictionary:
	var tool := Tools.tool(group, subtool)

	if tool == null:
		return {}

	return {"group": group, "subtool": subtool, "groupName": Tools.group(group).name, "name": tool.name, "cost": tool.cost}


## The tiles of a drag from `start` to `finish`, as the map view selects them
## for this kind of selection: one tile, a rectangle or a straight path.
static func selection_path(selection: String, start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []

	if selection == "point":
		path.append(finish)

		return path

	if selection == "rectangle":
		for x in range(mini(start.x, finish.x), maxi(start.x, finish.x) + 1):
			for y in range(mini(start.y, finish.y), maxi(start.y, finish.y) + 1):
				path.append(Vector2i(x, y))

		return path

	var current := start
	path.append(current)

	while current != finish:
		var difference := finish - current

		if absi(difference.y) < absi(difference.x):
			current.x += 1 if difference.x > 0 else -1
		else:
			current.y += 1 if difference.y > 0 else -1

		path.append(current)

	return path


func _game_version(_arguments: Array) -> Variant:
	var godot := Engine.get_version_info()

	return {
		"game": str(ProjectSettings.get_setting("application/config/version", "")),
		"godot": "%d.%d.%d" % [godot.major, godot.minor, godot.patch],
		"quickjs": ScriptRuntime.engine_version(),
	}


func _game_status(arguments: Array) -> Variant:
	if app.status_label != null:
		app.status_label.theme_type_variation = ""
		app.status_label.text = str(arguments[0]) if not arguments.is_empty() else ""

	return null


func _sim_speed(_arguments: Array) -> Variant:
	var controller := app.simulation_state.speed_controller

	return controller.speed_name() if controller != null else GameSpeed.SPEED_NAMES[GameSpeed.Speed.PAUSED]


func _sim_set_speed(arguments: Array) -> Variant:
	if not need_city():
		return null

	var value: Variant = arguments[0] if not arguments.is_empty() else null
	var speed := -1

	if is_number(value):
		speed = int(value)
	elif value is String:
		for id: int in GameSpeed.SPEED_NAMES:
			if GameSpeed.SPEED_NAMES[id].to_lower() == str(value).to_lower():
				speed = id

	if not GameSpeed.SPEED_NAMES.has(speed):
		return fail("The speed must be one of: %s." % ", ".join(GameSpeed.SPEED_NAMES.values()))

	app.frame.select_speed(speed)

	return app.simulation_state.speed_controller.speed_name()


func _sim_resume(_arguments: Array) -> Variant:
	if not need_city():
		return null

	var speed := app.simulation_state.resume_speed

	return _sim_set_speed([speed if speed > GameSpeed.Speed.PAUSED else GameSpeed.Speed.TURTLE])


func _sim_step(_arguments: Array) -> Variant:
	if not need_city():
		return null

	var report := app.debug_tools.steps.step_day()

	return report if report.begins_with("Day ran") else fail(report)


func _sim_disaster(_arguments: Array) -> Variant:
	var engine := app.simulation_state.simulation_engine

	if engine == null or engine.active_disaster_type == 0:
		return null

	return {"id": engine.active_disaster_type, "name": CityMenuBar.disaster_name(engine.active_disaster_type)}


func _sim_disasters(_arguments: Array) -> Variant:
	var result := {}

	for item: Array in CityMenuBar.DISASTER_ITEMS:
		result[item[0]] = item[1]

	return result


func _sim_start_disaster(arguments: Array) -> Variant:
	if not need_city():
		return null

	var value: Variant = arguments[0] if not arguments.is_empty() else null
	var disaster := -1

	for item: Array in CityMenuBar.DISASTER_ITEMS:
		if (value is String and str(item[0]).to_lower() == str(value).to_lower()) or (is_number(value)
				and int(value) == int(item[1])):
			disaster = int(item[1])

	if disaster < 0:
		return fail("Unknown disaster: %s. sim.disasters lists them." % str(value))

	var has_point := arguments.size() > 1 and arguments[1] is Dictionary
	var tile := point(arguments, 1) if has_point else app.map_view.center_tile()
	var report := app.reports.start_disaster_at(disaster, tile)

	return {"id": disaster, "name": report.name} if report.ok else fail("The disaster could not start: %s." % report.error)


func _sim_end_disaster(_arguments: Array) -> Variant:
	if not need_city():
		return null

	if app.simulation_state.simulation_engine.active_disaster_type == 0:
		return false

	var result := app.debug.debug_end_disaster()

	return true if result.ok else fail(result.message)


func _sim_set_no_disasters(arguments: Array) -> Variant:
	if not need_city():
		return null

	var result := app.debug.debug_set_no_disasters(bool(argument(arguments, 0, true)))

	return app.document_state.city.no_disasters_enabled() if result.ok else fail(result.message)


# runUntil({ year, month, day }, speed): runs at the speed, then pauses on the date
func _sim_run_until(arguments: Array) -> Variant:
	if not need_city():
		return null

	var date: Variant = argument(arguments, 0, {})

	if not date is Dictionary or not is_number(date.get("year")):
		return fail("runUntil takes a date such as { year: 2051, month: 3, day: 1 }.")

	var speed := int(argument(arguments, 1, GameSpeed.Speed.CHEETAH))
	var result := app.debug.debug_run_to_date(integer(date.get("month"), 1), integer(date.get("day"), 1), int(date.year), speed)

	return true if result.ok else fail(result.message)


func _tools_list(_arguments: Array) -> Variant:
	var result := []
	var city := app.document_state.city

	for group in Tools.GROUPS.size():
		for subtool in Tools.group(group).tools.size():
			var info := tool_info(group, subtool)
			info.available = city != null and ToolAvailability.is_available(city, group, subtool)
			result.append(info)

	return result


func _tools_select(arguments: Array) -> Variant:
	if not need_city():
		return null

	var choice := _find_tool(arguments[0] if not arguments.is_empty() else null, arguments[1] if arguments.size() > 1 else null)

	if choice.x < 0:
		return fail("Unknown tool. tools.list() lists the groups and tools.")

	app.current_tool.select_tool_group(choice.x)

	if app.tool_state.selected_group == choice.x:
		app.current_tool.select_subtool(choice.y)

	if app.tool_state.selected_group != choice.x or app.tool_state.selected_subtool != choice.y:
		return fail("%s cannot be selected now." % Tools.tool(choice.x, choice.y).name)

	return tool_info(choice.x, choice.y)


# (group, subtool) from indices, a group name and a tool name, or one tool
# name. (-1, -1) when nothing matches
func _find_tool(group_value: Variant, subtool_value: Variant) -> Vector2i:
	var group := _find_group(group_value)

	if group >= 0:
		var tools := Tools.group(group).tools

		if subtool_value == null:
			return Vector2i(group, int(app.tool_state.group_subtools.get(group, 0)))

		for subtool in tools.size():
			if _matches(subtool_value, subtool, tools[subtool].name, tools[subtool].id):
				return Vector2i(group, subtool)

		return Vector2i(-1, -1)

	# one tool name in any group
	if group_value is String and subtool_value == null:
		for index in Tools.GROUPS.size():
			var tools := Tools.group(index).tools

			for subtool in tools.size():
				if _matches(group_value, -1, tools[subtool].name, tools[subtool].id):
					return Vector2i(index, subtool)

	return Vector2i(-1, -1)


func _find_group(value: Variant) -> int:
	for index in Tools.GROUPS.size():
		if _matches(value, index, Tools.GROUPS[index].name, Tools.GROUPS[index].id):
			return index

	return -1


static func _matches(value: Variant, index: int, name: String, id: String) -> bool:
	if is_number(value):
		return int(value) == index

	return value is String and (str(value).to_lower() == name.to_lower() or str(value).to_lower() == id)


func _tools_apply(arguments: Array) -> Variant:
	if not need_city():
		return null

	var start := point(arguments, 0)
	var finish := point(arguments, 1) if arguments.size() > 1 else start

	for tile: Vector2i in [start, finish]:
		if not inside_map(tile):
			return fail("The tile %d, %d is outside the map." % [tile.x, tile.y])

	var state := ToolEditState.normal(app.document_state.city, app.view_state.overlay_mode, app.tool_state.selected_group,
		app.tool_state.selected_subtool)
	var path := selection_path(state.selection, start, finish)

	return app.city_edits.apply_map_selection(start, finish, path, start != finish)


func _tools_undo(_arguments: Array) -> Variant:
	if not need_city():
		return null

	if app.tool_state.last_edit_command == null:
		return false

	app.city_edits.undo_last_edit()

	return true


func _view_center(_arguments: Array) -> Variant:
	if app.map_view == null:
		return null

	var center := app.map_view.center_tile()

	return {"x": center.x, "y": center.y}


func _view_center_on(arguments: Array) -> Variant:
	if not need_city():
		return null

	return app.map_view.center_on_tile(point(arguments, 0))


func _view_zoom(_arguments: Array, closer: bool) -> Variant:
	if app.map_view == null:
		return null

	if closer:
		app.map_view.zoom_in()
	else:
		app.map_view.zoom_out()

	app.camera_input.update_zoom_controls(app.map_view.zoom_percent())

	return app.map_view.zoom_percent()


# turns the map a quarter turn, clockwise unless the argument is false
func _view_rotate(arguments: Array) -> Variant:
	if not need_city():
		return null

	app.camera_input.rotate_city(not bool(argument(arguments, 0, true)))

	return app.document_state.city.compass_rotation()


func _view_set_mode(arguments: Array) -> Variant:
	if not need_city():
		return null

	var mode := CityViewMode.from_key(str(arguments[0]) if not arguments.is_empty() else "")

	if mode == CityViewMode.Mode.NONE:
		return fail("The view mode must be one of: %s." % ", ".join(CityViewMode.KEYS))

	app.menus.set_overlay(mode)

	return CityViewMode.key(app.view_state.overlay_mode)


# a tile point from a script argument { x, y }
