class_name SaveChangesDialog
extends ConfirmationDialog


func _ready() -> void:
	title = "Save Changes"
	min_size = Vector2i(480, 190)
	exclusive = true
	get_label().add_theme_color_override("font_color", Color.WHITE)
	get_ok_button().text = "Save"
	get_cancel_button().text = "Cancel"
	add_button("Don't Save", true, "discard")


func set_city(city_name: String) -> void:
	dialog_text = "Save changes to %s before you continue?" % city_name


func show_city(city_name: String) -> void:
	set_city(city_name)
	popup_centered()
