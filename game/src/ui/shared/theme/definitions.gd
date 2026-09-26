class_name AppUiThemeDefinitions
extends RefCounted



static func build(value: String, files := false, translucent_menus := true) -> Theme:
	var dark := value == "dark"
	var result := _dark_theme() if dark else _light_file_dialog_theme() if files else _light_theme()
	result.set_color("default_color", "RichTextLabel", result.get_color("font_color", "Label"))
	# spinbox has separate arrow buttons; button icon colors do not reach them
	for direction in ["up", "down"]:
		for state in ["", "_hover", "_pressed", "_disabled"]:
			var ink := Color("eeeeee") if dark else Color("303030")
			if state == "_disabled":
				ink.a = 0.45
			result.set_color(direction + state + "_icon_modulate", "SpinBox", ink)
		for state in ["", "_hovered", "_pressed", "_disabled"]:
			var background := Color("50565e") if dark else Color("c0c0c0")
			if state == "_hovered":
				background = Color("606974") if dark else Color("d0d0d0")
			elif state == "_pressed":
				background = Color("353a40") if dark else Color("a0a0a0")
			result.set_stylebox(direction + "_background" + state, "SpinBox", create_box(background, Color.TRANSPARENT, 0, 0, 0))
	# map keys remain readable over city artwork, independent of the ui theme
	result.set_type_variation("MapLegend", "Panel")
	var legend := create_box(Color(0.06, 0.08, 0.12, 0.78 if translucent_menus else 1.0), Color.TRANSPARENT, 0, 12, 12)
	legend.set_corner_radius_all(6)
	result.set_stylebox("panel", "MapLegend", legend)
	result.set_color("font_color", "MapLegend", Color("eeeeee"))
	var tooltip := create_box(Color(0.03, 0.04, 0.05, 0.80 if translucent_menus else 1.0), Color.TRANSPARENT, 0, 7, 5)
	tooltip.set_corner_radius_all(3)
	result.set_stylebox("panel", "TooltipPanel", tooltip)
	result.set_color("font_color", "TooltipLabel", Color.WHITE)
	# godot's file toolbar and menubutton have their own native theme types
	for type_name in ["MenuButton", "FlatButton", "FlatMenuButton"]:
		if type_name != "MenuButton":
			result.set_type_variation(type_name, "Button")
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			result.set_stylebox(state, type_name, result.get_stylebox(state, "Button") if result.has_stylebox(state, "Button")
					else ThemeDB.get_default_theme().get_stylebox(state, "Button"))
		for color_name in result.get_color_list("Button"):
			result.set_color(color_name, type_name, result.get_color(color_name, "Button"))
	result.set_type_variation("ArtworkButton", "Button")
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		result.set_color("icon_" + state + "_color", "ArtworkButton", Color.WHITE)
	result.set_type_variation("HelpLabel", "Label")
	result.set_color("font_color", "HelpLabel", Color("b6bec8") if dark else Color("505050"))
	result.set_type_variation("WarningLabel", "Label")
	result.set_color("font_color", "WarningLabel", Color("ffcf70") if dark else Color("805000"))
	result.set_type_variation("ErrorLabel", "Label")
	result.set_color("font_color", "ErrorLabel", Color("ff7777") if dark else Color("d02020"))
	result.set_type_variation("SuccessLabel", "Label")
	result.set_color("font_color", "SuccessLabel", Color("64db99") if dark else Color("16803a"))
	result.set_color("error", "AppPalette", Color("ff7777") if dark else Color("d02020"))
	result.set_color("warning", "AppPalette", Color("ffcf70") if dark else Color("805000"))
	result.set_color("map_canvas", "AppPalette", Color("202830"))
	result.set_color("canvas", "AppPalette", Color("383d43") if dark else Color("c0c0c0"))
	result.set_color("ink", "AppPalette", Color("eeeeee") if dark else Color("202020"))
	result.set_color("paper", "AppPalette", Color("30353b") if dark else Color.WHITE)
	result.set_color("chart_accent", "AppPalette", Color("4aaaba") if dark else Color("000080"))
	result.set_color("grid", "AppPalette", Color("69727e") if dark else Color("dddddd"))
	result.set_color("border", "AppPalette", Color("9099a5") if dark else Color("484848"))
	# preserve scene layout padding while sharing the approved panel appearance
	for entry in [
		["PanelPadding0_0_0_0", 0, 0, 0, 0],
		["PanelPadding44_34_44_34", 44, 34, 44, 34],
		["PanelPadding5_2_5_2", 5, 2, 5, 2],
		["PanelPadding5_3_5_3", 5, 3, 5, 3],
		["PanelPadding8_8_8_8", 8, 8, 8, 8],
	]:
		result.set_type_variation(entry[0], "PanelContainer")
		var box := _copy_style(result, "PanelContainer", "panel")
		box.content_margin_left = entry[1]
		box.content_margin_top = entry[2]
		box.content_margin_right = entry[3]
		box.content_margin_bottom = entry[4]
		result.set_stylebox("panel", entry[0], box)
	result.set_type_variation("MainMenuPanel", "PanelContainer")
	var menu := _copy_style(result, "PanelPadding44_34_44_34", "panel")
	# the shared glass shader mixes these tints with the blurred city background
	menu.bg_color.a = (0.68 if dark else 0.75) if translucent_menus else 1.0
	result.set_stylebox("panel", "MainMenuPanel", menu)
	result.set_type_variation("CityToolbarPanel", "Panel")
	var toolbar := _copy_style(result, "PanelPadding5_3_5_3", "panel")
	toolbar.bg_color.a = (0.78 if dark else 0.75) if translucent_menus else 1.0
	toolbar.border_width_left = 0
	toolbar.border_width_top = 0
	toolbar.border_width_bottom = 0
	result.set_stylebox("panel", "CityToolbarPanel", toolbar)
	result.set_type_variation("CityMenuBarPanel", "PanelContainer")
	var menu_bar := _copy_style(result, "PanelPadding5_2_5_2", "panel")
	menu_bar.border_width_top = 0
	menu_bar.border_width_left = 0
	menu_bar.border_width_right = 0
	result.set_stylebox("panel", "CityMenuBarPanel", menu_bar)
	result.set_type_variation("CityStatusBarPanel", "PanelContainer")
	var status_bar := _copy_style(result, "PanelPadding5_3_5_3", "panel")
	status_bar.border_width_bottom = 0
	status_bar.border_width_left = 0
	status_bar.border_width_right = 0
	result.set_stylebox("panel", "CityStatusBarPanel", status_bar)
	return result


