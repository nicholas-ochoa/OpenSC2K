class_name ApplicationReports
extends RefCounted


const CityMapView = preload("res://src/view/city_map_window_control.gd")
const CityMenuBarView = preload("res://src/ui/shell/city_menu_bar.gd")
const NewsQueue = preload("res://src/simulation/reports/news_queue.gd")
const Music = preload("res://src/audio/music_director.gd")
const MENU_NO_DISASTERS := CityMenuBarView.MENU_NO_DISASTERS

var app: CityApplication
var document_state: ActiveDocumentState
var text_resources: OriginalTextResources
var newspaper_session_seed := 0
var newspaper_session_state := PackedByteArray()


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

	if not result.get("ok", false):
		app.interface.show_error("Cannot start the disaster: %s" % result.get("error", "unknown error"))


func start_disaster_at_view_center(id: int) -> Dictionary:
	if app.document_state.city == null or app.simulation_state.simulation_engine == null:
		return {"ok": false, "error": "no city is loaded"}

	var point := app.map_view.center_tile() if app.map_view != null else Vector2i(64, 64)

	if point.x < 0:
		point = Vector2i(64, 64)

	var result := app.simulation_state.simulation_engine.start_disaster(id, point)

	if not result.get("ok", false):
		return result

	if not result.get("started", false):
		return {"ok": false, "error": "the selected disaster could not start"}

	if app.document_state.city.music_enabled():
		app.effects_audio.play_music_track(Music.DISASTER_TRACK)

	app.tool_state.last_edit_command = null
	app.simulation_state.simulation_map_dirty = false
	app.map_render.refresh_map(false)

	for requested_point in result.get("view_center_requests", []):
		app.map_view.center_on_tile(requested_point)

	app.effects_audio.show_effect_events(
		result.get("effect_events", []), result.get("sound_events", [])
	)
	show_news_items(result.get("news_items", []))
	var disaster_name := CityMenuBar.disaster_name(id)
	app.status_label.theme_type_variation = ""
	app.status_label.text = "%s started." % disaster_name
	result["name"] = disaster_name

	return result


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


func _open_ordinance_window() -> void:
	if app.document_state.city == null or app.ordinance_window == null:
		return

	var result: Dictionary = app.ordinance_window.open_city(app.document_state.city)

	if not result.get("ok", false):
		app.interface.show_error("Cannot open ordinances: %s" % result.get("error", "invalid data"))


func on_ordinances_changed() -> void:
	app.interface.refresh_details()
	app.status_label.theme_type_variation = ""
	app.status_label.text = "Ordinance selection saved."


func _open_graph_window() -> void:
	if app.document_state.city == null or app.graph_window == null:
		return

	app.graph_window.show_city(app.document_state.city)


func _open_population_window() -> void:
	if app.document_state.city == null or app.population_window == null:
		return

	app.population_window.show_city(app.document_state.city)


func _open_industry_window() -> void:
	if app.document_state.city == null or app.industry_window == null:
		return

	app.industry_window.show_city(app.document_state.city)


func on_industry_tax_rates_changed() -> void:
	app.interface.refresh_details()
	app.status_label.theme_type_variation = ""
	app.status_label.text = "Industry tax rates saved."


func _open_simnation_window() -> void:
	if app.document_state.city == null or app.simnation_window == null:
		return

	app.simnation_window.show_city(app.document_state.city)


func open_city_map_window() -> void:
	if app.document_state.city == null or app.city_map_window == null:
		return

	app.city_map_window.toggle_city(app.document_state.city, app.asset_state.palette, city_map_viewport_outline())


func on_city_map_mode_changed(mode: String) -> void:
	app.status_label.theme_type_variation = ""
	app.status_label.text = "City Map: %s" % CityMapView.MODE_NAMES.get(mode, mode)


func on_city_map_center_requested(point: Vector2i) -> void:
	app.map_view.center_on_tile(point)
	app.status_label.theme_type_variation = ""
	app.status_label.text = "City view centered at %d, %d." % [point.x, point.y]


func city_map_viewport_outline() -> PackedVector2Array:
	if app.map_view == null or not CityViewMode.DISPLAY_MODES.has(app.view_state.overlay_mode):
		return PackedVector2Array()

	return app.map_view.visible_tile_outline()


func refresh_city_map_viewport() -> void:
	if app.city_map_window != null:
		app.city_map_window.refresh_viewport(city_map_viewport_outline())


func refresh_newspaper_menu() -> void:
	app.city_menu_bar.set_newspapers(
		NewspaperDialog.newspaper_titles(app.document_state.city, document_state.current_document, text_resources.original_query_strings),
	)


func on_newspaper_menu(id: int) -> void:
	if app.document_state.city == null or document_state.current_document == null:
		return

	if id < 0 or id >= NewsQueue.available_paper_count(app.document_state.city.city_status()):
		return

	if app.document_state.city.music_enabled() and app.simulation_state.simulation_engine != null:
		app.effects_audio.play_music_track(Music.newspaper_track(app.simulation_state.simulation_engine.lfsr_random))

	app.newspaper_dialog.open_reports(
		app.document_state.city,
		document_state.current_document,
		text_resources.newspaper_data,
		text_resources.original_query_strings,
		CityStatusBar.NEWS_NAMES,
		newspaper_session_seed,
		id,
	)


func on_help_menu(_id: int) -> void:
	app.interface.open_about_dialog()


func show_news_items(news_items: Array) -> void:
	if app.city_status_bar != null:
		app.city_status_bar.prepend_news_items(news_items)

	app.interface.refresh_status_summary()


func show_building_objection() -> void:
	if app.building_objection_dialog == null:
		return

	app.building_objection_dialog.show_message(text_resources.building_objection_text, true)


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

		if record.is_empty() or int(record.priority) <= 0:
			continue

		var story_type := int(record.type)
		reports.append(CityStatusBar.report_name(story_type, text_resources.original_query_strings))

		if reports.size() == 3:
			break

	if app.city_status_bar != null:
		app.city_status_bar.set_reports(reports)

	app.interface.refresh_status_summary()


func show_game_over_events(events: Array) -> void:
	app.simulation_state.game_over_active = true
	var messages := PackedStringArray()

	for event in events:
		match event.get("type", ""):
			"scenario_victory":
				messages.append("The scenario goals are complete.")
			"scenario_failure":
				messages.append("The scenario time limit expired.")
			"bankruptcy":
				messages.append("The city is bankrupt. The mayor was impeached.")

	app.game_over_dialog.title = "Game Over" if events.size() != 1 else (
		"Scenario Complete"
		if events[0].get("type", "") == "scenario_victory"
		else "Game Over"
	)
	app.game_over_dialog.dialog_text = "\n".join(messages) + "\n\nOpen another city to continue."
	app.game_over_dialog.popup_centered()
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
			if int(result.get(key, 0)) > 0:
				return true

	return false
