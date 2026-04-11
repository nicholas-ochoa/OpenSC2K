extends PanelContainer
## Generated state catalog. Fixed examples use the real control's theme resources.
## State samples ignore input; live examples below them retain normal behavior.

const STATES := ["Normal", "Hover", "Pressed", "Hover + pressed", "Disabled", "Focus"]
var preview_dialogs: Array[Window] = []


func _ready() -> void:
	%ThemeSelector.item_selected.connect(_rebuild)
	_rebuild(0)


func _rebuild(theme_index: int) -> void:
	for dialog in preview_dialogs:
		dialog.queue_free()
	preview_dialogs.clear()
	for page in %Tabs.get_children():
		%Tabs.remove_child(page)
		page.queue_free()
	theme = _light_theme() if theme_index == 0 else _dark_theme()
	# Give the catalog a readable canvas without changing the shared game theme.
	var canvas := ClassicUiStyle.create_box(Color("c0c0c0"), Color("808080"), 1, 12, 12) if theme_index == 0 else theme.get_stylebox("panel", "PanelContainer")
	add_theme_stylebox_override("panel", canvas)
	%Tabs.add_theme_stylebox_override("panel", canvas if theme_index == 0 else theme.get_stylebox("panel", "TabContainer"))
	_buttons_page()
	_choices_page()
	_fields_page()
	_ranges_page()
	_lists_page()
	_menus_page()
	_text_page()
	_theme_parts_page()
	%Tabs.current_tab = 0


func _light_theme() -> Theme:
	var result := ClassicUiStyle.create_dialog_theme()
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
	result.set_stylebox("background", "ProgressBar", ClassicUiStyle.create_box(Color("d0d0d0"), Color("484848"), 1, 1, 1))
	result.set_stylebox("fill", "ProgressBar", ClassicUiStyle.create_box(Color("173f73"), Color("173f73"), 0, 0, 0))
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
	var tooltip := _copy_style(result, "TooltipPanel", "panel")
	tooltip.set_corner_radius_all(3)
	result.set_stylebox("panel", "TooltipPanel", tooltip)
	result.set_stylebox("panel", "PanelContainer", ClassicUiStyle.create_box(Color("dedede"), Color("808080"), 1, 8, 8))
	return result


func _dark_theme() -> Theme:
	var result := ThemeDB.get_default_theme().duplicate() as Theme
	result.default_font_size = 13
	for type_name in result.get_type_list():
		for size_name in result.get_font_size_list(type_name):
			result.set_font_size(size_name, type_name, 13)
	var panel := _copy_style(result, "TabContainer", "panel")
	panel.bg_color = Color("383d43")
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
	# Preserve the switch's separate track and thumb tones while lifting dark pixels.
	for icon_name in ["unchecked", "unchecked_disabled", "unchecked_mirrored", "unchecked_disabled_mirrored"]:
		var image := result.get_icon(icon_name, "CheckButton").get_image()
		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				var lifted := Color(pixel.r, pixel.g, pixel.b).lerp(Color.WHITE, 0.35)
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


func _copy_style(source: Theme, type_name: String, state: String) -> StyleBoxFlat:
	var style := source.get_stylebox(state, type_name) if source.has_stylebox(state, type_name) else ThemeDB.get_default_theme().get_stylebox(state, type_name)
	return style.duplicate() as StyleBoxFlat


func _tinted_icon(texture: Texture2D, color: Color) -> Texture2D:
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


func _light_file_dialog_theme() -> Theme:
	var result := theme.duplicate() as Theme
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
		result.set_stylebox("panel", type_name, ClassicUiStyle.create_box(Color("dedede"), Color("808080"), 1, 4, 4))
		for state in ["selected", "selected_focus", "hovered", "hovered_selected", "hovered_selected_focus", "hover"]:
			result.set_stylebox(state, type_name, ClassicUiStyle.create_box(Color("aec8e5"), Color("6a88aa"), 1, 4, 4))
	for state in ["normal", "read_only"]:
		result.set_stylebox(state, "LineEdit", ClassicUiStyle.create_box(Color("eeeeee"), Color("808080"), 1, 4, 4))
	result.set_color("folder_icon_color", "FileDialog", Color.WHITE)
	result.set_color("file_icon_color", "FileDialog", Color.WHITE)
	return result


func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	%Tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)
	return content


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label


