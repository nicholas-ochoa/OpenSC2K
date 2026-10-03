class_name ScurkPlaceObjectList
extends Tree
## The Place & Print object list. Each row shows a thumbnail, the tile name,
## and dimmed lines for the tile type and the tile ID.

signal tile_chosen(index: int)

const THUMBNAIL_SIZE := 48
const ROW_PADDING := 4
const TEXT_GAP := 8
const DIMMED_ALPHA := 0.6

var item_count: int:
	get:
		return _rows.size()

var _rows: Array[Row] = []
var _items: Array[TreeItem] = []
# a selection from code does not report a choice
var _selecting := false


func _init() -> void:
	hide_root = true
	select_mode = Tree.SELECT_ROW
	allow_reselect = true
	columns = 1
	item_selected.connect(_emit_selected)
	item_activated.connect(_emit_selected)


func clear_tiles() -> void:
	clear()
	_rows.clear()
	_items.clear()
	create_item()


func add_tile(tile_id: int, tile_name: String, tile_type: String, thumbnail: Texture2D, tooltip: String) -> int:
	if get_root() == null:
		create_item()

	var item := create_item(get_root())
	item.set_cell_mode(0, TreeItem.CELL_MODE_CUSTOM)
	item.set_custom_draw_callback(0, _draw_row)
	item.set_custom_minimum_height(_row_height())
	item.set_tooltip_text(0, tooltip)
	item.set_metadata(0, _rows.size())
	_rows.append(Row.new(tile_id, tile_name, tile_type, thumbnail))
	_items.append(item)

	return _rows.size() - 1


func tile_id_at(index: int) -> int:
	return _rows[index].tile_id if index >= 0 and index < _rows.size() else -1


func select_index(index: int) -> void:
	if index < 0 or index >= _items.size():
		return

	_selecting = true
	set_selected(_items[index], 0)
	_selecting = false
	scroll_to_item(_items[index])


func _emit_selected() -> void:
	var item := get_selected()

	if item != null and not _selecting:
		tile_chosen.emit(int(item.get_metadata(0)))


func _row_height() -> int:
	var font := get_theme_font("font")
	var size := get_theme_font_size("font_size")
	var line := int(font.get_height(size)) if font != null else 16

	return maxi(THUMBNAIL_SIZE, line * 3) + ROW_PADDING * 2


func _draw_row(item: TreeItem, rect: Rect2) -> void:
	var row := _rows[int(item.get_metadata(0))]
	var font := get_theme_font("font")
	var size := get_theme_font_size("font_size")
	var selected := item.is_selected(0)
	var color := get_theme_color("font_selected_color" if selected else "font_color")
	var dimmed := Color(color, color.a * DIMMED_ALPHA)
	var x := rect.position.x + ROW_PADDING

	if row.thumbnail != null:
		var image_size := row.thumbnail.get_size()
		var scale := minf(1.0, float(THUMBNAIL_SIZE) / maxf(image_size.x, image_size.y))
		var drawn := image_size * scale
		var origin := Vector2(x + (THUMBNAIL_SIZE - drawn.x) / 2.0, rect.position.y + (rect.size.y - drawn.y) / 2.0)
		draw_texture_rect(row.thumbnail, Rect2(origin, drawn), false)

	if font == null:
		return

	x += THUMBNAIL_SIZE + TEXT_GAP
	var line := font.get_height(size)
	var width := maxf(0.0, rect.end.x - x - ROW_PADDING)
	var y := rect.position.y + (rect.size.y - line * 3) / 2.0
	var lines := [[row.tile_name, color], [row.tile_type, dimmed], ["Tile %03d" % row.tile_id, dimmed]]

	for entry: Array in lines:
		var text := TextLine.new()
		text.add_string(String(entry[0]), font, size)
		text.width = width
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.draw(get_canvas_item(), Vector2(x, y), entry[1])
		y += line


class Row extends RefCounted:
	var tile_id: int
	var tile_name: String
	var tile_type: String
	var thumbnail: Texture2D

	func _init(id: int, name: String, type: String, image: Texture2D) -> void:
		tile_id = id
		tile_name = name
		tile_type = type
		thumbnail = image
