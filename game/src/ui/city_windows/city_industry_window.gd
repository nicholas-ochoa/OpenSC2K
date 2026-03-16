class_name CityIndustryWindow
extends Window

signal tax_rates_changed

const IndustryView = preload("res://src/view/industry_window_control.gd")
const ClassicStyle = preload("res://src/ui/shared/classic_ui_style.gd")

var industry_control: IndustryWindowControl
var mode_buttons: Array[CheckBox] = []


func _ready() -> void:
	close_requested.connect(hide)
	industry_control = get_node("Background/Margin/Column/ChartFrame/Chart")
	industry_control.tax_rates_changed.connect(tax_rates_changed.emit)

	for child in $Background/Margin/Column/Controls.get_children():
		var radio := child as CheckBox
		radio.pressed.connect(_on_mode_selected.bind(mode_buttons.size()))
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
