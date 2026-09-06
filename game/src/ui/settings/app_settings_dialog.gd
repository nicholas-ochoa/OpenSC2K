class_name AppSettingsDialog
extends ConfirmationDialog

@warning_ignore_start("integer_division")

signal import_original_requested

var pack_error_label: Label
var original_compatibility_check: CheckBox
var warn_sc2x_conversion_check: CheckBox
var compatibility_error_label: Label
var shuffle_music_check: CheckBox
var toolbar_sounds_check: CheckBox
var sound_pack_edit: LineEdit
var music_pack_edit: LineEdit
var pack_name_labels: Dictionary = {}
var pack_edits: Dictionary = {}
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
var translucent_menus_check: CheckBox
var default_mayor_edit: LineEdit
var renderer_selector: OptionButton
var moving_frame_rate_selector: OptionButton
var background_audio_check: CheckBox


func _ready() -> void:
	# visible in the editor, closed at startup
	hide()
	theme = AppUiTheme.current()

	get_ok_button().text = "Save Changes"
	var button_row := get_ok_button().get_parent()
	var cancel_index := get_cancel_button().get_index()
	button_row.move_child(get_cancel_button(), get_ok_button().get_index())
	button_row.move_child(get_ok_button(), cancel_index)
	get_label().visible = false
	background_audio_check = %BackgroundAudioCheck
	compatibility_error_label = %CompatibilityErrorLabel
	default_mayor_edit = %DefaultMayorEdit
	theme_selector = %ThemeSelector
	translucent_menus_check = %TranslucentMenusCheck
	effects_slider = %EffectsSlider
	folder_edit = %FolderEdit
	dark_underground_check = %DarkUndergroundCheck
	fullscreen_check = %FullscreenCheck
	music_pack_edit = %MusicPackEdit
	music_slider = %MusicSlider
	original_compatibility_check = %OriginalCompatibilityCheck

	overview_graphics_selector = %OverviewGraphicsSelector
	pack_error_label = %PackErrorLabel
	renderer_selector = %RendererSelector
	moving_frame_rate_selector = %MovingFrameRateSelector
	shuffle_music_check = %ShuffleMusicCheck
	sound_pack_edit = %SoundPackEdit
	tabs = %Tabs
	toolbar_sounds_check = %ToolbarSoundsCheck
	warn_sc2x_conversion_check = %WarnSc2xConversionCheck
	folder_row = folder_edit.get_parent() as HBoxContainer
	zoom_graphics_selectors = [%Zoom25, %Zoom50, %Zoom100, %Zoom200, %Zoom300, %Zoom400]

	# acceptdialog owns the standard buttons and content placement
	var settings_parent := get_label().get_parent()

	if tabs.get_parent() != settings_parent:
		tabs.reparent(settings_parent)

	settings_parent.move_child(tabs, 0)

	for selector in zoom_graphics_selectors + [overview_graphics_selector]:
		selector.item_selected.connect(func(_size: int) -> void:
			_update_zoom_graphics_choices())

	_bind_pack_controls("graphics", folder_edit, %GraphicsPackName, %GraphicsBrowse)
	_bind_pack_controls("sound", sound_pack_edit, %SoundPackName, %SoundBrowse)
	_bind_pack_controls("music", music_pack_edit, %MusicPackName, %MusicBrowse)
	%ImportButton.pressed.connect(_request_original_import)
	about_to_popup.connect(_fit_to_viewport)
	if get_parent() != null:
		get_parent().get_viewport().size_changed.connect(_fit_to_viewport)
	theme_changed.connect(func() -> void: call_deferred("_fit_to_viewport"))
	_fit_to_viewport()


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


func _request_original_import() -> void:
	hide()
	import_original_requested.emit()


