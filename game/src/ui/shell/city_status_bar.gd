class_name CityStatusBar
extends PanelContainer

signal disaster_locate_requested
signal help_requested(topic: String)

var message_label: Label
var weather_label: Label
var rci_graph: RciStatusControl
var reports_label: Label
var locate_disaster_button: Button
var speed_label: Label
var compass: StatusCompass
var zoom_label: Label
var city_status_text := ""
var priority_status := false
var status_style := ""
var music_notice := ""
var music_notice_seconds := 0.0
# the key that turns a click on the status bar into a request for its help
var control_bindings := ControlBindings.defaults()


func _ready() -> void:
	message_label = $Metrics/Message
	weather_label = $Metrics/Weather
	rci_graph = $Metrics/RCI
	reports_label = $Metrics/Reports
	locate_disaster_button = $Metrics/LocateDisaster
	locate_disaster_button.pressed.connect(_on_locate_disaster_pressed)
	speed_label = $Metrics/Speed
	compass = $Metrics/Compass
	zoom_label = $Metrics/Zoom
	speed_label.theme_changed.connect(_fit_speed_label)
	_fit_speed_label()
	refresh_tooltips()
	_watch_help_clicks(self)


func _watch_help_clicks(control: Control) -> void:
	control.gui_input.connect(_on_help_gui_input.bind(control))

	for child in control.get_children():
		if child is Control:
			_watch_help_clicks(child)


# A click with the help key shows the help of the status bar, or of the
# Demand Indicator. The gui_input signal comes before a button reads the click
func _on_help_gui_input(event: InputEvent, control: Control) -> void:
	var mouse := event as InputEventMouseButton

	if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return

	if not control_bindings.modifier_held("button_help_modifier", event):
		return

	control.accept_event()
	help_requested.emit(ButtonHelp.DEMAND_INDICATOR if control == rci_graph else ButtonHelp.STATUS_BAR)


func _on_locate_disaster_pressed() -> void:
	disaster_locate_requested.emit()


func _fit_speed_label() -> void:
	var font := speed_label.get_theme_font("font")
	var font_size := speed_label.get_theme_font_size("font_size")
	var width := 122.0

	for speed_name: String in GameSpeedController.SPEED_NAMES.values():
		width = maxf(width, font.get_string_size(tr("Speed: %s") % tr(speed_name),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 8.0)

	speed_label.custom_minimum_size.x = ceilf(width)


func set_environment(demand: Vector3i, weather_name: String) -> void:
	weather_label.text = tr("Weather: %s") % tr(weather_name)
	rci_graph.set_demand(demand)
	refresh_tooltips()


func clear_environment() -> void:
	weather_label.text = "Weather: --"
	rci_graph.clear_demand()
	refresh_tooltips()


# the fit levels of a large map are below 10% and need a fraction
func set_zoom(factor: float) -> void:
	var percent := factor * 100.0
	zoom_label.text = (tr("Zoom: %d%%") % roundi(percent)) if percent >= 10.0 else (tr("Zoom: %s%%") % String.num(percent, 3))
	_sync_overflow_tooltip(zoom_label)


func set_compass(value: int) -> void:
	compass.set_compass(value)


func set_speed(speed_name: String) -> void:
	speed_label.text = tr("Speed: %s") % tr(speed_name)
	speed_label.set_meta(
		"status_tooltip_text", tr("Current simulation speed: %s.") % tr(speed_name)
	)
	_sync_overflow_tooltip(speed_label)


func update_music_notice(delta: float) -> void:
	if music_notice_seconds <= 0.0:
		return

	music_notice_seconds = maxf(0.0, music_notice_seconds - delta)

	if music_notice_seconds == 0.0:
		_refresh_report_text()
		_sync_overflow_tooltip(reports_label)


func refresh_tooltips() -> void:
	_sync_overflow_tooltip(message_label)
	_sync_overflow_tooltip(weather_label)
	_sync_overflow_tooltip(reports_label)
	_sync_overflow_tooltip(speed_label)
	_sync_overflow_tooltip(zoom_label)


func refresh_message_tooltip() -> void:
	_sync_overflow_tooltip(message_label)


func set_city_status(engine: SimulationEngine, paused: bool) -> void:
	city_status_text = ""
	priority_status = false
	status_style = ""
	var disaster_active := engine != null and engine.active_disaster_type != 0

	if engine != null:
		city_status_text = CityStatusMessages.text(engine.city_status_resource_id)

		if paused:
			city_status_text = CityStatusMessages.PAUSED_TEXT
			priority_status = true
			status_style = "SuccessLabel"
		elif engine.active_disaster_type != 0:
			var disaster := engine.active_disaster_type
			city_status_text = (CityStatusMessages.DISASTERS[disaster] if disaster > 0 and disaster < CityStatusMessages.DISASTERS.size()
				else "")
			priority_status = true
			status_style = "ErrorLabel"

	if locate_disaster_button != null:
		locate_disaster_button.visible = disaster_active

	_refresh_report_text()
	_sync_overflow_tooltip(reports_label)


# the message pane of SIMCITY.EXE 0x00406fd0: *PAUSED*, the disaster, or the
# city status, which can be blank. a music notice shows over the city status
# for a few seconds
func _refresh_report_text() -> void:
	reports_label.theme_type_variation = status_style

	if music_notice_seconds > 0.0 and not priority_status:
		reports_label.text = music_notice
		reports_label.set_meta("status_tooltip_text", music_notice)

		return

	reports_label.text = city_status_text
	reports_label.set_meta("status_tooltip_text", tr(city_status_text))


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


func show_music_notice(message: String) -> void:
	music_notice = message
	music_notice_seconds = 5.0
	_refresh_report_text()
	_sync_overflow_tooltip(reports_label)
