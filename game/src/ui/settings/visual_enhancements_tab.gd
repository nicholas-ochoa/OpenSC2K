class_name VisualEnhancementsTab
extends ScrollContainer

signal changed
signal reload_requested
signal export_requested

var controls: Dictionary = {}
var filling := false


func _ready() -> void:
	name = "Visual Enhancements"
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	add_child(content)
	var sections: Dictionary[String, VBoxContainer] = {}
	for title in ["Seasons", "Day and Night Shift", "Weather Effects", "Water", "Traffic & Movement", "Other Effects"]:
		if not VisualEnhancementOptions.FIELDS.any(func(field: Array) -> bool: return _category_for(field[0]) == title):
			continue
		var section := VBoxContainer.new()
		section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section.add_theme_constant_override("separation", 8)
		var heading := Label.new()
		heading.text = title
		heading.add_theme_font_size_override("font_size", get_theme_font_size("font_size") + 3)
		section.add_child(heading)
		section.add_child(HSeparator.new())
		content.add_child(section)
		sections[title] = section
	for field in VisualEnhancementOptions.FIELDS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = field[1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var control: Control
		match field[2]:
			"bool":
				control = CheckBox.new()
				(control as CheckBox).toggled.connect(func(_v: bool) -> void: _changed())
			"choice":
				control = OptionButton.new()
				for choice in field[4]:
					(control as OptionButton).add_item(choice)
				(control as OptionButton).item_selected.connect(func(_v: int) -> void: _choice_changed(field[0]))
			"number":
				var spin := SpinBox.new()
				spin.min_value = field[4]
				spin.max_value = field[5]
				spin.step = field[6]
				spin.value_changed.connect(func(_v: float) -> void: _changed())
				control = spin
			"path":
				control = LineEdit.new()
				control.custom_minimum_size.x = 240
				(control as LineEdit).text_submitted.connect(func(_v: String) -> void: _changed())
				control.focus_exited.connect(_changed)
		row.add_child(control)
		sections[_category_for(field[0])].add_child(row)
		controls[field[0]] = control
	var buttons := HFlowContainer.new()
	var brightmap_buttons := HFlowContainer.new()
	for title in ["Disable all", "Use defaults", "Reload brightmaps", "Export PNG templates"]:
		var button := Button.new()
		button.text = title
		button.pressed.connect(func() -> void:
			if title == "Use defaults":
				show_values({})
			elif title == "Disable all":
				var values := selected_values()
				for key in values:
					if str(key).ends_with("_enabled"):
						values[key] = false
				values.water_reflections = 0
				values.water_topography = false
				show_values(values)
			changed.emit()
			if title == "Reload brightmaps":
				reload_requested.emit()
			elif title == "Export PNG templates":
				export_requested.emit())
		if title in ["Reload brightmaps", "Export PNG templates"]:
			brightmap_buttons.add_child(button)
		else:
			buttons.add_child(button)
	sections["Day and Night Shift"].add_child(brightmap_buttons)
	content.add_child(HSeparator.new())
	content.add_child(buttons)
	show_values({})


func _category_for(key: String) -> String:
	if key.begins_with("season_"):
		return "Seasons"
	if key.begins_with("day_") or key.begins_with("night_") or key in ["brightmaps", "brightmap_folder", "lut_path", "speed_link", "pause_freezes"]:
		return "Day and Night Shift"
	if key.begins_with("weather_") or key.begins_with("cloud_"):
		return "Weather Effects"
	if key.begins_with("water_"):
		return "Water"
	if key.begins_with("life_") or key.begins_with("traffic_"):
		return "Traffic & Movement"
	return "Other Effects"


func _changed() -> void:
	if not filling:
		changed.emit()


func _choice_changed(key: String) -> void:
	if filling:
		return
	if key == "weather_fixed":
		# Choosing a specific weather is a manual override, immediately.
		(controls.weather_mode as OptionButton).select(2)
		(controls.weather_enabled as CheckBox).set_pressed_no_signal(true)
	_changed()


func show_values(source: Dictionary) -> void:
	filling = true
	var values := VisualEnhancementOptions.normalize(source)
	for key in controls:
		var control: Control = controls[key]
		if control is CheckBox:
			(control as CheckBox).button_pressed = values[key]
		elif control is OptionButton:
			(control as OptionButton).select(values[key])
		elif control is SpinBox:
			(control as SpinBox).value = values[key]
		elif control is LineEdit:
			(control as LineEdit).text = values[key]
	filling = false


func selected_values() -> Dictionary:
	var values := {}
	for key in controls:
		var control: Control = controls[key]
		if control is CheckBox:
			values[key] = (control as CheckBox).button_pressed
		elif control is OptionButton:
			values[key] = (control as OptionButton).selected
		elif control is SpinBox:
			values[key] = (control as SpinBox).value
		elif control is LineEdit:
			values[key] = (control as LineEdit).text
	return VisualEnhancementOptions.normalize(values)
