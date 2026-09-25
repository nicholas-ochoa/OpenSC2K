class_name ApplicationQueryChoices
extends RefCounted


const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
const Signs = preload("res://src/tools/city/sign_command.gd")
const Queries = preload("res://src/tools/city/query_info.gd")
const QueryFacilityActions = preload("res://src/tools/city/query_actions.gd")
const LibraryRuminateWindowsView = preload("res://src/ui/city_windows/library_ruminate_windows.gd")
const Music = preload("res://src/audio/music_director.gd")

var app: CityApplication
var text_resources: OriginalTextResources


func _init(application: CityApplication) -> void:
	app = application
	text_resources = application.original_text_resources


func open_tool_choice_dialog(group_index: int) -> void:
	if app.document_state.city == null or (group_index != CityToolIds.Group.POWER and group_index != CityToolIds.Group.REWARDS):
		return

	var first_subtool: int = CityToolIds.Power.COAL if group_index == CityToolIds.Group.POWER else CityToolIds.Rewards.PLYMOUTH
	var final_subtool: int = CityToolIds.Power.FUSION if group_index == CityToolIds.Group.POWER else CityToolIds.Rewards.LAUNCH
	var choices: Array[int] = []

	for subtool_index in range(first_subtool, final_subtool + 1):
		if ToolAvailability.is_available(app.document_state.city, group_index, subtool_index):
			choices.append(subtool_index)

	if choices.is_empty():
		app.interface.show_error("No building type is available for this chooser.")

		return

	app.tool_state.pending_tool_choices = ToolState.ToolChoices.new(
		group_index, choices
	)
	var title_text := (
		"Select Power Plant" if group_index == CityToolIds.Group.POWER else "Select Arcology"
	)
	var prompt_text := (
		"Select an available power plant."
		if group_index == CityToolIds.Group.POWER
		else "Select an available arcology."
	)
	var available_tools: Array[ToolCatalog.Tool] = []

	for subtool_index in choices:
		available_tools.append(Tools.tool(group_index, subtool_index))

	app.city_dialogs.tool_choice_dialog.show_tools(title_text, prompt_text, available_tools)


func choose_tool_variant(choice_index: int) -> void:
	if app.tool_state.pending_tool_choices == null:
		return

	var choices := app.tool_state.pending_tool_choices.subtools

	if choice_index < 0 or choice_index >= choices.size():
		return

	app.tool_state.selected_group = int(app.tool_state.pending_tool_choices.group_index)
	app.tool_state.selected_subtool = int(choices[choice_index])
	app.tool_state.pending_tool_choices = null
	app.city_dialogs.tool_choice_dialog.hide()
	app.current_tool.update_edit_state()


func cancel_tool_choice() -> void:
	app.tool_state.pending_tool_choices = null
	app.current_tool.update_edit_state()


func open_stadium_dialog(command: BuildingEditResult) -> void:
	var choices := BuildingFacilities.stadium_team_choices(app.document_state.city)

	if choices.is_empty():
		app.interface.show_error("Cannot read the available stadium teams.")

		return

	app.tool_state.pending_stadium_command = command.copy() as BuildingEditResult
	var teams: Array[StadiumTeamDialog.Team] = []

	for team_index in choices:
		teams.append(StadiumTeamDialog.Team.new(
			team_index, BuildingFacilities.stadium_team_name(app.document_state.city, team_index)
		))

	app.city_dialogs.stadium_dialog.show_teams(teams)


func confirm_stadium_team() -> void:
	if app.tool_state.pending_stadium_command == null:
		return

	var team_index := app.city_dialogs.stadium_dialog.selected_team_id()

	if team_index < 0:
		app.interface.show_error("Select a stadium team.")
		call_deferred("_restore_stadium_dialog")

		return

	var result := BuildingFacilities.assign_stadium_team(
		app.document_state.city,
		app.tool_state.pending_stadium_command,
		team_index,
		app.city_dialogs.stadium_dialog.entered_name(),
	)

	if not result.ok:
		app.interface.show_error("Cannot assign stadium team: %s" % result.error)
		call_deferred("_restore_stadium_dialog")

		return

	app.tool_state.last_edit_command = result
	app.tool_state.pending_stadium_command = null
	app.interface.refresh_details()
	app.effects_audio.play_tool_success_sound(CityToolIds.Group.RECREATION, CityToolIds.Recreation.STADIUM)

	if app.document_state.city.music_enabled():
		app.effects_audio.play_music_track(Music.RECREATION_TRACK)

	app.status_label.theme_type_variation = ""
	app.status_label.text = "Assigned %s to the new stadium." % result.stadium_team_name


func cancel_stadium_team() -> void:
	app.tool_state.pending_stadium_command = null
	app.effects_audio.play_tool_success_sound(CityToolIds.Group.RECREATION, CityToolIds.Recreation.STADIUM)

	if app.document_state.city != null and app.document_state.city.music_enabled():
		app.effects_audio.play_music_track(Music.RECREATION_TRACK)

	app.status_label.theme_type_variation = ""
	app.status_label.text = "The stadium was built without a team."


