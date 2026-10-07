class_name ApplicationReports
extends RefCounted

const CityMenuBarView = preload("res://src/ui/shell/city_menu_bar.gd")
const Music = preload("res://src/audio/music_director.gd")
const MENU_NO_DISASTERS := CityMenuBarView.MENU_NO_DISASTERS
# message box text from the supplied string table, by string ID
const NOTICE_TEXT := {
	241: "The Army has built a base in your city.",
	242: "An Air Force base has been placed here.",
	243: "A Naval base is built on your coastline.",
	244: "Six missile sites have been placed in your city.",
	411: ("The military is unable to find a suitable\nlocation for a base near your city.  You\nhave "
		+ "the thanks of the nation for your\npatriotic acquiesence.  SALUTE!!"),
	119: "Because you have no police or firefighters, the National Guard has been deployed to your city",
	284: "The people of your city love you so dearly that they\nhave thrown  a spontaneous parade in your honor.",
	292: "Due to the current fiscal crisis, the city council urges you to cut back drastically on city expenditures.",
	529: "The exodus has begun.",
	530: "Your launch arcos have departed into space to found new worlds. You have been compensated for their construction.",
}
# the notices that SIMCITY.EXE shows with a picture (0x0042b870), by string ID:
# the National Guard and the parade. the value is the BITMAPS picture
const NOTICE_PICTURES := {119: 406, 284: 407}
# the original stops the bulldozer sound before the National Guard notice
const NATIONAL_GUARD_NOTICE := 119

var app: CityApplication
var city_map: ApplicationCityMapReports
var document_state: ActiveDocumentState
var text_resources: OriginalTextResources
# the string IDs of the notices that wait for the notice dialog
var pending_notices := PackedInt32Array()
var military_notice_pending := false
# a newspaper that waits until the player closes the parade notice: the paper
# and the top complaint of its poll. -1 when no paper waits
var deferred_newspaper := -1
var deferred_opinion_subject := -1
var pending_game_over_events: Array[GameOverEvent] = []
var game_over_terminal := false


func _init(application: CityApplication) -> void:
	app = application
	city_map = ApplicationCityMapReports.new(application)
	document_state = application.document_state
	text_resources = application.original_text_resources


func on_disaster_menu(id: int) -> void:
	if app.tool_state.landscape_editor:
		return

	if app.document_state.city == null or app.simulation_state.simulation_engine == null:
		app.interface.show_error("Load a city before you start a disaster.")

		return

	if id == MENU_NO_DISASTERS:
		var enabled := not app.document_state.city.no_disasters_enabled()

		if not app.document_state.city.set_no_disasters_enabled(enabled):
			app.interface.show_error("Cannot update the No Disasters option.")

			return

		app.menus.sync_city_option_menus()
		app.status_label.theme_type_variation = ""
		app.status_label.text = tr("No Disasters %s.") % tr("enabled" if enabled else "disabled")

		return

	# the menu item selects the place, as in the original
	var engine := app.simulation_state.simulation_engine
	var result := start_disaster_at(id, engine.menu_disaster_point(id, _view_center_tile()))

	if not result.ok:
		app.interface.show_error(tr("Cannot start the disaster: %s") % result.error)


func start_disaster_at_view_center(id: int) -> DisasterReportResult:
	return start_disaster_at(id, _view_center_tile())


func _view_center_tile() -> Vector2i:
	var point := app.map_view.center_tile() if app.map_view != null else Vector2i(64, 64)

	return point if point.x >= 0 else Vector2i(64, 64)