func _section(parent: Node, title: String, explanation := "") -> void:
	var heading := _label(parent, title)
	heading.add_theme_font_size_override("font_size", 18)
	if not explanation.is_empty():
		var hint := _label(parent, explanation)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	return row


func _cell(parent: Node, caption: String) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size.x = 150
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 8)
	parent.add_child(cell)
	_label(cell, caption)
	return cell


func _matrix(parent: Node, headers: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = headers.size() + 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 14)
	parent.add_child(grid)
	_label(grid, "Control")
	for header in headers:
		var label := _label(grid, str(header))
		label.custom_minimum_size.x = 138
	return grid


func _freeze(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.focus_mode = Control.FOCUS_NONE
	for child in control.get_children():
		if child is Control:
			_freeze(child)


func _button_state(button: Button, state: String) -> void:
	var style_name := {
		"Normal": "normal", "Hover": "hover", "Pressed": "pressed",
		"Hover + pressed": "hover_pressed", "Disabled": "disabled", "Focus": "normal",
	}[state] as String
	var box := button.get_theme_stylebox(style_name)
	if button.flat and state != "Normal":
		button.flat = false
	var font_name := {
		"Normal": "font_color", "Hover": "font_hover_color", "Pressed": "font_pressed_color",
		"Hover + pressed": "font_hover_pressed_color", "Disabled": "font_disabled_color", "Focus": "font_focus_color",
	}[state] as String
	var font_color := button.get_theme_color(font_name)
	for target in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(target, box)
	for target in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(target, font_color)
	if state == "Focus":
		_add_focus_overlay(button)
	button.disabled = state == "Disabled"
	_freeze(button)


func _add_focus_overlay(control: Control) -> void:
	var overlay := Panel.new()
	var focus := control.get_theme_stylebox("focus").duplicate() as StyleBox
	if focus is StyleBoxFlat or focus is StyleBoxTexture:
		focus.draw_center = false
	overlay.add_theme_stylebox_override("panel", focus)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.add_child(overlay)
	_freeze(overlay)


func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = "Sample button: " + text
	parent.add_child(button)
	button.custom_minimum_size.y = 34
	button.pressed.connect(func() -> void: _status("Pressed: " + text))
	return button


func _status(text: String) -> void:
	%Status.text = text + " • Preview only"


func _buttons_page() -> void:
	var page := _page("Buttons")
	_section(page, "Fixed button states", "These are theme-state samples. They stay in the labeled state and do not accept input.")
	var grid := _matrix(page, STATES)
	for kind in ["Button", "Icon + text", "Flat button", "Toggle button"]:
		_label(grid, kind)
		for state in STATES:
			var button := _button(grid, "Save Changes" if kind == "Button" else "Sample")
			button.flat = kind == "Flat button" and %ThemeSelector.selected != 0
			if kind == "Icon + text":
				button.icon = get_theme_icon("folder", "FileDialog")
			if kind == "Toggle button":
				button.toggle_mode = true
				button.button_pressed = state in ["Pressed", "Hover + pressed"]
			_button_state(button, state)
	_section(page, "Live buttons", "Hover, hold a mouse button, or press Tab and Space to compare real interaction with the fixed samples.")
	var row := _row(page)
	_button(row, "Cancel")
	_button(row, "Save Changes")
	_button(row, "Browse...")
	var toggle := _button(row, "Toggle me")
	toggle.toggle_mode = true
	var disabled := _button(row, "Unavailable")
	disabled.disabled = true
	var link := LinkButton.new()
	link.text = "Sample link (local action)"
	link.pressed.connect(func() -> void: _status("Sample link selected"))
	row.add_child(link)
	_section(page, "Icon-only and texture buttons")
	row = _row(page)
	var icon_button := _button(row, "")
	icon_button.icon = get_theme_icon("folder", "FileDialog")
	icon_button.tooltip_text = "Open folder (sample)"
	var texture_button := TextureButton.new()
	if %ThemeSelector.selected == 0:
		texture_button.self_modulate = Color("202020")
	texture_button.texture_normal = get_theme_icon("close", "Window")
	texture_button.texture_pressed = get_theme_icon("close_pressed", "Window")
	texture_button.custom_minimum_size = Vector2(40, 34)
	texture_button.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	texture_button.tooltip_text = "TextureButton: window close artwork"
	row.add_child(texture_button)
	_label(row, "TextureButton: hover or press to see each state")


func _choices_page() -> void:
	var page := _page("Choices")
	_section(page, "Fixed selection states", "Each checkbox state appears both unchecked and checked. Radio buttons use a ButtonGroup.")
	var grid := _matrix(page, STATES)
	for kind in ["Checkbox off", "Checkbox on", "Radio off", "Radio on", "CheckButton off", "CheckButton on", "OptionButton"]:
		_label(grid, kind)
		for state in STATES:
			var button: Button
			if kind == "OptionButton":
				var option := OptionButton.new()
				option.add_item("Medium")
				button = option
			elif kind.begins_with("CheckButton"):
				button = CheckButton.new()
			else:
				button = CheckBox.new()
				if kind.begins_with("Radio"):
					button.button_group = ButtonGroup.new()
			grid.add_child(button)
			if kind != "OptionButton":
				button.text = "Option"
				button.button_pressed = kind.ends_with("on")
			button.custom_minimum_size.y = 34
			_button_state(button, state)
	_section(page, "Live choices")
	var row := _row(page)
	var check := CheckBox.new()
	check.text = "Retain compatibility"
	row.add_child(check)
	var group := ButtonGroup.new()
	for text in ["Small", "Medium", "Large"]:
		var radio := CheckBox.new()
		radio.text = text
		radio.button_group = group
		radio.button_pressed = text == "Medium"
		row.add_child(radio)
	var option := OptionButton.new()
	for text in ["GPU (recommended)", "CPU", "Unavailable option"]:
		option.add_item(text)
	option.set_item_disabled(2, true)
	row.add_child(option)


func _fields_page() -> void:
	var page := _page("Text fields")
	_section(page, "LineEdit states", "Read-only is the non-editable text state. Selection, caret, clear button, and context menu are available in the live fields.")
	var grid := _matrix(page, ["Normal", "Placeholder", "Read-only", "Focus", "Selected", "Password"])
	_label(grid, "LineEdit")
	for state in ["Normal", "Placeholder", "Read-only", "Focus", "Selected", "Password"]:
		var edit := LineEdit.new()
		grid.add_child(edit)
		edit.text = "Mayor name" if state != "Placeholder" else ""
		edit.placeholder_text = "Enter name"
		edit.editable = state != "Read-only"
		edit.secret = state == "Password"
		if state == "Selected":
			edit.select_all()
		if state == "Focus":
			_add_focus_overlay(edit)
		_freeze(edit)
	_section(page, "Live text input")
	var row := _row(page)
	var name_cell := _cell(row, "LineEdit: clear button")
	var name_edit := LineEdit.new()
	name_edit.text = "Sample City"
	name_edit.clear_button_enabled = true
	name_edit.tooltip_text = "Try selection, typing, and the right-click context menu."
	name_cell.add_child(name_edit)
	var spin_cell := _cell(row, "SpinBox: editable / read-only")
	for editable in [true, false]:
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 100
		spin.value = 50
		spin.editable = editable
		spin.suffix = "%"
		spin_cell.add_child(spin)
	_section(page, "TextEdit: editable, read-only, and placeholder text")
	row = _row(page)
	for state in ["Editable", "Read-only", "Placeholder"]:
		var cell := _cell(row, state)
		var edit := TextEdit.new()
		edit.custom_minimum_size = Vector2(260, 150)
		edit.text = "A sample city description.\nSelect text to inspect selection colors.\nUse the context menu for editing." if state != "Placeholder" else ""
		edit.placeholder_text = "Enter a city description..."
		edit.editable = state != "Read-only"
		cell.add_child(edit)
	_section(page, "Validation messages", "These colors are explicit semantic examples. They are separate from the native text-field states.")
	for sample in [["Help: Choose a pack.json file.", "606060"], ["Error: This pack could not be loaded.", "d02020" if %ThemeSelector.selected == 0 else "ff7777"], ["Success: Pack loaded.", "16803a" if %ThemeSelector.selected == 0 else "64db99"]]:
		_label(page, sample[0]).add_theme_color_override("font_color", Color(sample[1]))


func _ranges_page() -> void:
	var page := _page("Ranges")
	_section(page, "Slider states", "Normal, highlighted, disabled, and focus use native theme resources. Godot shares the highlighted slider artwork for hover and drag.")
	var row := _row(page)
	for state in ["Normal", "Hover / drag", "Disabled", "Focus"]:
		var cell := _cell(row, state)
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(200, 36)
		slider.value = 50
		cell.add_child(slider)
		slider.editable = state != "Disabled"
		if state == "Hover / drag":
			slider.add_theme_icon_override("grabber", slider.get_theme_icon("grabber_highlight"))
			slider.add_theme_stylebox_override("grabber_area", slider.get_theme_stylebox("grabber_area_highlight"))
		if state == "Focus":
			slider.add_theme_icon_override("grabber", slider.get_theme_icon("grabber_highlight"))
			slider.add_theme_stylebox_override("slider", slider.get_theme_stylebox("focus"))
		_freeze(slider)
	_section(page, "Live sliders and scroll bars")
	row = _row(page)
	var horizontal := _cell(row, "Horizontal: drag or use arrow keys")
	var slider := HSlider.new()
	slider.value = 35
	slider.tick_count = 5
	slider.custom_minimum_size = Vector2(360, 36)
	horizontal.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void: _status("Slider: %d%%" % value))
	var scroll := HScrollBar.new()
	scroll.max_value = 100
	scroll.page = 25
	scroll.value = 35
	scroll.custom_minimum_size.y = 24
	horizontal.add_child(scroll)
	var vertical := _cell(row, "Vertical slider / scroll bar")
	var vertical_row := _row(vertical)
	var vslider := VSlider.new()
	vslider.value = 60
	vslider.custom_minimum_size = Vector2(36, 140)
	vertical_row.add_child(vslider)
	var vscroll := VScrollBar.new()
	vscroll.max_value = 100
	vscroll.page = 25
	vscroll.value = 35
	vscroll.custom_minimum_size = Vector2(24, 140)
	vertical_row.add_child(vscroll)
	_section(page, "ProgressBar states")
	for value in [0, 45, 100, -1]:
		var progress := ProgressBar.new()
		progress.custom_minimum_size.y = 28
		progress.value = maxi(value, 0)
		progress.indeterminate = value == -1
		page.add_child(progress)


