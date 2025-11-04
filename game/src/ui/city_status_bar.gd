class_name CityStatusBar
extends PanelContainer

const RciStatusView = preload("res://src/view/rci_status_control.gd")

var message_label: Label
var weather_label: Label
var rci_graph: RciStatusControl
var reports_label: Label
var speed_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(0, 31)
	add_theme_stylebox_override(
		"panel", _classic_box(Color("c0c0c0"), Color("808080"), 2)
	)

	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 8)
	add_child(metrics)

	message_label = Label.new()
	message_label.text = "Ready."
	message_label.custom_minimum_size = Vector2(150, 22)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	message_label.add_theme_color_override("font_color", Color("202020"))
	message_label.set_meta("always_status_tooltip", true)
	metrics.add_child(message_label)
	metrics.add_child(VSeparator.new())

	weather_label = _metric_label("Weather: --", 120)
	weather_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	metrics.add_child(weather_label)
	metrics.add_child(VSeparator.new())

	rci_graph = RciStatusView.new()
	metrics.add_child(rci_graph)
	metrics.add_child(VSeparator.new())

	reports_label = _metric_label("News: None", 180, true)
	reports_label.set_meta("always_status_tooltip", true)
	metrics.add_child(reports_label)
	metrics.add_child(VSeparator.new())

	speed_label = _metric_label("Speed: --", 122)
	metrics.add_child(speed_label)


func _metric_label(text_value: String, minimum_width: int, expand := false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.custom_minimum_size = Vector2(minimum_width, 20)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


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
