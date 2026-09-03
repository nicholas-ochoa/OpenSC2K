class_name CityGraphControl
extends Control

@warning_ignore_start("integer_division")

const SERIES_COUNT := 16
const DEFAULT_SELECTED_MASK := 0x000f
const TIME_YEAR := 0
const TIME_DECADE := 1
const TIME_CENTURY := 2
const SERIES_NAMES := [
	"City Size",
	"Residents",
	"Commerce",
	"Industry",
	"Traffic",
	"Pollution",
	"Value",
	"Crime",
	"Power %",
	"Water %",
	"Health",
	"Education",
	"Unemployment",
	"GNP",
	"Nat'n Pop.",
	"Fed Rate",
]
const SERIES_MARKERS := [
	"S", "R", "C", "I", "T", "P", "V", "X",
	"p", "w", "h", "e", "u", "g", "n", "%",
]
const SERIES_COLORS := [
	Color("000000"),
	Color("00b000"),
	Color("0000b0"),
	Color("a0a000"),
	Color("808080"),
	Color("404040"),
	Color("008000"),
	Color("505000"),
	Color("b00000"),
	Color("0060b0"),
	Color("808080"),
	Color("b000b0"),
	Color("ff00ff"),
	Color("0000ff"),
	Color("000000"),
	Color("00ffff"),
]
const MONTH_NAMES := [
	"Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
]

var city: CityState
var selected_mask := DEFAULT_SELECTED_MASK
var time_scale := TIME_YEAR


func _init() -> void:
	theme_changed.connect(queue_redraw)
	custom_minimum_size = Vector2(620, 330)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_city(value: CityState) -> void:
	city = value
	queue_redraw()


func set_series_enabled(series: int, enabled: bool) -> void:
	if series < 0 or series >= SERIES_COUNT:
		return

	if enabled:
		selected_mask |= 1 << series
	else:
		selected_mask &= ~(1 << series)

	queue_redraw()


func set_time_scale(value: int) -> void:
	if value < TIME_YEAR or value > TIME_CENTURY:
		return

	time_scale = value
	queue_redraw()


func refresh() -> void:
	queue_redraw()


static func history_for_scale(
	value_city: CityState, series: int, scale: int
) -> PackedInt64Array:
	var ordered := PackedInt64Array()

	if value_city == null or series < 0 or series >= SERIES_COUNT:
		return ordered

	var record := value_city.graph_series(series)
	var key := _scale_key(scale)

	if record == null or key.is_empty():
		return ordered

	var stored: PackedInt64Array = record.values_for_period(key)

	for index in range(stored.size() - 1, -1, -1):
		ordered.append(stored[index])

	return ordered


static func display_maxima(value_city: CityState) -> PackedInt64Array:
	var raw := PackedInt64Array()
	raw.resize(SERIES_COUNT)

	for series in SERIES_COUNT:
		var record := value_city.graph_series(series) if value_city != null else null

		if record == null:
			continue

		for key in ["year", "decade", "century"]:
			var values: PackedInt64Array = record.values_for_period(key)

			for value in values:
				raw[series] = maxi(raw[series], int(value))

	var maxima := raw.duplicate()
	var population_maximum := maxi(1, raw[0])

	for series in range(0, 4):
		maxima[series] = population_maximum

	var quality_maximum := 1

	for series in range(4, 8):
		quality_maximum = maxi(quality_maximum, raw[series])

	for series in range(4, 8):
		maxima[series] = quality_maximum

	for series in range(8, SERIES_COUNT):
		maxima[series] = maxi(1, raw[series])

	maxima[13] = maxi(maxima[13], maxima[14])

	return maxima


static func format_value(series: int, value: int) -> String:
	var absolute := absi(value)
	var plain_limit := 1000 if series == 14 else 10000

	if absolute < plain_limit:
		return str(value)

	if absolute < 1000000:
		return "%dk" % int(value / 1000)

	return "%dm" % int(value / 1000000)


static func time_labels(value_city: CityState, scale: int) -> PackedStringArray:
	var labels := PackedStringArray()

	if value_city == null:
		return labels

	var year := value_city.current_year()
	var month := value_city.current_month()

	if scale == TIME_YEAR:
		for offset in range(11, -1, -1):
			var month_index := posmod(month - 1 - offset, 12)
			labels.append(MONTH_NAMES[month_index])
	elif scale == TIME_DECADE:
		var newest_half_year := year * 2 + (1 if month >= 7 else 0)

		for index in 20:
			var half_year := newest_half_year - 19 + index
			labels.append("'%02d" % posmod(int(half_year / 2), 100))
	elif scale == TIME_CENTURY:
		var newest_five_year := int(year / 5) * 5

		for index in 20:
			labels.append("'%02d" % posmod(newest_five_year - (19 - index) * 5, 100))

	return labels


static func _scale_key(scale: int) -> String:
	if scale == TIME_YEAR:
		return "year"

	if scale == TIME_DECADE:
		return "decade"

	if scale == TIME_CENTURY:
		return "century"

	return ""


