class_name ApplicationCityFiles
extends RefCounted

const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityFiles = preload("res://src/formats/city_file_store.gd")
const ScenarioModel = preload("res://src/model/scenario_state.gd")
# a larger SC2X city compresses and writes its save on a worker thread
const BACKGROUND_SAVE_EDGE := 256
# a city load that takes longer than this shows the busy box
const BUSY_DELAY_SEC := 0.15

var app: CityApplication
var document_state: ActiveDocumentState
var pending_city_exit_action := ""
var pending_city_exit_path := ""
var pending_city_exit_waiting_for_save := false
var pending_sc2x_document: Sc2File
var save_in_progress := false
var save_task_id := -1
var load_in_progress := false
var load_task_id := -1
var load_serial := 0


func _init(application: CityApplication) -> void:
	app = application
	document_state = application.document_state


func open_city_dialog() -> void:
	if not app.asset_state.assets_ready:
		return

	var city_directory := AppPaths.path("cities")

	if DirAccess.dir_exists_absolute(city_directory):
		app.city_dialogs.city_open_dialog.current_dir = city_directory
	elif DirAccess.dir_exists_absolute(app.asset_state.reference_root.path_join("CITIES")):
		app.city_dialogs.city_open_dialog.current_dir = app.asset_state.reference_root.path_join("CITIES")

	app.city_dialogs.city_open_dialog.popup_centered_ratio(0.8)


func open_scenario_dialog() -> void:
	if not app.asset_state.assets_ready:
		return

	var scenario_directory := AppPaths.path("scenarios")

	if DirAccess.dir_exists_absolute(scenario_directory):
		app.city_dialogs.city_open_dialog.current_dir = scenario_directory
	elif DirAccess.dir_exists_absolute(app.asset_state.reference_root.path_join("SCENARIO")):
		app.city_dialogs.city_open_dialog.current_dir = app.asset_state.reference_root.path_join("SCENARIO")

	app.city_dialogs.city_open_dialog.popup_centered_ratio(0.8)


func save_city() -> void:
	if document_state.current_document == null:
		return

	if document_state.current_save_path.is_empty():
		open_save_dialog()
	else:
		_save_copy(document_state.current_save_path)


func open_rename_dialog() -> void:
	if document_state.current_document == null or app.document_state.city == null:
		return

	app.city_dialogs.city_rename_dialog.set_max_length(document_state.current_document.city_name_limit())
	app.city_dialogs.city_rename_dialog.show_name(app.document_state.city.city_name())


# an sc2 name holds 30 ASCII characters, and a file without CNAM gets one.
# an sc2x version 4 name holds 64 characters in metadata
func rename_city() -> void:
	var document := document_state.current_document

	if document == null or app.document_state.city == null:
		return

	var city_name := app.city_dialogs.city_rename_dialog.entered_name()

	if city_name.is_empty():
		return

	document.add_city_name_chunk()

	if not document.set_city_name(city_name):
		app.interface.show_error("Cannot store the city name.")

		return

	app.city_menu_bar.set_city_name(app.document_state.city.display_name(),
		DebugFileInfo.city_tooltip(app.document_state.city.display_name(), app.document_state.current_document))
	app.reports.refresh_newspaper_menu()
	app.status_label.theme_type_variation = ""
	app.status_label.text = tr("City renamed to %s.") % app.document_state.city.city_name()
	app.scripting.emit("city.renamed", {"name": app.document_state.city.city_name()})


func _can_upgrade_city_to_sc2x() -> bool:
	if (app.tool_state.landscape_editor or app.document_state.city == null
			or document_state.current_document == null or app.simulation_state.simulation_engine == null):
		return false

	if document_state.current_document.is_extended() or document_state.current_document.full_resolution_maps():
		return false

	if not Sc2xCheckpoint.save_error(app.simulation_state.speed_controller).is_empty():
		return false

	var path := (document_state.current_save_path if not document_state.current_save_path.is_empty()
		else document_state.current_document.source_path)

	return path.get_extension().to_lower() == "sc2"


func sync_upgrade_city_option() -> void:
	if app.options_menu == null:
		return

	var popup := app.options_menu.get_popup()
	var index := popup.get_item_index(CityMenuBar.MENU_UPGRADE_SC2X)
	var available := _can_upgrade_city_to_sc2x()

	if available and index < 0:
		popup.add_item("Upgrade City to SC2X", CityMenuBar.MENU_UPGRADE_SC2X)
	elif not available and index >= 0:
		popup.remove_item(index)


