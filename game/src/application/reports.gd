class_name ApplicationReports
extends RefCounted


const CityMapView = preload("res://src/view/city_map_window_control.gd")
const CityMenuBarView = preload("res://src/ui/shell/city_menu_bar.gd")
const NewsQueue = preload("res://src/simulation/reports/news_queue.gd")
const Music = preload("res://src/audio/music_director.gd")
const MENU_NO_DISASTERS := CityMenuBarView.MENU_NO_DISASTERS

# message box text from the supplied string table, by string ID
const NOTICE_TEXT := {
	292: "Due to the current fiscal crisis, the city council urges you to cut back drastically on city expenditures.",
	529: "The exodus has begun.",
	530: "Your launch arcos have departed into space to found new worlds. You have been compensated for their construction.",
}

# presentation outcome and the complete typed simulation result
class DisasterReportResult extends RefCounted:
	var ok := false
	var error := ""
	var name := ""
	var phase_result: DisasterStartResult


var app: CityApplication
var document_state: ActiveDocumentState
var text_resources: OriginalTextResources
var pending_notices := PackedStringArray()


func _init(application: CityApplication) -> void:
	app = application
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
		app.status_label.text = "No Disasters %s." % ("enabled" if enabled else "disabled")

		return

	var result := start_disaster_at_view_center(id)

	if not result.ok:
		app.interface.show_error("Cannot start the disaster: %s" % result.error)


func start_disaster_at_view_center(id: int) -> DisasterReportResult:
	var report := DisasterReportResult.new()

	if app.document_state.city == null or app.simulation_state.simulation_engine == null:
		report.error = "no city is loaded"

		return report

	var point := app.map_view.center_tile() if app.map_view != null else Vector2i(64, 64)

	if point.x < 0:
		point = Vector2i(64, 64)

	var result := app.simulation_state.simulation_engine.start_disaster(id, point)
	report.phase_result = result

	if not result.ok:
		report.error = result.error

		return report

	if not result.started:
		report.error = "the selected disaster could not start"

		return report

	if app.document_state.city.music_enabled():
		app.effects_audio.play_music_track(Music.DISASTER_TRACK)

	app.tool_state.last_edit_command = null
	app.simulation_state.simulation_map_dirty = false
	app.map_render.refresh_map(false)

	for requested_point in result.view_center_requests:
		app.map_view.center_on_tile(requested_point)

	app.effects_audio.show_effect_events(
		result.effect_events, result.sound_events
	)
	show_news_items(result.news_items)
	var disaster_name := CityMenuBar.disaster_name(id)
	app.status_label.theme_type_variation = ""
	app.status_label.text = "%s started." % disaster_name

	report.ok = true
	report.name = disaster_name

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
		open_city_map_window()
	elif id == 7:
		app.debug_overlay.toggle()
	elif id == CityMenuBarView.MENU_SCENARIO_GOALS:
		var engine := app.simulation_state.simulation_engine
		if engine != null and engine.scenario != null:
			app.budget.open_scenario_intro(engine.scenario, false)


func _open_ordinance_window() -> void:
	if app.document_state.city == null or app.city_dialogs.ordinance_window == null:
		return

	var result: OrdinanceCommand.Result = app.city_dialogs.ordinance_window.open_city(app.document_state.city)

	if not result.ok:
		app.interface.show_error("Cannot open ordinances: %s" % result.error)


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


func open_city_map_window() -> void:
	if app.document_state.city == null or app.city_dialogs.city_map_window == null:
		return

	app.city_dialogs.city_map_window.toggle_city(app.document_state.city, app.asset_state.palette, city_map_viewport_outline())


func on_city_map_mode_changed(mode: String) -> void:
	app.status_label.theme_type_variation = ""
	app.status_label.text = "City Map: %s" % CityMapView.MODE_NAMES.get(mode, mode)


# the city map window drives the isometric view while its checkbox is on
func on_city_map_isometric_view_requested(mode: CityViewMode.Mode) -> void:
	if app.document_state.city == null or app.view_state.overlay_mode == mode:
		return

	app.menus.set_overlay(mode)


func on_city_map_center_requested(point: Vector2i) -> void:
	app.map_view.center_on_tile(point)
	app.status_label.theme_type_variation = ""
	app.status_label.text = "City view centered at %d, %d." % [point.x, point.y]


func city_map_viewport_outline() -> PackedVector2Array:
	if app.map_view == null or not CityViewMode.DISPLAY_MODES.has(app.view_state.overlay_mode):
		return PackedVector2Array()

	return app.map_view.visible_tile_outline()


func refresh_city_map_viewport() -> void:
	if app.city_dialogs.city_map_window != null:
		app.city_dialogs.city_map_window.refresh_viewport(city_map_viewport_outline())


