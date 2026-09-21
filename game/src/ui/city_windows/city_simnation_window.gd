class_name CitySimNationWindow
extends Window

var simnation_control: SimNationWindowControl


func _ready() -> void:
	hide()
	close_requested.connect(hide)
	simnation_control = get_node("View")


func set_resources(sprite_sheet: Image) -> void:
	simnation_control.set_sprite_sheet(sprite_sheet)


func show_city(value: CityState) -> void:
	if value == null or simnation_control == null:
		return

	simnation_control.set_city(value)

	if visible:
		move_to_foreground()
	else:
		popup_centered(Vector2i(612, 480))


func refresh_city(value: CityState) -> void:
	if visible and simnation_control != null:
		simnation_control.set_city(value)