func _lists_page() -> void:
	var page := _page("Lists & tabs")
	_section(page, "ItemList and Tree", "Try hover, selection, keyboard focus, scrolling, expand/collapse, checkboxes, and editing. Disabled items and read-only cells are included.")
	var row := _row(page)
	var list_cell := _cell(row, "ItemList: focused and unfocused selection")
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(340, 220)
	list.select_mode = ItemList.SELECT_MULTI
	list_cell.add_child(list)
	for index in 14:
		list.add_item("City %02d%s" % [index + 1, " (disabled)" if index == 3 else ""])
	list.set_item_disabled(3, true)
	list.select(1)
	list.select(2, false)
	var tree_cell := _cell(row, "Tree: headings, hierarchy, and editable cells")
	var tree := Tree.new()
	tree.custom_minimum_size = Vector2(500, 220)
	tree.columns = 3
	tree.column_titles_visible = true
	for index in 3:
		tree.set_column_title(index, ["Service", "Funding", "Enabled"][index])
	tree.hide_root = true
	tree_cell.add_child(tree)
	var root_item := tree.create_item()
	for name in ["Police", "Fire", "Education"]:
		var item := tree.create_item(root_item)
		item.set_text(0, name)
		item.set_text(1, "100%")
		item.set_editable(1, true)
		item.set_cell_mode(2, TreeItem.CELL_MODE_CHECK)
		item.set_checked(2, true)
		item.set_editable(2, true)
		var child := tree.create_item(item)
		child.set_text(0, "District detail")
		child.set_text(1, "Read-only")
		item.collapsed = name != "Police"
	_section(page, "TabContainer states")
	var tabs := TabContainer.new()
	tabs.custom_minimum_size.y = 130
	page.add_child(tabs)
	for title in ["General", "Graphics", "Disabled tab"]:
		var panel := PanelContainer.new()
		panel.name = title
		tabs.add_child(panel)
		_label(panel, "Sample content for " + title)
	tabs.set_tab_disabled(2, true)
	_section(page, "Split container: drag the divider")
	var split := HSplitContainer.new()
	split.custom_minimum_size.y = 90
	page.add_child(split)
	for text in ["Left pane", "Right pane"]:
		var panel := PanelContainer.new()
		panel.custom_minimum_size.x = 220
		split.add_child(panel)
		_label(panel, text)