static func _light_theme() -> Theme:
	var result := _base_light_theme()
	result.set_stylebox("panel", "TabContainer", create_box(Color("c0c0c0"), Color("808080"), 1, 12, 12))
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var button_box := _copy_style(result, "Button", state)
		button_box.border_color = Color("383838") if state != "disabled" else Color("606060")
		button_box.set_border_width_all(2)
		result.set_stylebox(state, "Button", button_box)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		result.set_color("icon_" + state + "_color", "Button", Color("303030"))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(state, "LinkButton", Color("0000cc"))
	for type_name in ["CheckBox", "CheckButton"]:
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			var empty := StyleBoxEmpty.new()
			empty.content_margin_left = 4
			empty.content_margin_right = 4
			empty.content_margin_top = 4
			empty.content_margin_bottom = 4
			result.set_stylebox(state, type_name, empty)
		result.set_color("font_disabled_color", type_name, Color("606060"))
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled", "normal_mirrored", "hover_mirrored", "pressed_mirrored", "disabled_mirrored"]:
		var option_box := _copy_style(result, "OptionButton", state)
		option_box.set_corner_radius_all(0)
		result.set_stylebox(state, "OptionButton", option_box)
	for type_name in ["LineEdit", "TextEdit"]:
		var readonly := _copy_style(result, type_name, "read_only")
		readonly.bg_color = Color("c8c8c8")
		result.set_stylebox("read_only", type_name, readonly)
	result.set_color("font_uneditable_color", "LineEdit", Color("505050"))
	result.set_color("font_readonly_color", "TextEdit", Color("505050"))
	for type_name in ["HSlider", "VSlider"]:
		result.set_icon("tick", type_name, _tinted_icon(ThemeDB.get_default_theme().get_icon("tick", type_name), Color("505050")))
	result.set_stylebox("background", "ProgressBar", create_box(Color("d0d0d0"), Color("484848"), 1, 1, 1))
	result.set_stylebox("fill", "ProgressBar", create_box(Color("173f73"), Color("173f73"), 0, 0, 0))
	for state in ["selected", "selected_focus", "hovered_selected", "hovered_selected_focus", "cursor", "cursor_unfocused"]:
		var selection := _copy_style(result, "ItemList", state)
		selection.set_corner_radius_all(0)
		result.set_stylebox(state, "ItemList", selection)
	for state in ["title_button_normal", "title_button_hover", "title_button_pressed"]:
		var heading := _copy_style(result, "Tree", state)
		heading.set_corner_radius_all(0)
		result.set_stylebox(state, "Tree", heading)
	for type_name in ["ItemList", "Tree"]:
		for color_name in ["font_color", "font_hovered_color", "font_selected_color", "font_hovered_selected_color"]:
			result.set_color(color_name, type_name, Color("eeeeee"))
	result.set_color("title_button_color", "Tree", Color("eeeeee"))
	result.set_stylebox("panel", "PanelContainer", create_box(Color("dedede"), Color("808080"), 1, 8, 8))
	return result


