class_name BridgeSelectionDialog
extends ConfirmationDialog

const Numbers = preload("res://src/ui/display_number_format.gd")

signal choice_requested(index: int)

var choice_buttons: Array[Button] = []


func _ready() -> void:
	title = "Select Bridge"
	dialog_text = "Select a bridge type."
	min_size = Vector2i(660, 250)
	exclusive = true
	get_ok_button().visible = false
	get_cancel_button().text = "Cancel"

	var choices := HBoxContainer.new()
	choices.set_anchors_preset(Control.PRESET_TOP_WIDE)
	choices.offset_left = 16
	choices.offset_top = 72
	choices.offset_right = -16
	choices.offset_bottom = 180
	choices.add_theme_constant_override("separation", 8)
	add_child(choices)
	for choice_index in 3:
		var choice_button := Button.new()
		choice_button.custom_minimum_size = Vector2(200, 104)
		choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_button.pressed.connect(choice_requested.emit.bind(choice_index))
		choices.add_child(choice_button)
		choice_buttons.append(choice_button)


func set_choices(
	span_length: int,
	request_type: String,
	choices: Array,
	free_mode: bool,
) -> void:
	var span_units := (
		"2 by 2 water sections" if request_type == "highway" else "water tiles"
	)
	dialog_text = "Select a bridge for %d %s." % [span_length, span_units]
	var cost_unit := (
		"2 by 2 water section" if request_type == "highway" else "water tile"
	)
	for choice_index in choice_buttons.size():
		var choice_button := choice_buttons[choice_index]
		choice_button.visible = choice_index < choices.size()
		if not choice_button.visible:
			continue
		var choice: Dictionary = choices[choice_index]
		choice_button.text = (
			"%s\nFree in Place & Print" % choice.get("name", "Bridge")
			if free_mode
			else "%s\n$%s total\n$%s for each %s" % [
				choice.get("name", "Bridge"),
				Numbers.format(int(choice.get("cost", 0))),
				Numbers.format(int(choice.get("cost_per_tile", 0))),
				cost_unit,
			]
		)
		choice_button.tooltip_text = "Build %s" % choice.get("name", "bridge")


func show_choices(
	span_length: int,
	request_type: String,
	choices: Array,
	free_mode: bool,
) -> void:
	set_choices(span_length, request_type, choices, free_mode)
	popup_centered()
