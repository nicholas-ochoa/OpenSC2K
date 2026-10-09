class_name ApplicationCityEdits
extends RefCounted

const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const SimpleEdits = preload("res://src/tools/shared/simple_edit_flow.gd")
const Zones = preload("res://src/tools/city/zone_command.gd")
const Signs = preload("res://src/tools/city/sign_command.gd")
const Landscapes = preload("res://src/tools/landscape/landscape_command.gd")
const Buildings = preload("res://src/tools/city/building_command.gd")
const ToolSounds = preload("res://src/audio/tool_sound_rules.gd")
const Networks = preload("res://src/tools/city/network_command.gd")
const Hydro = preload("res://src/tools/city/hydro_command.gd")
const SubwayToRail = preload("res://src/tools/city/subway_to_rail_command.gd")
const Onramps = preload("res://src/tools/city/onramp_command.gd")
const Tunnels = preload("res://src/tools/city/tunnel_command.gd")
const Highways = preload("res://src/tools/city/highway_command.gd")
const Demolish = preload("res://src/tools/city/demolish_command.gd")
const TerrainTools = preload("res://src/tools/landscape/terrain_command.gd")
const Dispatch = preload("res://src/tools/city/dispatch_command.gd")
const Music = preload("res://src/audio/music_director.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


## Uses the selected tool on a map selection. A script can cancel it in the
## tool.beforeApply event. Returns the detail of the tool.applied event, or
## an empty Dictionary without a city.
func apply_map_selection(
	start: Vector2i,
	finish: Vector2i,
	path: Array[Vector2i],
	dragged: bool
) -> Dictionary:
	var city := app.document_state.city

	if city == null:
		return {}

	var detail := {
		"tool": ApplicationScriptingApi.tool_info(app.tool_state.selected_group, app.tool_state.selected_subtool),
		"start": start, "finish": finish, "dragged": dragged, "tiles": path.size(),
	}

	if app.scripting.cancelled("tool.beforeApply", detail):
		detail.merge({"changed": false, "cancelled": true, "command": "", "cost": 0, "message": "A script cancelled the tool."})
		app.status_label.theme_type_variation = ""
		app.status_label.text = detail.message

		return detail

	var command_before := app.tool_state.last_edit_command
	var funds_before := city.funds()
	_apply_selected_tool(start, finish, path, dragged)
	var command := app.tool_state.last_edit_command
	var changed := command != null and command != command_before
	detail.merge({
		"changed": changed, "cancelled": false, "command": command.command_type if changed else "",
		"cost": funds_before - city.funds() if app.document_state.city == city else 0,
		"message": app.status_label.text if app.status_label != null else "",
	})
	app.scripting.emit("tool.applied", detail)

	return detail


func _apply_selected_tool(
	start: Vector2i,
	finish: Vector2i,
	path: Array[Vector2i],
	dragged: bool
) -> void:
	var tool := app.tool_state

	if (tool.landscape_editor
			and (tool.selected_group not in [CityToolIds.Group.BULLDOZER, CityToolIds.Group.LANDSCAPE, CityToolIds.Group.QUERY,
			CityToolIds.Group.CENTERING]
			or (tool.selected_group == CityToolIds.Group.BULLDOZER and tool.selected_subtool == CityToolIds.Bulldozer.DEZONE))):
		app.interface.show_error("Select Start City before building structures.")
		return

	var scurk_tool_mode := app.scurk_workspace.scurk_edit_tool_active()
	var scurk_tool := (
		app.scurk_place_print.selected_edit_tool() if scurk_tool_mode else null
	)

	if not _select_scurk_tool(finish, scurk_tool):
		return

	if not scurk_tool_mode and not tool.landscape_editor and not ToolAvailability.is_available(
		app.document_state.city, tool.selected_group, tool.selected_subtool
	):
		app.interface.show_error(
			tr("%s is not available in this city.")
			% Tools.tool(tool.selected_group, tool.selected_subtool).name
		)

		return

	if _apply_view_tool(finish):
		return

	if _apply_dispatch_tool(finish):
		return

	if _apply_landscape_editor_terrain(start, dragged):
		return

	if _apply_landscape_brush(start, path, scurk_tool_mode, scurk_tool):
		return

	if _apply_simple_edit(start, finish, path, scurk_tool_mode, scurk_tool):
		return

	if _apply_route_tool(start, finish, scurk_tool_mode):
		return

	if _apply_building_tool(finish, scurk_tool_mode):
		return

	var zone_edit := SimpleEdits.apply_zone(
		app.document_state.city,
		tool.selected_group,
		tool.selected_subtool,
		start,
		finish,
		dragged,
		scurk_tool_mode,
		scurk_tool.zone if scurk_tool != null else -1
	)
	_finish_simple_edit(zone_edit, scurk_tool_mode, scurk_tool)


# the map menu bulldozes one tile as the Bulldozer tool does. the selected tool
# does not change. a tile with nothing to bulldoze is not reported
func bulldoze_tile(point: Vector2i) -> void:
	if app.document_state.city == null:
		return

	var tool := app.tool_state
	var group := tool.selected_group
	var subtool := tool.selected_subtool
	tool.selected_group = CityToolIds.Group.BULLDOZER
	tool.selected_subtool = CityToolIds.Bulldozer.DEMOLISH
	var path: Array[Vector2i] = [point]
	var simple_edit := SimpleEdits.apply_supported(
		app.document_state.city, tool.selected_group, tool.selected_subtool, point, point, path, tool.tool_random,
		app.view_state.overlay_mode == CityViewMode.Mode.UNDERGROUND, tool.landscape_editor
	)

	if simple_edit.handled and simple_edit.command.error != "no eligible tiles changed":
		_finish_simple_edit(simple_edit, false, null)

	tool.selected_group = group
	tool.selected_subtool = subtool


# while the scurk place-and-print window is open, place an object at finish or
# select the window's edit tool. returns false when the selection is handled
# or no edit tool is chosen
func _select_scurk_tool(finish: Vector2i, scurk_tool: ScurkEditTool) -> bool:
	if app.scurk_place_print == null or not app.scurk_place_print.visible:
		return true

	if app.scurk_place_print.is_object_mode():
		app.scurk_workspace.apply_scurk_place_selection(finish)
		return false

	if scurk_tool == null:
		return false

	app.tool_state.selected_group = int(scurk_tool.group)
	app.tool_state.selected_subtool = int(scurk_tool.subtool)

	return true


# center, query, and sign tools. these read the city or open a dialog
func _apply_view_tool(finish: Vector2i) -> bool:
	var tool := app.tool_state

	if tool.selected_group == CityToolIds.Group.CENTERING:
		if HelicopterShotCommand.apply(app.document_state.city, finish) >= 0:
			var sound_ids: Array[int] = [HelicopterShotCommand.SOUND_HIT]
			app.effects_audio.play_sound_ids(sound_ids)

		app.camera_input.center_map_on_tile(finish)

		return true

	if tool.selected_group == CityToolIds.Group.QUERY:
		if tool.selected_subtool == CityToolIds.Query.TRIP_REACH:
			app.map_view.show_trip_reach(app.document_state.city, finish)
		elif tool.selected_subtool == CityToolIds.Query.TILE_INSPECTOR:
			app.debug_tools.pin_inspector(finish)
		else:
			app.query_choices.open_query(finish)

		return true

	if tool.selected_group == CityToolIds.Group.SIGNS:
		app.query_choices.open_sign_dialog(finish)

		return true

	return false


func _apply_dispatch_tool(finish: Vector2i) -> bool:
	var tool := app.tool_state

	if not Dispatch.supports_tool(tool.selected_group, tool.selected_subtool):
		return false

	var engine := app.simulation_state.simulation_engine

	# a new disaster resets the slot cycles, as 0x0044f910 does
	if engine != null and engine.dispatch_epoch != tool.dispatch_epoch:
		tool.dispatch_cycles = PackedInt32Array([0, 0, 0])
		tool.dispatch_epoch = engine.dispatch_epoch

	var cycles_before := tool.dispatch_cycles.duplicate()
	var points_before := _copy_slot_points(tool.dispatch_slot_points)
	var dispatch := Dispatch.apply(
		app.document_state.city,
		tool.selected_group,
		tool.selected_subtool,
		finish,
		tool.dispatch_cycles[tool.selected_subtool],
		tool.dispatch_slot_points[tool.selected_subtool],
		engine.dispatch_capacity if engine != null else Dispatch.NO_CAPACITY
	)

	if not dispatch.ok:
		app.interface.show_error(tr("Cannot dispatch unit: %s") % dispatch.error)

		return true

	_record_dispatch(dispatch, cycles_before, points_before)

	return true


static func _copy_slot_points(points: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for slots in points:
		result.append(slots.duplicate())

	return result


# advance the unit cycle, keep the cycle state undo restores, and report the unit
func _record_dispatch(
	dispatch: DispatchEditResult, cycles_before: PackedInt32Array, points_before: Array[Dictionary]
) -> void:
	var tool := app.tool_state
	dispatch.dispatch_cycles_before = cycles_before
	dispatch.dispatch_slot_points_before = points_before

	tool.dispatch_cycles[tool.selected_subtool] = dispatch.slot_index
	tool.dispatch_slot_points[tool.selected_subtool][dispatch.slot_index] = dispatch.target

	dispatch.dispatch_cycles_after = tool.dispatch_cycles.duplicate()

	tool.last_edit_command = dispatch

	app.static_render.refresh_after_city_edit(dispatch)
	app.effects_audio.play_tool_success_sound(tool.selected_group, tool.selected_subtool)

	app.status_label.theme_type_variation = ""
	app.status_label.text = tr("Deployed %s unit %d of %d.") % [
		tr(Tools.tool(tool.selected_group, tool.selected_subtool).name),
		dispatch.slot_index,
		dispatch.available,
	]


# landscape-editor terrain tools, including a stretch drag in progress
func _apply_landscape_editor_terrain(start: Vector2i, dragged: bool) -> bool:
	var tool := app.tool_state

	if (not (LandscapeEditorCommand.supports_tool(tool.selected_group, tool.selected_subtool) and tool.landscape_editor
			and not (tool.selected_group == CityToolIds.Group.LANDSCAPE and tool.selected_subtool == CityToolIds.Landscape.FOREST))):
		return false

	var levels := app.map_view.stretch_height_delta if dragged else 1

	if tool.terrain_stretch.active:
		app.camera_input.refresh_terrain_stretch(levels)
		var committed := tool.terrain_stretch.finish()

		if committed != null:
			app.effects_audio.stop_tool_loop_sound()
			var sound_ids: Array[int] = [ToolSounds.SOUND_TRACTOR]
			app.effects_audio.play_sound_ids(sound_ids)
			app.scurk_workspace.record_edit_command(committed)
			app.interface.refresh_details()

		app.status_label.text = "Stretch Terrain applied for $0."

		return true

	var command := LandscapeEditorCommand.apply(
		app.document_state.city,
		tool.selected_group,
		tool.selected_subtool,
		start,
		tool.tool_random,
		levels,
	)
	_finish_simple_edit(SimpleEdits._result("terrain", command, tool.selected_group, tool.selected_subtool, true), false, null)

	return true


# terrain and landscape brushes along the dragged path. a brush pass that
# changes nothing is not reported. the landscape editor and Place & Print
# paint for free
func _apply_landscape_brush(
	start: Vector2i, path: Array[Vector2i], scurk_tool_mode: bool, scurk_tool: ScurkEditTool
) -> bool:
	if not app.map_view.landscape_brush:
		return false

	var tool := app.tool_state
	var free := tool.landscape_editor or scurk_tool_mode

	if tool.selected_group == CityToolIds.Group.BULLDOZER:
		var origin := app.map_view.selection_start if app.map_view.selection_start.x >= 0 else start
		var target := tool.level_brush_altitude if tool.level_brush_altitude >= 0 else app.document_state.city.land_altitude(
			origin.x,
			origin.y,
		)
		var terrain_command := TerrainTools.apply_path(app.document_state.city, tool.selected_group, tool.selected_subtool,
			origin, path, tool.tool_random, free, target)

		if terrain_command.ok or terrain_command.error != "no terrain height changed":
			_finish_simple_edit(
				SimpleEdits._result("terrain", terrain_command, tool.selected_group, tool.selected_subtool, free),
				scurk_tool_mode,
				scurk_tool,
			)

		return true

	var command := LandscapeCommand.apply_path(
		app.document_state.city,
		tool.selected_group,
		tool.selected_subtool,
		path,
		tool.tool_random,
		free,
		true,
	)

	if command.ok or command.error != "no eligible tiles changed":
		_finish_simple_edit(
			SimpleEdits._result("landscape", command, tool.selected_group, tool.selected_subtool, free),
			scurk_tool_mode,
			scurk_tool,
		)

	return true


# tools that simpleedits applies in one step, such as demolish and terrain
# a demolish brush pass that changes nothing is not reported
func _apply_simple_edit(
	start: Vector2i, finish: Vector2i, path: Array[Vector2i], scurk_tool_mode: bool, scurk_tool: ScurkEditTool
) -> bool:
	var simple_edit := SimpleEdits.apply_supported(
		app.document_state.city,
		app.tool_state.selected_group,
		app.tool_state.selected_subtool,
		start,
		finish,
		path,
		app.tool_state.tool_random,
		app.view_state.overlay_mode == CityViewMode.Mode.UNDERGROUND,
		scurk_tool_mode or app.tool_state.landscape_editor,
		app.effects_audio.effect_tile_window(),
		ApplicationEffectsAudio.EFFECT_TILE_LIMIT
	)

	if not simple_edit.handled:
		return false

	if app.map_view.demolish_brush and simple_edit.command.error == "no eligible tiles changed":
		return true

	_finish_simple_edit(simple_edit, scurk_tool_mode, scurk_tool)

	return true


# networks, tunnels, and highways. their workflows ask for bridge and
# connection choices before they apply
func _apply_route_tool(start: Vector2i, finish: Vector2i, scurk_tool_mode: bool) -> bool:
	var group := app.tool_state.selected_group
	var subtool := app.tool_state.selected_subtool

	if Networks.supports_tool(group, subtool):
		app.network_edits.apply_network_selection(
			start,
			finish,
			Networks.BRIDGE_UNSELECTED,
			group,
			subtool,
			Networks.CONNECTION_UNSELECTED,
			scurk_tool_mode
		)

		return true

	if Tunnels.supports_tool(group, subtool):
		app.route_edits.apply_tunnel_selection(finish, Tunnels.CONFIRMATION_UNSELECTED, scurk_tool_mode)

		return true

	if Highways.supports_tool(group, subtool):
		app.route_edits.apply_highway_selection(
			start,
			finish,
			Highways.CONNECTION_UNSELECTED,
			Highways.BRIDGE_UNSELECTED,
			scurk_tool_mode
		)

		return true

	return false


func _apply_building_tool(finish: Vector2i, scurk_tool_mode: bool) -> bool:
	var building_group := app.tool_state.selected_group
	var building_subtool := app.tool_state.selected_subtool

	if not Buildings.supports_tool(building_group, building_subtool):
		return false

	var building := Buildings.apply(
		app.document_state.city,
		building_group,
		building_subtool,
		finish,
		app.simulation_state.simulation_engine.lfsr_random,
		app.tool_state.tool_random
	)

	if building.ok:
		_record_building(building, building_group, building_subtool, scurk_tool_mode)
	else:
		_report_building_rejection(building, building_group, building_subtool, scurk_tool_mode)

	return true


# A failed placement can still advance the LFSR. Clear undo in that case.
func _report_building_rejection(
	building: BuildingEditResult, building_group: int, building_subtool: int, scurk_tool_mode: bool
) -> void:
	var building_name: String = Tools.tool(building_group, building_subtool).name

	if building.lfsr_advanced:
		app.tool_state.last_edit_command = null

	if building.resident_objection:
		app.effects_audio.play_sound_ids(building.sound_events)
		app.tool_state.pending_building_objection_group = building_group
		app.tool_state.pending_building_objection_subtool = building_subtool
		app.reports.show_building_objection()
		app.status_label.theme_type_variation = ""
		app.status_label.text = tr("%s placement was rejected by nearby residents.") % tr(building_name)

		return

	app.interface.show_error(
		tr("Cannot build %s: %s")
		% [tr(building_name), building.error]
	)
	app.effects_audio.play_tool_failure_sound(
		building_group, building_subtool, str(building.error), scurk_tool_mode
	)


# keep the placement for undo, refresh the view, and report the cost. a
# stadium then asks for its team
func _record_building(
	building: BuildingEditResult, building_group: int, building_subtool: int, scurk_tool_mode: bool
) -> void:
	var building_name: String = Tools.tool(building_group, building_subtool).name
	app.tool_state.last_edit_command = building
	_publish_utility_usage(building)
	var stadium_team_pending := building.stadium_team_selection_required

	if not stadium_team_pending:
		app.effects_audio.play_tool_success_sound(building_group, building_subtool, scurk_tool_mode)

	app.interface.refresh_details()
	app.static_render.refresh_after_city_edit(building)

	if building_group == CityToolIds.Group.REWARDS and building_subtool < CityToolIds.Rewards.ARCOLOGIES:
		app.camera_input.choose_tool_group(CityToolIds.Group.CENTERING)

	if building_group == CityToolIds.Group.RECREATION and app.document_state.city.music_enabled() and not stadium_team_pending:
		app.effects_audio.play_music_track(Music.RECREATION_TRACK)

	app.status_label.theme_type_variation = ""
	app.status_label.text = tr("Built %s for $%s.") % [
		tr(building_name),
		app.interface.format_number(building.cost),
	]

	if stadium_team_pending:
		app.query_choices.open_stadium_dialog(building)
		app.status_label.text += " Select a stadium team."


# a bought neighbor connection changes the engine connection count. undo passes -1
func change_neighbor_connections(command: EditCommandResult, delta: int) -> void:
	var engine := app.simulation_state.simulation_engine
	var route := command as RouteEditResult

	if engine != null and route != null and route.connection_built:
		engine.change_connection_count(route.connection_kind(), delta)


# an immediate utility scan after placement updates the engine utilization
func _publish_utility_usage(command: EditCommandResult) -> void:
	var engine := app.simulation_state.simulation_engine

	if engine == null:
		return

	command.power_usage_before = engine.power_usage_percent
	command.water_usage_before = engine.water_usage_percent

	if command.power_usage_percent >= 0:
		engine.power_usage_percent = command.power_usage_percent

	if command.water_usage_percent >= 0:
		engine.water_usage_percent = command.water_usage_percent


# undo restores the utility flags, so it also restores their utilization
func _restore_utility_usage(command: EditCommandResult) -> void:
	var engine := app.simulation_state.simulation_engine

	if engine == null:
		return

	if command.power_usage_percent >= 0:
		engine.power_usage_percent = command.power_usage_before

	if command.water_usage_percent >= 0:
		engine.water_usage_percent = command.water_usage_before


func _finish_simple_edit(
	edit: SimpleEditFlow.Result, scurk_tool_mode: bool, scurk_tool: ScurkEditTool
) -> void:
	var command: EditCommandResult = edit.command

	if not command.ok:
		if edit.play_failure_sound:
			app.effects_audio.play_tool_failure_sound(
				app.tool_state.selected_group, app.tool_state.selected_subtool, str(command.error), scurk_tool_mode
			)

		app.interface.show_error(str(edit.message))

		return

	_publish_utility_usage(command)

	if edit.record_command:
		app.scurk_workspace.record_edit_command(
			command, scurk_tool_mode, scurk_tool.name if scurk_tool != null else ""
		)
	else:
		app.tool_state.last_edit_command = command

	if edit.refresh_details:
		app.interface.refresh_details()

	app.static_render.refresh_after_city_edit(command)

	if edit.show_effects:
		app.effects_audio.show_effect_events(command.effect_events, SoundEvent.from_ids(command.sound_events))

	if (app.tool_state.selected_group == CityToolIds.Group.BULLDOZER
			and app.tool_state.selected_subtool in [CityToolIds.Bulldozer.LEVEL, CityToolIds.Bulldozer.RAISE, CityToolIds.Bulldozer.LOWER,
			CityToolIds.Bulldozer.STRETCH, CityToolIds.Bulldozer.RAISE_SEA, CityToolIds.Bulldozer.LOWER_SEA]
			and not command.changed_ids.is_empty()):
		app.effects_audio.stop_tool_loop_sound()
		var sound_ids: Array[int] = [ToolSounds.SOUND_TRACTOR]
		app.effects_audio.play_sound_ids(sound_ids)

	if command.command_type == "zone":
		app.effects_audio.play_sound_ids(ToolSounds.zone_success_events((command as ZoneEditResult).zone_type))
	elif edit.play_success_sound:
		app.effects_audio.play_tool_success_sound(app.tool_state.selected_group, app.tool_state.selected_subtool, scurk_tool_mode)

	app.status_label.theme_type_variation = ""
	app.status_label.text = str(edit.message)

	# the notice takes the mouse and ends the stroke, as in the original.
	# the stroke ends after the input event that placed the edit
	if command is DemolishEditResult and (command as DemolishEditResult).easter_events > 0:
		app.reports.show_forest_protest()
		app.map_view.end_held_selection.call_deferred()


func undo_last_edit() -> void:
	if app.document_state.city == null or app.tool_state.last_edit_command == null:
		return

	var command := app.tool_state.last_edit_command
	var command_type := command.command_type

	if command.scurk_place_history:
		app.scurk_workspace.undo_scurk_place()

		return

	var result: EditCommandResult

	if command_type == "sign":
		result = Signs.undo(app.document_state.city, command as SignEditResult)
	elif command_type == "landscape":
		result = Landscapes.undo(app.document_state.city, command as LandscapeEditResult, app.tool_state.tool_random)
	elif command_type == "building":
		result = Buildings.undo(
			app.document_state.city, command as BuildingEditResult, app.simulation_state.simulation_engine.lfsr_random,
			app.tool_state.tool_random
		)
	elif command_type == "network":
		result = Networks.undo(app.document_state.city, command as RouteEditResult)
	elif command_type == "hydro":
		result = Hydro.undo(app.document_state.city, command as HydroEditResult, app.tool_state.tool_random)
	elif command_type == "subway_to_rail":
		result = SubwayToRail.undo(app.document_state.city, command as SubwayToRailEditResult)
	elif command_type == "onramp":
		result = Onramps.undo(app.document_state.city, command as OnrampEditResult)
	elif command_type == "tunnel":
		result = Tunnels.undo(app.document_state.city, command as TunnelEditResult)
	elif command_type == "highway":
		result = Highways.undo(app.document_state.city, command as RouteEditResult)
	elif command_type == "demolish":
		result = Demolish.undo(app.document_state.city, command as DemolishEditResult, app.tool_state.tool_random)
	elif command_type == "terrain":
		result = TerrainTools.undo(app.document_state.city, command as TerrainEditResult, app.tool_state.tool_random)
	elif command_type == "dispatch":
		result = Dispatch.undo(app.document_state.city, command as DispatchEditResult)
	else:
		result = Zones.undo(app.document_state.city, command as ZoneEditResult)

	if not result.ok:
		app.interface.show_error(tr("Cannot undo the last edit: %s") % result.error)

		return

	if command is DispatchEditResult:
		var dispatch := command as DispatchEditResult
		app.tool_state.dispatch_cycles = dispatch.dispatch_cycles_before

		if not dispatch.dispatch_slot_points_before.is_empty():
			app.tool_state.dispatch_slot_points = dispatch.dispatch_slot_points_before

	app.tool_state.last_edit_command = null
	_restore_utility_usage(command)
	change_neighbor_connections(command, -1)
	app.interface.refresh_details()
	app.static_render.refresh_after_city_edit(command)

	app.status_label.theme_type_variation = ""

	if command_type == "sign":
		app.status_label.text = "Restored the previous sign."
	elif command_type == "landscape":
		app.status_label.text = tr("Restored %d landscape actions and the previous funds value.") % result.restored_tiles
	elif command_type == "building":
		app.status_label.text = tr("Removed the last building and restored %d tiles.") % result.restored_tiles
	elif command_type == "network":
		app.status_label.text = tr("Restored the previous route across %d tiles.") % result.restored_tiles
	elif command_type == "hydro":
		app.status_label.text = "Removed the last hydroelectric plant."
	elif command_type == "subway_to_rail":
		app.status_label.text = "Removed the last subway-to-rail connection."
	elif command_type == "onramp":
		app.status_label.text = "Removed the last on-ramp."
	elif command_type == "tunnel":
		app.status_label.text = "Removed the last tunnel."
	elif command_type == "highway":
		app.status_label.text = tr("Restored the previous highway route across %d tiles.") % result.restored_tiles
	elif command_type == "demolish":
		app.status_label.text = tr("Restored %d demolished tiles and the previous funds value.") % result.restored_tiles
	elif command_type == "terrain":
		app.status_label.text = tr("Restored %d terrain tiles and the previous funds value.") % result.restored_tiles
	elif command_type == "dispatch":
		app.status_label.text = "Restored the previous dispatched unit."
	else:
		app.status_label.text = tr("Restored %d tiles and the previous funds value.") % result.restored_tiles

	app.scripting.emit("tool.undone", {"command": command_type})
