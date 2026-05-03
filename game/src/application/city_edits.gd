class_name ApplicationCityEdits
extends RefCounted


const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
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


func _apply_map_selection(
	start: Vector2i,
	finish: Vector2i,
	path: Array[Vector2i],
	dragged: bool
) -> void:
	if app.city == null:
		return

	if app.landscape_editor and (app.selected_group not in [0, 1, 16, 17] or (app.selected_group == 0 and app.selected_subtool == 4)):
		app.interface._show_error("Select Start City before building structures.")

		return

	var scurk_tool_mode := app.scurk_workspace._scurk_edit_tool_active()
	var scurk_tool := (
		app.scurk_place_print.selected_edit_tool() if scurk_tool_mode else {}
	)

	if app.scurk_place_print != null and app.scurk_place_print.visible:
		if app.scurk_place_print.is_object_mode():
			app.scurk_workspace._apply_scurk_place_selection(finish)

			return

		if scurk_tool.is_empty():
			return

		app.selected_group = int(scurk_tool.group)
		app.selected_subtool = int(scurk_tool.subtool)

	if not scurk_tool_mode and not app.landscape_editor and not ToolAvailability.is_available(
		app.city, app.selected_group, app.selected_subtool
	):
		app.interface._show_error(
			"%s is not available in this city."
			% Tools.tool(app.selected_group, app.selected_subtool).name
		)

		return

	if app.selected_group == 17:
		app.camera_input._center_map_on_tile(finish)

		return

	if app.selected_group == 16:
		if app.selected_subtool == 1:
			app.map_view.show_trip_reach(app.city, finish)
		elif app.selected_subtool == 2:
			var result := app.map_view.show_service_query(app.city, finish, app.map_view._shift_pressed)
			if not result.ok:
				app.interface._show_error(str(result.error))
		else:
			app.query_choices._open_query(finish)

		return

	if app.selected_group == 15:
		app.query_choices._open_sign_dialog(finish)

		return

	if Dispatch.supports_tool(app.selected_group, app.selected_subtool):
		var cycles_before := app.dispatch_cycles.duplicate()
		var initialized_before := app.dispatch_initialized
		var dispatch := Dispatch.apply(
			app.city,
			app.selected_group,
			app.selected_subtool,
			finish,
			app.dispatch_cycles[app.selected_subtool],
			not app.dispatch_initialized
		)

		if not dispatch.ok:
			app.interface._show_error("Cannot dispatch unit: %s" % dispatch.error)

			return

		dispatch["dispatch_cycles_before"] = cycles_before
		dispatch["dispatch_initialized_before"] = initialized_before
		app.dispatch_initialized = true
		app.dispatch_cycles[app.selected_subtool] = int(dispatch.slot_index)
		dispatch["dispatch_cycles_after"] = app.dispatch_cycles.duplicate()
		app.last_edit_command = dispatch
		app.static_render._refresh_after_city_edit(dispatch)
		app.effects_audio._play_tool_success_sound(app.selected_group, app.selected_subtool)
		app.status_label.theme_type_variation = ""
		app.status_label.text = "Deployed %s unit %d of %d." % [
			Tools.tool(app.selected_group, app.selected_subtool).name,
			dispatch.slot_index,
			dispatch.available,
		]

		return

	if LandscapeEditorCommand.supports_tool(app.selected_group, app.selected_subtool) and app.landscape_editor and not (app.selected_group == 1 and app.selected_subtool == 3):
		var levels := app.map_view.stretch_height_delta if dragged else 1

		if app.terrain_stretch.active:
			app.camera_input._refresh_terrain_stretch(levels)
			var committed := app.terrain_stretch.finish()

			if not committed.is_empty():
				app.effects_audio._stop_tool_loop_sound()
				app.effects_audio._play_sound_events([ToolSounds.SOUND_TRACTOR])
				app.scurk_workspace._record_edit_command(committed)
				app.interface._refresh_details()

			app.status_label.text = "Stretch Terrain applied for $0."

			return

		var command := LandscapeEditorCommand.apply(app.city, app.selected_group, app.selected_subtool, start, app.tool_random, levels)
		_finish_simple_edit(SimpleEdits._result("terrain", command, app.selected_group, app.selected_subtool, true), false, {})

		return

	if app.map_view.landscape_brush and app.selected_group == 0:
		var origin := app.map_view.selection_start if app.map_view.selection_start.x >= 0 else start
		var target := app.level_brush_altitude if app.level_brush_altitude >= 0 else app.city.land_altitude(origin.x, origin.y)
		var command := TerrainTools.apply_path(app.city, app.selected_group, app.selected_subtool,
			origin, path, app.tool_random, app.landscape_editor, target)
		if command.ok or command.get("error", "") != "no terrain height changed":
			_finish_simple_edit(SimpleEdits._result("terrain", command, app.selected_group, app.selected_subtool, app.landscape_editor), false, {})
		return

	if app.map_view.landscape_brush:
		var command := LandscapeCommand.apply_path(app.city, app.selected_group, app.selected_subtool,
			path, app.tool_random, app.landscape_editor, true)
		if command.ok or command.get("error", "") != "no eligible tiles changed":
			_finish_simple_edit(SimpleEdits._result("landscape", command, app.selected_group, app.selected_subtool, app.landscape_editor), false, {})
		return

	var simple_edit := SimpleEdits.apply_supported(
		app.city,
		app.selected_group,
		app.selected_subtool,
		start,
		finish,
		path,
		app.tool_random,
		app.overlay_mode == "underground",
		scurk_tool_mode or app.landscape_editor
	)

	if simple_edit.handled:
		if app.map_view.demolish_brush and simple_edit.command.get("error", "") == "no eligible tiles changed":
			return
		_finish_simple_edit(simple_edit, scurk_tool_mode, scurk_tool)

		return

	if Networks.supports_tool(app.selected_group, app.selected_subtool):
		app.network_edits._apply_network_selection(
			start,
			finish,
			Networks.BRIDGE_UNSELECTED,
			app.selected_group,
			app.selected_subtool,
			Networks.CONNECTION_UNSELECTED,
			scurk_tool_mode
		)

		return

	if Tunnels.supports_tool(app.selected_group, app.selected_subtool):
		app.route_edits._apply_tunnel_selection(finish, Tunnels.CONFIRMATION_UNSELECTED, scurk_tool_mode)

		return

	if Highways.supports_tool(app.selected_group, app.selected_subtool):
		app.route_edits._apply_highway_selection(
			start,
			finish,
			Highways.CONNECTION_UNSELECTED,
			Highways.BRIDGE_UNSELECTED,
			scurk_tool_mode
		)

		return

	if Buildings.supports_tool(app.selected_group, app.selected_subtool):
		var building_group := app.selected_group
		var building_subtool := app.selected_subtool
		var building_name: String = Tools.tool(
			building_group, building_subtool
		).name
		var building := Buildings.apply(
			app.city,
			building_group,
			building_subtool,
			finish,
			app.simulation_engine.lfsr_random,
			app.tool_random
		)

		if not building.ok:
			# A failed placement can still advance the LFSR. Clear undo in that case.
			if building.get("lfsr_advanced", false):
				app.last_edit_command = {}

			if building.get("resident_objection", false):
				app.effects_audio._play_sound_events(building.get("sound_events", []))
				app.pending_building_objection_group = building_group
				app.pending_building_objection_subtool = building_subtool
				app.reports._show_building_objection()
				app.status_label.theme_type_variation = ""
				app.status_label.text = "%s placement was rejected by nearby residents." % building_name

				return

			app.interface._show_error(
				"Cannot build %s: %s"
				% [building_name, building.error]
			)
			app.effects_audio._play_tool_failure_sound(
				building_group, building_subtool, str(building.error), scurk_tool_mode
			)

			return

		app.last_edit_command = building
		var stadium_team_pending := bool(
			building.get("stadium_team_selection_required", false)
		)

		if not stadium_team_pending:
			app.effects_audio._play_tool_success_sound(building_group, building_subtool, scurk_tool_mode)

		app.interface._refresh_details()
		app.static_render._refresh_after_city_edit(building)

		if building_group == 5 and building_subtool < 4:
			app.camera_input._choose_tool_group(17)

		if building_group == 14 and app.city.music_enabled() and not stadium_team_pending:
			app.effects_audio._play_music_track(Music.RECREATION_TRACK)

		app.status_label.theme_type_variation = ""
		app.status_label.text = "Built %s for $%s." % [
			building_name,
			app.interface._format_number(building.cost),
		]

		if stadium_team_pending:
			app.query_choices._open_stadium_dialog(building)
			app.status_label.text += " Select a stadium team."

		return

	var zone_edit := SimpleEdits.apply_zone(
		app.city,
		app.selected_group,
		app.selected_subtool,
		start,
		finish,
		dragged,
		scurk_tool_mode,
		int(scurk_tool.get("zone", -1))
	)
	_finish_simple_edit(zone_edit, scurk_tool_mode, scurk_tool)


