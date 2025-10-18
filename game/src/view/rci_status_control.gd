class_name RciStatusControl
extends Control

const MAX_DEMAND := 2000
const GRAPH_LEFT := 27.0
const GRAPH_BACKGROUND := Color("eeeeee")
const ZONE_COLORS := [
	Color("20b050"),
	Color("2878d0"),
	Color("d8b818"),
]

var demand := Vector3i.ZERO
var demand_available := false


func _init() -> void:
	custom_minimum_size = Vector2(100, 24)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_update_tooltip()


func set_demand(value: Vector3i) -> void:
	demand = Vector3i(
		clampi(value.x, -MAX_DEMAND, MAX_DEMAND),
		clampi(value.y, -MAX_DEMAND, MAX_DEMAND),
		clampi(value.z, -MAX_DEMAND, MAX_DEMAND),
	)
	demand_available = true
	_update_tooltip()
	queue_redraw()


func clear_demand() -> void:
	demand = Vector3i.ZERO
	demand_available = false
	_update_tooltip()
	queue_redraw()


static func bar_rects(value: Vector3i, graph_rect: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if graph_rect.size.x <= 0.0 or graph_rect.size.y <= 0.0:
		return result
	var baseline := floorf(graph_rect.position.y + graph_rect.size.y * 0.5)
	var half_height := maxf(1.0, floorf((graph_rect.size.y - 3.0) * 0.5))
	var slot_width := graph_rect.size.x / 3.0
	var bar_width := maxf(2.0, floorf(slot_width * 0.52))
	var values := [value.x, value.y, value.z]
	for index in 3:
		var magnitude := floorf(
			minf(1.0, absf(float(values[index])) / float(MAX_DEMAND))
			* half_height
		)
		if values[index] != 0:
			magnitude = maxf(1.0, magnitude)
		var x := floorf(
			graph_rect.position.x
			+ slot_width * (float(index) + 0.5)
			- bar_width * 0.5
		)
		var y := baseline - magnitude if values[index] >= 0 else baseline + 1.0
		result.append(Rect2(x, y, bar_width, magnitude))
	return result


static func demand_tooltip(value: Vector3i) -> String:
	return "Residential (green): %+d\nCommercial (blue): %+d\nIndustrial (yellow): %+d" % [
		value.x, value.y, value.z,
	]


func _update_tooltip() -> void:
	tooltip_text = demand_tooltip(demand) if demand_available else "RCI demand is not available."


func _draw() -> void:
	var font := get_theme_default_font()
	var font_size := 11
	var baseline := floorf(size.y * 0.5)
	draw_string(
		font,
		Vector2(2, baseline + 4),
		"RCI",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color("202020"),
	)
	var graph_rect := Rect2(
		GRAPH_LEFT,
		2,
		maxf(1.0, size.x - GRAPH_LEFT - 2.0),
		maxf(1.0, size.y - 4.0),
	)
	draw_rect(graph_rect, GRAPH_BACKGROUND, true)
	draw_line(
		Vector2(graph_rect.position.x, floorf(graph_rect.get_center().y)),
		Vector2(graph_rect.end.x, floorf(graph_rect.get_center().y)),
		Color("909090"),
		1.0,
	)
	var bars: Array[Rect2] = []
	if demand_available:
		bars = bar_rects(demand, graph_rect)
	for index in bars.size():
		if bars[index].size.y > 0.0:
			draw_rect(bars[index], ZONE_COLORS[index], true)
	draw_rect(graph_rect, Color("505050"), false, 1.0)
	draw_rect(graph_rect.grow(-1.0), Color("ffffff"), false, 1.0)
