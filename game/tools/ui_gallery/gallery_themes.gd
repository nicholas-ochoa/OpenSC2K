extends RefCounted
## Gallery themes inspired by desktop UI styles. These use no original
## Windows resources or third-party theme assets.

const LABELS := ["Windows 95 / 98", "Windows 2000", "Modern Light", "Modern Dark", "Windows 3.11"]


static func palette(index: int) -> Dictionary:
	if index in [0, 4]:
		return {"surface": Color("c0c0c0"), "field": Color.WHITE, "button": Color("c0c0c0"), "hover": Color("c8c8c8"), "pressed": Color("b0b0b0"), "border": Color("808080"), "text": Color.BLACK, "muted": Color("808080"), "accent": Color("000080"), "selection_text": Color.WHITE, "radius": 0}
	if index == 1:
		return {"surface": Color("d4d0c8"), "field": Color.WHITE, "button": Color("d4d0c8"), "hover": Color("dedbd4"), "pressed": Color("c0bcb4"), "border": Color("808080"), "text": Color.BLACK, "muted": Color("808080"), "accent": Color("0a246a"), "selection_text": Color.WHITE, "radius": 0}
	if index == 2:
		return {"surface": Color("f4f6f9"), "field": Color.WHITE, "button": Color.WHITE, "hover": Color("eaf1ff"), "pressed": Color("d7e5ff"), "border": Color("aab5c5"), "text": Color("202b3b"), "muted": Color("657287"), "accent": Color("245fc7"), "selection_text": Color.WHITE, "radius": 5}
	return {"surface": Color("202630"), "field": Color("151b24"), "button": Color("303a49"), "hover": Color("3e5068"), "pressed": Color("233d60"), "border": Color("596b83"), "text": Color("edf2fa"), "muted": Color("a4b1c5"), "accent": Color("78abff"), "selection_text": Color("101b2c"), "radius": 5}


static func box(background: Color, border: Color, radius := 0, margin := 8) -> StyleBoxFlat:
	var result := ClassicUiStyle.create_box(background, border, 1, margin, 6)
	result.set_corner_radius_all(radius)
	return result


static func _bevel(background: Color, sunken := false) -> StyleBoxTexture:
	var image := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	image.fill(background)
	var top := Color("404040") if sunken else Color.WHITE
	var bottom := Color.WHITE if sunken else Color("404040")
	for y in 6:
		for x in 6:
			if x == 0 or y == 0:
				image.set_pixel(x, y, top)
			elif x == 5 or y == 5:
				image.set_pixel(x, y, bottom)
			elif x == 1 or y == 1:
				image.set_pixel(x, y, Color("808080") if sunken else background.lightened(0.12))
			elif x == 4 or y == 4:
				image.set_pixel(x, y, background if sunken else Color("808080"))
	var result := StyleBoxTexture.new()
	result.texture = ImageTexture.create_from_image(image)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(side, 2)
		result.set_content_margin(side, 6 if side in [SIDE_LEFT, SIDE_RIGHT] else 3)
	return result


static func _icon(mark: String, color: Color, background := Color.TRANSPARENT, border := Color.TRANSPARENT) -> Texture2D:
	var fill := "#" + color.to_html(false)
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">'
	if background.a > 0:
		svg += '<rect x="1" y="1" width="14" height="14" fill="#%s" stroke="#%s"/>' % [background.to_html(false), border.to_html(false)]
	match mark:
		"check":
			svg += '<path d="M4 8L7 11L12 5" fill="none" stroke="%s" stroke-width="2"/>' % fill
		"radio", "radio_off":
			svg += '<circle cx="8" cy="8" r="6" fill="none" stroke="%s" stroke-width="1.5"/>' % fill
			if mark == "radio":
				svg += '<circle cx="8" cy="8" r="3" fill="%s"/>' % fill
		"down":
			svg += '<path d="M4 6L8 10L12 6Z" fill="%s"/>' % fill
		"right":
			svg += '<path d="M6 4L10 8L6 12Z" fill="%s"/>' % fill
		"grabber":
			svg += '<circle cx="8" cy="8" r="6" fill="%s"/>' % fill
		"close":
			svg += '<path d="M4 4L12 12M12 4L4 12" stroke="%s" stroke-width="2"/>' % fill
	svg += '</svg>'
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)


