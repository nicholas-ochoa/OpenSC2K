class_name CityOrdinanceWindow
extends Window

signal ordinances_changed
signal update_failed(message: String)

const OrdinanceView = preload("res://src/view/ordinance_window_control.gd")

var ordinance_control: OrdinanceWindowControl


func _ready() -> void:
	name = "OrdinanceWindow"
	title = "Ordinances"
	size = Vector2i(800, 640)
	min_size = Vector2i(720, 580)
	transient = true
	exclusive = true
	visible = false
	close_requested.connect(hide)

	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override(
		"panel", _classic_box(Color("c0c0c0"), Color("808080"), 2)
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


func _classic_box(color: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.content_margin_left = 5
	box.content_margin_top = 3
	box.content_margin_right = 5
	box.content_margin_bottom = 3
	return box
