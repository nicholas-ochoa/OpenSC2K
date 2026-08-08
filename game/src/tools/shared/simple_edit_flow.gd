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
	var command: EditCommandResult

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
	command: EditCommandResult,
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
			command is DemolishEditResult and command.ok and (command as DemolishEditResult).easter_events > 0
		),
		"play_success_sound": kind in [
			"landscape", "hydro", "subway_to_rail", "onramp", "zone"
		],
		"play_failure_sound": kind in [
			"landscape", "hydro", "subway_to_rail", "onramp", "zone"
		],
	}

	if not command.ok:
		result["message"] = _failure_message(
			kind, tool_name, command.error if not command.error.is_empty() else "unknown error"
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
	kind: String, tool_name: String, command: EditCommandResult
) -> String:
	match kind:
		"landscape":
			var landscape := command as LandscapeEditResult
			var message := "%s changed %d path tiles for $%s." % [
				tool_name,
				landscape.tile_indices.size(),
				DisplayNumbers.format(landscape.cost),
			]

			if landscape.skipped_insufficient > 0:
				message += (
					" Funds were not sufficient for %d later path tiles."
					% landscape.skipped_insufficient
				)

			return message
		"demolish":
			var demolition := command as DemolishEditResult
			var message := "Applied %d demolition actions for $%s." % [
				demolition.action_count, DisplayNumbers.format(demolition.cost)
			]

			if demolition.skipped_specialized > 0:
				message += (
					" %d specialized structures were not changed."
					% demolition.skipped_specialized
				)

			if demolition.easter_events > 0:
				message += " A forest protest kept %d %s." % [
					demolition.easter_events,
					"tree" if demolition.easter_events == 1 else "trees",
				]

			return message
		"terrain":
			var terrain := command as TerrainEditResult
			var message := "%s applied %d actions for $%s." % [
				tool_name,
				terrain.action_count,
				DisplayNumbers.format(terrain.cost),
			]

			if terrain.skipped_conflicts > 0:
				message += (
					" %d structure conflicts were not changed."
					% terrain.skipped_conflicts
				)

			return message
		"hydro":
			return (
				"Built hydroelectric power for $%s."
				% DisplayNumbers.format(command.cost)
			)
		"subway_to_rail":
			return (
				"Built a subway-to-rail connection at no charge. "
				+ "Listed cost: $%s."
				% DisplayNumbers.format(command.listed_cost)
			)
		"onramp":
			return (
				"Built an on-ramp for $%s."
				% DisplayNumbers.format(command.cost)
			)
		_:
			return "%s changed %d tiles for $%s." % [
				tool_name,
				command.tile_indices.size(),
				DisplayNumbers.format(command.cost),
			]
