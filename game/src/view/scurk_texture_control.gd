class_name ScurkTextureControl
extends Control

signal texture_selected(index: int)

const COLUMN_COUNT := 3
const CELL_SIZE := 20
const SWATCH_SCALE := 2
const SWATCH_OFFSET := 2

var palette: Sc2Palette
var patterns: Array[PackedInt32Array] = []
var foreground_index := 0
var background_index := 255
var selected_index := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(COLUMN_COUNT * CELL_SIZE, 0)


func set_palette(value: Sc2Palette) -> void:
	palette = value
	queue_redraw()


func set_patterns(value: Array[PackedInt32Array]) -> void:
	patterns.clear()
	for pattern in value:
		patterns.append(pattern.duplicate())
	selected_index = clampi(selected_index, 0, maxi(0, patterns.size() - 1))
	var row_count := int(ceil(float(patterns.size()) / COLUMN_COUNT))
	custom_minimum_size = Vector2(COLUMN_COUNT * CELL_SIZE, row_count * CELL_SIZE)
	reset_size()
	queue_redraw()


func set_colors(foreground: int, background: int) -> void:
	foreground_index = clampi(foreground, 0, 255)
	background_index = clampi(background, 0, 255)
	queue_redraw()


func set_selected(index: int) -> void:
	selected_index = clampi(index, 0, maxi(0, patterns.size() - 1))
	queue_redraw()


func index_at(position: Vector2) -> int:
	var column := floori(position.x / CELL_SIZE)
	var row := floori(position.y / CELL_SIZE)
	var index := row * COLUMN_COUNT + column
	if (
		column < 0
		or column >= COLUMN_COUNT
		or row < 0
		or index < 0
		or index >= patterns.size()
	):
		return -1
	return index


func _gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		var index := index_at(event.position)
		if index >= 0:
			selected_index = index
			queue_redraw()
			texture_selected.emit(index)
			accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	var index := index_at(at_position)
	if index < 0:
		return ""
	if index == 0:
		return "Solid foreground"
	if index == 1:
		return "Foreground and background mix"
	if index == 2:
		return "Solid background"
	return "Original SCURK texture %d" % (index - 2)


func _draw() -> void:
	for index in patterns.size():
		var origin := Vector2i(
			(index % COLUMN_COUNT) * CELL_SIZE,
			int(index / COLUMN_COUNT) * CELL_SIZE
		)
		draw_rect(Rect2(origin, Vector2i(CELL_SIZE, CELL_SIZE)), Color("c0c0c0"), true)
		var pattern := patterns[index]
		if pattern.size() == 64:
			for y in 8:
				for x in 8:
					var source := pattern[y * 8 + x]
					var palette_index := _resolve(source)
					var color := (
						palette.color(palette_index)
						if palette != null and palette.is_valid()
						else Color.MAGENTA
					)
					draw_rect(
						Rect2(
							origin.x + SWATCH_OFFSET + x * SWATCH_SCALE,
							origin.y + SWATCH_OFFSET + y * SWATCH_SCALE,
							SWATCH_SCALE, SWATCH_SCALE
						),
						color, true
					)
		draw_rect(
			Rect2(origin, Vector2i(CELL_SIZE, CELL_SIZE)),
			Color("404040"), false, 1.0
		)
	if selected_index >= 0 and selected_index < patterns.size():
		var selected_origin := Vector2i(
			(selected_index % COLUMN_COUNT) * CELL_SIZE,
			int(selected_index / COLUMN_COUNT) * CELL_SIZE
		)
		draw_rect(
			Rect2(selected_origin + Vector2i.ONE, Vector2i(CELL_SIZE - 2, CELL_SIZE - 2)),
			Color("ff2020"), false, 2.0
		)


func _resolve(source: int) -> int:
	if source == 0xff:
		return foreground_index
	if source == 0xf5 or source == 0:
		return background_index
	return clampi(source, 0, 255)
