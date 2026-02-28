class_name CityMapPreviewControl
extends Control

signal center_requested(point: Vector2i)

const MAP_SIZE := 128

var map_texture: Texture2D
var viewport_outline := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	custom_minimum_size = Vector2(384, 384)
	gui_input.connect(_on_gui_input)


func set_map(image: Image) -> void:
	map_texture = null if image == null or image.is_empty() else ImageTexture.create_from_image(image)
	queue_redraw()


func set_viewport_outline(points: PackedVector2Array) -> void:
	viewport_outline = points.duplicate()
	queue_redraw()


func map_rect() -> Rect2:
	var edge := minf(size.x, size.y)

	return Rect2((size - Vector2(edge, edge)) * 0.5, Vector2(edge, edge))


func _draw() -> void:
	var map_edge: int = map_texture.get_width() if map_texture != null else 128
	var target := map_rect()
	draw_rect(target.grow(2), Color("404040"), true)

	if map_texture != null:
		draw_texture_rect(map_texture, target, false)

	if viewport_outline.size() < 2:
		return

	var local := PackedVector2Array()

	for point in viewport_outline:
		local.append(target.position + point / float(map_edge) * target.size)

	local.append(local[0])
	draw_polyline(local, Color("202020"), 3.0, false)
	draw_polyline(local, Color("ffffff"), 1.0, false)


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