func refresh_newspaper_menu() -> void:
	app.city_menu_bar.set_newspapers(
		NewspaperDialog.newspaper_titles(app.document_state.city, document_state.current_document),
	)


func on_newspaper_menu(id: int) -> void:
	if app.document_state.city == null or document_state.current_document == null:
		return

	if id < 0 or id >= NewsQueue.available_paper_count(app.document_state.city.city_status()):
		return

	if app.document_state.city.music_enabled() and app.simulation_state.simulation_engine != null:
		app.effects_audio.play_music_track(Music.newspaper_track(app.simulation_state.simulation_engine.lfsr_random))

	app.city_dialogs.newspaper_dialog.open_reports(
		app.document_state.city,
		document_state.current_document,
		text_resources.newspaper_data,
		CityStatusBar.NEWS_NAMES,
		app.newspaper_state.session_seed,
		id,
	)


func on_help_menu(_id: int) -> void:
	app.interface.open_about_dialog()


# open the newspaper that the simulation requested. the original opens the
# paper that MISC 0x100c selects
func open_scheduled_newspaper() -> void:
	var city := app.document_state.city

	if city == null or document_state.current_document == null:
		return

	var paper_count := NewsQueue.available_paper_count(city.city_status())

	if paper_count <= 0:
		return

	on_newspaper_menu(clampi(city.document.misc_u32(Sc2MiscLayout.NEWSPAPER_CHOICE), 0, paper_count - 1))
	app.newspaper_state.scheduled_pending = app.city_dialogs.newspaper_dialog.visible


func on_scheduled_newspaper_visibility_changed() -> void:
	if not app.city_dialogs.newspaper_dialog.visible:
		app.newspaper_state.scheduled_pending = false


func show_news_items(news_items: Array[NewsEvent]) -> void:
	if app.city_status_bar != null:
		app.city_status_bar.prepend_news_items(news_items)

	app.interface.refresh_status_summary()


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


func refresh_saved_news_summary() -> void:
	if app.document_state.city == null or document_state.current_document == null:
		if app.city_status_bar != null:
			app.city_status_bar.set_reports(PackedStringArray())

		app.interface.refresh_status_summary()

		return

	var misc_chunk := document_state.current_document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != NewsQueue.MISC_SIZE:
		if app.city_status_bar != null:
			app.city_status_bar.set_reports(PackedStringArray(["Unavailable"]))

		app.interface.refresh_status_summary()

		return

	var reports := PackedStringArray()

	for slot in NewsQueue.QUEUE_COUNT:
		var record := NewsQueue.story_record(misc_chunk.decoded_payload, slot)

		if record == null or int(record.priority) <= 0:
			continue

		var story_type := int(record.type)
		reports.append(CityStatusBar.report_name(story_type))

		if reports.size() == 3:
			break

	if app.city_status_bar != null:
		app.city_status_bar.set_reports(reports)

	app.interface.refresh_status_summary()


# queue each notice and show them one at a time. the notice dialog suspends
# the simulation, as the original message box does
func show_notices(notice_ids: PackedInt32Array) -> void:
	var dialog := app.city_dialogs.notice_dialog

	if not dialog.visibility_changed.is_connected(_show_next_notice):
		dialog.visibility_changed.connect(_show_next_notice, CONNECT_DEFERRED)

	for notice_id in notice_ids:
		if NOTICE_TEXT.has(notice_id):
			pending_notices.append(NOTICE_TEXT[notice_id])

	# a notice can follow an option change, such as Auto Budget
	app.menus.sync_city_option_menus()
	_show_next_notice()


func reset_notices() -> void:
	pending_notices.clear()

	if app.city_dialogs.notice_dialog.visible:
		app.city_dialogs.notice_dialog.hide()


func _show_next_notice() -> void:
	var dialog := app.city_dialogs.notice_dialog

	if dialog.visible or pending_notices.is_empty():
		return

	dialog.dialog_text = pending_notices[0]
	pending_notices.remove_at(0)
	dialog.popup_centered()


func show_game_over_events(events: Array[GameOverEvent]) -> void:
	app.simulation_state.game_over_active = true
	var messages := PackedStringArray()

	for event in events:
		match event.type:
			"scenario_victory":
				messages.append("The scenario goals are complete.")
			"scenario_failure":
				messages.append("The scenario time limit expired.")
			"bankruptcy":
				messages.append("The city is bankrupt. The mayor was impeached.")

	app.city_dialogs.game_over_dialog.title = "Game Over" if events.size() != 1 else (
		"Scenario Complete"
		if events[0].type == "scenario_victory"
		else "Game Over"
	)
	app.city_dialogs.game_over_dialog.dialog_text = "\n".join(messages) + "\n\nOpen another city to continue."
	app.city_dialogs.game_over_dialog.popup_centered()
	app.status_label.theme_type_variation = "WarningLabel"
	app.status_label.text = "\n".join(messages)


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
