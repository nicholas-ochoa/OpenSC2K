class_name CityStatusBar
extends PanelContainer

const REPORT_ROTATION_SECONDS := 7.0
const NEWS_NAMES := {
	1: "Local news",
	4: "New invention",
	5: "New innovation",
	6: "War report",
	7: "Market report",
	8: "Sports report",
	9: "Federal rate increase",
	10: "Federal rate decrease",
	0x0b: "Political report",
	0x0c: "Diplomatic report",
	0x0d: "Disaster report",
	0x0e: "Medical report",
	0x0f: "Upbeat report",
	0x10: "High crime",
	0x11: "High traffic",
	0x12: "High pollution",
	0x13: "Poor education",
	0x14: "Poor health",
	0x15: "Poor employment",
	3: "City milestone",
	0x24: "Power plant report",
	0x26: "Education report",
	39: "Bridge collapse",
	0x28: "Forest protest",
	0x29: "New ordinance",
	0x3d: "Low crime",
	0x3e: "Low traffic",
	0x3f: "Low pollution",
	0x40: "Good education",
	0x41: "Good health",
	0x42: "Good employment",
	0x1f8: "Explosion",
	0x1fe: "Traffic report",
	0x201: "High mayor approval",
	0x202: "Monster attack",
	0x203: "Air disaster",
	0x205: "Cargo ship report",
	0x206: "Airplane takeoff",
	0x207: "Airplane landing",
	0x20c: "Train report",
	0x20f: "Sailboat distress",
	0x211: "Arcology launch",
	0x212: "Arcology launch complete",
}

var message_label: Label
var weather_label: Label
var rci_graph: RciStatusControl
var reports_label: Label
var speed_label: Label
var compass: StatusCompass
var zoom_label: Label
var recent_reports := PackedStringArray()
var music_notice := ""
var music_notice_seconds := 0.0
var report_index := 0
var report_elapsed_seconds := 0.0


func _ready() -> void:
	message_label = $Metrics/Message
	weather_label = $Metrics/Weather
	rci_graph = $Metrics/RCI
	reports_label = $Metrics/Reports
	speed_label = $Metrics/Speed
	compass = $Metrics/Compass
	zoom_label = $Metrics/Zoom
	speed_label.theme_changed.connect(_fit_speed_label)
	_fit_speed_label()
	refresh_tooltips()


func _fit_speed_label() -> void:
	var font := speed_label.get_theme_font("font")
	var font_size := speed_label.get_theme_font_size("font_size")
	var width := 122.0

	for speed_name: String in GameSpeedController.SPEED_NAMES.values():
		width = maxf(width, font.get_string_size("Speed: " + speed_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 8.0)

	speed_label.custom_minimum_size.x = ceilf(width)


func set_environment(demand: Vector3i, weather_name: String) -> void:
	weather_label.text = "Weather: %s" % weather_name
	rci_graph.set_demand(demand)
	refresh_tooltips()


func clear_environment() -> void:
	weather_label.text = "Weather: --"
	rci_graph.clear_demand()
	refresh_tooltips()


func set_zoom(percent: int) -> void:
	zoom_label.text = "Zoom: %d%%" % percent
	_sync_overflow_tooltip(zoom_label)


func set_compass(value: int) -> void:
	compass.set_compass(value)


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


func prepend_news_items(news_items: Array, maximum := 3) -> void:
	var reports := PackedStringArray()

	for item in news_items:
		reports.append(report_name(int(item.get("type", 0))))

	prepend_reports(reports, maximum)


static func report_name(news_type: int) -> String:
	return str(NEWS_NAMES.get(news_type, "City report"))


func update_report_rotation(delta: float) -> void:
	if music_notice_seconds > 0.0:
		music_notice_seconds = maxf(0.0, music_notice_seconds - delta)

		if music_notice_seconds == 0.0:
			_refresh_report_text()

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
	_sync_overflow_tooltip(zoom_label)


func refresh_message_tooltip() -> void:
	_sync_overflow_tooltip(message_label)


func _refresh_report_text() -> void:
	if music_notice_seconds > 0.0:
		reports_label.text = music_notice
		reports_label.set_meta("status_tooltip_text", music_notice)

		return

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


func show_music_notice(message: String) -> void:
	music_notice = message
	music_notice_seconds = 5.0
	_refresh_report_text()
	_sync_overflow_tooltip(reports_label)
