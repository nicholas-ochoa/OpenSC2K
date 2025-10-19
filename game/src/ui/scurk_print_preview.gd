class_name ScurkPrintPreview
extends Control

signal selection_changed

const Output = preload("res://src/assets/scurk_city_output.gd")

var magnification := 1
var columns := 2
var rows := 1
var selected_pages := PackedByteArray([1, 1])
var entire_city := true
var preview_texture: Texture2D


func _ready() -> void:
	custom_minimum_size = Vector2(560, 310)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func set_magnification(value: int) -> bool:
	var grid := Output.page_grid(value)
	if grid.is_empty():
		return false
	magnification = value
	columns = int(grid.columns)
	rows = int(grid.rows)
	selected_pages.resize(int(grid.count))
	selected_pages.fill(1)
	queue_redraw()
	selection_changed.emit()
	return true


func set_entire_city(value: bool) -> void:
	entire_city = value
	queue_redraw()


func set_preview_image(image: Image) -> void:
	if image == null or image.is_empty():
		preview_texture = null
	else:
		preview_texture = ImageTexture.create_from_image(image)
	queue_redraw()


func select_all(value := true) -> void:
	selected_pages.fill(1 if value else 0)
	queue_redraw()
	selection_changed.emit()


func selected_page_count() -> int:
	if entire_city:
		return selected_pages.size()
	var count := 0
	for selected in selected_pages:
		count += 1 if selected != 0 else 0
	return count


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color("ffffff"))
	if preview_texture != null:
		draw_texture_rect(preview_texture, bounds, false)
	else:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(16, 28),
			"Preparing city preview...",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color("303030")
		)
	var cell_size := Vector2(size.x / float(columns), size.y / float(rows))
	var font := ThemeDB.fallback_font
	for column in columns:
		for row in rows:
			var page_index := column * rows + row
			var cell := Rect2(
				Vector2(column, row) * cell_size,
				cell_size
			)
			var selected := entire_city or selected_pages[page_index] != 0
			if not selected:
				draw_rect(cell.grow(-1.0), Color(0.25, 0.25, 0.25, 0.72))
			draw_rect(
				cell.grow(-0.5),
				Color("1b4f9c") if selected else Color("686868"),
				false,
				2.0
			)
			draw_rect(
				Rect2(cell.position + Vector2(5, 4), Vector2(28, 20)),
				Color(1.0, 1.0, 1.0, 0.85)
			)
			draw_string(
				font,
				cell.position + Vector2(10, 19),
				str(page_index + 1),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				13,
				Color("202020")
			)


func _gui_input(event: InputEvent) -> void:
	if (
		not event is InputEventMouseButton
		or event.button_index != MOUSE_BUTTON_LEFT
		or not event.pressed
		or entire_city
	):
		return
	var column := clampi(floori(event.position.x * columns / size.x), 0, columns - 1)
	var row := clampi(floori(event.position.y * rows / size.y), 0, rows - 1)
	var page_index := column * rows + row
	selected_pages[page_index] = 0 if selected_pages[page_index] != 0 else 1
	queue_redraw()
	selection_changed.emit()
	accept_event()
