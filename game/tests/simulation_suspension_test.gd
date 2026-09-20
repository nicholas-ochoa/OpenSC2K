extends SceneTree
## Each registered window declares whether it suspends the simulation.

const Modality = CityDialogRegistry.Modality

var main: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	main.main_menu.hide()
	assert(main.city_session.activate_document(EmptyCityTemplate.create(128)))
	main.scurk_editor = main.main_overlays.ensure_scurk_editor()
	main.scurk_place_print = main.main_overlays.ensure_scurk_place_print()
	main.scurk_print = main.main_overlays.ensure_scurk_print()
	_hide_all()
	assert(not main.frame._simulation_suspended(), "No open window leaves the simulation running")

	_check_every_window_is_classified()
	_check_current_classification()
	_check_scenario_goals()
	_check_new_windows()
	main.queue_free()
	await process_frame
	print("PASS: registered windows declare whether they suspend the simulation")
	quit()


# A window added to a registry without a modality fails here.
func _check_every_window_is_classified() -> void:
	var registries: Array = [main.city_dialogs, main.main_overlays]
	var containers: Array[Node] = [main.main_overlays, main.main_overlays.scurk_workspace]

	for group: Node in main.city_dialogs.dialog_groups.values():
		containers.append(group)

	for container in containers:
		for child in container.get_children():
			if child == main.main_overlays.scurk_workspace:
				continue

			var count := 0

			for registry in registries:
				count += registry.blocking_windows.count(child) + registry.modeless_windows.count(child)

			assert(count == 1, "Missing or duplicate window registration: %s" % child.get_path())


# The set matches the suspend condition that preceded the registries.
func _check_current_classification() -> void:
	var blocking: Array[Node] = [
		main.save_dialog, main.city_png_export_dialog, main.city_png_export_progress,
		main.new_city_dialog, main.bridge_dialog, main.tool_choice_dialog, main.stadium_dialog,
		main.network_connection_dialog, main.highway_connection_dialog, main.tunnel_dialog,
		main.query_dialog, main.ordinance_window, main.building_objection_dialog,
		main.scenario_dialog, main.military_dialog, main.budget_dialog,
		main.main_menu, main.settings_dialog, main.reference_import_dialog, main.save_changes_dialog,
		main.scurk_editor, main.scurk_place_print, main.scurk_print,
	]
	var modeless: Array[Node] = [
		main.file_dialog, main.tile_set_dialog, main.sign_dialog,
		main.graph_window, main.population_window, main.industry_window,
		main.simnation_window, main.city_map_window, main.city_analysis_dialog,
		main.newspaper_dialog, main.library_ruminate_windows, main.game_over_dialog,
		main.about_dialog,
	]
	var registered_blocking: Array[Node] = main.city_dialogs.blocking_windows + main.main_overlays.blocking_windows
	var registered_modeless: Array[Node] = main.city_dialogs.modeless_windows + main.main_overlays.modeless_windows
	assert(_same_set(registered_blocking, blocking), "Blocking windows are unchanged")
	assert(_same_set(registered_modeless, modeless), "Modeless windows are unchanged")

	for window in blocking:
		_set_shown(window, true)
		assert(main.frame._simulation_suspended(), "%s suspends the simulation" % window.name)
		_hide_all()

	for window in modeless:
		_set_shown(window, true)
		assert(not main.frame._simulation_suspended(), "%s leaves the simulation running" % window.name)
		_hide_all()


func _check_scenario_goals() -> void:
	var popup: PopupMenu = main.city_menu_bar.windows_menu.get_popup()
	assert(popup.get_item_index(CityMenuBar.MENU_SCENARIO_GOALS) == -1)
	main.reports.on_windows_menu(CityMenuBar.MENU_SCENARIO_GOALS)
	assert(not main.scenario_dialog.visible)
	var document := Sc2File.load_path(ProjectSettings.globalize_path(
		"res://../references/SIMCITY2000/SCENARIO/MALIBU.SCN"))
	assert(document.is_valid())
	assert(main.city_session.activate_document(document))
	_hide_all()
	assert(popup.get_item_index(CityMenuBar.MENU_SCENARIO_GOALS) >= 0)
	var engine: SimulationEngine = main.simulation_state.simulation_engine
	var before := document.serialize().data
	var random_states := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
	main.status_label.text = "Status before reviewing goals"
	var status_before: String = main.status_label.text
	popup.id_pressed.emit(CityMenuBar.MENU_SCENARIO_GOALS)
	assert(main.scenario_dialog.visible)
	assert(not main.scenario_dialog.starts_scenario)
	assert(not main.scenario_dialog.text_view.text.is_empty())
	assert(main.frame._simulation_suspended())
	main.scenario_dialog.get_ok_button().pressed.emit()
	assert(not main.scenario_dialog.visible)
	assert(not main.frame._simulation_suspended())
	assert(main.status_label.text == status_before)
	assert(document.serialize().data == before)
	assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == random_states)
	main.budget.open_scenario_intro(engine.scenario)
	assert(main.scenario_dialog.starts_scenario)
	main.scenario_dialog.get_ok_button().pressed.emit()
	assert(main.status_label.text != status_before)
	assert(main.city_session.activate_document(EmptyCityTemplate.create(128)))
	_hide_all()
	assert(popup.get_item_index(CityMenuBar.MENU_SCENARIO_GOALS) == -1)
	main.reports.on_windows_menu(CityMenuBar.MENU_SCENARIO_GOALS)
	assert(not main.scenario_dialog.visible)


func _check_new_windows() -> void:
	var blocking := AcceptDialog.new()
	main.city_dialogs._register(blocking, "Tools", Modality.BLOCKING)
	blocking.show()
	assert(main.frame._simulation_suspended(), "A newly registered blocking window suspends the simulation")
	blocking.hide()
	assert(not main.frame._simulation_suspended())

	var modeless := Window.new()
	main.city_dialogs._register(modeless, "CityWindows", Modality.MODELESS)
	modeless.show()
	assert(not main.frame._simulation_suspended(), "A newly registered modeless window leaves the simulation running")
	modeless.hide()


func _hide_all() -> void:
	for registry in [main.city_dialogs, main.main_overlays]:
		for window: Node in registry.blocking_windows + registry.modeless_windows:
			_set_shown(window, false)

	main.tool_state.landscape_editor = false
	main.newspaper_state.founding_pending = false


func _set_shown(window: Node, shown: bool) -> void:
	if window is Window:
		(window as Window).visible = shown
	else:
		(window as CanvasItem).visible = shown


func _same_set(actual: Array[Node], expected: Array[Node]) -> bool:
	if actual.size() != expected.size():
		return false

	for window in expected:
		if actual.count(window) != 1:
			return false

	return true
