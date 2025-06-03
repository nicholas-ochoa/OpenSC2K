# todo: load a city and put something on screen

extends Control


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("101820")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_CENTER)
	layout.position = Vector2(-260.0, -90.0)
	layout.size = Vector2(520.0, 180.0)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(layout)

	var title := Label.new()
	title.text = "SIMCITY 2000"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	layout.add_child(title)

	var status := Label.new()
	status.text = "Compatibility foundation in progress"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Color("9db2c5"))
	status.add_theme_font_size_override("font_size", 18)
	layout.add_child(status)

