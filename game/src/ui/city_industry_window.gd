class_name CityIndustryWindow
extends Window

signal tax_rates_changed

const IndustryView = preload("res://src/view/industry_window_control.gd")

var industry_control: IndustryWindowControl
var mode_buttons: Array[CheckBox] = []


func _ready() -> void:
	name = "IndustryWindow"
	title = "City Industry"
	size = Vector2i(700, 450)
	min_size = Vector2i(600, 390)
	transient = true
	exclusive = false
	visible = false
	close_requested.connect(hide)

	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override(
		"panel", _classic_box(Color("c0c0c0"), Color("808080"), 2)
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
		"panel", _classic_box(Color("c0c0c0"), Color("404040"), 1)
	)
	column.add_child(chart_frame)
	industry_control = IndustryView.new()
	industry_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	industry_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	industry_control.tax_rates_changed.connect(tax_rates_changed.emit)
	chart_frame.add_child(industry_control)

	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 0)
	column.add_child(mode_row)
	var mode_group := ButtonGroup.new()
	for entry in [
		["Ratios", IndustryWindowControl.Mode.RATIOS],
		["Tax Rates", IndustryWindowControl.Mode.TAX_RATES],
		["Demand", IndustryWindowControl.Mode.DEMAND],
	]:
		var radio := CheckBox.new()
		radio.text = entry[0]
		radio.button_group = mode_group
		radio.button_pressed = entry[1] == IndustryWindowControl.Mode.RATIOS
		radio.custom_minimum_size = Vector2(120, 28)
		radio.pressed.connect(_on_mode_selected.bind(entry[1]))
		mode_row.add_child(radio)
		mode_buttons.append(radio)


func set_resources(industry_names: PackedStringArray, icon_strip: Image) -> void:
	industry_control.set_industry_names(industry_names)
	industry_control.set_icon_strip(icon_strip)


func show_city(value: CityState) -> void:
	if value == null or industry_control == null:
		return
	industry_control.set_city(value)
	if visible:
		move_to_foreground()
	else:
		popup_centered(Vector2i(700, 450))


func refresh_city(value: CityState) -> void:
	if visible and industry_control != null:
		industry_control.set_city(value)


func _on_mode_selected(mode: int) -> void:
	industry_control.set_mode(mode)


func _classic_box(color: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.content_margin_left = 5
	box.content_margin_top = 3
	box.content_margin_right = 5
	box.content_margin_bottom = 3
	return box
