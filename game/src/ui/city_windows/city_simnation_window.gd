class_name CitySimNationWindow
extends Window

const SimNationView = preload("res://src/view/simnation_window_control.gd")

var simnation_control: SimNationWindowControl
var neighbor_name_strings: Dictionary = {}


func _ready() -> void:
	hide()
	close_requested.connect(hide)
	simnation_control = get_node("View")


func set_resources(
	sprite_sheet: Image, national_format: String, name_strings: Dictionary
) -> void:
	neighbor_name_strings = name_strings.duplicate()
	simnation_control.set_sprite_sheet(sprite_sheet)
	simnation_control.set_national_format(national_format)


func show_city(value: CityState) -> void:
	if value == null or simnation_control == null:
		return

	simnation_control.set_neighbor_names(_neighbor_names(value))
	simnation_control.set_city(value)

	if visible:
		move_to_foreground()
	else:
		popup_centered(Vector2i(612, 480))


func refresh_city(value: CityState) -> void:
	if visible and simnation_control != null:
		simnation_control.set_city(value)


func _neighbor_names(value: CityState) -> Dictionary[int, String]:
	var names: Dictionary[int, String] = {}
	var data := SimNationView.snapshot(value)

	if not data.ok:
		return names

	for neighbor in data.neighbors:
		var name_index := int(neighbor.name_index)

		if name_index <= 0:
			continue

		var resource_id := SimNationView.NEIGHBOR_NAME_STRING_BASE + name_index
		names[name_index] = str(
			neighbor_name_strings.get(resource_id, "City %d" % name_index)
		)

	return names
