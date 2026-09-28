class_name CityMapContextMenu
extends PopupMenu
## The map click menu of the original game: Center Map, Query Tile, and Bulldoze Tile.

enum Item { CENTER, QUERY, BULLDOZE }

var map: CityMapControl
var point := Vector2i(-1, -1)


func _init() -> void:
	add_item("Center Map", Item.CENTER)
	add_item("Query Tile", Item.QUERY)
	add_item("Bulldoze Tile", Item.BULLDOZE)
	id_pressed.connect(_on_id_pressed)


# open the menu at a map position for the tile below it
func open_at(tile: Vector2i, map_position: Vector2) -> void:
	point = tile
	var transform := map.get_global_transform_with_canvas() if is_embedded() else map.get_screen_transform()
	position = Vector2i(transform * map_position)
	reset_size()
	popup()


func _on_id_pressed(id: int) -> void:
	if point.x < 0:
		return

	match id:
		Item.CENTER:
			map.center_requested.emit(point)
		Item.QUERY:
			map.query_requested.emit(point)
		Item.BULLDOZE:
			map.bulldoze_requested.emit(point)