static func _dark_theme() -> Theme:
	var result := ThemeDB.get_default_theme().duplicate() as Theme
	result.set_stylebox("panel", "PanelContainer", create_box(Color("30353b"), Color("69727e"), 1, 8, 8))
	result.default_font_size = 13
	for type_name in result.get_type_list():
		for size_name in result.get_font_size_list(type_name):
			result.set_font_size(size_name, type_name, 13)
	var panel := _copy_style(result, "TabContainer", "panel")
	panel.bg_color = Color("383d43")
	panel.set_content_margin_all(12)
	result.set_stylebox("panel", "TabContainer", panel)
	var selected_tab := _copy_style(result, "TabContainer", "tab_selected")
	selected_tab.bg_color = panel.bg_color
	result.set_stylebox("tab_selected", "TabContainer", selected_tab)
	for type_name in ["Button", "OptionButton"]:
		for state in ["normal", "disabled"]:
			var box := _copy_style(result, type_name, state)
			box.bg_color = Color("50565e") if state == "normal" else Color("353a40")
			box.border_color = Color("9099a5") if state == "normal" else Color("69727e")
			box.set_border_width_all(1)
			result.set_stylebox(state, type_name, box)
			if type_name == "OptionButton":
				result.set_stylebox(state + "_mirrored", type_name, box)
	for type_name in ["Button", "OptionButton"]:
		for state in ["hover", "hover_pressed"]:
			var hover := _copy_style(result, type_name, "hover" if state == "hover" else "pressed")
			hover.bg_color = Color("65717d") if state == "hover" else Color("506c78")
			hover.border_color = Color("8dcbd4")
			hover.set_border_width_all(1)
			result.set_stylebox(state, type_name, hover)
			if type_name == "OptionButton" and state == "hover":
				result.set_stylebox("hover_mirrored", type_name, hover)
	for icon_name in ["unchecked", "unchecked_disabled", "radio_unchecked", "radio_unchecked_disabled"]:
		var tint := Color("aeb8c4") if not "disabled" in icon_name else Color("79838f")
		result.set_icon(icon_name, "CheckBox", _tinted_icon(result.get_icon(icon_name, "CheckBox"), tint))
	result.set_color("checkbox_unchecked_color", "CheckBox", Color.WHITE)
	result.set_color("button_unchecked_color", "CheckButton", Color.WHITE)
	# preserve the switch's separate track and thumb tones while lifting dark pixels
	for icon_name in ["unchecked", "unchecked_disabled", "unchecked_mirrored", "unchecked_disabled_mirrored"]:
		var icon := result.get_icon(icon_name, "CheckButton")
		var lift := func(color: Color) -> Color: return color.lerp(Color.WHITE, 0.35)
		# keep a scalable icon sharp at every UI scale
		if icon is DPITexture:
			result.set_icon(icon_name, "CheckButton", _recolored_svg(icon, lift, false))
			continue
		var image := icon.get_image()
		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				var lifted: Color = lift.call(Color(pixel.r, pixel.g, pixel.b))
				lifted.a = pixel.a
				image.set_pixel(x, y, lifted)
		result.set_icon(icon_name, "CheckButton", ImageTexture.create_from_image(image))
	for type_name in ["LineEdit", "TextEdit"]:
		for state in ["normal", "read_only"]:
			var field := _copy_style(result, type_name, state)
			field.bg_color = Color("41474f") if state == "normal" else Color("3b4149")
			result.set_stylebox(state, type_name, field)
	var fill := _copy_style(result, "ProgressBar", "fill")
	fill.bg_color = Color("087e8b")
	result.set_stylebox("fill", "ProgressBar", fill)
	for state in ["selected", "selected_focus", "hovered_selected", "hovered_selected_focus", "cursor", "cursor_unfocused"]:
		var selection := _copy_style(result, "ItemList", state)
		selection.set_corner_radius_all(0)
		result.set_stylebox(state, "ItemList", selection)
	for state in ["title_button_normal", "title_button_hover", "title_button_pressed"]:
		var heading := _copy_style(result, "Tree", state)
		heading.set_corner_radius_all(0)
		result.set_stylebox(state, "Tree", heading)
	for state in ["embedded_border", "embedded_unfocused_border"]:
		var window := _copy_style(result, "Window", state)
		window.bg_color = Color("202a36") if state == "embedded_border" else Color("2c333d")
		result.set_stylebox(state, "Window", window)
	return result


