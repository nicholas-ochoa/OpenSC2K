class_name ToolChoiceDialog
extends ConfirmationDialog

const Numbers = preload("res://src/ui/display_number_format.gd")

signal choice_requested(index: int)

var choice_buttons: Array[Button] = []


func _ready() -> void:
	title = "Select Building"
	dialog_text = "Select a building type."
	min_size = Vector2i(680, 390)
	exclusive = true
	get_ok_button().visible = false
	get_cancel_button().text = "Cancel"

	var choices := GridContainer.new()
	choices.columns = 3
	choices.set_anchors_preset(Control.PRESET_TOP_WIDE)
	choices.offset_left = 16
	choices.offset_top = 72
	choices.offset_right = -16
	choices.offset_bottom = 320
	choices.add_theme_constant_override("h_separation", 8)
	choices.add_theme_constant_override("v_separation", 8)
	add_child(choices)
	for choice_index in 9:
		var choice_button := Button.new()
		choice_button.custom_minimum_size = Vector2(205, 72)
		choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_button.pressed.connect(choice_requested.emit.bind(choice_index))
		choices.add_child(choice_button)
		choice_buttons.append(choice_button)


func set_tools(title_text: String, prompt_text: String, tools: Array) -> void:
	title = title_text
	dialog_text = prompt_text
	for choice_index in choice_buttons.size():
		var choice_button := choice_buttons[choice_index]
		choice_button.visible = choice_index < tools.size()
		if not choice_button.visible:
			continue
		var tool: Dictionary = tools[choice_index]
		choice_button.text = "%s\n$%s" % [
			tool.get("name", "Building"),
			Numbers.format(int(tool.get("cost", 0))),
		]
		choice_button.tooltip_text = "Select %s" % tool.get("name", "building")


func show_tools(title_text: String, prompt_text: String, tools: Array) -> void:
	set_tools(title_text, prompt_text, tools)
	popup_centered()
