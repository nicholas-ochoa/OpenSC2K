class_name ApplicationQueryChoices
extends RefCounted


const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
const Signs = preload("res://src/tools/city/sign_command.gd")
const Queries = preload("res://src/tools/city/query_info.gd")
const QueryFacilityActions = preload("res://src/tools/city/query_actions.gd")
const LibraryRuminateWindowsView = preload("res://src/ui/city_windows/library_ruminate_windows.gd")
const Buildings = preload("res://src/tools/city/building_command.gd")
const Music = preload("res://src/audio/music_director.gd")

var app: CityApplication
var text_resources: OriginalTextResources


func _init(application: CityApplication) -> void:
	app = application
	text_resources = application.original_text_resources


func _open_tool_choice_dialog(group_index: int) -> void:
	if app.city == null or (group_index != 3 and group_index != 5):
		return

	var first_subtool := 2 if group_index == 3 else 5
	var final_subtool := 10 if group_index == 3 else 8
	var choices: Array[int] = []

	for subtool_index in range(first_subtool, final_subtool + 1):
		if ToolAvailability.is_available(app.city, group_index, subtool_index):
			choices.append(subtool_index)

	if choices.is_empty():
		app.interface._show_error("No building type is available for this chooser.")

		return

	app.pending_tool_choices = {
		"group_index": group_index,
		"subtools": choices,
	}
	var title_text := (
		"Select Power Plant" if group_index == 3 else "Select Arcology"
	)
	var prompt_text := (
		"Select an available power plant."
		if group_index == 3
		else "Select an available arcology."
	)
	var available_tools: Array[Dictionary] = []

	for subtool_index in choices:
		available_tools.append(Tools.tool(group_index, subtool_index))

	app.tool_choice_dialog.show_tools(title_text, prompt_text, available_tools)


func _choose_tool_variant(choice_index: int) -> void:
	if app.pending_tool_choices.is_empty():
		return

	var choices: Array = app.pending_tool_choices.get("subtools", [])

	if choice_index < 0 or choice_index >= choices.size():
		return

	app.selected_group = int(app.pending_tool_choices.group_index)
	app.selected_subtool = int(choices[choice_index])
	app.pending_tool_choices.clear()
	app.tool_choice_dialog.hide()
	app.current_tool._update_edit_state()


func _cancel_tool_choice() -> void:
	app.pending_tool_choices.clear()
	app.current_tool._update_edit_state()


func _open_stadium_dialog(command: Dictionary) -> void:
	var choices := Buildings.stadium_team_choices(app.city)

	if choices.is_empty():
		app.interface._show_error("Cannot read the available stadium teams.")

		return

	app.pending_stadium_command = command.duplicate(true)
	var teams: Array[Dictionary] = []

	for team_index in choices:
		teams.append({
			"id": team_index,
			"name": Buildings.stadium_team_name(app.city, team_index),
		})

	app.stadium_dialog.show_teams(teams)


func _confirm_stadium_team() -> void:
	if app.pending_stadium_command.is_empty():
		return

	var team_index := app.stadium_dialog.selected_team_id()

	if team_index < 0:
		app.interface._show_error("Select a stadium team.")
		call_deferred("_restore_stadium_dialog")

		return

	var result := Buildings.assign_stadium_team(
		app.city,
		app.pending_stadium_command,
		team_index,
		app.stadium_dialog.entered_name(),
	)

	if not result.ok:
		app.interface._show_error("Cannot assign stadium team: %s" % result.error)
		call_deferred("_restore_stadium_dialog")

		return

	app.last_edit_command = result.command
	app.pending_stadium_command.clear()
	app.interface._refresh_details()
	app.effects_audio._play_tool_success_sound(14, 3)

	if app.city.music_enabled():
		app.effects_audio._play_music_track(Music.RECREATION_TRACK)

	app.status_label.theme_type_variation = ""
	app.status_label.text = "Assigned %s to the new stadium." % result.team_name


func _cancel_stadium_team() -> void:
	app.pending_stadium_command.clear()
	app.effects_audio._play_tool_success_sound(14, 3)

	if app.city != null and app.city.music_enabled():
		app.effects_audio._play_music_track(Music.RECREATION_TRACK)

	app.status_label.theme_type_variation = ""
	app.status_label.text = "The stadium was built without a team."


func _restore_stadium_dialog() -> void:
	if not app.pending_stadium_command.is_empty():
		app.stadium_dialog.popup_centered()


