class_name CityOrdinanceWindow
extends Window

signal ordinances_changed
signal update_failed(message: String)

const OrdinanceView = preload("res://src/view/ordinance_window_control.gd")
const ClassicStyle = preload("res://src/ui/shared/classic_ui_style.gd")

var ordinance_control: OrdinanceWindowControl


func _ready() -> void:
	close_requested.connect(hide)
	theme = ThemeDB.get_default_theme().duplicate()
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_color("font_uneditable_color", "LineEdit", Color.WHITE)

	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(state, "CheckBox", Color.WHITE)

	ordinance_control = get_node("Background/Margin/OrdinanceWindowControl")
	ordinance_control.ordinances_changed.connect(ordinances_changed.emit)
	ordinance_control.update_failed.connect(update_failed.emit)
	ordinance_control.close_requested.connect(hide)


func open_city(value: CityState) -> Dictionary:
	if value == null or ordinance_control == null:
		return {"ok": false, "error": "city is not available"}

	var result := ordinance_control.set_city(value)

	if result.get("ok", false):
		popup_centered(Vector2i(800, 640))

	return result


func refresh_city() -> void:
	if visible and ordinance_control != null:
		ordinance_control.refresh()
