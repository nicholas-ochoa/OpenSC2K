class_name ClassicUiStyle
extends RefCounted


static func create_box(
	background: Color,
	border: Color,
	width: int,
	horizontal_margin := 5,
	vertical_margin := 3
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.content_margin_left = horizontal_margin
	box.content_margin_top = vertical_margin
	box.content_margin_right = horizontal_margin
	box.content_margin_bottom = vertical_margin
	return box


static func create_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 13
	result.set_color("font_color", "Label", Color("101010"))
	result.set_color("font_color", "Button", Color("101010"))
	result.set_color("font_hover_color", "Button", Color("101010"))
	result.set_color("font_pressed_color", "Button", Color("101010"))
	result.set_color("font_focus_color", "Button", Color("101010"))
	result.set_color("font_color", "OptionButton", Color("101010"))
	result.set_stylebox(
		"normal", "Button", create_box(Color("c0c0c0"), Color("ffffff"), 2)
	)
	result.set_stylebox(
		"hover", "Button", create_box(Color("d0d0d0"), Color("ffffff"), 2)
	)
	result.set_stylebox(
		"pressed", "Button", create_box(Color("a0a0a0"), Color("404040"), 2)
	)
	result.set_stylebox(
		"focus", "Button", create_box(Color("c0c0c0"), Color("000000"), 1)
	)
	result.set_stylebox(
		"normal", "OptionButton", create_box(Color("ffffff"), Color("808080"), 2)
	)
	result.set_stylebox(
		"hover", "OptionButton", create_box(Color("ffffff"), Color("000080"), 2)
	)
	result.set_stylebox(
		"pressed", "OptionButton", create_box(Color("e0e0e0"), Color("404040"), 2)
	)
	result.set_stylebox(
		"normal", "PanelContainer", create_box(Color("c0c0c0"), Color("808080"), 1)
	)
	result.set_stylebox(
		"panel",
		"TooltipPanel",
		create_box(
			Color(0.0, 0.0, 0.0, 0.82), Color(1.0, 1.0, 1.0, 0.45), 1, 7, 5
		),
	)
	result.set_color("font_color", "TooltipLabel", Color.WHITE)
	return result
