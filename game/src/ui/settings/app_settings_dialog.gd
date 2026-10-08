class_name AppSettingsDialog
extends AcceptDialog
## Settings apply as soon as the player changes them. Text fields apply when
## the player presses Enter, leaves the field, or closes the dialog.

@warning_ignore_start("integer_division")

signal import_original_requested(categories: PackedStringArray)
signal update_check_requested
signal button_clicked
# the player changed a setting. read the new values with selected_values()
signal settings_changed
signal brightmaps_reload_requested
signal brightmaps_export_requested
# the player accepted the Use Defaults warning. the controls reset and save at once
signal controls_reset_requested

const CONTROLS_TAB := 3
const DATA_TAB := 4

var pack_error_label: Label
var shuffle_music_check: CheckBox
var soundfont_selector: OptionButton
var soundfont_edit: LineEdit
var soundfont_status_label: Label
var toolbar_sounds_check: CheckBox
var city_sounds_selector: OptionButton
var sound_pack_edit: LineEdit
var music_pack_edit: LineEdit
var data_pack_edit: LineEdit
var pack_name_labels: Dictionary = {}
var pack_edits: Dictionary = {}
var pack_import_buttons: Dictionary = {}
var loaded_pack_names: Dictionary = {}
var loaded_pack_paths: Dictionary = {}
var tabs: TabContainer
var folder_edit: LineEdit
var folder_row: HBoxContainer
var folder_dialog: FileDialog
var music_slider: HSlider
var effects_slider: HSlider
var dark_underground_check: CheckBox
var fullscreen_check: CheckBox
var zoom_graphics_selectors: Array[OptionButton] = []
var overview_graphics_selector: OptionButton
var theme_selector: OptionButton
var ui_scale_selector: OptionButton
var translucent_menus_check: CheckBox
var default_mayor_edit: LineEdit
var renderer_selector: OptionButton
var background_audio_check: CheckBox
var check_for_updates_check: CheckBox
var check_updates_now_button: Button
var update_status_label: Label
var controls_list: ControlsBindingList
var use_defaults_button: Button
var reset_controls_dialog: ConfirmationDialog
# true while the application fills the controls with the saved values
var loading_values := false
var visual_tab: VisualEnhancementsTab
var visual_message_dialog: AcceptDialog
var visual_change_in_progress := false


