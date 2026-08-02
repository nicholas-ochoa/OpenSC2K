class_name CityGraphWindow
extends Window

const GraphView = preload("res://src/view/city_graph_control.gd")

var graph_control: CityGraphControl
var series_buttons: Array[CheckBox] = []


func _ready() -> void:
	# visible in the editor, closed at startup
	hide()
	close_requested.connect(hide)
	graph_control = get_node("Background/Margin/Column/ChartFrame/Chart")

	for child in $Background/Margin/Column/Controls/SeriesChoices.get_children():
		var check := child as CheckBox
		check.toggled.connect(_on_series_toggled.bind(series_buttons.size()))
		series_buttons.append(check)

	var scale_index := 0

	for child in $Background/Margin/Column/Controls/TimeScales.get_children():
		if child is CheckBox:
			child.pressed.connect(_on_time_scale_selected.bind(scale_index))
			scale_index += 1


func show_city(value: CityState) -> void:
	if value == null or graph_control == null:
		return

	graph_control.set_city(value)

	if visible:
		move_to_foreground()
	else:
		popup_centered(Vector2i(860, 560))


func refresh_city(value: CityState) -> void:
	if visible and graph_control != null:
		graph_control.set_city(value)


func _on_series_toggled(enabled: bool, series: int) -> void:
	graph_control.set_series_enabled(series, enabled)


func _on_time_scale_selected(scale: int) -> void:
	graph_control.set_time_scale(scale)
