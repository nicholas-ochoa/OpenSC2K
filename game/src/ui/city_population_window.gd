class_name CityPopulationWindow
extends Window

const PopulationView = preload("res://src/view/population_window_control.gd")
const ClassicStyle = preload("res://src/ui/classic_ui_style.gd")

var population_control: PopulationWindowControl
var mode_buttons: Array[CheckBox] = []


func _ready() -> void:
	name = "PopulationWindow"
	title = "Population"
	size = Vector2i(700, 450)
	min_size = Vector2i(560, 380)
	transient = true
	exclusive = false
	visible = false
	close_requested.connect(hide)

	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override(
		"panel", ClassicStyle.create_box(Color("c0c0c0"), Color("808080"), 2)
	)
	add_child(background)
	var margin := MarginContainer.new()

	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)

	background.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var chart_frame := PanelContainer.new()
	chart_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_frame.add_theme_stylebox_override(
		"panel", ClassicStyle.create_box(Color("ffffff"), Color("404040"), 1)
	)
	column.add_child(chart_frame)
	population_control = PopulationView.new()
	population_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	population_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_frame.add_child(population_control)

	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 0)
	column.add_child(mode_row)
	var mode_group := ButtonGroup.new()

	for entry in [
		["Population", PopulationWindowControl.Mode.POPULATION],
		["Health", PopulationWindowControl.Mode.HEALTH],
		["Education", PopulationWindowControl.Mode.EDUCATION],
	]:
		var radio := CheckBox.new()
		radio.text = entry[0]
		radio.button_group = mode_group
		radio.button_pressed = entry[1] == PopulationWindowControl.Mode.POPULATION
		radio.custom_minimum_size = Vector2(120, 28)
		radio.pressed.connect(_on_mode_selected.bind(entry[1]))
		mode_row.add_child(radio)
		mode_buttons.append(radio)


func show_city(value: CityState) -> void:
	if value == null or population_control == null:
		return

	population_control.set_city(value)

	if visible:
		move_to_foreground()
	else:
		popup_centered(Vector2i(700, 450))


func refresh_city(value: CityState) -> void:
	if visible and population_control != null:
		population_control.set_city(value)


func _on_mode_selected(mode: int) -> void:
	population_control.set_mode(mode)