func _ready() -> void:
	hide()
	theme = AppUiTheme.current()

	get_ok_button().text = "Close"
	get_label().visible = false
	background_audio_check = %BackgroundAudioCheck
	check_for_updates_check = %CheckForUpdatesCheck
	check_updates_now_button = %CheckUpdatesNowButton
	update_status_label = %UpdateStatusLabel
	default_mayor_edit = %DefaultMayorEdit
	theme_selector = %ThemeSelector
	ui_scale_selector = %UiScaleSelector
	translucent_menus_check = %TranslucentMenusCheck
	effects_slider = %EffectsSlider
	folder_edit = %FolderEdit
	dark_underground_check = %DarkUndergroundCheck
	fullscreen_check = %FullscreenCheck
	music_pack_edit = %MusicPackEdit
	data_pack_edit = %DataPackEdit
	music_slider = %MusicSlider

	overview_graphics_selector = %OverviewGraphicsSelector
	pack_error_label = %PackErrorLabel
	renderer_selector = %RendererSelector
	shuffle_music_check = %ShuffleMusicCheck
	soundfont_selector = %SoundFontSelector
	soundfont_edit = %SoundFontEdit
	soundfont_status_label = %SoundFontStatus
	_build_soundfont_controls()
	sound_pack_edit = %SoundPackEdit
	tabs = %Tabs
	visual_tab = VisualEnhancementsTab.new()
	tabs.add_child(visual_tab)
	visual_tab.changed.connect(_notify_visual_change)
	visual_tab.reload_requested.connect(func() -> void: brightmaps_reload_requested.emit())
	visual_tab.export_requested.connect(func() -> void: brightmaps_export_requested.emit())
	toolbar_sounds_check = %ToolbarSoundsCheck
	city_sounds_selector = %CitySoundsSelector
	folder_row = folder_edit.get_parent() as HBoxContainer
	controls_list = %ControlsList
	zoom_graphics_selectors = [%Zoom25, %Zoom50, %Zoom100, %Zoom200, %Zoom300, %Zoom400]

	# acceptdialog owns the standard buttons and content placement. the tabs
	# and the Controls tab footer share one content column
	var settings_parent := get_label().get_parent()
	var content := VBoxContainer.new()
	content.name = "SettingsContent"
	settings_parent.add_child(content)
	settings_parent.move_child(content, 0)
	tabs.reparent(content)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL

	for selector in zoom_graphics_selectors + [overview_graphics_selector]:
		selector.item_selected.connect(func(_size: int) -> void:
			_update_zoom_graphics_choices())

	_bind_pack_controls("graphics", folder_edit, %GraphicsPackName, %GraphicsBrowse)
	_bind_pack_controls("sound", sound_pack_edit, %SoundPackName, %SoundBrowse)
	_bind_pack_controls("music", music_pack_edit, %MusicPackName, %MusicBrowse)
	_bind_pack_controls("data", data_pack_edit, %DataPackName, %DataBrowse)
	_watch_clicks(tabs)
	tabs.get_tab_bar().tab_clicked.connect(button_clicked.emit.unbind(1))
	_build_controls_reset(content)
	_watch_changes(tabs)
	controls_list.bindings_changed.connect(_notify_change)
	# closing the dialog applies a text field that still has focus
	visibility_changed.connect(func() -> void:
		if not visible:
			_notify_change())
	canceled.connect(button_clicked.emit)
	%ImportButton.pressed.connect(_request_original_import.bind(PackedStringArray(Sc2MediaImporter.CATEGORIES)))
	check_updates_now_button.pressed.connect(update_check_requested.emit)
	about_to_popup.connect(func() -> void:
		_fit_to_viewport()
		# Refit after popup_centered applies the content minimum size.
		call_deferred("_fit_to_viewport"))
	if get_parent() != null:
		get_parent().get_viewport().size_changed.connect(_fit_to_viewport)
	theme_changed.connect(func() -> void: call_deferred("_fit_to_viewport"))
	_fit_to_viewport()


# Use Defaults sits in its own row below the tab panel, and only the Controls
# tab shows it
func _build_controls_reset(content: VBoxContainer) -> void:
	controls_list.button_clicked.connect(button_clicked.emit)
	controls_list.attach_capture_overlay(self)
	var row := HBoxContainer.new()
	row.name = "ControlsFooter"
	row.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(row)
	use_defaults_button = Button.new()
	use_defaults_button.name = "UseDefaults"
	use_defaults_button.text = "Use Defaults"
	use_defaults_button.tooltip_text = "Return every keyboard and mouse binding to its default"
	row.add_child(use_defaults_button)
	use_defaults_button.pressed.connect(button_clicked.emit)
	use_defaults_button.pressed.connect(_confirm_use_defaults)
	visibility_changed.connect(func() -> void:
		if not visible:
			controls_list.cancel_capture())
	tabs.tab_changed.connect(_update_use_defaults)
	reset_controls_dialog = ConfirmationDialog.new()
	reset_controls_dialog.title = "Reset all controls?"
	reset_controls_dialog.dialog_text = ("All keyboard and mouse bindings will return to their default values. "
		+ "Your custom bindings will be lost.")
	reset_controls_dialog.dialog_autowrap = true
	reset_controls_dialog.ok_button_text = "Reset Controls"
	reset_controls_dialog.exclusive = true
	reset_controls_dialog.min_size = Vector2i(420, 0)
	reset_controls_dialog.confirmed.connect(controls_reset_requested.emit)
	reset_controls_dialog.confirmed.connect(button_clicked.emit)
	reset_controls_dialog.canceled.connect(button_clicked.emit)
	add_child(reset_controls_dialog)
	_update_use_defaults(tabs.current_tab)