static func make(index: int) -> Theme:
	var p := palette(index)
	var result := ThemeDB.get_default_theme().duplicate() as Theme
	var legacy := index in [0, 1, 4]
	result.default_font_size = 11 if legacy else 14
	if legacy:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Tahoma", "Microsoft Sans Serif", "Arial"] if index == 1 else ["MS Sans Serif", "Microsoft Sans Serif", "Arial"])
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_NORMAL
		result.default_font = font
	var normal: StyleBox = _bevel(p.button) if legacy else box(p.button, p.border, p.radius)
	var hover: StyleBox = normal if legacy else box(p.hover, p.accent, p.radius)
	var pressed: StyleBox = _bevel(p.button, true) if legacy else box(p.pressed, p.accent, p.radius)
	var disabled: StyleBox = _bevel(p.surface) if legacy else box(p.surface, p.border, p.radius)
	if index == 4:
		normal = _win311_button(p.surface)
		hover = normal
		pressed = _win311_button(p.surface, true)
		disabled = normal
	var focus := box(Color.TRANSPARENT, p.accent, p.radius)
	focus.draw_center = false
	focus.set_border_width_all(2)
	var field: StyleBox = _bevel(p.field, true) if legacy else box(p.field, p.border, p.radius)
	if index == 4:
		field = box(p.field, Color.BLACK, 0, 3)
	if legacy:
		field.content_margin_top = 2
		field.content_margin_bottom = 2
	var panel: StyleBox = _bevel(p.surface) if legacy else box(p.surface, p.border, p.radius, 12)
	if index == 4:
		panel = box(p.surface, Color.BLACK, 0, 3)
	for type_name in ["Label", "Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton", "LinkButton", "LineEdit", "TextEdit", "SpinBox", "ItemList", "Tree", "PopupMenu", "TabBar", "TabContainer", "ProgressBar", "FileDialog", "TooltipLabel"]:
		result.set_font_size("font_size", type_name, 11 if legacy else 14)
		if legacy:
			result.set_font("font", type_name, result.default_font)
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_selected_color", "font_unselected_color"]:
			result.set_color(color_name, type_name, p.text)
		result.set_color("font_disabled_color", type_name, p.muted)
		result.set_color("font_placeholder_color", type_name, p.muted)
		result.set_color("selection_color", type_name, p.accent)
		result.set_color("font_selected_color", type_name, p.selection_text)
	for type_name in ["Button", "OptionButton", "MenuButton"]:
		result.set_stylebox("normal", type_name, normal)
		result.set_stylebox("hover", type_name, hover)
		result.set_stylebox("pressed", type_name, pressed)
		result.set_stylebox("hover_pressed", type_name, pressed)
		result.set_stylebox("disabled", type_name, disabled)
		result.set_stylebox("focus", type_name, _legacy_focus() if legacy else focus)
	for type_name in ["CheckBox", "CheckButton"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 4
		empty.content_margin_right = 4
		empty.content_margin_top = 2 if legacy else 6
		empty.content_margin_bottom = 2 if legacy else 6
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			result.set_stylebox(state, type_name, empty)
		result.set_stylebox("focus", type_name, _legacy_focus() if legacy else focus)
		for suffix in ["", "_disabled"]:
			var ink: Color = p.muted if suffix == "_disabled" else p.text
			result.set_icon("checked" + suffix, type_name, _legacy_check(true, ink, index == 4) if legacy else _icon("check", ink, p.field, p.border))
			result.set_icon("unchecked" + suffix, type_name, _legacy_check(false, ink, index == 4) if legacy else _icon("", ink, p.field, p.border))
			result.set_icon("radio_checked" + suffix, type_name, _icon("radio", ink))
			result.set_icon("radio_unchecked" + suffix, type_name, _icon("radio_off", ink))
		result.set_icon("checked_mirrored", type_name, _icon("check", p.text, p.field, p.border))
		result.set_icon("unchecked_mirrored", type_name, _icon("", p.text, p.field, p.border))
	for type_name in ["LineEdit", "TextEdit"]:
		result.set_stylebox("normal", type_name, field)
		result.set_stylebox("read_only", type_name, disabled)
		result.set_stylebox("focus", type_name, _legacy_focus() if legacy else focus)
		result.set_color("caret_color", type_name, p.text)
	for type_name in ["Panel", "PanelContainer", "AcceptDialog", "PopupMenu", "TooltipPanel"]:
		result.set_stylebox("panel", type_name, panel)
	for type_name in ["TabContainer", "TabBar"]:
		var selected_tab: StyleBox
		var inactive_tab: StyleBox
		if legacy:
			selected_tab = _legacy_tab(p.surface, true)
			inactive_tab = _legacy_tab(p.surface, false)
		else:
			var attached := box(p.surface, p.border, p.radius)
			attached.corner_radius_bottom_left = 0
			attached.corner_radius_bottom_right = 0
			attached.border_width_bottom = 0
			attached.expand_margin_bottom = 2
			selected_tab = attached
			var inactive := box(p.button, p.border, p.radius)
			inactive.corner_radius_bottom_left = 0
			inactive.corner_radius_bottom_right = 0
			inactive_tab = inactive
		result.set_stylebox("tab_selected", type_name, selected_tab)
		result.set_stylebox("tab_unselected", type_name, inactive_tab)
		result.set_stylebox("tab_hovered", type_name, inactive_tab)
		result.set_stylebox("tab_disabled", type_name, inactive_tab)
		result.set_stylebox("tab_focus", type_name, _legacy_focus() if legacy else focus)
		result.set_constant("side_margin", type_name, 0)
		var tab_panel := panel.duplicate() as StyleBox
		if tab_panel is StyleBoxFlat:
			tab_panel.corner_radius_top_left = 0
			tab_panel.corner_radius_top_right = 0
		result.set_stylebox("panel", type_name, tab_panel)
		result.set_color("font_selected_color", type_name, p.text)
		result.set_color("font_hovered_color", type_name, p.text)
	for type_name in ["Tree", "ItemList"]:
		result.set_stylebox("panel", type_name, field)
		result.set_stylebox("selected", type_name, box(p.accent, p.accent, 0))
		result.set_stylebox("selected_focus", type_name, box(p.accent, p.accent, 0))
		result.set_stylebox("cursor", type_name, focus)
		result.set_stylebox("cursor_unfocused", type_name, focus)
		result.set_color("guide_color", type_name, p.border)
	for state in ["normal", "hover", "pressed"]:
		result.set_stylebox("title_button_" + state, "Tree", normal if state == "normal" else hover)
	result.set_icon("checked", "Tree", _icon("check", p.text, p.field, p.border))
	result.set_icon("unchecked", "Tree", _icon("", p.text, p.field, p.border))
	result.set_icon("arrow", "Tree", _icon("down", p.text))
	result.set_icon("arrow_collapsed", "Tree", _icon("right", p.text))
	result.set_stylebox("hover", "PopupMenu", box(p.accent, p.accent, p.radius))
	result.set_color("font_hover_color", "PopupMenu", p.selection_text)
	for type_name in ["HSlider", "VSlider"]:
		var track := box(p.field, p.border, 2, 0)
		track.content_margin_top = 3
		track.content_margin_bottom = 3
		result.set_stylebox("slider", type_name, track)
		result.set_stylebox("grabber_area", type_name, box(p.accent, p.accent, 2, 0))
		result.set_stylebox("grabber_area_highlight", type_name, box(p.accent, p.accent, 2, 0))
		result.set_stylebox("focus", type_name, _legacy_focus() if legacy else focus)
		result.set_icon("grabber", type_name, _legacy_thumb(p.surface) if legacy else _icon("grabber", p.accent))
		result.set_icon("grabber_highlight", type_name, _legacy_thumb(p.surface) if legacy else _icon("grabber", p.accent.lightened(0.15)))
		result.set_icon("grabber_disabled", type_name, _legacy_thumb(p.surface) if legacy else _icon("grabber", p.muted))
	for type_name in ["HScrollBar", "VScrollBar"]:
		result.set_stylebox("scroll", type_name, box(p.field, p.border, 0))
		result.set_stylebox("scroll_focus", type_name, focus)
		result.set_stylebox("grabber", type_name, normal)
		result.set_stylebox("grabber_highlight", type_name, hover)
		result.set_stylebox("grabber_pressed", type_name, pressed)
	result.set_stylebox("background", "ProgressBar", field)
	result.set_stylebox("fill", "ProgressBar", box(p.accent, p.accent, p.radius))
	result.set_color("font_color", "ProgressBar", p.text)
	result.set_color("font_outline_color", "ProgressBar", p.surface)
	result.set_constant("outline_size", "ProgressBar", 2)
	result.set_color("default_color", "RichTextLabel", p.text)
	result.set_color("font_color", "TooltipLabel", p.text)
	result.set_icon("arrow", "OptionButton", _icon("down", p.text))
	result.set_constant("modulate_arrow", "OptionButton", 0)
	result.set_icon("clear", "LineEdit", _icon("close", p.muted))
	return result


static func _legacy_focus() -> StyleBoxTexture:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in 4:
		for x in 4:
			if (x == 0 or y == 0 or x == 3 or y == 3) and (x + y) % 2 == 0:
				image.set_pixel(x, y, Color.BLACK)
	var result := StyleBoxTexture.new()
	result.texture = ImageTexture.create_from_image(image)
	result.draw_center = false
	result.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	result.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(side, 1)
		result.set_expand_margin(side, -4)
	return result


static func _legacy_check(checked: bool, ink: Color, windows_311: bool) -> Texture2D:
	var image := Image.create(13, 13, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	for y in 13:
		for x in 13:
			if x == 0 or y == 0:
				image.set_pixel(x, y, Color.BLACK if windows_311 else Color("808080"))
			elif x == 12 or y == 12:
				image.set_pixel(x, y, Color.BLACK if windows_311 else Color.WHITE)
			elif not windows_311 and (x == 1 or y == 1):
				image.set_pixel(x, y, Color.BLACK)
			elif not windows_311 and (x == 11 or y == 11):
				image.set_pixel(x, y, Color("c0c0c0"))
	if checked:
		if windows_311:
			for offset in 7:
				image.set_pixel(3 + offset, 3 + offset, ink)
				image.set_pixel(9 - offset, 3 + offset, ink)
		else:
			for point in [Vector2i(3, 5), Vector2i(4, 6), Vector2i(5, 7), Vector2i(6, 6), Vector2i(7, 5), Vector2i(8, 4), Vector2i(9, 3)]:
				image.set_pixelv(point, ink)
				image.set_pixelv(point + Vector2i.DOWN, ink)
	return ImageTexture.create_from_image(image)


static func _legacy_thumb(background: Color) -> Texture2D:
	var image := Image.create(11, 19, false, Image.FORMAT_RGBA8)
	image.fill(background)
	for y in 19:
		for x in 11:
			if x == 0 or y == 0:
				image.set_pixel(x, y, Color.WHITE)
			elif x == 10 or y == 18:
				image.set_pixel(x, y, Color("404040"))
			elif x == 9 or y == 17:
				image.set_pixel(x, y, Color("808080"))
	return ImageTexture.create_from_image(image)


static func _legacy_tab(background: Color, selected: bool) -> StyleBoxTexture:
	var result := _bevel(background)
	if selected:
		var image := result.texture.get_image()
		for y in [4, 5]:
			for x in range(2, 4):
				image.set_pixel(x, y, background)
		result.texture = ImageTexture.create_from_image(image)
		result.expand_margin_bottom = 2
	result.content_margin_left = 6
	result.content_margin_right = 6
	result.content_margin_top = 4
	result.content_margin_bottom = 4
	return result


static func title_box(index: int) -> StyleBox:
	var p := palette(index)
	if index == 1:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color("0a246a"), Color("a6caf0")])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 256
		texture.height = 18
		var result := StyleBoxTexture.new()
		result.texture = texture
		result.content_margin_left = 3
		result.content_margin_right = 2
		result.content_margin_top = 1
		result.content_margin_bottom = 1
		return result
	var result := box(p.accent if index in [0, 4] else p.button, Color.BLACK if index == 4 else p.border, p.radius, 3)
	result.content_margin_top = 1 if index in [0, 4] else 4
	result.content_margin_bottom = result.content_margin_top
	if index == 0:
		result.set_border_width_all(0)
	return result


static func _win311_button(background: Color, pressed := false) -> StyleBoxTexture:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(background)
	for y in 8:
		for x in 8:
			if x == 0 or y == 0 or x == 7 or y == 7:
				image.set_pixel(x, y, Color.BLACK)
			elif x == 1 or y == 1:
				image.set_pixel(x, y, Color("808080") if pressed else Color.WHITE)
			elif x >= 6 or y >= 6:
				image.set_pixel(x, y, background if pressed else Color("808080"))
	for point in [Vector2i(0, 0), Vector2i(7, 0), Vector2i(0, 7), Vector2i(7, 7)]:
		image.set_pixelv(point, Color.TRANSPARENT)
	var result := StyleBoxTexture.new()
	result.texture = ImageTexture.create_from_image(image)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(side, 3)
		result.set_content_margin(side, 6 if side in [SIDE_LEFT, SIDE_RIGHT] else 3)
	return result
