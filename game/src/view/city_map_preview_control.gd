class_name CityMapPreviewControl
extends Control

signal center_requested(point: Vector2i)

const MAP_SIZE := 128
const BORDER := 2.0

var map_texture: Texture2D
var viewport_outline := PackedVector2Array()
# the city-centre cross in tiles. A negative point hides it
var center_marker := Vector2i(-1, -1)
var center_marker_map_size := MAP_SIZE
var center_marker_color := Color.BLACK


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	custom_minimum_size = Vector2(256, 256)
	gui_input.connect(_on_gui_input)
	# a UI scale change on the main window moves the screen pixel grid
	get_tree().root.size_changed.connect(queue_redraw)


func _draw() -> void:
	var map_edge: int = map_texture.get_width() if map_texture != null else 128
	var target := map_rect()
	draw_rect(target.grow(BORDER), Color("1b222b"), true)
	draw_rect(target.grow(BORDER), Color("8d97a5"), false, 1.0)

	if map_texture != null:
		draw_texture_rect(map_texture, target, false)

	for rect in center_marker_rects():
		draw_rect(rect, center_marker_color, true)

	if viewport_outline.size() < 2:
		return

	var local := PackedVector2Array()

	for point in viewport_outline:
		local.append(target.position + point / float(map_edge) * target.size)

	local.append(local[0])
	draw_polyline(local, Color("202020"), 3.0, false)
	draw_polyline(local, Color("ffffff"), 1.0, false)


func set_map(image: Image) -> void:
	map_texture = null if image == null or image.is_empty() else ImageTexture.create_from_image(image)
	queue_redraw()


func set_viewport_outline(points: PackedVector2Array) -> void:
	viewport_outline = points.duplicate()
	queue_redraw()


func set_center_marker(point: Vector2i, map_size: int, color: Color) -> void:
	center_marker = point
	center_marker_map_size = maxi(1, map_size)
	center_marker_color = color
	queue_redraw()


# SIMCITY.EXE 0x00487b45 draws a cross of seven pixels across and down at the
# city centre of a 128-pixel map. The cross keeps that size in 128-tile map
# cells. It is empty when the marker is hidden.
func center_marker_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []

	if center_marker.x < 0 or center_marker.y < 0:
		return rects

	var target := map_rect()
	var unit := maxf(1.0, floorf(target.size.x / float(MAP_SIZE)))
	var point := target.position + Vector2(center_marker) / float(center_marker_map_size) * target.size
	rects.append(Rect2(point.x - unit * 3.0, point.y, unit * 7.0, unit))
	rects.append(Rect2(point.x, point.y - unit * 3.0, unit, unit * 7.0))

	return rects


func map_rect() -> Rect2:
	# leave room for the border inside the control, which clips its contents
	var edge := maxf(0.0, minf(size.x, size.y) - BORDER * 2.0)
	# give each map pixel the same whole number of screen pixels
	edge = ScreenPixels.whole_cells(edge, map_texture.get_width() if map_texture != null else MAP_SIZE)

	return Rect2(ScreenPixels.snap(self, (size - Vector2(edge, edge)) * 0.5), Vector2(edge, edge))


func _on_gui_input(event: InputEvent) -> void:
	var map_edge: int = map_texture.get_width() if map_texture != null else 128

	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton

	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var target := map_rect()

	if not target.has_point(mouse_event.position):
		return

	var relative := (mouse_event.position - target.position) / target.size
	var point := Vector2i(
		clampi(floori(relative.x * map_edge), 0, map_edge - 1),
		clampi(floori(relative.y * map_edge), 0, map_edge - 1),
	)
	center_requested.emit(point)
	accept_event()