func _menus_page() -> void:
	var page := _page("Menus & dialogs")
	_section(page, "Live menus", "Open each menu to inspect normal, hover, disabled, checked, radio, separator, shortcut, and submenu items.")
	var row := _row(page)
	var menu := MenuButton.new()
	menu.text = "Sample menu"
	row.add_child(menu)
	var popup := menu.get_popup()
	popup.add_item("Open sample", 0, KEY_MASK_CTRL | KEY_O)
	popup.add_item("Unavailable action", 1)
	popup.set_item_disabled(1, true)
	popup.add_separator("Options")
	popup.add_check_item("Checked item", 3)
	popup.set_item_checked(3, true)
	popup.add_check_item("Unchecked item", 4)
	popup.add_radio_check_item("Selected radio", 5)
	popup.set_item_checked(5, true)
	popup.add_radio_check_item("Other radio", 6)
	var submenu := PopupMenu.new()
	submenu.name = "More"
	popup.add_child(submenu)
	submenu.add_item("Submenu action")
	popup.add_submenu_item("More options", "More")
	popup.id_pressed.connect(func(id: int) -> void:
		if id in [3, 4]:
			popup.set_item_checked(id, not popup.is_item_checked(id))
		_status("Menu item: %d" % id))
	_section(page, "Dialog examples", "Each opens a real window with this preview theme. File selection only updates the sample status; it does not read or write the selected file.")
	row = _row(page)
	var notice := AcceptDialog.new()
	notice.title = "Sample notice"
	notice.dialog_text = "This is a sample information message.\nInspect the title bar, body, focus, and OK button."
	_add_dialog(notice)
	_button(row, "Information dialog...").pressed.connect(func() -> void: notice.popup_centered(Vector2i(480, 180)))
	var confirmation := ConfirmationDialog.new()
	confirmation.title = "Sample confirmation"
	confirmation.dialog_text = "Save the sample changes?\nThis preview does not save data."
	confirmation.ok_button_text = "Save Changes"
	_add_dialog(confirmation)
	_button(row, "Confirmation dialog...").pressed.connect(func() -> void: confirmation.popup_centered(Vector2i(480, 180)))
	var file := FileDialog.new()
	file.title = "Sample file picker"
	file.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file.access = FileDialog.ACCESS_RESOURCES
	file.filters = PackedStringArray(["*.json ; JSON files", "*.tscn ; Scene files"])
	file.use_native_dialog = false
	_add_dialog(file)
	if %ThemeSelector.selected == 0:
		file.theme = _light_file_dialog_theme()
	file.file_selected.connect(func(_path: String) -> void: _status("Sample file selected; no file was opened"))
	_button(row, "File dialog...").pressed.connect(func() -> void: file.popup_centered(Vector2i(800, 520)))
	_section(page, "Tooltip")
	var tooltip_button := _button(page, "Hover here for a multiline tooltip")
	tooltip_button.tooltip_text = "Sample tooltip\nSecond line with help for this control.\nTooltips use the shared TooltipPanel and TooltipLabel styles."
	_section(page, "Custom title bar used by app panels")
	var title := DialogTitleBar.new("Sample modeless window")
	page.add_child(title)
	if %ThemeSelector.selected == 1:
		title.color = (theme.get_stylebox("embedded_border", "Window") as StyleBoxFlat).bg_color
		title.title_label.add_theme_font_size_override("font_size", 13)
	title.close_requested.connect(func() -> void: _status("Sample title-bar close pressed"))


