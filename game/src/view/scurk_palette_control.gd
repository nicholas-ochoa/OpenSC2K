class_name ScurkPaletteControl
extends Control

@warning_ignore_start("integer_division")

signal index_selected(index: int)
signal index_hovered(index: int)
signal ramp_changed(indices: PackedInt32Array)
signal navigation_changed(state: Dictionary)

const COLUMN_COUNT := 16
const RECENT_LIMIT := 32
const MODE_ALL := 0
const MODE_USED := 1
const MODE_RECENT := 2
const MODE_FAVORITES := 3
const MODE_RAMP := 4

var palette: Sc2Palette
var cell_size := 18
var selected_color_index := 0
var palette_cycle_ticks := 0
var view_mode := MODE_ALL
var used_indices := PackedInt32Array()
var recent_indices := PackedInt32Array()
var favorite_indices := PackedInt32Array()
var ramp_indices := PackedInt32Array()
var visible_indices := PackedInt32Array()
var hovered_index := -1
var animated_indices := PackedInt32Array()
var cycle_indices := PackedInt32Array()


func set_cycle_tick(tick: int) -> void:
	palette_cycle_ticks = tick
	if palette != null and palette.is_valid():
		cycle_indices = palette.scurk_animation_index_map(tick)
	queue_redraw()


func display_palette_index(index: int) -> int:
	return cycle_indices[index] if index >= 0 and index < cycle_indices.size() else index


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(COLUMN_COUNT * cell_size, COLUMN_COUNT * cell_size)
	_refresh_indices()
	mouse_exited.connect(func() -> void: _set_hovered(-1))


func set_palette(value: Sc2Palette) -> void:
	palette = value
	animated_indices.clear()
	if palette != null and palette.is_valid():
		var changed := palette.animation_index_map_steps(1, 1)
		for index in 256:
			if changed[index] != index:
				animated_indices.append(index)
	set_cycle_tick(palette_cycle_ticks)


func set_selected_color(index: int) -> void:
	selected_color_index = clampi(index, 0, 255)
	queue_redraw()


func set_view_mode(mode: int) -> void:
	view_mode = clampi(mode, MODE_ALL, MODE_RAMP)
	_refresh_indices()


func set_used_pixels(pixels: PackedInt32Array) -> void:
	var present := PackedByteArray()
	present.resize(256)
	for index in pixels:
		if index >= 0 and index <= 255:
			present[index] = 1
	used_indices.clear()
	for index in 256:
		if present[index]:
			used_indices.append(index)
	_refresh_indices()


func remember_index(index: int) -> void:
	if index < 0 or index > 255:
		return
	var previous := recent_indices.find(index)
	if previous >= 0:
		recent_indices.remove_at(previous)
	recent_indices.insert(0, index)
	if recent_indices.size() > RECENT_LIMIT:
		recent_indices.resize(RECENT_LIMIT)
	_refresh_indices()
	navigation_changed.emit(export_state())


func toggle_favorite(index: int) -> void:
	_toggle_index(favorite_indices, index)
	_refresh_indices()
	navigation_changed.emit(export_state())


func toggle_ramp_index(index: int) -> void:
	_toggle_index(ramp_indices, index)
	_refresh_indices()
	ramp_changed.emit(ramp_indices.duplicate())
	navigation_changed.emit(export_state())


func clear_ramp() -> void:
	ramp_indices.clear()
	_refresh_indices()
	ramp_changed.emit(ramp_indices.duplicate())
	navigation_changed.emit(export_state())


func export_state() -> Dictionary:
	return {"recent": Array(recent_indices), "favorites": Array(favorite_indices), "ramp": Array(ramp_indices)}


func import_state(state: Dictionary) -> void:
	recent_indices = _clean_indices(state.get("recent", []), RECENT_LIMIT)
	favorite_indices = _clean_indices(state.get("favorites", []))
	ramp_indices = _clean_indices(state.get("ramp", []))
	_refresh_indices()
	ramp_changed.emit(ramp_indices.duplicate())