func upgrade_city_to_sc2x(confirmed := false) -> void:
	if not _can_upgrade_city_to_sc2x():
		return

	if not document_state.current_document.is_extended() and not confirmed:
		if app.sc2x_conversion_dialog == null:
			app.sc2x_conversion_dialog = ConfirmationDialog.new()
			app.sc2x_conversion_dialog.title = "Upgrade city to SC2X?"
			app.sc2x_conversion_dialog.dialog_text = (
				"This permanently converts this city to SC2X.\nIt cannot return to SC2 or use original compatibility.\nThe " +
				"original SimCity 2000 cannot open SC2X files.\n\nSave a separate SC2X copy. Your existing SC2 file stays " +
				"unchanged.")
			app.sc2x_conversion_dialog.get_ok_button().text = "Upgrade to SC2X"
			app.sc2x_conversion_dialog.exclusive = true
			app.sc2x_conversion_dialog.theme = AppUiTheme.current()
			app.add_child(app.sc2x_conversion_dialog)
			app.sc2x_conversion_dialog.confirmed.connect(_confirm_sc2x_conversion)
			app.sc2x_conversion_dialog.canceled.connect(func() -> void:
				pending_sc2x_document = null)

		pending_sc2x_document = document_state.current_document
		app.sc2x_conversion_dialog.popup_centered()

		return

	var source := document_state.current_document
	var converted := Sc2xDocument.from_legacy(source, source.source_path.get_file().get_basename())

	if not converted.ok:
		app.interface.show_error(tr("Cannot convert the city to SC2X: %s") % converted.error)

		return

	var document := converted.document
	document.sc2x_converted_from = source.source_path
	# the conversion carries the running engine state into the new city
	Sc2xCheckpoint.capture(app.simulation_state.speed_controller, document.sc2x_metadata)
	var status := "City upgraded to SC2X. Save a separate copy; the original game cannot open it."

	if not converted.issues.is_empty():
		status += tr(" %d links or records that SC2X cannot describe were kept unchanged.") % converted.issues.size()

	if not app.city_session.activate_document(document, _loaded_scenario(document), status, true):
		return

	document_state.current_save_path = ""
	document_state.current_city_saved_once = false
	sync_upgrade_city_option()
	open_save_dialog()


func _confirm_sc2x_conversion() -> void:
	var expected := pending_sc2x_document
	pending_sc2x_document = null

	if expected != null and document_state.current_document == expected:
		upgrade_city_to_sc2x(true)


func open_save_dialog() -> void:
	if document_state.current_document == null:
		return

	var save_directory := AppPaths.path("cities")
	DirAccess.make_dir_recursive_absolute(save_directory)
	app.city_dialogs.city_save_dialog.current_dir = save_directory
	var save_name := document_state.current_document.source_path.get_file().get_basename()

	if save_name.is_empty() and app.document_state.city != null:
		save_name = app.document_state.city.city_name().validate_filename()

	if save_name.is_empty():
		save_name = "New City"

	var document := document_state.current_document
	var sc2kfix := document.source_format == "sc2kfix"
	var sc2_filter := "*.SC2, *.sc2 ; SimCity 2000 cities"
	var sc2kfix_filter := "*.sc2x ; sc2kfix cities"

	if document.is_extended():
		app.city_dialogs.city_save_dialog.filters = PackedStringArray(["*.sc2x ; Extended cities"])
	elif sc2kfix:
		app.city_dialogs.city_save_dialog.filters = PackedStringArray([sc2kfix_filter, sc2_filter])
	else:
		app.city_dialogs.city_save_dialog.filters = PackedStringArray([sc2_filter, sc2kfix_filter])

	app.city_dialogs.city_save_dialog.current_file = save_name + (".sc2x" if document.is_extended() or sc2kfix else ".SC2")
	app.city_dialogs.city_save_dialog.popup_centered_ratio(0.8)


func _city_has_unsaved_changes() -> bool:
	if document_state.current_document == null or app.document_state.city == null:
		return false

	if not document_state.current_city_saved_once:
		return true

	var snapshot := document_state.current_document.content_snapshot()

	return snapshot.is_empty() or snapshot != document_state.saved_city_snapshot


