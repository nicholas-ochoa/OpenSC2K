class_name ApplicationCityFiles
extends RefCounted


const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityFiles = preload("res://src/formats/city_file_store.gd")
const ScenarioModel = preload("res://src/model/scenario_state.gd")

var app: CityApplication
var document_state: ActiveDocumentState
var pending_city_exit_action := ""
var pending_city_exit_path := ""
var pending_city_exit_waiting_for_save := false
var pending_sc2x_document: Sc2File


func _init(application: CityApplication) -> void:
	app = application
	document_state = application.document_state


func _open_city_dialog() -> void:
	if not app.assets_ready:
		return

	var city_directory := ProjectSettings.globalize_path("user://cities")

	if DirAccess.dir_exists_absolute(city_directory):
		app.file_dialog.current_dir = city_directory

	app.file_dialog.popup_centered_ratio(0.8)


func _open_scenario_dialog() -> void:
	if not app.assets_ready:
		return

	var scenario_directory := ProjectSettings.globalize_path("user://scenarios")

	if DirAccess.dir_exists_absolute(scenario_directory):
		app.file_dialog.current_dir = scenario_directory

	app.file_dialog.popup_centered_ratio(0.8)


func _save_city() -> void:
	if document_state.current_document == null:
		return

	if document_state.current_save_path.is_empty():
		_open_save_dialog()
	else:
		_save_copy(document_state.current_save_path)


func _can_upgrade_city_to_sc2x() -> bool:
	if app.preferences.original_compatibility or app.landscape_editor or app.city == null or document_state.current_document == null or app.simulation_engine == null:
		return false

	if document_state.current_document.is_extended() or document_state.current_document.full_resolution_maps():
		return false

	var path := document_state.current_save_path if not document_state.current_save_path.is_empty() else document_state.current_document.source_path

	return path.get_extension().to_lower() == "sc2"


func _sync_upgrade_city_option() -> void:
	if app.options_menu == null:
		return

	var popup := app.options_menu.get_popup()
	var index := popup.get_item_index(CityMenuBar.MENU_UPGRADE_SC2X)
	var available := _can_upgrade_city_to_sc2x()

	if available and index < 0:
		popup.add_item("Upgrade City to SC2X...", CityMenuBar.MENU_UPGRADE_SC2X)
	elif not available and index >= 0:
		popup.remove_item(index)


func _upgrade_city_to_sc2x(confirmed := false) -> void:
	if not _can_upgrade_city_to_sc2x():
		return

	if not document_state.current_document.is_extended() and app.preferences.warn_sc2x_conversion and not confirmed:
		if app.sc2x_conversion_dialog == null:
			app.sc2x_conversion_dialog = ConfirmationDialog.new()
			app.sc2x_conversion_dialog.title = "Upgrade city to SC2X?"
			app.sc2x_conversion_dialog.dialog_text = "This permanently converts this city to SC2X.\nIt cannot return to SC2 or use original compatibility.\nThe original SimCity 2000 cannot open SC2X files.\n\nSave a separate SC2X copy. Your existing SC2 file stays unchanged."
			app.sc2x_conversion_dialog.get_ok_button().text = "Upgrade to SC2X"
			app.sc2x_conversion_dialog.exclusive = true
			app.sc2x_conversion_dialog.theme = ClassicUiStyle.create_dialog_theme()
			app.add_child(app.sc2x_conversion_dialog)
			app.sc2x_conversion_dialog.confirmed.connect(_confirm_sc2x_conversion)
			app.sc2x_conversion_dialog.canceled.connect(func() -> void:
				pending_sc2x_document = null)

		pending_sc2x_document = document_state.current_document
		app.sc2x_conversion_dialog.popup_centered()

		return

	if app.frame_simulation != null:
		app.frame_simulation.close()
		app.frame_simulation = null

	var enabled := document_state.current_document.enable_full_resolution_maps()

	if app.speed_controller != null and document_state.current_document.is_extended():
		app.frame_simulation = FrameSimulationRunner.new(app.speed_controller)

	if not enabled:
		app.interface._show_error("Cannot enable per-tile data maps: city data is incomplete.")

		return

	app.simulation_timings.clear()
	app.last_edit_command.clear()
	app.scurk_edit_history.clear()
	document_state.current_save_path = ""
	app.static_render._invalidate_view_render()
	app.map_render._refresh_map(false)
	_sync_upgrade_city_option()
	app.status_label.text = "City upgraded to SC2X. Save a separate copy; the original game cannot open it."
	_open_save_dialog()


func _confirm_sc2x_conversion() -> void:
	var expected := pending_sc2x_document
	pending_sc2x_document = null

	if expected != null and document_state.current_document == expected:
		_upgrade_city_to_sc2x(true)


