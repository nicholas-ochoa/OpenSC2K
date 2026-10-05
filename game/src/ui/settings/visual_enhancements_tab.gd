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
				spin.value_changed.connect(func(_v: float) -> void: _changed())
				control = spin
			"path":
				control = LineEdit.new()
				control.custom_minimum_size.x = 240
				(control as LineEdit).text_submitted.connect(func(_v: String) -> void: _changed())
				control.focus_exited.connect(_changed)
		row.add_child(control)
		content.add_child(row)
		controls[field[0]] = control
	var buttons := HBoxContainer.new()
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
		buttons.add_child(button)
	content.add_child(buttons)
	show_values({})


func _changed() -> void:
	if not filling:
		changed.emit()


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