func _finish_simple_edit(
	edit: Dictionary, scurk_tool_mode: bool, scurk_tool: Dictionary
) -> void:
	var command: Dictionary = edit.command

	if not command.ok:
		if edit.play_failure_sound:
			app.effects_audio._play_tool_failure_sound(
				app.selected_group, app.selected_subtool, str(command.error), scurk_tool_mode
			)

		app.interface._show_error(str(edit.message))

		return

	if edit.record_command:
		app.scurk_workspace._record_edit_command(
			command, scurk_tool_mode, String(scurk_tool.get("name", ""))
		)
	else:
		app.last_edit_command = command

	if edit.refresh_details:
		app.interface._refresh_details()

	app.static_render._refresh_after_city_edit(command)

	if edit.show_effects:
		app.effects_audio._show_effect_events(
			command.get("effect_events", []), command.get("sound_events", [])
		)

	if app.selected_group == 0 and app.selected_subtool in [1, 2, 3, 5, 6, 7] and not command.get("changed_ids", []).is_empty():
		app.effects_audio._stop_tool_loop_sound()
		app.effects_audio._play_sound_events([ToolSounds.SOUND_TRACTOR])

	# keep the tree and news story, no modal protest notice
	if edit.refresh_news_summary:
		app.reports._refresh_saved_news_summary()

	if command.get("command_type", "") == "zone":
		app.effects_audio._play_sound_events(ToolSounds.zone_success_events(int(command.zone_type)))
	elif edit.play_success_sound:
		app.effects_audio._play_tool_success_sound(app.selected_group, app.selected_subtool, scurk_tool_mode)

	app.status_label.theme_type_variation = ""
	app.status_label.text = str(edit.message)