func index_at(position: Vector2) -> int:
	var column := floori(position.x / cell_size)
	var row := floori(position.y / cell_size)
	if column < 0 or row < 0 or column >= COLUMN_COUNT or row >= COLUMN_COUNT:
		return -1

	var slot := row * COLUMN_COUNT + column
	return visible_indices[slot] if slot < visible_indices.size() else -1


func _refresh_indices() -> void:
	match view_mode:
		MODE_USED:
			visible_indices = used_indices.duplicate()
		MODE_RECENT:
			visible_indices = recent_indices.duplicate()
		MODE_FAVORITES:
			visible_indices = favorite_indices.duplicate()
		MODE_RAMP:
			visible_indices = ramp_indices.duplicate()
		_:
			visible_indices.resize(256)
			for index in 256:
				visible_indices[index] = index
	_set_hovered(-1)
	queue_redraw()


func _set_hovered(index: int) -> void:
	if hovered_index == index:
		return
	hovered_index = index
	index_hovered.emit(index)


static func _toggle_index(indices: PackedInt32Array, index: int) -> void:
	if index < 0 or index > 255:
		return
	var existing := indices.find(index)
	if existing >= 0:
		indices.remove_at(existing)
	else:
		indices.append(index)


static func _clean_indices(values: Variant, limit := 256) -> PackedInt32Array:
	var result := PackedInt32Array()
	if not values is Array and not values is PackedInt32Array:
		return result
	for value: Variant in values:
		if not value is int and not value is float:
			continue
		var index := int(value)
		if index >= 0 and index <= 255 and float(index) == float(value) and not result.has(index):
			result.append(index)
			if result.size() == limit:
				break
	return result


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered(index_at(event.position))
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var index := index_at(event.position)
		if index < 0:
			return
		if event.shift_pressed:
			toggle_ramp_index(index)
		elif event.ctrl_pressed or event.meta_pressed:
			toggle_favorite(index)
		else:
			selected_color_index = index
			remember_index(index)
			index_selected.emit(index)
		queue_redraw()
		accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	var index := index_at(at_position)
	if index < 0:
		return ""
	var note := " (animated)" if animated_indices.has(index) else ""
	var ramp := ramp_indices.find(index)
	if ramp >= 0:
		note += " · ramp step %d" % (ramp + 1)
	return "Palette index %d (0x%02X)%s\nClick: select color\nShift-click: add/remove ramp step\nCtrl/Cmd-click: add/remove favorite\nHover: highlight matching pixels" % [index, index, note]


func _cell_rect(slot: int) -> Rect2:
	return Rect2((slot % COLUMN_COUNT) * cell_size, (slot / COLUMN_COUNT) * cell_size, cell_size, cell_size)


func _draw() -> void:
	for slot in visible_indices.size():
		var index := visible_indices[slot]
		var rect := _cell_rect(slot)
		var color := palette.color(display_palette_index(index)) if palette != null and palette.is_valid() else Color.MAGENTA
		draw_rect(rect, color, true)
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.3), false, 1.0)
		if animated_indices.has(index):
			var center := rect.position + Vector2(cell_size - 4, 4)
			draw_circle(center, 2.5, Color.BLACK)
			draw_circle(center, 1.5, Color.WHITE)
		if favorite_indices.has(index):
			draw_rect(Rect2(rect.position + Vector2(2, cell_size - 5), Vector2(3, 3)), Color("ffdc70"))
		if ramp_indices.has(index):
			draw_line(rect.position + Vector2(4, cell_size - 3), rect.end - Vector2(3, 3), Color("6eeeff"), 2.0)

	var selected_slot := visible_indices.find(selected_color_index)
	if selected_slot >= 0:
		var rect := _cell_rect(selected_slot)
		draw_rect(rect, Color.WHITE, false, 2.0)
		draw_rect(rect.grow(-2), Color.BLACK, false, 1.0)
	if visible_indices.is_empty():
		var font := get_theme_default_font()
		draw_string(font, Vector2(6, 22), "No colors in this view.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, get_theme_color("font_color", "Label"))
