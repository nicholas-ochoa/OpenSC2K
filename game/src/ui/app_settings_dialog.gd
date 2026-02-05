class_name AppSettingsDialog
extends ConfirmationDialog

signal import_original_requested

var tabs: TabContainer
var source_selector: OptionButton
var folder_edit: LineEdit
var folder_row: HBoxContainer
var folder_dialog: FileDialog
var active_source_label: Label

var soundtrack_edit: LineEdit
var soundtrack_dialog: FileDialog
var soundtrack_status: Label
var automatic_soundtrack_folder := ""

var music_slider: HSlider
var effects_slider: HSlider
var fullscreen_check: CheckBox
var renderer_selector: OptionButton
var background_audio_check: CheckBox


func _ready() -> void:
	title = "OpenSC2K Settings"
	theme = ClassicUiStyle.create_dialog_theme()
	min_size = Vector2i(700, 500)
	exclusive = true
	get_ok_button().text = "Apply"
	get_label().visible = false

	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(660, 350)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_stylebox_override("panel", ClassicUiStyle.create_box(Color("eceeea"), Color("808080"), 1, 16, 16))
	for state in ["selected", "unselected", "hovered"]:
		tabs.add_theme_stylebox_override("tab_" + state, ClassicUiStyle.create_box(Color("eceeea") if state == "selected" else Color("d2d5d2"), Color("808080"), 1, 14, 8))
		tabs.add_theme_color_override("font_" + state + "_color", Color("202830"))
	var settings_parent := get_label().get_parent()
	settings_parent.add_child(tabs)
	settings_parent.move_child(tabs, 0)
	var display_grid := _add_settings_tab("Display")
	var settings_grid := _add_settings_tab("Audio")
	for label_text in ["Music Volume", "Sound Effects Volume"]:
		var label := Label.new()
		label.text = label_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		settings_grid.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size = Vector2(250, 32)
		settings_grid.add_child(slider)
		if label_text == "Music Volume":
			music_slider = slider
		else:
			effects_slider = slider
	settings_grid.add_child(Label.new())
	background_audio_check = CheckBox.new()
	background_audio_check.text = "Play music and sounds in background"
	settings_grid.add_child(background_audio_check)
	var soundtrack_label := Label.new()
	soundtrack_label.text = "Soundtrack folder"
	settings_grid.add_child(soundtrack_label)
	var soundtrack_row := HBoxContainer.new()
	soundtrack_edit = LineEdit.new()
	soundtrack_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	soundtrack_edit.placeholder_text = "Automatic (OST in original-data folder)"
	soundtrack_edit.text_changed.connect(func(_text: String) -> void: _update_soundtrack_status())
	soundtrack_row.add_child(soundtrack_edit)
	var soundtrack_browse := Button.new()
	soundtrack_browse.text = "Browse..."
	soundtrack_browse.pressed.connect(func() -> void:
		var folder := soundtrack_edit.text.strip_edges()
		if folder.is_empty():
			folder = automatic_soundtrack_folder
		if DirAccess.dir_exists_absolute(folder):
			soundtrack_dialog.current_dir = folder
		soundtrack_dialog.popup_centered_ratio(0.8)
	)
	soundtrack_row.add_child(soundtrack_browse)
	settings_grid.add_child(soundtrack_row)
	settings_grid.add_child(Label.new())
	soundtrack_status = Label.new()
	soundtrack_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	soundtrack_status.custom_minimum_size.x = 350
	settings_grid.add_child(soundtrack_status)
	soundtrack_dialog = FileDialog.new()
	soundtrack_dialog.title = "Select soundtrack folder (MP3, FLAC or Ogg Vorbis)"
	soundtrack_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	soundtrack_dialog.access = FileDialog.ACCESS_FILESYSTEM
	soundtrack_dialog.exclusive = true
	soundtrack_dialog.dir_selected.connect(func(path: String) -> void:
		soundtrack_edit.text = path
		_update_soundtrack_status()
	)
	add_child(soundtrack_dialog)
	settings_grid = display_grid
	var display_label := Label.new()
	display_label.text = "Display"
	display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	settings_grid.add_child(display_label)
	fullscreen_check = CheckBox.new()
	fullscreen_check.text = "Fullscreen"
	settings_grid.add_child(fullscreen_check)
	var renderer_label := Label.new()
	renderer_label.text = "Default city renderer"
	settings_grid.add_child(renderer_label)
	renderer_selector = OptionButton.new()
	renderer_selector.add_item("GPU (recommended)")
	renderer_selector.add_item("CPU")
	renderer_selector.tooltip_text = "Use this renderer now and for new cities. If GPU setup fails, use the CPU renderer."
	settings_grid.add_child(renderer_selector)
	settings_grid = _add_settings_tab("Graphics")
	var source_label := Label.new()
	source_label.text = "Graphics"
	settings_grid.add_child(source_label)
	source_selector = OptionButton.new()
	source_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for text in ["Automatic", "SimCity 2000", "Graphics pack folder"]:
		source_selector.add_item(text)
	source_selector.item_selected.connect(func(_index: int) -> void: _update_folder_visibility())
	settings_grid.add_child(source_selector)
	var folder_label := Label.new()
	folder_label.text = "Pack folder"
	settings_grid.add_child(folder_label)
	folder_row = HBoxContainer.new()
	folder_edit = LineEdit.new()
	folder_edit.placeholder_text = "Folder containing pack.json"
	folder_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	folder_row.add_child(folder_edit)
	var browse_button := Button.new()
	browse_button.text = "Browse..."
	browse_button.pressed.connect(func() -> void: folder_dialog.popup_centered_ratio(0.8))
	folder_row.add_child(browse_button)
	settings_grid.add_child(folder_row)
	folder_row.set_meta("label", folder_label)
	var import_label := Label.new()
	import_label.text = "Original data"
	settings_grid.add_child(import_label)
	var import_button := Button.new()
	import_button.text = "Import SimCity 2000..."
	import_button.pressed.connect(func() -> void:
		hide()
		import_original_requested.emit()
	)
	settings_grid.add_child(import_button)
	active_source_label = Label.new()
	active_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_source_label.custom_minimum_size.x = 590
	var note := Label.new()
	note.text = "Restart OpenSC2K to use a different graphics source."
	folder_dialog = FileDialog.new()
	folder_dialog.title = "Select a graphics pack folder"
	folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	folder_dialog.exclusive = true
	folder_dialog.dir_selected.connect(func(path: String) -> void: folder_edit.text = path)
	add_child(folder_dialog)
	var graphics_page := settings_grid.get_parent()
	graphics_page.add_child(active_source_label)
	graphics_page.add_child(note)