func _add_dialog(dialog: Window) -> void:
	dialog.theme = theme
	dialog.exclusive = true
	add_child(dialog)
	preview_dialogs.append(dialog)


func _text_page() -> void:
	var page := _page("Text & panels")
	_section(page, "Labels, messages, and panels")
	var row := _row(page)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	_label(content, "PanelContainer with shared panel style")
	_label(content, "Default body text: population 125,400")
	_label(content, "Secondary help text").add_theme_color_override("font_color", Color("505050") if %ThemeSelector.selected == 0 else Color("606060"))
	content.add_child(HSeparator.new())
	_label(content, "Horizontal separator above")
	row.add_child(VSeparator.new())
	var right := _cell(row, "Vertical separator at left")
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.custom_minimum_size = Vector2(360, 120)
	rich.text = "[b]Rich text heading[/b]\nNormal, [i]italic[/i], and [u]underlined[/u] text.\n[color=#800000]Error message example.[/color]\n• First indented explanation\n• Second explanation"
	right.add_child(rich)
	_section(page, "TextureRect and ColorRect", "These are display controls. They have no native hover, pressed, or disabled states.")
	row = _row(page)
	var texture := TextureRect.new()
	texture.texture = get_theme_icon("folder", "FileDialog")
	texture.custom_minimum_size = Vector2(64, 64)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(texture)
	for color in [Color("c0c0c0"), Color("808080"), Color("404040"), Color("000080"), Color("800000")]:
		var cell := _cell(row, "#" + color.to_html(false))
		var swatch := ColorRect.new()
		swatch.color = color
		swatch.custom_minimum_size = Vector2(120, 64)
		cell.add_child(swatch)
	_section(page, "Layout reference")
	_label(page, "Margin / HBox / VBox / Grid / Center / Scroll / Split containers arrange controls.\nTheir visible effects are spacing, alignment, clipping, scrolling, and dividers.")
	_section(page, "Review checklist")
	_label(page, "1. Borders and backgrounds\n2. Text contrast and disabled contrast\n3. Hover and pressed feedback\n4. Keyboard focus and selection\n5. Padding, row height, and alignment\n6. Check marks, arrows, and other icons\n7. Dialog, menu, and tooltip consistency")


