class_name AppSettingsDialog
extends ConfirmationDialog

var music_slider: HSlider
var effects_slider: HSlider
var fullscreen_check: CheckBox


func _ready() -> void:
	title = "OpenSC2K Settings"
	min_size = Vector2i(520, 330)
	exclusive = true
	get_ok_button().text = "Apply"
	get_label().visible = false

	var settings_grid := GridContainer.new()
	settings_grid.columns = 2
	settings_grid.custom_minimum_size = Vector2(460, 210)
	settings_grid.add_theme_constant_override("h_separation", 14)
	settings_grid.add_theme_constant_override("v_separation", 14)
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
	var display_label := Label.new()
	display_label.text = "Display"
	display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	settings_grid.add_child(display_label)
	fullscreen_check = CheckBox.new()
	fullscreen_check.text = "Fullscreen"
	settings_grid.add_child(fullscreen_check)
	var settings_parent := get_label().get_parent()
	settings_parent.add_child(settings_grid)
	settings_parent.move_child(settings_grid, 0)


func show_values(music_volume: float, effects_volume: float, fullscreen: bool) -> void:
	music_slider.value = clampf(music_volume, 0.0, 1.0) * 100.0
	effects_slider.value = clampf(effects_volume, 0.0, 1.0) * 100.0
	fullscreen_check.button_pressed = fullscreen
	popup_centered()


func selected_values() -> Dictionary:
	return {
		"music_volume": float(music_slider.value) / 100.0,
		"effects_volume": float(effects_slider.value) / 100.0,
		"fullscreen": fullscreen_check.button_pressed,
	}