func start_disaster_at(id: int, point: Vector2i) -> DisasterReportResult:
	var report := DisasterReportResult.new()

	if app.document_state.city == null or app.simulation_state.simulation_engine == null:
		report.error = "no city is loaded"

		return report

	if app.scripting.cancelled("disaster.beforeStart", {"id": id, "name": CityMenuBar.disaster_name(id), "x": point.x, "y": point.y}):
		report.error = "a script cancelled it"

		return report

	var result := app.simulation_state.simulation_engine.start_disaster(id, point)
	report.phase_result = result

	if not result.ok:
		report.error = result.error

		return report

	if not result.started:
		report.error = "the selected disaster could not start"

		return report

	if app.simulation_state.speed_controller != null and app.simulation_state.speed_controller.slow_for_disaster():
		app.simulation_state.resume_speed = GameSpeedController.Speed.CHEETAH
		app.frame.sync_speed_ui()

	if app.document_state.city.music_enabled():
		app.effects_audio.play_music_track(Music.DISASTER_TRACK)

	app.tool_state.last_edit_command = null
	app.simulation_state.simulation_map_dirty = false
	app.map_render.refresh_map(false)

	# a disaster enables the Emergency tool
	if app.current_tool.refresh_tool_availability():
		app.current_tool.update_edit_state()

	for requested_point in result.view_center_requests:
		app.map_view.center_on_tile(requested_point)

	app.effects_audio.show_effect_events(
		result.effect_events, result.sound_events
	)
	app.interface.refresh_status_summary()
	show_notices(result.notice_ids)
	var first_update := result.first_update

	if first_update != null:
		for requested_point in first_update.view_center_requests:
			app.map_view.center_on_tile(requested_point)

		app.effects_audio.show_effect_events(first_update.effect_events, first_update.sound_events)
		app.interface.refresh_status_summary()

		if first_update.newspaper_requested:
			open_scheduled_newspaper(first_update.newspaper_paper)

	var disaster_name := CityMenuBar.disaster_name(id)
	app.status_label.theme_type_variation = ""
	app.status_label.text = tr("%s started.") % tr(disaster_name)

	report.ok = true
	report.name = disaster_name
	app.scripting.check_disaster()

	return report


func on_windows_menu(id: int) -> void:
	if id == 0:
		app.budget.open_manual_budget()
	elif id == 1:
		_open_ordinance_window()
	elif id == 2:
		_open_population_window()
	elif id == 3:
		_open_industry_window()
	elif id == 4:
		_open_graph_window()
	elif id == 5:
		_open_simnation_window()
	elif id == 6:
		city_map.open_window()
	elif id == 7:
		app.debug_overlay.toggle()
	elif id == CityMenuBarView.MENU_CONSOLE:
		app.console_window.open()
	elif id == CityMenuBarView.MENU_SCENARIO_GOALS:
		var engine := app.simulation_state.simulation_engine
		if engine != null and engine.scenario != null:
			app.budget.open_scenario_intro(engine.scenario, false)


func _open_ordinance_window() -> void:
	if app.document_state.city == null or app.city_dialogs.ordinance_window == null:
		return

	var result: OrdinanceCommand.Result = app.city_dialogs.ordinance_window.open_city(app.document_state.city)

	if not result.ok:
		app.interface.show_error(tr("Cannot open ordinances: %s") % result.error)


func on_ordinances_changed() -> void:
	app.interface.refresh_details()
	app.status_label.theme_type_variation = ""
	app.status_label.text = "Ordinance selection saved."


func _open_graph_window() -> void:
	if app.document_state.city == null or app.city_dialogs.graph_window == null:
		return

	app.city_dialogs.graph_window.show_city(app.document_state.city)


func _open_population_window() -> void:
	if app.document_state.city == null or app.city_dialogs.population_window == null:
		return

	app.city_dialogs.population_window.show_city(app.document_state.city)


func _open_industry_window() -> void:
	if app.document_state.city == null or app.city_dialogs.industry_window == null:
		return

	app.city_dialogs.industry_window.show_city(app.document_state.city)


func on_industry_tax_rates_changed() -> void:
	app.interface.refresh_details()
	app.status_label.theme_type_variation = ""
	app.status_label.text = "Industry tax rates saved."


func _open_simnation_window() -> void:
	if app.document_state.city == null or app.city_dialogs.simnation_window == null:
		return

	app.city_dialogs.simnation_window.show_city(app.document_state.city)


func refresh_newspaper_menu() -> void:
	var city := app.document_state.city
	app.city_menu_bar.set_newspapers(
		NewspaperDialog.newspaper_titles(city, document_state.current_document),
		city != null and city.newspaper_subscription_enabled(),
		city != null and city.newspaper_extras_enabled(),
		city.document.misc_u32(Sc2MiscLayout.NEWSPAPER_CHOICE) if city != null else -1,
	)


func on_newspaper_menu(id: int) -> void:
	if app.document_state.city == null or document_state.current_document == null:
		return

	if id == CityMenuBarView.MENU_NEWSPAPER_SUBSCRIPTION or id == CityMenuBarView.MENU_NEWSPAPER_EXTRAS:
		_toggle_newspaper_option(id)

		return

	if id < 0 or id >= NewsQueue.available_paper_count(app.document_state.city.city_status()):
		return

	# the original saves the paper that the player opens. a subscribed or extra
	# edition opens this paper
	if not app.document_state.city.document.set_misc_u32(Sc2MiscLayout.NEWSPAPER_CHOICE, id):
		app.interface.show_error("Cannot store the newspaper choice.")

		return

	# SIMCITY.EXE (0x00477880) polls the mayor approval before it shows a
	# paper. a rise to 80 percent shows the parade notice first
	var subject := _poll_mayor_approval()

	if notice_visible() or not pending_notices.is_empty():
		deferred_newspaper = id
		deferred_opinion_subject = subject

		return

	_open_newspaper(id, subject)


