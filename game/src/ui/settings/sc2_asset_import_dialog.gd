class_name Sc2AssetImportDialog
extends Window


signal packs_imported(result: Sc2MediaImportResult)
signal dismissed

var packs_root := "user://packs"
var source_edit: LineEdit
var graphics_check: CheckBox
var sound_check: CheckBox
var music_check: CheckBox
var import_button: Button
var close_button: Button
var result_text: TextEdit
var browser: FileDialog
var busy := false
var last_result: Sc2MediaImportResult
var _worker: Thread
var _activation_notes := PackedStringArray()


func _ready() -> void:
	hide()
	theme = AppUiTheme.current()
	source_edit = %SourceEdit
	graphics_check = %GraphicsCheck
	sound_check = %SoundCheck
	music_check = %MusicCheck
	import_button = %ImportButton
	close_button = %CloseButton
	result_text = %ResultText
	close_requested.connect(_close)
	close_button.pressed.connect(_close)
	import_button.pressed.connect(start_import)
	source_edit.text_submitted.connect(func(_text: String) -> void: start_import())
	source_edit.text_changed.connect(func(_text: String) -> void: _update_import_button())

	for check in [graphics_check, sound_check, music_check]:
		check.toggled.connect(func(_enabled: bool) -> void: _update_import_button())

	browser = FileDialog.new()
	browser.title = "Select SimCity 2000 game files"
	browser.access = FileDialog.ACCESS_FILESYSTEM
	browser.exclusive = true
	browser.theme = AppUiTheme.file_dialog()
	browser.file_selected.connect(_select_source)
	browser.dir_selected.connect(_select_source)
	add_child(browser)
	%BrowseFolder.pressed.connect(_browse.bind(FileDialog.FILE_MODE_OPEN_DIR))
	%BrowseFile.pressed.connect(_browse.bind(FileDialog.FILE_MODE_OPEN_FILE))
	_set_busy(false)
	set_process(false)


func open() -> void:
	theme = AppUiTheme.current()
	browser.theme = AppUiTheme.file_dialog()
	popup_centered(Vector2i(720, 520))
	source_edit.grab_focus()


func selected_categories() -> PackedStringArray:
	var categories := PackedStringArray()

	if graphics_check.button_pressed:
		categories.append("graphics")
	if sound_check.button_pressed:
		categories.append("sound")
	if music_check.button_pressed:
		categories.append("music")

	return categories


func start_import() -> void:
	if busy:
		return

	var source := source_edit.text.strip_edges()
	var categories := selected_categories()

	if source.is_empty() or categories.is_empty():
		result_text.text = "Choose a game folder or file and at least one asset type."
		return

	last_result = null
	_activation_notes.clear()
	result_text.text = "Reading game files and creating packs…"
	_set_busy(true)
	_worker = Thread.new()
	var error := _worker.start(Sc2MediaImporter.import_assets.bind(source, ProjectSettings.globalize_path(packs_root), categories))

	if error != OK:
		_worker = null
		_set_busy(false)
		result_text.text = "Cannot start the import: " + error_string(error)
		return

	set_process(true)


func _process(_delta: float) -> void:
	if _worker == null or _worker.is_alive():
		return

	last_result = _worker.wait_to_finish() as Sc2MediaImportResult
	_worker = null
	set_process(false)
	_set_busy(false)

	if last_result == null:
		result_text.text = "The import did not return a result."
		return

	if last_result.ok:
		packs_imported.emit(last_result)

	var heading := "Import complete." if last_result.ok else "Import failed."

	if last_result.ok and last_result.partial:
		heading = "Import finished. Some assets are missing or need attention."

	result_text.text = heading + "\n\n" + last_result.summary()

	if not last_result.root.is_empty():
		result_text.text += "\n\nSaved packs: " + last_result.root

	if not _activation_notes.is_empty():
		result_text.text += "\n\n" + "\n".join(_activation_notes)


func add_activation_notes(notes: PackedStringArray) -> void:
	_activation_notes.append_array(notes)


func _set_busy(value: bool) -> void:
	busy = value
	source_edit.editable = not busy
	close_button.disabled = busy
	%BrowseFolder.disabled = busy
	%BrowseFile.disabled = busy
	%Progress.visible = busy
	%BusyLabel.visible = busy

	for check in [graphics_check, sound_check, music_check]:
		check.disabled = busy

	_update_import_button()


func _update_import_button() -> void:
	import_button.disabled = busy or source_edit.text.strip_edges().is_empty() or selected_categories().is_empty()


func _browse(mode: FileDialog.FileMode) -> void:
	if busy:
		return

	browser.file_mode = mode
	browser.current_file = ""
	browser.popup_centered_ratio(0.8)


func _select_source(path: String) -> void:
	source_edit.text = path
	_update_import_button()
	import_button.grab_focus()


func _close() -> void:
	if busy:
		return

	hide()
	dismissed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not browser.visible:
		_close()
		set_input_as_handled()


func _exit_tree() -> void:
	# a shutdown must not abandon a running writer or free its thread handle
	if _worker != null and _worker.is_started():
		_worker.wait_to_finish()
