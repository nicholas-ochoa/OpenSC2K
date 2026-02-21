class_name AppSettingsDialog
extends ConfirmationDialog

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
var fullscreen_check: CheckBox
var zoom_graphics_selectors: Array[OptionButton] = []
var zoom_graphics_counts: Array[Label] = []
var graphics_availability: Dictionary = {}
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
	var settings_grid := _add_settings_tab("Audio", true)
	pack_error_label = Label.new()
	pack_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pack_error_label.add_theme_color_override("font_color", Color("800000"))
	pack_error_label.hide()
	settings_grid.get_parent().add_child(pack_error_label)
	settings_grid.get_parent().move_child(pack_error_label, 0)
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
	settings_grid.add_child(Label.new())
	toolbar_sounds_check = CheckBox.new()
	toolbar_sounds_check.text = "Play toolbar sounds"
	toolbar_sounds_check.button_pressed = true
	settings_grid.add_child(toolbar_sounds_check)
	settings_grid.add_child(Label.new())
	shuffle_music_check = CheckBox.new()
	shuffle_music_check.text = "Shuffle all music"
	shuffle_music_check.tooltip_text = "Play all 19 tracks, including menu and special music, once per shuffle cycle."
	settings_grid.add_child(shuffle_music_check)
	sound_pack_edit = _pack_folder_row(settings_grid, "Sound Pack", "sound")
	music_pack_edit = _pack_folder_row(settings_grid, "Music Pack", "music")
	settings_grid = display_grid
	var display_label := Label.new()
	display_label.text = "Display"
	display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	settings_grid.add_child(display_label)
	fullscreen_check = CheckBox.new()
	fullscreen_check.text = "Fullscreen"
	settings_grid.add_child(fullscreen_check)
	var renderer_label := Label.new()
	renderer_label.text = "Renderer"
	settings_grid.add_child(renderer_label)
	renderer_selector = OptionButton.new()
	renderer_selector.add_item("GPU (recommended)")
	renderer_selector.add_item("CPU")
	renderer_selector.tooltip_text = "Use this renderer now and for new cities. If GPU setup fails, use the CPU renderer."
	settings_grid.add_child(renderer_selector)
	renderer_selector.item_selected.connect(func(_index: int) -> void: _update_graphics_counts())
	settings_grid = _add_settings_tab("Graphics", true)
	var zoom_grid := GridContainer.new()
	zoom_grid.columns = 4
	zoom_grid.add_theme_constant_override("h_separation", 12)
	zoom_grid.add_theme_constant_override("v_separation", 14)
	settings_grid.get_parent().add_child(zoom_grid)
	settings_grid.get_parent().move_child(zoom_grid, 0)
	zoom_graphics_selectors.resize(6)
	zoom_graphics_counts.resize(6)
	for zoom_index in [0, 3, 1, 4, 2, 5]:
		var zoom_label := Label.new()
		zoom_label.text = "%d%% zoom" % AppSettingsStore.GRAPHICS_ZOOMS[zoom_index]
		zoom_grid.add_child(zoom_label)
		var selector := OptionButton.new()
		for size_name: String in AppSettingsStore.GRAPHICS_SIZES:
			selector.add_item(size_name)
		selector.tooltip_text = "Higher zoom levels must use the same graphics size or a larger size."
		selector.item_selected.connect(func(_size: int) -> void: _update_zoom_graphics_choices())
		zoom_graphics_selectors[zoom_index] = selector
		var zoom_row := HBoxContainer.new()
		zoom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zoom_row.add_child(selector)
		var count_label := Label.new()
		count_label.add_theme_color_override("font_color", Color("606060"))
		zoom_graphics_counts[zoom_index] = count_label
		zoom_row.add_child(count_label)
		zoom_grid.add_child(zoom_row)
	folder_edit = _pack_folder_row(settings_grid, "Graphics pack", "graphics")
	folder_row = folder_edit.get_parent() as HBoxContainer
	settings_grid = _add_settings_tab("Import Data")
	var import_label := Label.new()
	import_label.text = "Original Data"
	settings_grid.add_child(import_label)
	var import_button := Button.new()
	import_button.text = "Import SimCity 2000..."
	import_button.pressed.connect(func() -> void:
		hide()
		import_original_requested.emit()
	)
	settings_grid.add_child(import_button)
	var compatibility_grid := _add_settings_tab("Compatibility")
	compatibility_grid.columns = 1
	original_compatibility_check = CheckBox.new()
	original_compatibility_check.text = "Original SimCity 2000 compatibility"
	compatibility_grid.add_child(original_compatibility_check)
	var explanation := Label.new()
	explanation.text = "• Use original SC2 cities and SCN scenarios.\n• New cities use the original 128 × 128 map and data grids.\n• Larger maps and per-tile data maps are disabled.\n• Fire uses the original update timing.\n• Opening an SC2X city turns this option off automatically.\n• SC2X cities cannot return to original compatibility.\n• Graphics, audio, and interface improvements remain available."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.custom_minimum_size.x = 560
	compatibility_grid.add_child(explanation)
	warn_sc2x_conversion_check = CheckBox.new()
	warn_sc2x_conversion_check.text = "Warn before converting an SC2 city to SC2X"
	warn_sc2x_conversion_check.button_pressed = true
	compatibility_grid.add_child(warn_sc2x_conversion_check)
	compatibility_error_label = Label.new()
	compatibility_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	compatibility_error_label.custom_minimum_size.x = 560
	compatibility_error_label.add_theme_color_override("font_color", Color("800000"))
	compatibility_error_label.hide()
	compatibility_grid.add_child(compatibility_error_label)