func _open_newspaper(id: int, opinion_subject: int) -> void:
	if app.document_state.city == null or document_state.current_document == null:
		return

	if app.document_state.city.music_enabled() and app.simulation_state.simulation_engine != null:
		app.effects_audio.play_music_track(Music.newspaper_track(app.simulation_state.simulation_engine.lfsr_random))

	app.city_dialogs.newspaper_dialog.open_reports(
		app.document_state.city,
		document_state.current_document,
		text_resources.newspaper_data,
		NewspaperDialog.STORY_NAMES,
		app.newspaper_state.session_seed,
		id,
		opinion_subject,
	)


# the approval poll of a paper. returns its top complaint, or -1 without a poll
func _poll_mayor_approval() -> int:
	var engine := app.simulation_state.simulation_engine

	if engine == null:
		return -1

	var approval := engine.recalculate_mayor_house()

	if not approval.ok:
		app.interface.show_error(tr("Cannot calculate mayor approval: %s") % approval.error)

		return -1

	show_mayor_approval(approval)

	return approval.ranking[0] if not approval.ranking.is_empty() else -1


# the original toggles each saved option and changes nothing else
func _toggle_newspaper_option(id: int) -> void:
	var city := app.document_state.city
	var subscription := id == CityMenuBarView.MENU_NEWSPAPER_SUBSCRIPTION
	var enabled := not (city.newspaper_subscription_enabled() if subscription else city.newspaper_extras_enabled())
	var stored := (
		city.set_newspaper_subscription_enabled(enabled)
		if subscription
		else city.set_newspaper_extras_enabled(enabled)
	)

	if not stored:
		app.interface.show_error("Cannot update the newspaper option.")

		return

	refresh_newspaper_menu()
	app.status_label.theme_type_variation = ""
	app.status_label.text = tr("Newspaper %s %s.") % [
		tr("subscription" if subscription else "extra editions"), tr("enabled" if enabled else "disabled"),
	]


func on_help_menu(id: int) -> void:
	if id == CityMenuBarView.MENU_CHECK_FOR_UPDATES:
		app.updates.check_now()
	else:
		app.interface.open_about_dialog()


# open the newspaper that the simulation requested. the original opens the
# paper that MISC 0x100c selects
# `paper` -1 opens the saved newspaper choice
func open_scheduled_newspaper(paper := -1) -> void:
	var city := app.document_state.city

	if city == null or document_state.current_document == null:
		return

	var paper_count := NewsQueue.available_paper_count(city.city_status())

	if paper_count <= 0:
		return

	if paper < 0:
		paper = city.document.misc_u32(Sc2MiscLayout.NEWSPAPER_CHOICE)

	on_newspaper_menu(clampi(paper, 0, paper_count - 1))
	app.newspaper_state.scheduled_pending = app.city_dialogs.newspaper_dialog.visible or deferred_newspaper >= 0


func on_scheduled_newspaper_visibility_changed() -> void:
	if not app.city_dialogs.newspaper_dialog.visible:
		app.newspaper_state.scheduled_pending = false


func show_building_objection() -> void:
	if app.city_dialogs.building_objection_dialog == null:
		return

	app.city_dialogs.building_objection_dialog.show_message(BuildingConstants.NUISANCE_OBJECTION, true)


func on_building_objection_closed() -> void:
	if app.tool_state.pending_building_objection_group < 0:
		return

	app.effects_audio.play_tool_failure_sound(
		app.tool_state.pending_building_objection_group,
		app.tool_state.pending_building_objection_subtool,
	)
	app.tool_state.pending_building_objection_group = -1
	app.tool_state.pending_building_objection_subtool = -1


# queue each notice and show them one at a time. the notice dialogs suspend
# the simulation, as the original message box does
func show_notices(notice_ids: PackedInt32Array) -> void:
	for dialog: Window in _notice_dialogs():
		if not dialog.visibility_changed.is_connected(_show_next_notice):
			dialog.visibility_changed.connect(_show_next_notice, CONNECT_DEFERRED)

	for notice_id in notice_ids:
		if NOTICE_TEXT.has(notice_id):
			pending_notices.append(notice_id)

	# a notice can follow an option change, such as Auto Budget
	app.menus.sync_city_option_menus()
	_show_next_notice()