func _theme_parts_page() -> void:
	var page := _page("All theme states")
	_section(page, "Complete theme-state reference", "Fixed samples of every style box and state icon for the controls below. These show individual theme parts; use the other pages to see them assembled in real controls.")
	var native_theme := ThemeDB.get_default_theme()
	for type_name in ["Button", "CheckBox", "CheckButton", "OptionButton", "MenuButton", "LinkButton", "LineEdit", "TextEdit", "SpinBox", "HSlider", "VSlider", "HScrollBar", "VScrollBar", "ProgressBar", "ItemList", "Tree", "TabContainer", "TabBar", "PopupMenu", "AcceptDialog", "Window", "FileDialog", "Panel", "PanelContainer", "TooltipPanel", "HSeparator", "VSeparator", "HSplitContainer"]:
		_section(page, type_name)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 14)
		page.add_child(grid)
		var style_names := Array(native_theme.get_stylebox_list(type_name))
		for style_name in theme.get_stylebox_list(type_name):
			if style_name not in style_names:
				style_names.append(style_name)
		# Button-derived controls can inherit Button boxes from the app theme.
		if type_name in ["CheckBox", "CheckButton", "OptionButton", "MenuButton"]:
			for style_name in theme.get_stylebox_list("Button"):
				if style_name not in style_names:
					style_names.append(style_name)
		style_names.sort()
		for style_name in style_names:
			var cell := _cell(grid, str(style_name).replace("_", " ").capitalize())
			cell.custom_minimum_size.x = 245
			var swatch := Panel.new()
			swatch.custom_minimum_size = Vector2(245, 48)
			var box: StyleBox
			if theme.has_stylebox(style_name, type_name):
				box = theme.get_stylebox(style_name, type_name)
			elif type_name in ["CheckBox", "CheckButton", "OptionButton", "MenuButton"] and theme.has_stylebox(style_name, "Button"):
				box = theme.get_stylebox(style_name, "Button")
			else:
				box = native_theme.get_stylebox(style_name, type_name)
			swatch.add_theme_stylebox_override("panel", box)
			cell.add_child(swatch)
		var icon_names := Array(native_theme.get_icon_list(type_name))
		for icon_name in theme.get_icon_list(type_name):
			if icon_name not in icon_names:
				icon_names.append(icon_name)
		icon_names.sort()
		for icon_name in icon_names:
			var cell := _cell(grid, str(icon_name).replace("_", " ").capitalize())
			cell.custom_minimum_size.x = 245
			var icon := TextureRect.new()
			icon.texture = theme.get_icon(icon_name, type_name) if theme.has_icon(icon_name, type_name) else native_theme.get_icon(icon_name, type_name)
			icon.custom_minimum_size = Vector2(245, 32)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			cell.add_child(icon)