func _open_sign_dialog(point: Vector2i) -> void:
	var overlay := app.city.text_overlay_id(point.x, point.y)

	if overlay != 0 and not OverlayData.is_sign(overlay):
		app.interface._show_error("This tile has a protected simulation label.")

		return

	app.pending_sign_tile = point
	app.sign_dialog.show_text(app.city.label(overlay) if overlay > 0 else "")


func _commit_sign() -> void:
	if app.city == null or app.pending_sign_tile.x < 0:
		return

	var result := Signs.set_sign(app.city, app.pending_sign_tile, app.sign_dialog.entered_text())
	app.pending_sign_tile = Vector2i(-1, -1)

	if not result.ok:
		app.interface._show_error("Cannot change sign: %s" % result.error)

		return

	app.last_edit_command = result
	app.static_render._refresh_after_city_edit(result)
	app.status_label.theme_type_variation = ""
	app.status_label.text = "Sign removed." if result.new_overlay == 0 else "Sign saved as label %d." % result.label_id


func _cancel_sign() -> void:
	app.pending_sign_tile = Vector2i(-1, -1)


func _open_query(point: Vector2i) -> void:
	var result := Queries.inspect(app.city, point, text_resources.original_query_strings)

	if not result.ok:
		app.interface._show_error("Cannot query tile: %s" % result.error)

		return

	if result.get("overlay_id", 0) == 111 and app.simulation_engine != null:
		var approval := app.simulation_engine.recalculate_mayor_house()

		if not approval.get("ok", false):
			app.interface._show_error("Cannot calculate mayor approval: %s" % approval.error)

			return

		app.reports._show_news_items(approval.news_items)
		result = Queries.inspect(app.city, point, text_resources.original_query_strings)

	if (
		result.get("kind", "") == "general"
		and app.active_scurk_tile_set != null
		and app.active_scurk_tile_set.names.has(int(result.get("tile_id", -1)))
	):
		result.title = app.active_scurk_tile_set.names[int(result.tile_id)]

	app.active_query_result = result
	var is_specific: bool = result.kind == "specific"
	var action := str(result.get("action", ""))
	var action_text := ""

	if not action.is_empty():
		var action_resource_id := int(result.get("action_resource_id", -1))
		var fallback := "Analyze" if action == "city_analysis" else "Ruminate"
		action_text = str(text_resources.original_query_strings.get(action_resource_id, fallback))

	var neighborhood := QueryNeighborhood.render(app.city, point, app.palette_index_encoding, app.large_sprites)
	app.query_dialog.show_query(
		str(result.title),
		str(result.title) if is_specific else "",
		is_specific,
		Queries.format_text(result),
		action_text,
		result,
		ImageTexture.create_from_image(neighborhood) if neighborhood != null else null,
		app.palette,
		app.palette_cycle_ticks,
	)
	app.effects_audio._play_sound_events(result.get("sound_events", []))


func _close_query(commit_rename := false) -> bool:
	if app.query_dialog == null or not app.query_dialog.visible:
		return true

	if (
		commit_rename
		and app.query_dialog.rename_is_enabled()
		and app.active_query_result.get("kind", "") == "specific"
	):
		var renamed := QueryFacilityActions.rename_facility(
			app.city, app.active_query_result, app.query_dialog.facility_name()
		)

		if not renamed.ok:
			app.interface._show_error("Cannot rename facility: %s" % renamed.error)

			return false

		app.active_query_result["title"] = renamed.new_value

	app.query_dialog.close_query()

	return true


func _run_query_action() -> void:
	if app.city == null:
		return

	if not _close_query(true):
		return

	match str(app.active_query_result.get("action", "")):
		"city_analysis":
			var analysis := QueryFacilityActions.city_analysis(
				app.city, text_resources.original_query_strings
			)

			if not analysis.ok:
				app.interface._show_error("Cannot analyze city: %s" % analysis.error)

				return

			app.city_analysis_dialog.show_categories(analysis.categories)
		"library_ruminate":
			if (
				text_resources.library_texts.size()
				!= LibraryRuminateWindowsView.TEXT_RESOURCE_IDS.size()
			):
				app.interface._show_error("The Library text resources are missing or invalid.")

				return

			app.library_ruminate_windows.show_texts(
				text_resources.library_texts, Vector2i(app.get_viewport_rect().size)
			)