func _restore_stadium_dialog() -> void:
	if app.tool_state.pending_stadium_command != null:
		app.city_dialogs.stadium_dialog.popup_centered()


func open_sign_dialog(point: Vector2i) -> void:
	var overlay := app.document_state.city.text_overlay_id(point.x, point.y)

	if overlay != 0 and not OverlayData.is_sign(overlay):
		app.interface.show_error("This tile has a protected simulation label.")

		return

	app.tool_state.pending_sign_tile = point
	app.city_dialogs.sign_dialog.show_text(app.document_state.city.label(overlay) if overlay > 0 else "")


func commit_sign() -> void:
	if app.document_state.city == null or app.tool_state.pending_sign_tile.x < 0:
		return

	var result := Signs.set_sign(app.document_state.city, app.tool_state.pending_sign_tile, app.city_dialogs.sign_dialog.entered_text())
	app.tool_state.pending_sign_tile = Vector2i(-1, -1)

	if not result.ok:
		app.interface.show_error("Cannot change sign: %s" % result.error)

		return

	app.tool_state.last_edit_command = result
	app.static_render.refresh_after_city_edit(result)
	app.status_label.theme_type_variation = ""
	app.status_label.text = "Sign removed." if result.new_overlay == 0 else "Sign saved as label %d." % result.label_id


func cancel_sign() -> void:
	app.tool_state.pending_sign_tile = Vector2i(-1, -1)


func open_query(point: Vector2i) -> void:
	var result := Queries.inspect(app.document_state.city, point)

	if not result.ok:
		app.interface.show_error("Cannot query tile: %s" % result.error)

		return

	if result.overlay_id == 111 and app.simulation_state.simulation_engine != null:
		var approval := app.simulation_state.simulation_engine.recalculate_mayor_house()

		if not approval.ok:
			app.interface.show_error("Cannot calculate mayor approval: %s" % approval.error)

			return

		app.reports.show_news_items(approval.news_items)
		result = Queries.inspect(app.document_state.city, point)

	if (
		result.kind == "general"
		and app.asset_state.active_scurk_tile_set != null
		and app.asset_state.active_scurk_tile_set.names.has(int(result.tile_id))
	):
		result.title = app.asset_state.active_scurk_tile_set.names[int(result.tile_id)]

	app.tool_state.active_query_result = result
	var is_specific: bool = result.kind == "specific"
	var action := str(result.action)
	var action_text := ""

	if not action.is_empty():
		action_text = str(QueryStrings.ACTIONS.get(action, ""))

	var neighborhood := QueryNeighborhood.render(app.document_state.city, point, app.asset_state.palette_index_encoding, app.asset_state.large_sprites)
	app.city_dialogs.query_dialog.show_query(
		str(result.title),
		str(result.title) if is_specific else "",
		is_specific,
		QueryText.format_text(result),
		action_text,
		result,
		ImageTexture.create_from_image(neighborhood) if neighborhood != null else null,
		app.asset_state.palette,
		app.palette_clock.cycle_ticks,
	)
	app.effects_audio.play_sound_ids(result.sound_events)


func close_query(commit_rename := false) -> bool:
	if app.city_dialogs.query_dialog == null or not app.city_dialogs.query_dialog.visible:
		return true

	if (
		commit_rename
		and app.city_dialogs.query_dialog.rename_is_enabled()
		and app.tool_state.active_query_result != null
		and app.tool_state.active_query_result.kind == "specific"
	):
		var renamed := QueryFacilityActions.rename_facility(
			app.document_state.city, app.tool_state.active_query_result, app.city_dialogs.query_dialog.facility_name()
		)

		if not renamed.ok:
			app.interface.show_error("Cannot rename facility: %s" % renamed.error)

			return false

		app.tool_state.active_query_result.title = renamed.new_value

	app.city_dialogs.query_dialog.close_query()

	return true


# the original keeps Query open below the action window
func run_query_action() -> void:
	if app.document_state.city == null or app.tool_state.active_query_result == null:
		return

	match str(app.tool_state.active_query_result.action):
		"city_analysis":
			var analysis := QueryFacilityActions.city_analysis(app.document_state.city)

			if not analysis.ok:
				app.interface.show_error("Cannot analyze city: %s" % analysis.error)

				return

			app.city_dialogs.analysis_dialog.show_categories(analysis.categories)
		"library_ruminate":
			if (
				text_resources.library_texts.size()
				!= LibraryRuminateWindowsView.TEXT_RESOURCE_IDS.size()
			):
				app.interface.show_error("The Library text resources are missing or invalid.")

				return

			app.city_dialogs.library_windows.show_texts(
				text_resources.library_texts, Vector2i(app.get_viewport_rect().size)
			)