func show_values(
	music_volume: float, effects_volume: float, fullscreen: bool,
	source := "auto", folder := "", city_renderer := "gpu", background_audio := false, zoom_graphics: Array = AppSettingsStore.DEFAULT_ZOOM_GRAPHICS,
) -> void:
	pack_error_label.hide()
	compatibility_error_label.hide()
	var normalized := AppSettingsStore.normalize_zoom_graphics(zoom_graphics)

	for index in zoom_graphics_selectors.size():
		zoom_graphics_selectors[index].select(normalized[index])

	_update_zoom_graphics_choices()
	background_audio_check.button_pressed = background_audio
	renderer_selector.select(1 if city_renderer == "cpu" else 0)
	music_slider.value = clampf(music_volume, 0.0, 1.0) * 100.0
	effects_slider.value = clampf(effects_volume, 0.0, 1.0) * 100.0
	fullscreen_check.button_pressed = fullscreen
	folder_edit.text = pack_file_path(folder) if source == "folder" else ""
	tabs.current_tab = 0
	popup_centered()


func selected_values() -> AppSettingsStore.Values:
	var result := AppSettingsStore.Values.new()
	result.default_mayor_name = default_mayor_edit.text.strip_edges()
	result.ui_theme = "dark" if theme_selector.selected == 1 else "light"
	result.translucent_menus = translucent_menus_check.button_pressed
	result.overview_graphics = overview_graphics_selector.selected
	result.original_compatibility = original_compatibility_check.button_pressed
	result.warn_sc2x_conversion = warn_sc2x_conversion_check.button_pressed
	result.toolbar_sounds = toolbar_sounds_check.button_pressed
	result.shuffle_music = shuffle_music_check.button_pressed
	result.sound_pack_folder = sound_pack_edit.text.strip_edges()
	result.music_pack_folder = music_pack_edit.text.strip_edges()
	result.zoom_graphics = _selected_zoom_graphics()
	result.background_audio = background_audio_check.button_pressed
	result.city_renderer = "cpu" if renderer_selector.selected == 1 else "gpu"
	result.moving_frame_rate = moving_frame_rate_selector.get_selected_id()
	result.music_volume = float(music_slider.value) / 100.0
	result.effects_volume = float(effects_slider.value) / 100.0
	result.dark_underground = dark_underground_check.button_pressed
	result.fullscreen = fullscreen_check.button_pressed
	result.graphics_source = "auto" if folder_edit.text.strip_edges().is_empty() else "folder"
	result.graphics_folder = folder_edit.text.strip_edges()

	return result


func select_moving_frame_rate(rate: int) -> void:
	moving_frame_rate_selector.select(moving_frame_rate_selector.get_item_index(
		AppSettingsStore.normalize_moving_frame_rate(rate)
	))


func _selected_zoom_graphics() -> Array[int]:
	var sizes: Array[int] = []

	for selector in zoom_graphics_selectors:
		sizes.append(selector.selected)

	return AppSettingsStore.normalize_zoom_graphics(sizes)


func _update_zoom_graphics_choices() -> void:
	var sizes := _selected_zoom_graphics()

	for index in zoom_graphics_selectors.size():
		var selector := zoom_graphics_selectors[index]
		selector.select(sizes[index])

		for size_index in AppSettingsStore.GRAPHICS_SIZES.size():
			selector.set_item_disabled(size_index, index > 0 and size_index < sizes[index - 1])


func _bind_pack_controls(kind: String, edit: LineEdit, label: Label, browse: Button) -> void:
	var picker := _pack_picker(kind, edit)

	if kind == "graphics":
		folder_dialog = picker

	browse.pressed.connect(func() -> void:
		picker.popup_centered_ratio(0.8))
	pack_name_labels[kind] = label
	pack_edits[kind] = edit
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
	tabs.current_tab = 1
	(tabs.get_child(1) as ScrollContainer).scroll_vertical = 0
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
		edit.text = path)

	return picker


func show_compatibility_error(message: String) -> void:
	compatibility_error_label.text = message
	compatibility_error_label.show()
	tabs.current_tab = 4
	call_deferred("popup_centered")
