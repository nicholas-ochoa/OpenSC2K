class_name CityGraphWindow
extends Window

const GraphView = preload("res://src/view/city_graph_control.gd")
const ClassicStyle = preload("res://src/ui/classic_ui_style.gd")

var graph_control: CityGraphControl
var series_buttons: Array[CheckBox] = []


func _ready() -> void:
	name = "GraphWindow"
	title = "Graph Window"
	size = Vector2i(860, 560)
	min_size = Vector2i(700, 480)
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

	var graph_frame := PanelContainer.new()
	graph_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_frame.add_theme_stylebox_override(
		"panel", ClassicStyle.create_box(Color("ffffff"), Color("404040"), 1)
	)
	column.add_child(graph_frame)
	graph_control = GraphView.new()
	graph_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_frame.add_child(graph_control)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	column.add_child(controls)
	var series_grid := GridContainer.new()
	series_grid.columns = 4
	series_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	series_grid.add_theme_constant_override("h_separation", 8)
	series_grid.add_theme_constant_override("v_separation", 2)
	controls.add_child(series_grid)

	for series in CityGraphControl.SERIES_COUNT:
		var check := CheckBox.new()
		check.text = CityGraphControl.SERIES_NAMES[series]
		check.tooltip_text = "%s graph (%s)" % [
			CityGraphControl.SERIES_NAMES[series],
			CityGraphControl.SERIES_MARKERS[series],
		]
		check.custom_minimum_size = Vector2(132, 24)
		check.button_pressed = bool(
			CityGraphControl.DEFAULT_SELECTED_MASK & (1 << series)
		)
		check.toggled.connect(_on_series_toggled.bind(series))
		series_grid.add_child(check)
		series_buttons.append(check)

	var scale_column := VBoxContainer.new()
	scale_column.custom_minimum_size = Vector2(110, 0)
	controls.add_child(scale_column)
	var scale_heading := Label.new()
	scale_heading.text = "Time Scale"
	scale_heading.add_theme_color_override("font_color", Color("000080"))
	scale_column.add_child(scale_heading)
	var scale_group := ButtonGroup.new()

	for entry in [["1 Year", 0], ["10 Years", 1], ["100 Yrs", 2]]:
		var radio := CheckBox.new()
		radio.text = entry[0]
		radio.button_group = scale_group
		radio.button_pressed = entry[1] == 0
		radio.pressed.connect(_on_time_scale_selected.bind(entry[1]))
		scale_column.add_child(radio)


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