func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, size)
	draw_rect(frame, get_theme_color("paper", "AppPalette"), true)
	draw_rect(frame, get_theme_color("border", "AppPalette"), false, 1.0)

	if city == null or not city.is_valid():
		_draw_centered_message("No city is loaded.")

		return

	var font := get_theme_default_font()
	var font_size := 12
	var plot := Rect2(44, 18, maxf(1.0, size.x - 132.0), maxf(1.0, size.y - 55.0))

	for step in 5:
		var y := plot.position.y + plot.size.y * float(step) / 4.0
		draw_line(
			Vector2(plot.position.x, y), Vector2(plot.end.x, y),
			get_theme_color("grid", "AppPalette"), 1.0
		)

	draw_line(plot.position, Vector2(plot.position.x, plot.end.y), get_theme_color("border", "AppPalette"), 1.0)
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, get_theme_color("border", "AppPalette"), 1.0)

	var labels := time_labels(city, time_scale)
	var point_count := 12 if time_scale == TIME_YEAR else 20

	for index in point_count:
		var x := _point_x(plot, index, point_count)
		var major_tick := time_scale == TIME_YEAR or index % 2 == 1

		if major_tick:
			draw_line(Vector2(x, plot.end.y), Vector2(x, plot.end.y + 4), get_theme_color("border", "AppPalette"), 1.0)
			var label := labels[index] if index < labels.size() else ""
			var label_width := font.get_string_size(
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
			).x
			draw_string(
				font, Vector2(x - label_width * 0.5, plot.end.y + 17), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color("ink", "AppPalette")
			)

	var maxima := display_maxima(city)
	var endpoints: Array[Dictionary] = []

	for series in SERIES_COUNT:
		if (selected_mask & (1 << series)) == 0:
			continue

		var history := history_for_scale(city, series, time_scale)

		if history.size() != point_count:
			continue

		var points := PackedVector2Array()

		for index in history.size():
			points.append(Vector2(
				_point_x(plot, index, point_count),
				_value_y(plot, history[index], maxima[series])
			))

		if points.size() >= 2:
			draw_polyline(points, _series_color(series), 1.0, false)

		endpoints.append({
			"series": series,
			"point": points[points.size() - 1],
			"value": history[history.size() - 1],
		})

	_draw_endpoint_labels(plot, endpoints, font, font_size)


func _draw_endpoint_labels(
	plot: Rect2, endpoints: Array[Dictionary], font: Font, font_size: int
) -> void:
	endpoints.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_point: Vector2 = left.point
		var right_point: Vector2 = right.point

		return left_point.y < right_point.y
	)
	var label_positions := PackedFloat32Array()

	for index in endpoints.size():
		var endpoint: Dictionary = endpoints[index]
		var point: Vector2 = endpoint.point
		var prior_y := (
			label_positions[index - 1] if index > 0 else plot.position.y - 14.0
		)
		label_positions.append(maxf(point.y, prior_y + 14.0))

	if not label_positions.is_empty() and label_positions[-1] > plot.end.y:
		var bottom_shift := label_positions[-1] - plot.end.y

		for index in label_positions.size():
			label_positions[index] -= bottom_shift

	for index in range(label_positions.size() - 2, -1, -1):
		label_positions[index] = minf(
			label_positions[index], label_positions[index + 1] - 14.0
		)

	if not label_positions.is_empty() and label_positions[0] < plot.position.y:
		var top_shift := plot.position.y - label_positions[0]

		for index in label_positions.size():
			label_positions[index] += top_shift

	for index in endpoints.size():
		var endpoint: Dictionary = endpoints[index]
		var point: Vector2 = endpoint.point
		var label_y := label_positions[index]
		var series: int = endpoint.series
		var color: Color = _series_color(series)
		var label := "%s %s" % [
			SERIES_MARKERS[series], format_value(series, int(endpoint.value))
		]
		draw_line(point, Vector2(plot.end.x + 5, label_y), color, 1.0)
		draw_string(
			font, Vector2(plot.end.x + 8, label_y + font.get_ascent(font_size) * 0.35),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color
		)


func _draw_centered_message(message: String) -> void:
	var font := get_theme_default_font()
	var font_size := 14
	var width := font.get_string_size(
		message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	draw_string(
		font, Vector2((size.x - width) * 0.5, size.y * 0.5), message,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color("ink", "AppPalette")
	)


func _point_x(plot: Rect2, index: int, point_count: int) -> float:
	if point_count <= 1:
		return plot.position.x

	return plot.position.x + plot.size.x * float(index) / float(point_count - 1)


func _value_y(plot: Rect2, value: int, maximum: int) -> float:
	var fraction := clampf(float(value) / float(maxi(1, maximum)), 0.0, 1.0)

	return plot.end.y - plot.size.y * fraction


func _series_color(series: int) -> Color:
	var original: Color = SERIES_COLORS[series]
	return original.lerp(Color.WHITE, 0.5) if AppUiTheme.selected == "dark" else original