func request_city_exit(action: String, path := "") -> void:
	if not _city_has_unsaved_changes():
		_perform_city_exit(action, path)

		return

	pending_city_exit_action = action
	pending_city_exit_path = path
	pending_city_exit_waiting_for_save = false
	var display_name := app.document_state.city.city_name()

	if display_name.is_empty():
		display_name = "this city"

	app.main_overlays.save_changes_dialog.show_city(display_name)


func _perform_city_exit(action: String, path := "") -> void:
	match action:
		"create_new_city":
			app.new_city.create_new_city_unchecked()
		"load_city":
			_load_city_in_background(path)
		"quit":
			app.get_tree().quit()


func save_pending_city_exit() -> void:
	if pending_city_exit_action.is_empty():
		return

	if document_state.current_save_path.is_empty():
		pending_city_exit_waiting_for_save = true
		open_save_dialog()

		return

	_save_copy(document_state.current_save_path, _continue_pending_city_exit)


func on_save_changes_action(action: StringName) -> void:
	if action != &"discard":
		return

	app.main_overlays.save_changes_dialog.hide()
	_continue_pending_city_exit()


func cancel_pending_city_exit() -> void:
	pending_city_exit_action = ""
	pending_city_exit_path = ""
	pending_city_exit_waiting_for_save = false


func _continue_pending_city_exit() -> void:
	var action := pending_city_exit_action
	var path := pending_city_exit_path
	cancel_pending_city_exit()
	_perform_city_exit(action, path)


func load_city(path: String) -> void:
	request_city_exit("load_city", path)


func _load_city_unchecked(path: String) -> void:
	if not app.asset_state.assets_ready:
		return

	_activate_read_city(_read_city(path))


# read the city on a worker thread. the busy box shows when the read is slow or
# the city is large, and stays until the city is active
func _load_city_in_background(path: String) -> void:
	if not app.asset_state.assets_ready or load_in_progress:
		return

	load_in_progress = true
	load_serial += 1
	var serial := load_serial
	app.get_tree().create_timer(BUSY_DELAY_SEC).timeout.connect(func() -> void:
		if load_in_progress and load_serial == serial:
			app.main_overlays.busy_overlay.show_message("Loading city…"))
	load_task_id = WorkerThreadPool.add_task(func() -> void:
		var read := _read_city(path)
		_finish_background_load.call_deferred(read))


func _finish_background_load(read: ReadCity) -> void:
	WorkerThreadPool.wait_for_task_completion(load_task_id)
	load_task_id = -1
	var busy := app.main_overlays.busy_overlay

	# activation runs on this thread. draw the box first for a large city
	if read.error.is_empty() and read.document.map_size > BACKGROUND_SAVE_EDGE and not busy.visible:
		busy.show_message("Loading city…")

	if busy.visible:
		await app.get_tree().process_frame
		await app.get_tree().process_frame

	_activate_read_city(read)
	load_in_progress = false
	busy.hide()


# the parsed document, its scenario and its status. this does not change the
# application, so a worker thread can run it
func _read_city(path: String) -> ReadCity:
	var read := ReadCity.new()
	var document := Sc2Document.load_path(path)

	if not document.is_valid():
		read.error = document.parse_error

		return read

	if not document.compatibility_error().is_empty():
		read.error = document.compatibility_error()

		return read

	read.status = tr("Loaded %s. Map view: %s.") % [path.get_file(), CityViewMode.key(app.view_state.overlay_mode).capitalize()]

	if document.source_format == "sc2kfix":
		read.status = "Loaded the sc2kfix city %s. Map view: %s." % [path.get_file(), CityViewMode.key(app.view_state.overlay_mode).capitalize()]

	if document.repaired_form_length:
		read.status += " Its file header had a zero length, which the game repaired. Save the city to a new file."

	# an SCLG city becomes an SC2X version 4 city in memory. its file stays unchanged
	if document.is_extended() and not document.is_sc2x():
		var converted := Sc2xDocument.from_legacy(document, path.get_file().get_basename())

		if not converted.ok:
			read.error = tr("Cannot convert %s to SC2X version 4: %s") % [path.get_file(), converted.error]

			return read

		converted.document.sc2x_converted_from = path
		document = converted.document
		read.status = tr("Converted %s to SC2X version 4. Save a new copy; the original file stays unchanged.") % path.get_file()

		if not converted.issues.is_empty():
			read.status += tr(" %d links or records that SC2X cannot describe were kept unchanged.") % converted.issues.size()

	read.scenario = _loaded_scenario(document)

	if read.scenario != null and not read.scenario.is_valid():
		read.error = read.scenario.load_error

		return read

	read.document = document
	read.snapshot = document.content_snapshot()

	return read