static func _copy_style(source: Theme, type_name: String, state: String) -> StyleBoxFlat:
	var style := source.get_stylebox(state, type_name) if source.has_stylebox(state, type_name) else ThemeDB.get_default_theme().get_stylebox(state, type_name)
	return style.duplicate() as StyleBoxFlat


static func _tinted_icon(texture: Texture2D, color: Color) -> Texture2D:
	# keep a scalable icon sharp at every UI scale
	if texture is DPITexture:
		return _recolored_svg(texture, func(_color: Color) -> Color: return color, true)
	var image := texture.get_image()
	if image == null:
		return texture
	var maximum_alpha := 0.0
	for y in image.get_height():
		for x in image.get_width():
			maximum_alpha = maxf(maximum_alpha, image.get_pixel(x, y).a)
	if maximum_alpha == 0.0:
		return texture
	for y in image.get_height():
		for x in image.get_width():
			var pixel := color
			pixel.a *= image.get_pixel(x, y).a / maximum_alpha
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)


# rewrites each SVG color through recolor. full_opacity scales the opacities so
# that the most opaque part is fully opaque, like a tint of the rasterized icon
static func _recolored_svg(texture: DPITexture, recolor: Callable, full_opacity: bool) -> DPITexture:
	var source := texture.get_source()
	var colors := RegEx.create_from_string("#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\\b")
	source = _replace_matches(source, colors, func(found: RegExMatch) -> String:
		return "#" + (recolor.call(Color.html(found.get_string())) as Color).to_html(false))
	if full_opacity:
		# the drawn icon gives the largest opacity, including parts without an
		# opacity of their own
		var image := texture.get_image()
		var maximum := 0.0
		for y in image.get_height():
			for x in image.get_width():
				maximum = maxf(maximum, image.get_pixel(x, y).a)
		if maximum > 0.0 and maximum < 1.0:
			var opacities := RegEx.create_from_string("(fill-opacity|stroke-opacity|opacity)=\"([0-9.]+)\"")
			source = _replace_matches(source, opacities, func(found: RegExMatch) -> String:
				return "%s=\"%s\"" % [found.get_string(1), minf(1.0, found.get_string(2).to_float() / maximum)])
	return DPITexture.create_from_string(source, texture.base_scale, texture.saturation, texture.color_map)


