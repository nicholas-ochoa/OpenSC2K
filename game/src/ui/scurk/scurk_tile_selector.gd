class_name ScurkTileSelector
extends ScurkTileRow

signal item_selected(index: int)

const RowScene = preload("res://src/ui/scurk/scurk_tile_row.tscn")

class Entry extends RefCounted:
	var large_id: int
	var title: String
	var category: String
	var thumbnail: Texture2D

	func _init(id: int, name: String, group: String, image: Texture2D) -> void:
		large_id = id
		title = name
		category = group
		thumbnail = image


var entries: Array[Entry] = []
var selected := -1
var rows: Array[ScurkTileRow] = []
var rows_current := false


func _ready() -> void:
	super._ready()
	pressed.connect(show_choices)
	$Popup.popup_hide.connect(grab_focus)


func set_entries(values: Array[Entry], selected_id: int) -> void:
	$Popup.hide()
	entries = values
	rows_current = false
	selected = -1
	for index in entries.size():
		if entries[index].large_id == selected_id:
			selected = index
	if selected < 0 and not entries.is_empty():
		selected = 0
	disabled = entries.is_empty()
	select(selected)


func select(index: int) -> void:
	selected = index if index >= 0 and index < entries.size() else -1
	if selected < 0:
		show_tile(0, "No matching tiles", "", null)
		$Content/Row/Labels/Category.text = ""
		return
	var entry := entries[selected]
	show_tile(ScurkEditorRules.object_tile_id(entry.large_id), entry.title, entry.category, entry.thumbnail)


func update_thumbnail(large_id: int, thumbnail: Texture2D) -> void:
	for index in entries.size():
		var entry := entries[index]
		if entry.large_id != large_id:
			continue
		entry.thumbnail = thumbnail
		if rows_current:
			rows[index].show_tile(ScurkEditorRules.object_tile_id(large_id), entry.title, entry.category, thumbnail)
		if index == selected:
			select(index)
		return


func show_choices() -> void:
	if entries.is_empty():
		return
	if not rows_current:
		_rebuild_rows()
	var anchor := get_global_rect()
	var bounds := get_viewport_rect()
	var padding: Vector2 = $Popup.get_theme_stylebox("panel", "PopupPanel").get_minimum_size()
	var content_height := rows[0].get_combined_minimum_size().y * rows.size() + padding.y
	var popup_size := Vector2(minf(maxf(size.x, 310), bounds.size.x), minf(minf(content_height, 480), bounds.size.y))
	var origin := Vector2(clampf(anchor.position.x, 0, bounds.size.x - popup_size.x), anchor.end.y)
	if origin.y + popup_size.y > bounds.end.y:
		origin.y = maxf(0, anchor.position.y - popup_size.y)
	$Popup.popup(Rect2i(Vector2i(origin), Vector2i(popup_size)))
	_focus_selected.call_deferred()


func _rebuild_rows() -> void:
	for row in rows:
		row.get_parent().remove_child(row)
		row.queue_free()
	rows.clear()
	for index in entries.size():
		var entry := entries[index]
		var row := RowScene.instantiate() as ScurkTileRow
		$Popup/Scroll/Rows.add_child(row)
		row.show_tile(ScurkEditorRules.object_tile_id(entry.large_id), entry.title, entry.category, entry.thumbnail)
		row.pressed.connect(_choose.bind(index))
		row.focus_entered.connect(func() -> void: $Popup/Scroll.ensure_control_visible(row))
		rows.append(row)
	for index in rows.size():
		rows[index].focus_neighbor_top = rows[maxi(0, index - 1)].get_path()
		rows[index].focus_neighbor_bottom = rows[mini(rows.size() - 1, index + 1)].get_path()
	rows_current = true


func _focus_selected() -> void:
	if $Popup.visible and selected >= 0 and selected < rows.size():
		rows[selected].grab_focus()
		$Popup/Scroll.ensure_control_visible(rows[selected])


func _choose(index: int) -> void:
	select(index)
	$Popup.hide()
	item_selected.emit(index)