func show_visual_message(message: String) -> void:
	if visual_message_dialog == null:
		visual_message_dialog = AcceptDialog.new()
		visual_message_dialog.title = "Visual Enhancements"
		visual_message_dialog.dialog_autowrap = true
		visual_message_dialog.exclusive = true
		visual_message_dialog.confirmed.connect(button_clicked.emit)
		visual_message_dialog.canceled.connect(button_clicked.emit)
		add_child(visual_message_dialog)
	visual_message_dialog.dialog_text = message
	visual_message_dialog.popup_centered(Vector2i(620, 220))


func _update_use_defaults(tab: int) -> void:
	use_defaults_button.get_parent().visible = tab == CONTROLS_TAB


func _confirm_use_defaults() -> void:
	controls_list.cancel_capture()
	reset_controls_dialog.popup_centered()


func _watch_clicks(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(button_clicked.emit)

	if node is OptionButton:
		node.item_selected.connect(button_clicked.emit.unbind(1))
	elif node is Slider:
		node.drag_started.connect(button_clicked.emit)
		node.gui_input.connect(_on_slider_key_input)

	for child in node.get_children():
		_watch_clicks(child)


func _watch_changes(node: Node) -> void:
	# This tab owns its control signals, including batch resets and time input.
	if node == visual_tab:
		return
	if node is CheckBox:
		node.toggled.connect(_notify_change.unbind(1))
	elif node is OptionButton:
		node.item_selected.connect(_notify_change.unbind(1))
	elif node is Slider:
		node.value_changed.connect(_notify_change.unbind(1))
	elif node is LineEdit:
		node.text_submitted.connect(_notify_change.unbind(1))
		node.focus_exited.connect(_notify_change)

	for child in node.get_children():
		_watch_changes(child)


func _notify_change() -> void:
	if not loading_values:
		settings_changed.emit()


func _notify_visual_change() -> void:
	visual_change_in_progress = true
	_notify_change()
	visual_change_in_progress = false


func _on_slider_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	for action in [&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_home", &"ui_end"]:
		if event.is_action_pressed(action, true):
			button_clicked.emit()
			return


func _fit_to_viewport() -> void:
	if get_parent() == null:
		return

	var viewport_size := Vector2i(get_parent().get_viewport().get_visible_rect().size)
	# include the embedded title bar in the 90% height allowance
	var height_limit := maxi(1, int(viewport_size.y * 0.9) - get_theme_constant("title_height"))
	max_size = Vector2i(0, height_limit)
	size = Vector2i(700, mini(500, height_limit))

	if visible:
		position = (viewport_size - size) / 2


# the import dialog selects only these pack kinds
func _request_original_import(categories: PackedStringArray) -> void:
	hide()
	import_original_requested.emit(categories)


func set_update_check_running(running: bool) -> void:
	check_updates_now_button.disabled = running
	check_updates_now_button.text = "Checking..." if running else "Check now"


# show the result of the last update check, or nothing before the first check
func set_update_status(checked_at: int, error: String) -> void:
	update_status_label.visible = checked_at > 0
	update_status_label.text = ReleaseUpdateCheck.status_text(checked_at, error)
	update_status_label.theme_type_variation = &"HelpLabel" if error.is_empty() else &"ErrorLabel"


func show_values(
	music_volume: float, effects_volume: float, fullscreen: bool,
	source := "auto", folder := "", city_renderer := "gpu", background_audio := false,
	zoom_graphics: Array = AppSettingsStore.DEFAULT_ZOOM_GRAPHICS,
) -> void:
	var was_loading := loading_values
	loading_values = true
	pack_error_label.hide()
	var normalized := AppSettingsStore.normalize_zoom_graphics(zoom_graphics, overview_graphics_selector.selected)

	for index in zoom_graphics_selectors.size():
		zoom_graphics_selectors[index].select(normalized[index])

	_update_zoom_graphics_choices()
	background_audio_check.button_pressed = background_audio
	renderer_selector.select(1 if city_renderer == "cpu" else 0)
	music_slider.value = clampf(music_volume, 0.0, 1.0) * 100.0
	effects_slider.value = clampf(effects_volume, 0.0, 1.0) * 100.0
	fullscreen_check.button_pressed = fullscreen
	folder_edit.text = pack_file_path(folder) if source == "folder" else ""
	if tabs.get_current_tab_control() != visual_tab:
		tabs.current_tab = 0

	# every tab opens at the top, not where the player left it
	for tab in tabs.get_children():
		if tab is ScrollContainer:
			(tab as ScrollContainer).scroll_vertical = 0
	# Visual settings retain the category and its scroll position for this session.

	_update_use_defaults(tabs.current_tab)
	loading_values = was_loading
	popup_centered()


# show the saved bindings
func show_control_bindings(bindings: ControlBindings) -> void:
	controls_list.show_bindings(bindings)


func selected_values() -> AppSettingsStore.Values:
	var result := AppSettingsStore.Values.new()
	result.visual_enhancements = visual_tab.selected_values()
	result.default_mayor_name = default_mayor_edit.text.strip_edges()
	result.ui_theme = "dark" if theme_selector.selected == 1 else "light"
	result.translucent_menus = translucent_menus_check.button_pressed
	result.ui_scale = AppUiScale.OPTIONS[maxi(0, ui_scale_selector.selected)]
	result.overview_graphics = overview_graphics_selector.selected
	result.toolbar_sounds = toolbar_sounds_check.button_pressed
	result.city_sounds = maxi(0, city_sounds_selector.selected)
	result.shuffle_music = shuffle_music_check.button_pressed
	result.music_soundfont = selected_soundfont()
	result.music_soundfont_path = soundfont_edit.text.strip_edges()
	result.sound_pack_folder = sound_pack_edit.text.strip_edges()
	result.music_pack_folder = music_pack_edit.text.strip_edges()
	result.data_pack_folder = data_pack_edit.text.strip_edges()
	result.zoom_graphics = _selected_zoom_graphics()
	result.background_audio = background_audio_check.button_pressed
	result.city_renderer = "cpu" if renderer_selector.selected == 1 else "gpu"
	result.music_volume = float(music_slider.value) / 100.0
	result.effects_volume = float(effects_slider.value) / 100.0
	result.dark_underground = dark_underground_check.button_pressed
	result.fullscreen = fullscreen_check.button_pressed
	result.check_for_updates = check_for_updates_check.button_pressed
	result.control_bindings = controls_list.pending.duplicate_set()
	result.graphics_source = "auto" if folder_edit.text.strip_edges().is_empty() else "folder"
	result.graphics_folder = folder_edit.text.strip_edges()

	return result


func _selected_zoom_graphics() -> Array[int]:
	var sizes: Array[int] = []

	for selector in zoom_graphics_selectors:
		sizes.append(selector.selected)

	return AppSettingsStore.normalize_zoom_graphics(sizes, overview_graphics_selector.selected)


func _update_zoom_graphics_choices() -> void:
	var sizes := _selected_zoom_graphics()

	for index in zoom_graphics_selectors.size():
		var selector := zoom_graphics_selectors[index]
		selector.select(sizes[index])

		for size_index in AppSettingsStore.GRAPHICS_SIZES.size():
			selector.set_item_disabled(size_index, size_index < (sizes[index - 1] if index > 0 else overview_graphics_selector.selected))


func _build_soundfont_controls() -> void:
	for choice in SoundFontCatalog.choices():
		soundfont_selector.add_item(SoundFontCatalog.label(choice))
		soundfont_selector.set_item_metadata(soundfont_selector.item_count - 1, choice)

	soundfont_selector.item_selected.connect(func(_index: int) -> void:
		_update_soundfont_row())
	var picker := FileDialog.new()
	picker.theme = AppUiTheme.file_dialog()
	picker.title = "Select a SoundFont"
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.filters = PackedStringArray(["*.sf2, *.sf3, *.dls ; General MIDI SoundFont"])
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.exclusive = true
	add_child(picker)
	picker.file_selected.connect(func(path: String) -> void:
		soundfont_edit.text = path
		_notify_change())
	%SoundFontBrowse.pressed.connect(func() -> void:
		picker.popup_centered_ratio(0.8))


## Shows the saved SoundFont choice and the synthesizer that plays now.
func show_soundfont(choice: String, custom_path: String, status: String) -> void:
	var normalized := SoundFontCatalog.normalize(choice)
	# a saved choice that this computer does not offer shows the default
	soundfont_selector.select(0)

	for index in soundfont_selector.item_count:
		if str(soundfont_selector.get_item_metadata(index)) == normalized:
			soundfont_selector.select(index)

	soundfont_edit.text = custom_path
	soundfont_status_label.text = status
	soundfont_status_label.visible = not status.is_empty()
	_update_soundfont_row()


func selected_soundfont() -> String:
	return str(soundfont_selector.get_item_metadata(maxi(0, soundfont_selector.selected)))


func _update_soundfont_row() -> void:
	%SoundFontRow.visible = selected_soundfont() == SoundFontCatalog.CUSTOM


func _bind_pack_controls(kind: String, edit: LineEdit, label: Label, browse: Button) -> void:
	var picker := _pack_picker(kind, edit)

	if kind == "graphics":
		folder_dialog = picker

	browse.pressed.connect(func() -> void:
		picker.popup_centered_ratio(0.8))

	# Import only this pack kind from a copy of the game.
	var import_button := Button.new()
	import_button.name = kind.capitalize() + "Import"
	import_button.text = "Import..."
	import_button.custom_minimum_size = browse.custom_minimum_size
	import_button.tooltip_text = "Import only a %s pack from your copy of SimCity 2000." % kind
	import_button.pressed.connect(_request_original_import.bind(PackedStringArray([kind])))
	browse.get_parent().add_child(import_button)
	pack_import_buttons[kind] = import_button
	pack_name_labels[kind] = label
	pack_edits[kind] = edit
	edit.placeholder_text = "Automatic (%s)" % MediaPack.default_folder(kind).path_join("pack.json")
	edit.text_changed.connect(func(_text: String) -> void:
		_refresh_pack_name(kind))


func set_loaded_pack(kind: String, pack_name: String, path: String) -> void:
	loaded_pack_names[kind] = pack_name
	loaded_pack_paths[kind] = pack_file_path(path.strip_edges())
	_refresh_pack_name(kind)


func _refresh_pack_name(kind: String) -> void:
	var edit: LineEdit = pack_edits[kind]
	var label: Label = pack_name_labels[kind]
	var matches_loaded := pack_file_path(edit.text.strip_edges()) == str(loaded_pack_paths.get(kind, ""))
	label.text = str(loaded_pack_names.get(kind, "")) if matches_loaded else ""
	label.tooltip_text = label.text


func show_pack_error(message: String) -> void:
	pack_error_label.text = message
	pack_error_label.show()
	tabs.current_tab = DATA_TAB
	(tabs.get_child(DATA_TAB) as ScrollContainer).scroll_vertical = 0
	call_deferred("popup_centered")


static func pack_file_path(value: String) -> String:
	if value.is_empty() or value.get_file() == "pack.json":
		return value

	return value.path_join("pack.json")


func _pack_picker(kind: String, edit: LineEdit) -> FileDialog:
	var picker := FileDialog.new()
	picker.theme = AppUiTheme.file_dialog()
	picker.title = "Select %s pack.json" % kind
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.filters = PackedStringArray(["pack.json ; OpenSC2K pack"])
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.exclusive = true
	add_child(picker)
	picker.file_selected.connect(func(path: String) -> void:
		edit.text = path
		_notify_change())

	return picker
