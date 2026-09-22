class_name ScurkSelectionOutline
extends Node2D

const FRAME_SECONDS := 1.0 / 12.0
const DASH_LENGTH := 4.0
const DASH_PERIOD := 8

var phase := 0
var animated := false
var edges := PackedVector2Array()
var _white_edges := PackedVector2Array()
var _elapsed := 0.0


func _init() -> void:
	set_process(false)


func _ready() -> void:
	_update_processing()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_update_processing()


func configure(value: PackedVector2Array, animate: bool) -> void:
	if edges == value and animated == animate:
		return

	edges = value.duplicate()
	animated = animate
	phase = 0
	_elapsed = 0.0
	visible = not edges.is_empty()
	_rebuild_dashes()
	_update_processing()
	queue_redraw()


func _process(delta: float) -> void:
	if not animated or edges.is_empty() or not is_visible_in_tree():
		return

	_elapsed += delta
	if _elapsed < FRAME_SECONDS:
		return

	var steps := int(_elapsed / FRAME_SECONDS)
	_elapsed = fmod(_elapsed, FRAME_SECONDS)
	phase = (phase + steps) % DASH_PERIOD
	_rebuild_dashes()
	queue_redraw()


func _update_processing() -> void:
	set_process(animated and not edges.is_empty() and is_visible_in_tree())
	if not is_processing():
		_elapsed = 0.0


func _rebuild_dashes() -> void:
	_white_edges.clear()
	if not animated:
		return

	for index in range(0, edges.size() - 1, 2):
		var first := edges[index]
		var last := edges[index + 1]
		if first.x + first.y > last.x + last.y:
			var previous := first
			first = last
			last = previous
		var length := first.distance_to(last)
		var direction := first.direction_to(last)
		var offset := 0.0
		while offset < length:
			var position_in_dash := fposmod(first.x + first.y + offset + phase, DASH_PERIOD)
			var white := position_in_dash < DASH_LENGTH
			var span := DASH_LENGTH - position_in_dash if white else DASH_PERIOD - position_in_dash
			var finish := minf(offset + span, length)
			if white:
				_white_edges.append(first + direction * offset)
				_white_edges.append(first + direction * finish)
			offset = finish


func _draw() -> void:
	if edges.is_empty():
		return

	draw_multiline(edges, Color.BLACK, 1.0 if animated else 3.0)
	if animated:
		if not _white_edges.is_empty():
			draw_multiline(_white_edges, Color.WHITE, 1.0)
	else:
		draw_multiline(edges, Color.WHITE, 1.0)
