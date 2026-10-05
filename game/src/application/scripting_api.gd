class_name ApplicationScriptingApi
extends RefCounted
## The game functions that scripts call through `__runtime.host(name, ...)`.
## game/assets/scripting/api.js wraps them as the `game`, `city`, `sim`,
## `tools` and `view` objects. A function that fails calls `_fail`: the
## script then gets an Error with the message. See docs/scripting.md.

const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")

var app: CityApplication
# the message of the last failed call. ApplicationScripting throws it in the script
var failure := ""


func _init(application: CityApplication) -> void:
	app = application


func handlers() -> Dictionary[String, Callable]:
	return {
		"game.version": _game_version,
		"game.events": func(_arguments: Array) -> Variant: return ApplicationScripting.EVENTS,
		"game.status": _game_status,
		"city.loaded": func(_arguments: Array) -> Variant: return app.document_state.city != null,
		"city.info": _city_info,
		"city.setFunds": _city_set_funds,
		"city.addFunds": _city_add_funds,
		"city.tile": _city_tile,
		"sim.speed": _sim_speed,
		"sim.setSpeed": _sim_set_speed,
		"sim.resume": _sim_resume,
		"sim.step": _sim_step,
		"sim.disaster": _sim_disaster,
		"sim.disasters": _sim_disasters,
		"sim.startDisaster": _sim_start_disaster,
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
	}


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


func _fail(message: String) -> Variant:
	failure = message

	return null


func _need_city() -> bool:
	if app.document_state.city == null or app.simulation_state.simulation_engine == null:
		_fail("No city is loaded.")

		return false

	return true


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


func _city_info(_arguments: Array) -> Variant:
	if not _need_city():
		return null

	var city := app.document_state.city
	var demand := city.rci_demand()

	return {
		"name": city.city_name(),
		"mayor": city.mayor_name(),
		"size": city.map_size,
		"funds": city.funds(),
		"population": city.population(),
		"foundingYear": city.founding_year(),
		"difficulty": city.difficulty(),
		"scenario": app.simulation_state.simulation_engine.scenario != null,
		"path": app.document_state.current_save_path,
		"date": {"year": city.current_year(), "month": city.current_month(), "day": city.current_day(), "age": city.age_in_days()},
		"demand": {"residential": demand.x, "commercial": demand.y, "industrial": demand.z},
	}


func _city_set_funds(arguments: Array) -> Variant:
	if not _need_city():
		return null

	if arguments.is_empty() or typeof(arguments[0]) not in [TYPE_INT, TYPE_FLOAT]:
		return _fail("Funds must be a number.")

	var result := app.debug.debug_set_funds(int(arguments[0]))

	return app.document_state.city.funds() if result.ok else _fail(result.message)


func _city_add_funds(arguments: Array) -> Variant:
	if not _need_city():
		return null

	if arguments.is_empty() or typeof(arguments[0]) not in [TYPE_INT, TYPE_FLOAT]:
		return _fail("The amount must be a number.")

	var total := clampi(app.document_state.city.funds() + int(arguments[0]), CityDebugActions.MIN_FUNDS, CityDebugActions.MAX_FUNDS)

	return _city_set_funds([total])


func _city_tile(arguments: Array) -> Variant:
	if not _need_city():
		return null

	var point := _point(arguments, 0)
	var city := app.document_state.city

	if point.x < 0 or point.y < 0 or point.x >= city.map_size or point.y >= city.map_size:
		return null

	return {
		"x": point.x,
		"y": point.y,
		"altitude": city.land_altitude(point.x, point.y),
		"waterAltitude": city.water_altitude(point.x, point.y),
		"terrain": city.terrain_id(point.x, point.y),
		"building": city.building_id(point.x, point.y),
		"zone": city.zone_id(point.x, point.y),
		"underground": city.underground_id(point.x, point.y),
		"overlay": city.text_overlay_id(point.x, point.y),
		"water": city.is_water(point.x, point.y),
		"saltWater": city.is_salt_water(point.x, point.y),
		"powered": city.is_powered(point.x, point.y),
		"powerable": city.is_powerable(point.x, point.y),
		"watered": city.is_watered(point.x, point.y),
		"piped": city.is_piped(point.x, point.y),
		"traffic": city.traffic_density(point.x, point.y),
	}


func _sim_speed(_arguments: Array) -> Variant:
	var controller := app.simulation_state.speed_controller

	return controller.speed_name() if controller != null else GameSpeed.SPEED_NAMES[GameSpeed.Speed.PAUSED]