func _add_settings_tab(tab_title: String) -> GridContainer:
	var page := VBoxContainer.new()
	page.name = tab_title
	page.add_theme_constant_override("separation", 16)
	tabs.add_child(page)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	page.add_child(grid)
	return grid


func show_values(
	music_volume: float, effects_volume: float, fullscreen: bool,
	source := "auto", folder := "", active_name := "",
	soundtrack_folder := "", automatic_folder := "", city_renderer := "gpu", background_audio := false,
) -> void:
	background_audio_check.button_pressed = background_audio
	renderer_selector.select(1 if city_renderer == "cpu" else 0)
	automatic_soundtrack_folder = automatic_folder
	soundtrack_edit.text = soundtrack_folder
	_update_soundtrack_status()
	music_slider.value = clampf(music_volume, 0.0, 1.0) * 100.0
	effects_slider.value = clampf(effects_volume, 0.0, 1.0) * 100.0
	fullscreen_check.button_pressed = fullscreen
	source_selector.select(maxi(0, GameAssetSource.MODES.find(source)))
	folder_edit.text = folder
	active_source_label.text = "Active graphics: " + active_name
	active_source_label.visible = not active_name.is_empty()
	_update_folder_visibility()
	tabs.current_tab = 0
	popup_centered()


func selected_values() -> Dictionary:
	return {
		"background_audio": background_audio_check.button_pressed,
		"soundtrack_folder": soundtrack_edit.text.strip_edges(),
		"city_renderer": "cpu" if renderer_selector.selected == 1 else "gpu",
		"music_volume": float(music_slider.value) / 100.0,
		"effects_volume": float(effects_slider.value) / 100.0,
		"fullscreen": fullscreen_check.button_pressed,
		"graphics_source": GameAssetSource.MODES[source_selector.selected],
		"graphics_folder": folder_edit.text.strip_edges(),
	}


func _update_folder_visibility() -> void:
	var show_folder: bool = GameAssetSource.MODES[source_selector.selected] == "folder"
	folder_row.visible = show_folder
	(folder_row.get_meta("label") as Label).visible = show_folder


func _update_soundtrack_status() -> void:
	var folder := soundtrack_edit.text.strip_edges()
	if folder.is_empty():
		folder = automatic_soundtrack_folder
	var tracks := 0
	if DirAccess.dir_exists_absolute(folder):
		for track_id in range(MusicDirector.FIRST_TRACK_ID, MusicDirector.FIRST_TRACK_ID + MusicDirector.TRACK_COUNT):
			if not RecordedSoundtrack.find_tracks(folder, track_id).is_empty():
				tracks += 1
	soundtrack_status.text = "%d of 19 recordings found. Missing tracks use MIDI.\nChanges take effect when you apply. Leave blank for automatic selection." % tracks
	soundtrack_status.tooltip_text = "Folder: " + folder
