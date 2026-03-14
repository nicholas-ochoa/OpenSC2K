class_name ToolChoiceDialog
extends ConfirmationDialog

const Numbers = preload("res://src/ui/shared/display_number_format.gd")

signal choice_requested(index: int)

var choice_buttons: Array[Button] = []


func _ready() -> void:
	theme = ClassicUiStyle.create_dialog_theme()
	get_ok_button().visible = false

	for child in $Choices.get_children():
		var choice_button := child as Button
		choice_button.pressed.connect(choice_requested.emit.bind(choice_buttons.size()))
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
