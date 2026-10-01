class_name CityDebugOverlayCanvas
extends Node2D
## Debug lines and rectangles in map source pixels. The node takes the map
## transform, so a pan or zoom moves it without a new draw. Lines keep one
## interface width at every zoom. A draw call takes a whole list of lines.

# how long a repainted region stays highlighted
const FLASH_SECONDS := 0.6
# line width in map control pixels
const LINE_WIDTH := 1.5
const FLASH_COLOR := Color(1.0, 0.85, 0.1)

# [PackedVector2Array of point pairs, Color]
var line_sets: Array = []
# [Rect2, Color] filled rectangles
var fills: Array = []
# [Vector2 center, float radius, Color]
var dots: Array = []
# [Rect2, msec at the repaint]
var flashes: Array = []
# Flashes fade in each frame. Their own canvas draws them, so the line lists
# draw again only when they change
var flash_layer := Node2D.new()


func _init() -> void:
	name = "DebugOverlayCanvas"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	flash_layer.name = "Flashes"
	flash_layer.draw.connect(_draw_flashes)
	add_child(flash_layer)


func set_view_transform(scale_value: float, offset: Vector2) -> void:
	position = offset

	if not is_equal_approx(scale.x, scale_value):
		scale = Vector2.ONE * scale_value
		queue_redraw()


func clear_flashes() -> void:
	flashes.clear()
	flash_layer.queue_redraw()


func add_flash(rect: Rect2) -> void:
	flashes.append([rect, Time.get_ticks_msec()])


# drop old flashes. true while flashes remain, so the caller draws again
func expire_flashes() -> bool:
	var now := Time.get_ticks_msec()
	var limit := int(FLASH_SECONDS * 1000.0)
	var had_flashes := not flashes.is_empty()
	flashes = flashes.filter(func(flash: Array) -> bool: return now - int(flash[1]) < limit)

	if had_flashes:
		flash_layer.queue_redraw()

	return not flashes.is_empty()


func clear() -> void:
	line_sets.clear()
	fills.clear()
	dots.clear()
	flashes.clear()
	queue_redraw()
	flash_layer.queue_redraw()


func _draw() -> void:
	for fill in fills:
		draw_rect(fill[0], fill[1])

	var width := _line_width()

	for line_set in line_sets:
		if (line_set[0] as PackedVector2Array).size() >= 2:
			draw_multiline(line_set[0], line_set[1], width)

	for dot in dots:
		draw_circle(dot[0], dot[1], dot[2])


func _draw_flashes() -> void:
	var now := Time.get_ticks_msec()
	var width := _line_width() * 2.0

	for flash in flashes:
		var fade := 1.0 - float(now - int(flash[1])) / (FLASH_SECONDS * 1000.0)
		flash_layer.draw_rect(flash[0], Color(FLASH_COLOR, 0.12 * fade))
		flash_layer.draw_rect(flash[0], Color(FLASH_COLOR, 0.9 * fade), false, width)


func _line_width() -> float:
	return LINE_WIDTH / maxf(scale.x, 0.001)
