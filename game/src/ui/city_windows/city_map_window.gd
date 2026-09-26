class_name CityMapDialog
extends Window

signal mode_changed(mode: String)
signal center_requested(point: Vector2i)
signal isometric_view_requested(mode: CityViewMode.Mode)

const CityMapView = preload("res://src/view/city_map_window_control.gd")
const DEFAULT_SIZE := Vector2i(420, 530)

var map_control: CityMapWindowControl
# the size before it was fitted to screen pixels, the fitted size, and the
# position of the last fit
var _unfitted_size := DEFAULT_SIZE
var _fitted_size := Vector2i.ZERO
var _fitted_position := Vector2i.ZERO
var _last_position := Vector2i.ZERO


func _ready() -> void:
	hide()
	close_requested.connect(hide)
	map_control = get_node("Background/Margin/CityMapWindowControl")
	map_control.mode_changed.connect(mode_changed.emit)
	map_control.center_requested.connect(center_requested.emit)
	map_control.isometric_view_requested.connect(isometric_view_requested.emit)
	get_tree().root.size_changed.connect(_fit_screen_pixels)


func set_resources(icon_strip: Image) -> void:
	map_control.set_resources(icon_strip)


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
	_unfitted_size = DEFAULT_SIZE
	popup_centered(DEFAULT_SIZE)
	_fitted_size = DEFAULT_SIZE
	_fit_screen_pixels()


func refresh_city(
	value: CityState, palette: Sc2Palette, viewport_outline: PackedVector2Array
) -> void:
	if not visible or map_control == null:
		return

	map_control.set_city(value, palette)
	map_control.refresh_viewport(viewport_outline)


func _process(_delta: float) -> void:
	# the fit depends on the position, and a dragged window has no signal. fit
	# again when the window stops moving
	var moving := position != _last_position
	_last_position = position

	if visible and not moving and position != _fitted_position:
		_fit_screen_pixels()


# keep the map artwork on whole screen pixels. the fit only enlarges the window
# by a few interface pixels and never moves it
func _fit_screen_pixels() -> void:
	if not visible:
		return

	# a size other than the last fitted size comes from the player
	if size != _fitted_size:
		_unfitted_size = size

	_fitted_position = position
	_fitted_size = ScreenPixels.window_size(position, _unfitted_size)
	size = _fitted_size


# keeps the isometric view checkbox honest when the city view changes elsewhere
func sync_view_mode(mode: CityViewMode.Mode) -> void:
	if map_control != null:
		map_control.sync_view_mode(mode)


func refresh_viewport(viewport_outline: PackedVector2Array) -> void:
	if visible and map_control != null:
		map_control.refresh_viewport(viewport_outline)