func _open_save_dialog() -> void:
	if document_state.current_document == null:
		return

	var save_directory := ProjectSettings.globalize_path("user://cities")
	DirAccess.make_dir_recursive_absolute(save_directory)
	app.save_dialog.current_dir = save_directory
	var save_name := document_state.current_document.source_path.get_file().get_basename()

	if save_name.is_empty() and app.city != null:
		save_name = app.city.city_name().validate_filename()

	if save_name.is_empty():
		save_name = "New City"

	app.save_dialog.filters = PackedStringArray(["*.sc2x ; Extended cities"] if document_state.current_document.is_extended() else ["*.SC2, *.sc2 ; SimCity 2000 cities"])
	app.save_dialog.current_file = save_name + (".sc2x" if document_state.current_document.is_extended() else ".SC2")
	app.save_dialog.popup_centered_ratio(0.8)


func _city_has_unsaved_changes() -> bool:
	if document_state.current_document == null or app.city == null:
		return false

	if not document_state.current_city_saved_once:
		return true

	var serialized := document_state.current_document.serialize()

	return not serialized.ok or serialized.data != document_state.saved_city_snapshot


func _request_city_exit(action: String, path := "") -> void:
	if not _city_has_unsaved_changes():
		_perform_city_exit(action, path)

		return

	pending_city_exit_action = action
	pending_city_exit_path = path
	pending_city_exit_waiting_for_save = false
	var display_name := app.city.city_name()

	if display_name.is_empty():
		display_name = "this city"

	app.save_changes_dialog.show_city(display_name)


func _perform_city_exit(action: String, path := "") -> void:
	match action:
		"create_new_city":
			app.new_city._create_new_city_unchecked()
		"load_city":
			_load_city_unchecked(path)
		"quit":
			app.get_tree().quit()


func _save_pending_city_exit() -> void:
	if pending_city_exit_action.is_empty():
		return

	if document_state.current_save_path.is_empty():
		pending_city_exit_waiting_for_save = true
		_open_save_dialog()

		return

	if _save_copy(document_state.current_save_path):
		_continue_pending_city_exit()


func _on_save_changes_action(action: StringName) -> void:
	if action != &"discard":
		return

	app.save_changes_dialog.hide()
	_continue_pending_city_exit()


func _cancel_pending_city_exit() -> void:
	pending_city_exit_action = ""
	pending_city_exit_path = ""
	pending_city_exit_waiting_for_save = false


func _continue_pending_city_exit() -> void:
	var action := pending_city_exit_action
	var path := pending_city_exit_path
	_cancel_pending_city_exit()
	_perform_city_exit(action, path)


func _load_city(path: String) -> void:
	_request_city_exit("load_city", path)


func _load_city_unchecked(path: String) -> void:
	if not app.assets_ready:
		return

	var document := Sc2Document.load_path(path)

	if not document.is_valid():
		app.interface._show_error(document.parse_error)

		return

	var loaded_scenario: ScenarioState

	if document.find_chunk("SCEN") != null:
		loaded_scenario = ScenarioModel.from_document(document)

		if not loaded_scenario.is_valid():
			app.interface._show_error(loaded_scenario.load_error)

			return

	app.city_session._activate_document(
		document,
		loaded_scenario,
		"Loaded %s. Map view: %s."
		% [path.get_file(), app.overlay_mode.capitalize()],
	)


func _on_save_path_selected(path: String) -> void:
	var saved := _save_copy(path)

	if saved and pending_city_exit_waiting_for_save:
		_continue_pending_city_exit()


func _on_save_dialog_canceled() -> void:
	if pending_city_exit_waiting_for_save:
		_cancel_pending_city_exit()


func _save_copy(path: String) -> bool:
	var result := CityFiles.save_copy(document_state.current_document, path, app.reference_root, app.preferences.original_compatibility)

	if not result.ok:
		app.interface._show_error(result.error)

		return false

	var output_path: String = result.path
	document_state.current_document.source_path = output_path
	document_state.current_save_path = output_path
	document_state.current_city_saved_once = true
	document_state.saved_city_snapshot = result.data.duplicate()
	app.status_label.theme_type_variation = ""
	app.status_label.text = "Saved city: %s" % output_path
	_sync_upgrade_city_option()

	return true


func _request_main_menu() -> void:
	var prompt := ConfirmationDialog.new()
	prompt.title = "Return to Main Menu"
	prompt.dialog_text = "Return to the main menu? You can use Continue City to resume this city."
	prompt.theme = AppUiTheme.current()
	prompt.min_size = Vector2i(480, 180)
	app.add_child(prompt)
	prompt.confirmed.connect(func() -> void:
		app.interface._show_main_menu()
		prompt.queue_free())
	prompt.canceled.connect(prompt.queue_free)
	prompt.popup_centered()