static func _replace_matches(text: String, pattern: RegEx, replacement: Callable) -> String:
	var result := ""
	var end := 0
	for found in pattern.search_all(text):
		result += text.substr(end, found.get_start() - end) + str(replacement.call(found))
		end = found.get_end()
	return result + text.substr(end)


static func _light_file_dialog_theme() -> Theme:
	var result := _light_theme()
	var native := ThemeDB.get_default_theme()
	for icon_name in native.get_icon_list("FileDialog"):
		result.set_icon(icon_name, "FileDialog", _tinted_icon(native.get_icon(icon_name, "FileDialog"), Color("383838")))
	for type_name in ["OptionButton", "LineEdit"]:
		for icon_name in native.get_icon_list(type_name):
			result.set_icon(icon_name, type_name, _tinted_icon(native.get_icon(icon_name, type_name), Color("383838")))
	for icon_name in ["arrow", "arrow_collapsed", "arrow_collapsed_mirrored", "select_arrow", "updown"]:
		result.set_icon(icon_name, "Tree", _tinted_icon(native.get_icon(icon_name, "Tree"), Color("383838")))
	result.set_color("caret_color", "LineEdit", Color("383838"))
	result.set_color("font_placeholder_color", "LineEdit", Color("606060"))
	result.set_color("font_uneditable_color", "LineEdit", Color("505050"))
	result.set_color("title_button_color", "Tree", Color("383838"))
	for type_name in ["Label", "Button", "OptionButton", "CheckBox", "LineEdit", "ItemList", "Tree", "PopupMenu"]:
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color", "font_selected_color", "font_hovered_color", "font_hovered_selected_color"]:
			result.set_color(color_name, type_name, Color("383838"))
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		result.set_color("icon_" + state + "_color", "Button", Color("383838"))
	for type_name in ["Tree", "ItemList", "PopupMenu"]:
		result.set_stylebox("panel", type_name, create_box(Color("dedede"), Color("808080"), 1, 4, 4))
		for state in ["selected", "selected_focus", "hovered", "hovered_selected", "hovered_selected_focus", "hover"]:
			result.set_stylebox(state, type_name, create_box(Color("aec8e5"), Color("6a88aa"), 1, 4, 4))
	for state in ["normal", "read_only"]:
		result.set_stylebox(state, "LineEdit", create_box(Color("eeeeee"), Color("808080"), 1, 4, 4))
	result.set_color("folder_icon_color", "FileDialog", Color.WHITE)
	result.set_color("file_icon_color", "FileDialog", Color.WHITE)
	return result


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


static func _base_light_controls() -> Theme:
	var result := Theme.new()
	result.default_font_size = 13
	result.set_color("font_color", "Label", Color("101010"))
	result.set_color("font_color", "Button", Color("101010"))
	result.set_color("font_hover_color", "Button", Color("101010"))
	result.set_color("font_pressed_color", "Button", Color("101010"))
	result.set_color("font_hover_pressed_color", "Button", Color("101010"))
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
		"hover_pressed", "Button", create_box(Color("b8b8b8"), Color("404040"), 2)
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
	return result


static func _base_light_theme() -> Theme:
	var result := _base_light_controls()
	result.set_stylebox("panel", "AcceptDialog", create_box(Color("c0c0c0"), Color("808080"), 2, 12, 12))

	return result
