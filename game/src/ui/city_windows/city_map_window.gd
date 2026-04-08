class_name CityMapDialog
extends Window

signal mode_changed(mode: String)
signal center_requested(point: Vector2i)

const CityMapView = preload("res://src/view/city_map_window_control.gd")
const ClassicStyle = preload("res://src/ui/shared/classic_ui_style.gd")

var map_control: CityMapWindowControl


func _ready() -> void:
	# visible in the editor, closed at startup
	hide()
	close_requested.connect(hide)
	map_control = get_node("Background/Margin/CityMapWindowControl")
	map_control.mode_changed.connect(mode_changed.emit)
	map_control.center_requested.connect(center_requested.emit)


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
