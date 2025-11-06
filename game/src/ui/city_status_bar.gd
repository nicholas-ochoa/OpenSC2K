class_name CityStatusBar
extends PanelContainer

const RciStatusView = preload("res://src/view/rci_status_control.gd")
const REPORT_ROTATION_SECONDS := 7.0

var message_label: Label
var weather_label: Label
var rci_graph: RciStatusControl
var reports_label: Label
var speed_label: Label
var recent_reports := PackedStringArray()
var report_index := 0
var report_elapsed_seconds := 0.0


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
	refresh_tooltips()


func set_environment(demand: Vector3i, weather_name: String) -> void:
	weather_label.text = "Weather: %s" % weather_name
	rci_graph.set_demand(demand)
	refresh_tooltips()


func clear_environment() -> void:
	weather_label.text = "Weather: --"
	rci_graph.clear_demand()
	refresh_tooltips()


func set_speed(speed_name: String) -> void:
	speed_label.text = "Speed: %s" % speed_name
	speed_label.set_meta(
		"status_tooltip_text", "Current simulation speed: %s." % speed_name
	)
	_sync_overflow_tooltip(speed_label)


func set_reports(reports: PackedStringArray) -> void:
	recent_reports = reports.duplicate()
	report_index = 0
	report_elapsed_seconds = 0.0
	_refresh_report_text()
	_sync_overflow_tooltip(reports_label)


func prepend_reports(reports: PackedStringArray, maximum := 3) -> void:
	for report in reports:
		recent_reports.insert(0, report)
	while recent_reports.size() > maximum:
		recent_reports.remove_at(recent_reports.size() - 1)
	report_index = 0
	report_elapsed_seconds = 0.0
	_refresh_report_text()
	_sync_overflow_tooltip(reports_label)


func update_report_rotation(delta: float) -> void:
	if delta <= 0.0 or recent_reports.size() < 2:
		return
	report_elapsed_seconds += delta
	if report_elapsed_seconds < REPORT_ROTATION_SECONDS:
		return
	var steps := floori(report_elapsed_seconds / REPORT_ROTATION_SECONDS)
	report_elapsed_seconds = fmod(
		report_elapsed_seconds, REPORT_ROTATION_SECONDS
	)
	report_index = posmod(report_index + steps, recent_reports.size())
	_refresh_report_text()
	_sync_overflow_tooltip(reports_label)


func refresh_tooltips() -> void:
	_sync_overflow_tooltip(message_label)
	_sync_overflow_tooltip(weather_label)
	_sync_overflow_tooltip(reports_label)
	_sync_overflow_tooltip(speed_label)


func refresh_message_tooltip() -> void:
	_sync_overflow_tooltip(message_label)


func _refresh_report_text() -> void:
	var current_report := "None"
	if not recent_reports.is_empty():
		report_index = posmod(report_index, recent_reports.size())
		current_report = recent_reports[report_index]
	else:
		report_index = 0
		report_elapsed_seconds = 0.0
	reports_label.text = "News: %s" % current_report
	reports_label.set_meta(
		"status_tooltip_text",
		(
			"Recent city reports. These are the newest saved newspaper records.\n%s"
			% (
				"No reports."
				if recent_reports.is_empty()
				else "\n".join(recent_reports)
			)
		),
	)


func _sync_overflow_tooltip(label: Label) -> void:
	if label == null:
		return
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	if (
		bool(label.get_meta("always_status_tooltip", false))
		or text_width > maxf(0.0, label.size.x - 4.0)
	):
		label.tooltip_text = str(label.get_meta("status_tooltip_text", label.text))
	else:
		label.tooltip_text = ""


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