func _sim_set_speed(arguments: Array) -> Variant:
	if not _need_city():
		return null

	var value: Variant = arguments[0] if not arguments.is_empty() else null
	var speed := -1

	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		speed = int(value)
	elif value is String:
		for id: int in GameSpeed.SPEED_NAMES:
			if GameSpeed.SPEED_NAMES[id].to_lower() == str(value).to_lower():
				speed = id

	if not GameSpeed.SPEED_NAMES.has(speed):
		return _fail("The speed must be one of: %s." % ", ".join(GameSpeed.SPEED_NAMES.values()))

	app.frame.select_speed(speed)

	return app.simulation_state.speed_controller.speed_name()


func _sim_resume(_arguments: Array) -> Variant:
	if not _need_city():
		return null

	var speed := app.simulation_state.resume_speed

	return _sim_set_speed([speed if speed > GameSpeed.Speed.PAUSED else GameSpeed.Speed.TURTLE])


func _sim_step(_arguments: Array) -> Variant:
	if not _need_city():
		return null

	var report := app.debug_tools.steps.step_day()

	return report if report.begins_with("Day ran") else _fail(report)


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
	if not _need_city():
		return null

	var value: Variant = arguments[0] if not arguments.is_empty() else null
	var disaster := -1

	for item: Array in CityMenuBar.DISASTER_ITEMS:
		if (value is String and str(item[0]).to_lower() == str(value).to_lower()) or (typeof(value) in [TYPE_INT, TYPE_FLOAT]
				and int(value) == int(item[1])):
			disaster = int(item[1])

	if disaster < 0:
		return _fail("Unknown disaster: %s. sim.disasters lists them." % str(value))

	var has_point := arguments.size() > 1 and arguments[1] is Dictionary
	var point := _point(arguments, 1) if has_point else app.map_view.center_tile()
	var report := app.reports.start_disaster_at(disaster, point)

	return {"id": disaster, "name": report.name} if report.ok else _fail("The disaster could not start: %s." % report.error)


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
	if not _need_city():
		return null

	var choice := _find_tool(arguments[0] if not arguments.is_empty() else null, arguments[1] if arguments.size() > 1 else null)

	if choice.x < 0:
		return _fail("Unknown tool. tools.list() lists the groups and tools.")

	app.current_tool.select_tool_group(choice.x)

	if app.tool_state.selected_group == choice.x:
		app.current_tool.select_subtool(choice.y)

	if app.tool_state.selected_group != choice.x or app.tool_state.selected_subtool != choice.y:
		return _fail("%s cannot be selected now." % Tools.tool(choice.x, choice.y).name)

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
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return int(value) == index

	return value is String and (str(value).to_lower() == name.to_lower() or str(value).to_lower() == id)


func _tools_apply(arguments: Array) -> Variant:
	if not _need_city():
		return null

	var start := _point(arguments, 0)
	var finish := _point(arguments, 1) if arguments.size() > 1 else start
	var map_size := app.document_state.city.map_size

	for point in [start, finish]:
		if point.x < 0 or point.y < 0 or point.x >= map_size or point.y >= map_size:
			return _fail("The tile %d, %d is outside the map." % [point.x, point.y])

	var state := ToolEditState.normal(app.document_state.city, app.view_state.overlay_mode, app.tool_state.selected_group,
		app.tool_state.selected_subtool)
	var path := selection_path(state.selection, start, finish)

	return app.city_edits.apply_map_selection(start, finish, path, start != finish)


func _tools_undo(_arguments: Array) -> Variant:
	if not _need_city():
		return null

	if app.tool_state.last_edit_command == null:
		return false

	app.city_edits.undo_last_edit()

	return true


func _view_center(_arguments: Array) -> Variant:
	if app.map_view == null:
		return null

	var point := app.map_view.center_tile()

	return {"x": point.x, "y": point.y}


func _view_center_on(arguments: Array) -> Variant:
	if not _need_city():
		return null

	return app.map_view.center_on_tile(_point(arguments, 0))


func _view_set_mode(arguments: Array) -> Variant:
	if not _need_city():
		return null

	var mode := CityViewMode.from_key(str(arguments[0]) if not arguments.is_empty() else "")

	if mode == CityViewMode.Mode.NONE:
		return _fail("The view mode must be one of: %s." % ", ".join(CityViewMode.KEYS))

	app.menus.set_overlay(mode)

	return CityViewMode.key(app.view_state.overlay_mode)


# a tile point from a script argument { x, y }
static func _point(arguments: Array, index: int) -> Vector2i:
	if index >= arguments.size() or not arguments[index] is Dictionary:
		return Vector2i(-1, -1)

	var value: Dictionary = arguments[index]

	return Vector2i(_integer(value.get("x"), -1), _integer(value.get("y"), -1))


static func _integer(value: Variant, fallback: int) -> int:
	return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fallback
