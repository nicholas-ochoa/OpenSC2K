class_name CityMapDataTooltip
extends PanelContainer
## Immediate data-view hover text with the shared frosted tooltip background.

var map: CityMapControl
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"TooltipPanel"
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.theme_type_variation = &"TooltipLabel"
	_label.add_theme_font_size_override("font_size", 16)
	add_child(_label)
	FrostedTooltipPanel.bind(self)
	hide()


func refresh() -> void:
	visible = map.city_source != null and map.city != null and map.data_view_mesh != null and map.hover_tile.x >= 0
	if not visible:
		return
	_label.text = CityDataView.tile_text(map.city, map.data_view_mode, map.hover_tile, map._shift_pressed)
	size = get_combined_minimum_size()
	var point := map.get_local_mouse_position() + Vector2(18, 24)
	point.x = clampf(point.x, 4, maxf(4, map.size.x - size.x - 4))
	point.y = clampf(point.y, 4, maxf(4, map.size.y - size.y - 4))
	position = point