func _undo_last_edit() -> void:
	if app.city == null or app.last_edit_command.is_empty():
		return

	var undone_command := app.last_edit_command
	var command_type: String = app.last_edit_command.get("command_type", "")

	if app.last_edit_command.get("scurk_place_history", false):
		app.scurk_workspace._undo_scurk_place()

		return

	var undo_forest_protest := (
		command_type == "demolish"
		and int(app.last_edit_command.get("easter_events", 0)) > 0
	)
	var result: Dictionary

	if command_type == "sign":
		result = Signs.undo(app.city, app.last_edit_command)
	elif command_type == "landscape":
		result = Landscapes.undo(app.city, app.last_edit_command, app.tool_random)
	elif command_type == "building":
		result = Buildings.undo(
			app.city, app.last_edit_command, app.simulation_engine.lfsr_random, app.tool_random
		)
	elif command_type == "network":
		result = Networks.undo(app.city, app.last_edit_command)
	elif command_type == "hydro":
		result = Hydro.undo(app.city, app.last_edit_command, app.tool_random)
	elif command_type == "subway_to_rail":
		result = SubwayToRail.undo(app.city, app.last_edit_command)
	elif command_type == "onramp":
		result = Onramps.undo(app.city, app.last_edit_command)
	elif command_type == "tunnel":
		result = Tunnels.undo(app.city, app.last_edit_command)
	elif command_type == "highway":
		result = Highways.undo(app.city, app.last_edit_command)
	elif command_type == "demolish":
		result = Demolish.undo(app.city, app.last_edit_command, app.tool_random)
	elif command_type == "terrain":
		result = TerrainTools.undo(app.city, app.last_edit_command, app.tool_random)
	elif command_type == "dispatch":
		result = Dispatch.undo(app.city, app.last_edit_command)
	else:
		result = Zones.undo(app.city, app.last_edit_command)

	if not result.ok:
		app.interface._show_error("Cannot undo the last edit: %s" % result.error)

		return

	if command_type == "dispatch":
		app.dispatch_cycles = app.last_edit_command.get("dispatch_cycles_before", app.dispatch_cycles)
		app.dispatch_initialized = bool(
			app.last_edit_command.get("dispatch_initialized_before", app.dispatch_initialized)
		)

	app.last_edit_command = {}
	app.interface._refresh_details()
	app.static_render._refresh_after_city_edit(undone_command)

	if undo_forest_protest:
		app.reports._refresh_saved_news_summary()

	app.status_label.theme_type_variation = ""

	if command_type == "sign":
		app.status_label.text = "Restored the previous sign."
	elif command_type == "landscape":
		app.status_label.text = "Restored %d landscape actions and the previous funds value." % result.restored_tiles
	elif command_type == "building":
		app.status_label.text = "Removed the last building and restored %d tiles." % result.restored_tiles
	elif command_type == "network":
		app.status_label.text = "Restored the previous route across %d tiles." % result.restored_tiles
	elif command_type == "hydro":
		app.status_label.text = "Removed the last hydroelectric plant."
	elif command_type == "subway_to_rail":
		app.status_label.text = "Removed the last subway-to-rail connection."
	elif command_type == "onramp":
		app.status_label.text = "Removed the last on-ramp."
	elif command_type == "tunnel":
		app.status_label.text = "Removed the last tunnel."
	elif command_type == "highway":
		app.status_label.text = "Restored the previous highway route across %d tiles." % result.restored_tiles
	elif command_type == "demolish":
		app.status_label.text = "Restored %d demolished tiles and the previous funds value." % result.restored_tiles
	elif command_type == "terrain":
		app.status_label.text = "Restored %d terrain tiles and the previous funds value." % result.restored_tiles
	elif command_type == "dispatch":
		app.status_label.text = "Restored the previous dispatched unit."
	else:
		app.status_label.text = "Restored %d tiles and the previous funds value." % result.restored_tiles
