class_name CityToolHoldMenu
extends PopupPanel

signal subtool_requested(index: int)

const PaletteView = preload("res://src/ui/shell/city_child_tool_palette.gd")
var palette: CityChildToolPalette


func _init() -> void:
	palette = PaletteView.new()
	palette.build()
	palette.custom_minimum_size = Vector2(280, 0)
	palette.scroll.custom_minimum_size.y = 180
	palette.subtool_requested.connect(_select_subtool)
	add_child(palette)


func show_tools(
	group_index: int, city: CityState, icon_provider: Callable,
	selected_subtool: int, anchor: Rect2
) -> void:
	palette.show_tool_group(group_index, city, icon_provider)
	palette.sync_selection(group_index, selected_subtool)
	var available_height := maxi(180, int(get_parent().get_viewport_rect().size.y * 0.6))
	var height := mini(available_height, palette.buttons.size() * 43 + 40)
	popup(Rect2i(Vector2i(anchor.end.x + 4, anchor.position.y), Vector2i(300, height)))


func _select_subtool(index: int) -> void:
	hide()
	subtool_requested.emit(index)
