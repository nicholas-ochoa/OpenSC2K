class_name ApplicationCityMapReports
extends RefCounted

const CityMapView = preload("res://src/view/city_map_window_control.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func open_window() -> void:
	if app.document_state.city == null or app.city_dialogs.city_map_window == null:
		return

	app.city_dialogs.city_map_window.toggle_city(app.document_state.city, app.asset_state.palette, viewport_outline())


func on_mode_changed(mode: String) -> void:
	app.status_label.theme_type_variation = ""
	app.status_label.text = tr("City Map: %s") % CityMapView.MODE_NAMES.get(mode, mode)


# the city map window drives the isometric view while its checkbox is on
func on_isometric_view_requested(mode: CityViewMode.Mode) -> void:
	if app.document_state.city == null or app.view_state.overlay_mode == mode:
		return

	app.menus.set_overlay(mode)


func on_center_requested(point: Vector2i) -> void:
	app.map_view.center_on_tile(point)
	app.status_label.theme_type_variation = ""
	app.status_label.text = tr("City view centered at %d, %d.") % [point.x, point.y]


func viewport_outline() -> PackedVector2Array:
	if app.map_view == null or not CityViewMode.DISPLAY_MODES.has(app.view_state.overlay_mode):
		return PackedVector2Array()

	return app.map_view.visible_tile_outline()


func refresh_viewport() -> void:
	if app.city_dialogs.city_map_window != null:
		app.city_dialogs.city_map_window.refresh_viewport(viewport_outline())
