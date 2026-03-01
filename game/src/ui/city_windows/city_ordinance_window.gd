class_name CityOrdinanceWindow
extends Window

signal ordinances_changed
signal update_failed(message: String)

const OrdinanceView = preload("res://src/view/ordinance_window_control.gd")
const ClassicStyle = preload("res://src/ui/shared/classic_ui_style.gd")

var ordinance_control: OrdinanceWindowControl


func _ready() -> void:
	name = "OrdinanceWindow"
	title = "Ordinances"
	theme = ThemeDB.get_default_theme().duplicate()
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_color("font_uneditable_color", "LineEdit", Color.WHITE)

	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(state, "CheckBox", Color.WHITE)

	size = Vector2i(800, 640)
	min_size = Vector2i(720, 580)
	transient = true
	exclusive = true
	visible = false
	close_requested.connect(hide)

	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override(
		"panel", ClassicStyle.create_box(Color("303030"), Color("b0b0b0"), 2)
	)
	add_child(background)
	var margin := MarginContainer.new()

	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)

	background.add_child(margin)
	ordinance_control = OrdinanceView.new()
	ordinance_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ordinance_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ordinance_control.ordinances_changed.connect(ordinances_changed.emit)
	ordinance_control.update_failed.connect(update_failed.emit)
	ordinance_control.close_requested.connect(hide)
	margin.add_child(ordinance_control)


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
