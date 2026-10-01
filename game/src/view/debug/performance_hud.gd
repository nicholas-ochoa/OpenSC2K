class_name CityPerformanceHud
extends PanelContainer
## Frame and render counters with a frame-time graph. The graph keeps the last
## SAMPLES frames. The text changes four times a second; the graph draws one
## line list for each frame.

const SAMPLES := 240
const GRAPH_SIZE := Vector2(240, 64)
# the graph top: 50 ms, three 60 Hz frames
const GRAPH_MAX_MSEC := 50.0
const TEXT_INTERVAL_MSEC := 250
const GUIDE_MSEC := [16.7, 33.3]

var frame_msec := PackedFloat32Array()
var _next := 0
var _label: Label
var _graph: Control
var _text_at := 0


func _ready() -> void:
	name = "PerformanceHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"TooltipPanel"
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rows)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.theme_type_variation = &"TooltipLabel"
	_label.add_theme_font_size_override("font_size", 12)
	rows.add_child(_label)
	_graph = Control.new()
	_graph.custom_minimum_size = GRAPH_SIZE
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.draw.connect(_draw_graph)
	rows.add_child(_graph)
	FrostedTooltipPanel.bind(self)
	frame_msec.resize(SAMPLES)
	hide()


func add_frame(delta: float) -> void:
	frame_msec[_next] = delta * 1000.0
	_next = (_next + 1) % SAMPLES
	_graph.queue_redraw()


# true when the text is due again
func text_due() -> bool:
	return Time.get_ticks_msec() >= _text_at


func set_text(value: String) -> void:
	_text_at = Time.get_ticks_msec() + TEXT_INTERVAL_MSEC
	_label.text = value
	size = Vector2.ZERO
	size = get_combined_minimum_size()


# the slowest and the mean frame of the samples, in milliseconds
func frame_summary() -> Vector2:
	var slowest := 0.0
	var total := 0.0

	for value in frame_msec:
		slowest = maxf(slowest, value)
		total += value

	return Vector2(slowest, total / SAMPLES)


func _draw_graph() -> void:
	var area := _graph.size
	_graph.draw_rect(Rect2(Vector2.ZERO, area), Color(0, 0, 0, 0.35))

	for guide: float in GUIDE_MSEC:
		var y := area.y * (1.0 - guide / GRAPH_MAX_MSEC)
		_graph.draw_line(Vector2(0, y), Vector2(area.x, y), Color(1, 1, 1, 0.25), -1.0)

	var points := PackedVector2Array()
	points.resize(SAMPLES)

	for index in SAMPLES:
		var value := frame_msec[(_next + index) % SAMPLES]
		points[index] = Vector2(area.x * index / (SAMPLES - 1.0), area.y * (1.0 - minf(value, GRAPH_MAX_MSEC) / GRAPH_MAX_MSEC))

	_graph.draw_polyline(points, Color("7cf29c"), -1.0)
