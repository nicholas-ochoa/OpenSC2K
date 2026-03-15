class_name CityPopulationWindow
extends Window


var population_control: PopulationWindowControl
var mode_buttons: Array[CheckBox] = []


func _ready() -> void:
	close_requested.connect(hide)
	population_control = $Background/Margin/Column/ChartFrame/Chart

	for child in $Background/Margin/Column/Modes.get_children():
		var radio := child as CheckBox
		radio.pressed.connect(_on_mode_selected.bind(mode_buttons.size()))
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