# the result of a mayor approval poll: the parade notice and its sound
func show_mayor_approval(approval: MayorApprovalPhase.Result) -> void:
	app.effects_audio.play_sound_events(approval.sound_events, true)
	app.interface.refresh_status_summary()
	show_notices(approval.notice_ids)


func reset_notices() -> void:
	military_notice_pending = false
	pending_notices.clear()
	deferred_newspaper = -1
	deferred_opinion_subject = -1

	for dialog: Window in _notice_dialogs():
		if dialog.visible:
			dialog.hide()


func notice_visible() -> bool:
	return _notice_dialogs().any(func(dialog: Window) -> bool: return dialog.visible)


func _notice_dialogs() -> Array[Window]:
	var dialogs: Array[Window] = [app.city_dialogs.notice_dialog, app.city_dialogs.picture_notice_dialog]

	return dialogs


func _show_next_notice() -> void:
	if notice_visible():
		return

	if pending_notices.is_empty():
		if military_notice_pending:
			military_notice_pending = false
			app.budget.resolve_military_notice()
		elif deferred_newspaper >= 0:
			var paper := deferred_newspaper
			deferred_newspaper = -1
			_open_newspaper(paper, deferred_opinion_subject)

		return

	var notice_id := pending_notices[0]
	pending_notices.remove_at(0)
	var text: String = NOTICE_TEXT[notice_id]
	var picture := _notice_picture(notice_id)

	if notice_id == NATIONAL_GUARD_NOTICE:
		app.effects_audio.stop_tool_loop_sound()

	if picture == null:
		app.city_dialogs.notice_dialog.dialog_text = text
		app.city_dialogs.notice_dialog.popup_centered()

		return

	app.city_dialogs.picture_notice_dialog.set_picture(picture)
	app.city_dialogs.picture_notice_dialog.show_message(text, true)


# the original picture of a notice, or null without a picture or imported graphics
func _notice_picture(notice_id: int) -> Image:
	var assets := app.city_dialogs.original_assets

	if not NOTICE_PICTURES.has(notice_id) or assets == null or assets.city_ui_graphics == null:
		return null

	return assets.city_ui_graphics.notices.get(NOTICE_PICTURES[notice_id])


func show_game_over_events(events: Array[GameOverEvent]) -> void:
	var dialog := app.city_dialogs.game_over_dialog

	if not dialog.visibility_changed.is_connected(_show_next_game_over):
		dialog.visibility_changed.connect(_show_next_game_over, CONNECT_DEFERRED)

	app.simulation_state.game_over_active = true
	pending_game_over_events.append_array(events)
	app.city_menu_bar.set_scenario_available(false)
	_show_next_game_over()


func reset_game_over() -> void:
	pending_game_over_events.clear()
	game_over_terminal = false
	app.simulation_state.game_over_active = false
	app.city_dialogs.game_over_dialog.hide()


func _show_next_game_over() -> void:
	var dialog := app.city_dialogs.game_over_dialog

	if dialog.visible or not app.simulation_state.game_over_active:
		return

	if pending_game_over_events.is_empty():
		app.simulation_state.game_over_active = false

		if game_over_terminal:
			game_over_terminal = false
			app.city_session.finish_game()
		elif app.simulation_state.speed_controller != null:
			app.simulation_state.speed_controller.acknowledge_game_over()

		return

	var event := pending_game_over_events.pop_front() as GameOverEvent
	game_over_terminal = game_over_terminal or event.is_terminal()
	var message := ""

	match event.type:
		"scenario_victory":
			message = "The scenario goals are complete. You can continue this city."
		"scenario_failure":
			message = "The scenario time limit expired."
		"bankruptcy":
			message = "The city is bankrupt. The mayor was impeached."

	dialog.title = "Game Over" if event.is_terminal() else "Scenario Complete"
	dialog.dialog_text = message
	app.effects_audio.play_sound_ids([event.sound_id])
	dialog.popup_centered()
	app.status_label.theme_type_variation = "WarningLabel" if event.is_terminal() else ""
	app.status_label.text = message


func moving_things_are_active(results: Array) -> bool:
	for result in results:
		for key in [
			"active_airplanes",
			"active_helicopters",
			"active_ships",
			"active_monsters",
			"active_explosions",
			"active_sailboats",
			"active_trains",
			"active_tornadoes",
			"active_maxis_men",
		]:
			if int(result.get(key)) > 0:
				return true

	return false


# presentation outcome and the complete typed simulation result
class DisasterReportResult extends RefCounted:
	var ok := false
	var error := ""
	var name := ""
	var phase_result: DisasterStartResult
