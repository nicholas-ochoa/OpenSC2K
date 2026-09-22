class_name ScurkPaletteControl
extends Control

@warning_ignore_start("integer_division")

signal index_selected(index: int, background: bool)

const COLUMN_COUNT := 16

var palette: Sc2Palette
var cell_size := 18
var foreground_index := 0
var background_index := 255
var palette_cycle_ticks := 0


func set_cycle_tick(tick: int) -> void:
	palette_cycle_ticks = tick
	queue_redraw()


func display_palette_index(index: int) -> int:
	return palette.scurk_animation_index_map(palette_cycle_ticks)[index] if palette != null and palette.is_valid() else index


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(COLUMN_COUNT * cell_size, COLUMN_COUNT * cell_size)


func set_palette(value: Sc2Palette) -> void:
	palette = value
	queue_redraw()


func set_selected_indices(foreground: int, background: int) -> void:
	foreground_index = clampi(foreground, 0, 255)
	background_index = clampi(background, 0, 255)
	queue_redraw()


func index_at(position: Vector2) -> int:
	var column := floori(position.x / cell_size)
	var row := floori(position.y / cell_size)

	if column < 0 or row < 0 or column >= COLUMN_COUNT or row >= COLUMN_COUNT:
		return -1

	return row * COLUMN_COUNT + column


func _gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
		and event.pressed
	):
		var index := index_at(event.position)

		if index >= 0:
			var background: bool = event.button_index == MOUSE_BUTTON_RIGHT

			if background:
				background_index = index
			else:
				foreground_index = index

			queue_redraw()
			index_selected.emit(index, background)
			accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	var index := index_at(at_position)

	return "Palette index %d (0x%02X)" % [index, index] if index >= 0 else ""


func _draw() -> void:
	for index in 256:
		var x := (index % COLUMN_COUNT) * cell_size
		var y := int(index / COLUMN_COUNT) * cell_size
		var color := (
			palette.color(display_palette_index(index))
			if palette != null and palette.is_valid()
			else Color.MAGENTA
		)
		draw_rect(Rect2(x, y, cell_size, cell_size), color, true)
		draw_rect(Rect2(x, y, cell_size, cell_size), Color(0.0, 0.0, 0.0, 0.3), false, 1.0)

	var background_x := (background_index % COLUMN_COUNT) * cell_size
	var background_y := int(background_index / COLUMN_COUNT) * cell_size
	draw_rect(
		Rect2(background_x, background_y, cell_size, cell_size), Color("ff3030"), false, 2.0
	)
	var selected_x := (foreground_index % COLUMN_COUNT) * cell_size
	var selected_y := int(foreground_index / COLUMN_COUNT) * cell_size
	draw_rect(
		Rect2(selected_x, selected_y, cell_size, cell_size), Color.WHITE, false, 2.0
	)
	draw_rect(
		Rect2(selected_x + 2, selected_y + 2, cell_size - 4, cell_size - 4),
		Color.BLACK, false, 1.0
	)