func _add_settings_tab(tab_title: String, scrollable := false) -> GridContainer:
	var page := VBoxContainer.new()
	page.name = tab_title
	page.add_theme_constant_override("separation", 16)
	if scrollable:
		var scroll := ScrollContainer.new()
		scroll.name = tab_title
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(page)
	else:
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
	_update_graphics_counts()
	tabs.current_tab = 0
	popup_centered()


func selected_values() -> Dictionary:
	return {
		"original_compatibility": original_compatibility_check.button_pressed,
		"warn_sc2x_conversion": warn_sc2x_conversion_check.button_pressed,
		"toolbar_sounds": toolbar_sounds_check.button_pressed,
		"shuffle_music": shuffle_music_check.button_pressed,
		"sound_pack_folder": sound_pack_edit.text.strip_edges(),
		"music_pack_folder": music_pack_edit.text.strip_edges(),
		"zoom_graphics": _selected_zoom_graphics(),
		"background_audio": background_audio_check.button_pressed,
		"city_renderer": "cpu" if renderer_selector.selected == 1 else "gpu",
		"music_volume": float(music_slider.value) / 100.0,
		"effects_volume": float(effects_slider.value) / 100.0,
		"fullscreen": fullscreen_check.button_pressed,
		"graphics_source": "auto" if folder_edit.text.strip_edges().is_empty() else "folder",
		"graphics_folder": folder_edit.text.strip_edges(),
	}


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

	_update_graphics_counts()


func _update_graphics_counts() -> void:
	if graphics_availability.is_empty():
		return
	for index in zoom_graphics_counts.size():
		var size_index := zoom_graphics_selectors[index].selected
		var counts: Dictionary = graphics_availability.sizes[size_index]
		var label := zoom_graphics_counts[index]
		label.text = "%d / %d valid" % [counts.valid, counts.total]
		label.tooltip_text = "Valid images in the selected graphics size. Missing images use original artwork."


func _pack_folder_row(grid: GridContainer, caption: String, kind: String) -> LineEdit:
	var label := Label.new()
	label.text = caption
	grid.add_child(label)
	var row := HBoxContainer.new()
	grid.add_child(row)
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.placeholder_text = "Automatic (user://packs/%s/pack.json)" % kind
	row.add_child(edit)
	var browse := Button.new()
	browse.text = "Browse..."
	row.add_child(browse)
	var picker := _pack_picker(kind, edit)
	if kind == "graphics":
		folder_dialog = picker
	browse.pressed.connect(func() -> void: picker.popup_centered_ratio(0.8))
	var pack_name := Label.new()
	pack_name.custom_minimum_size.x = 150
	pack_name.clip_text = true
	pack_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pack_name.add_theme_color_override("font_color", Color("606060"))
	row.add_child(pack_name)
	pack_name_labels[kind] = pack_name
	pack_edits[kind] = edit
	edit.text_changed.connect(func(_text: String) -> void: _refresh_pack_name(kind))
	return edit


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
	picker.title = "Select %s pack.json" % kind
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.filters = PackedStringArray(["pack.json ; OpenSC2K pack"])
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.exclusive = true
	add_child(picker)
	picker.file_selected.connect(func(path: String) -> void: edit.text = path)
	return picker


func show_compatibility_error(message: String) -> void:
	compatibility_error_label.text = message
	compatibility_error_label.show()
	tabs.current_tab = 4
	call_deferred("popup_centered")
