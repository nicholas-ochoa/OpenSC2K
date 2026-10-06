class_name VisualEnhancementsTab
extends ScrollContainer

signal changed
signal reload_requested
signal export_requested
signal luts_reload_requested
signal luts_export_requested

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
	for title in ["Seasons", "Day and Night Shift", "Weather Effects", "Environment", "Traffic & Movement", "Other Effects"]:
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
				(control as OptionButton).item_selected.connect(func(_v: int) -> void: _changed())
			"number":
				var spin := SpinBox.new()
				spin.min_value = field[4]
				spin.max_value = field[5]
				spin.step = field[6]
				if field[0] == "night_light_strength":
					spin.suffix = "%"
					spin.tooltip_text = "Brightness of building and vehicle lights. 100% uses the original brightness; 0% turns the lights off without changing the night colors."
				spin.value_changed.connect(func(_v: float) -> void: _changed())
				control = spin
			"path":
				control = LineEdit.new()
				control.custom_minimum_size.x = 240
				(control as LineEdit).text_submitted.connect(func(_v: String) -> void: _changed())
				control.focus_exited.connect(_changed)
		row.add_child(control)
		if field[0] == "weather_fixed":
			control.tooltip_text = "Snow is shown only in winter. In other seasons, snow selections use rain of the same strength."
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
	var lut_buttons := HFlowContainer.new()
	for title in ["Reload LUT profiles", "Export LUT profiles"]:
		var button := Button.new()
		button.text = title
		button.pressed.connect(func() -> void:
			if title == "Reload LUT profiles":
				luts_reload_requested.emit()
			else:
				luts_export_requested.emit())
		lut_buttons.add_child(button)
	sections["Other Effects"].add_child(lut_buttons)
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
		return "Environment"
	if key.begins_with("life_") or key.begins_with("traffic_"):
		return "Traffic & Movement"
	return "Other Effects"


func _changed() -> void:
	if not filling:
		_update_availability()
		changed.emit()


func _update_availability() -> void:
	var values := selected_values()
	for key: String in controls:
		var available := true
		if key.begins_with("season_") and key != "season_enabled":
			available = values.season_enabled
		elif (key.begins_with("day_") and key != "day_enabled") or key in ["night_strength", "brightmaps", "night_light_strength", "brightmap_folder"]:
			available = values.day_enabled
		elif key.begins_with("weather_") and key != "weather_enabled":
			available = values.weather_enabled
		elif key.begins_with("cloud_") and key != "cloud_enabled":
			available = values.cloud_enabled
		match key:
			"season_fixed":
				available = available and values.season_mode == 2
			"season_seconds":
				available = available and values.season_mode == 1
			"season_transition":
				available = available and values.season_mode != 2
			"day_hour":
				available = available and values.day_mode == 1
			"day_seconds":
				available = available and values.day_mode == 0
			"weather_fixed":
				available = available and values.weather_mode == 2
			"weather_seconds":
				available = available and values.weather_mode == 1
			"brightmap_folder", "night_light_strength":
				available = available and values.brightmaps
			"life_car_amount":
				available = values.life_cars_enabled
			"life_people_amount":
				available = values.life_people_enabled
		var control: Control = controls[key]
		if control is BaseButton:
			(control as BaseButton).disabled = not available
		elif control is SpinBox:
			(control as SpinBox).editable = available
		elif control is LineEdit:
			(control as LineEdit).editable = available
		control.get_parent().modulate.a = 1.0 if available else 0.45


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
	_update_availability()


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