func _activate_read_city(read: ReadCity) -> void:
	if not read.error.is_empty():
		app.interface.show_error(read.error)

		return

	var document := read.document
	app.city_session.activate_document(document, read.scenario, read.status, true, read.snapshot)
	app.scurk_workspace.restore_city_tile_sets(document)

	# a converted city has no file of its own yet
	if not document.sc2x_converted_from.is_empty():
		document_state.current_save_path = ""
		document_state.current_city_saved_once = false


func _loaded_scenario(document: Sc2File) -> ScenarioState:
	if document.find_chunk("SCEN") == null:
		return null

	return ScenarioModel.from_document(document)


func on_save_path_selected(path: String) -> void:
	_save_copy(path, _continue_pending_city_exit if pending_city_exit_waiting_for_save else Callable())


func on_save_dialog_canceled() -> void:
	if pending_city_exit_waiting_for_save:
		cancel_pending_city_exit()


# Returns true when the save finished now. A larger SC2X city prepares its
# save here and writes it on a worker thread; `on_saved` runs after a
# successful save in both cases.
func _save_copy(path: String, on_saved := Callable()) -> bool:
	if save_in_progress:
		app.interface.show_error("The city is still being saved.")

		return false

	var document := document_state.current_document

	if document.is_sc2x() and document.map_size > BACKGROUND_SAVE_EDGE:
		save_in_progress = true
		_save_in_background(document, path, on_saved)

		return false

	var prepared := CityFiles.prepare(document, path, app.asset_state.reference_root, app.simulation_state.speed_controller)

	if not prepared.ok:
		app.interface.show_error(prepared.error)

		return false

	return _finish_save(document, prepared, CityFiles.write(prepared), on_saved)


# the busy box shows while the save is prepared here and written on a worker thread
func _save_in_background(document: Sc2File, path: String, on_saved: Callable) -> void:
	var busy := app.main_overlays.busy_overlay
	busy.show_message("Saving city…")

	# draw the box before the prepared snapshot holds this thread
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	var prepared := CityFiles.prepare(document, path, app.asset_state.reference_root, app.simulation_state.speed_controller)

	if not prepared.ok:
		save_in_progress = false
		busy.hide()
		app.interface.show_error(prepared.error)

		return

	app.status_label.theme_type_variation = ""
	app.status_label.text = tr("Saving city: %s") % prepared.path
	save_task_id = WorkerThreadPool.add_task(func() -> void:
		var written := CityFiles.write(prepared)
		_finish_save.call_deferred(document, prepared, written, on_saved))


func _finish_save(document: Sc2File, prepared: CityFiles.PreparedSave, result: FileWriteResult, on_saved: Callable) -> bool:
	save_in_progress = false

	if save_task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(save_task_id)
		save_task_id = -1

	if not load_in_progress:
		app.main_overlays.busy_overlay.hide()

	if not result.ok:
		app.interface.show_error(result.error)

		return false

	# the content snapshot is the saved content, even when the city changed meanwhile
	document.source_path = result.path

	if not document.is_extended():
		document.source_format = "sc2kfix" if CityFiles.uses_sc2kfix_format(document, result.path) else ""

	if document_state.current_document == document:
		document_state.current_save_path = result.path
		document_state.current_city_saved_once = true
		document_state.saved_city_snapshot = prepared.snapshot
		app.status_label.theme_type_variation = ""
		app.status_label.text = tr("Saved city: %s") % result.path
		sync_upgrade_city_option()
		app.scripting.emit("city.saved", {"path": result.path})

	if on_saved.is_valid():
		on_saved.call()

	return true


func request_main_menu() -> void:
	var prompt := ConfirmationDialog.new()
	prompt.title = "Return to Main Menu"
	prompt.dialog_text = "Return to the main menu? You can use Continue City to resume this city."
	prompt.theme = AppUiTheme.current()
	prompt.min_size = Vector2i(480, 180)
	app.add_child(prompt)
	prompt.confirmed.connect(func() -> void:
		app.interface.show_main_menu()
		prompt.queue_free())
	prompt.canceled.connect(prompt.queue_free)
	prompt.popup_centered()


class ReadCity extends RefCounted:
	var document: Sc2File
	var scenario: ScenarioState
	var status := ""
	var error := ""
	# the content of the document before activation
	var snapshot := PackedByteArray()
