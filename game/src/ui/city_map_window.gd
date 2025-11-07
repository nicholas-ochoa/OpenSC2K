class_name CityMapDialog
extends Window

signal mode_changed(mode: String)
signal center_requested(point: Vector2i)

const CityMapView = preload("res://src/view/city_map_window_control.gd")
const ClassicStyle = preload("res://src/ui/classic_ui_style.gd")

var map_control: CityMapWindowControl


func _ready() -> void:
	name = "CityMapWindow"
	title = "City Map"
	size = Vector2i(480, 680)
	min_size = Vector2i(420, 620)
	transient = true
	exclusive = false
	visible = false
	close_requested.connect(hide)

	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override(
		"panel", ClassicStyle.create_box(Color("c0c0c0"), Color("808080"), 2)
	)
	add_child(background)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	background.add_child(margin)
	map_control = CityMapView.new()
	map_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_control.mode_changed.connect(mode_changed.emit)
	map_control.center_requested.connect(center_requested.emit)
	margin.add_child(map_control)


func set_resources(icon_strip: Image, strings: Dictionary) -> void:
	map_control.set_resources(icon_strip, strings)


func toggle_city(
	value: CityState, palette: Sc2Palette, viewport_outline: PackedVector2Array
) -> void:
	if value == null or map_control == null:
		return
	if visible:
		hide()
		return
	map_control.set_city(value, palette)
	map_control.refresh_viewport(viewport_outline)
	popup_centered(Vector2i(480, 680))


func refresh_city(
	value: CityState, palette: Sc2Palette, viewport_outline: PackedVector2Array
) -> void:
	if not visible or map_control == null:
		return
	map_control.set_city(value, palette)
	map_control.refresh_viewport(viewport_outline)


func refresh_viewport(viewport_outline: PackedVector2Array) -> void:
	if visible and map_control != null:
		map_control.refresh_viewport(viewport_outline)
