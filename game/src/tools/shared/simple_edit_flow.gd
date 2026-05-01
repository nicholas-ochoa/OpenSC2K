class_name SimpleEditFlow
extends RefCounted

const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const DisplayNumbers = preload("res://src/ui/shared/display_number_format.gd")
const Landscapes = preload("res://src/tools/landscape/landscape_command.gd")
const Demolish = preload("res://src/tools/city/demolish_command.gd")
const TerrainTools = preload("res://src/tools/landscape/terrain_command.gd")
const Hydro = preload("res://src/tools/city/hydro_command.gd")
const SubwayToRail = preload("res://src/tools/city/subway_to_rail_command.gd")
const Onramps = preload("res://src/tools/city/onramp_command.gd")
const Zones = preload("res://src/tools/city/zone_command.gd")


static func apply_supported(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	finish: Vector2i,
	path: Array[Vector2i],
	random: SimRandom,
	underground: bool,
	free_mode: bool
) -> Dictionary:
	var command: Dictionary

	if Landscapes.supports_tool(group_index, subtool_index):
		command = Landscapes.apply_path(
			city, group_index, subtool_index, path, random, free_mode
		)

		return _result("landscape", command, group_index, subtool_index, free_mode)

	if Demolish.supports_tool(group_index, subtool_index):
		command = Demolish.apply_path(
			city,
			group_index,
			subtool_index,
			path,
			random,
			underground,
			free_mode
		)

		return _result("demolish", command, group_index, subtool_index, free_mode)

	if TerrainTools.supports_tool(group_index, subtool_index):
		command = TerrainTools.apply_path(
			city, group_index, subtool_index, start, path, random, free_mode
		)

		return _result("terrain", command, group_index, subtool_index, free_mode)

	if Hydro.supports_tool(group_index, subtool_index):
		command = Hydro.apply(city, group_index, subtool_index, finish, random)

		return _result("hydro", command, group_index, subtool_index, free_mode)

	if SubwayToRail.supports_tool(group_index, subtool_index):
		command = SubwayToRail.apply(city, group_index, subtool_index, finish)

		return _result(
			"subway_to_rail", command, group_index, subtool_index, free_mode
		)

	if Onramps.supports_tool(group_index, subtool_index):
		command = Onramps.apply(
			city, group_index, subtool_index, finish, free_mode
		)

		return _result("onramp", command, group_index, subtool_index, free_mode)

	return {"handled": false}


static func apply_zone(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	finish: Vector2i,
	dragged: bool,
	free_mode: bool,
	zone_type: int
) -> Dictionary:
	var command := Zones.apply_rectangle(
		city,
		group_index,
		subtool_index,
		start,
		finish,
		dragged,
		free_mode,
		zone_type
	)

	return _result("zone", command, group_index, subtool_index, free_mode)


static func _result(
	kind: String,
	command: Dictionary,
	group_index: int,
	subtool_index: int,
	free_mode: bool
) -> Dictionary:
	var tool_name := String(Tools.tool(group_index, subtool_index).get("name", "Tool"))
	var result := {
		"handled": true,
		"command": command,
		"record_command": kind != "hydro",
		"refresh_details": kind != "subway_to_rail",
		"show_effects": kind == "terrain" or (kind == "demolish" and not free_mode),
		"refresh_news_summary": (
			kind == "demolish" and int(command.get("easter_events", 0)) > 0
		),
		"play_success_sound": kind in [
			"landscape", "hydro", "subway_to_rail", "onramp", "zone"
		],
		"play_failure_sound": kind in [
			"landscape", "hydro", "subway_to_rail", "onramp", "zone"
		],
	}

	if not bool(command.get("ok", false)):
		result["message"] = _failure_message(
			kind, tool_name, str(command.get("error", "unknown error"))
		)

		return result

	result["message"] = _success_message(kind, tool_name, command)

	return result


static func _failure_message(kind: String, tool_name: String, error: String) -> String:
	match kind:
		"demolish":
			return "Cannot demolish: %s" % error
		"terrain":
			return "Cannot change terrain: %s" % error
		"hydro":
			return "Cannot build hydroelectric power: %s" % error
		"subway_to_rail":
			return "Cannot build subway-to-rail connection: %s" % error
		"onramp":
			return "Cannot build on-ramp: %s" % error
		_:
			return "Cannot apply %s: %s" % [tool_name, error]


static func _success_message(
	kind: String, tool_name: String, command: Dictionary
) -> String:
	match kind:
		"landscape":
			var message := "%s changed %d path tiles for $%s." % [
				tool_name,
				command.tile_indices.size(),
				DisplayNumbers.format(int(command.cost)),
			]

			if command.skipped_insufficient > 0:
				message += (
					" Funds were not sufficient for %d later path tiles."
					% command.skipped_insufficient
				)

			return message
		"demolish":
			var message := "Applied %d demolition actions for $%s." % [
				command.action_count, DisplayNumbers.format(int(command.cost))
			]

			if command.skipped_specialized > 0:
				message += (
					" %d specialized structures were not changed."
					% command.skipped_specialized
				)

			if command.easter_events > 0:
				message += " A forest protest kept %d %s." % [
					command.easter_events,
					"tree" if command.easter_events == 1 else "trees",
				]

			return message
		"terrain":
			var message := "%s applied %d actions for $%s." % [
				tool_name,
				command.action_count,
				DisplayNumbers.format(int(command.cost)),
			]

			if command.skipped_conflicts > 0:
				message += (
					" %d structure conflicts were not changed."
					% command.skipped_conflicts
				)

			return message
		"hydro":
			return (
				"Built hydroelectric power for $%s."
				% DisplayNumbers.format(int(command.cost))
			)
		"subway_to_rail":
			return (
				"Built a subway-to-rail connection at no charge. "
				+ "Listed cost: $%s."
				% DisplayNumbers.format(int(command.listed_cost))
			)
		"onramp":
			return (
				"Built an on-ramp for $%s."
				% DisplayNumbers.format(int(command.cost))
			)
		_:
			return "%s changed %d tiles for $%s." % [
				tool_name,
				command.tile_indices.size(),
				DisplayNumbers.format(int(command.cost)),
			]
