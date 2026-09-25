class_name CityMapLegend
extends Panel
## Keep the frosted background separate from the legend text and symbols.

const GlassShader = preload("res://src/ui/shared/frosted_panel.gdshader")

var map: CityMapControl
var _content: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"MapLegend"
	var glass := ShaderMaterial.new()
	glass.shader = GlassShader
	material = glass
	var background_copy := BackBufferCopy.new()
	background_copy.show_behind_parent = true
	add_child(background_copy)
	AppUiTheme.bind_frosted_panel(self, background_copy)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.draw.connect(_draw_content)
	add_child(_content)
	hide()


func refresh() -> void:
	var has_trip := map.trip_reach != null and map.trip_reach.analysis != null
	visible = map.city_source != null and (map.data_view_mesh != null or has_trip)
	if not visible:
		return
	var area := map.trip_reach.key_rect(map) if has_trip else Rect2(
		map.layers.data_key_origin(), Vector2(320, 116 if map.data_view_mode == CityViewMode.Mode.HEIGHT else 96))
	position = area.position
	size = area.size
	_content.size = size
	_content.queue_redraw()


func _draw_content() -> void:
	if map.trip_reach != null and map.trip_reach.analysis != null:
		map.trip_reach.draw_key(_content)
	elif map.data_view_mesh != null:
		map.layers.draw_data_key(_content)
