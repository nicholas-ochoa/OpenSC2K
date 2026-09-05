extends "res://tests/support/scene_case.gd"

var confirmations := 0
var selected_choice := -1


func run() -> void:
	var sign := preload("res://src/ui/tools/city_sign_dialog.tscn").instantiate() as CitySignDialog
	root.add_child(sign)
	sign.confirmed.connect(func() -> void: confirmations += 1)
	sign.show_text("Old sign")
	await process_frame
	assert(sign.text_input.has_focus())
	sign.text_input.text = "A new sign"
	assert(sign.entered_text() == "A new sign")
	sign.text_input.text = "x".repeat(32)
	assert(sign.entered_text().length() == 23, "Sign input respects the saved XLAB limit")
	sign.get_ok_button().pressed.emit()
	assert(confirmations == 1 and not sign.visible)
	sign.show_text("")
	assert(sign.entered_text().is_empty())
	sign.hide()
	sign.free()
	var stadium := preload("res://src/ui/tools/stadium_team_dialog.tscn").instantiate() as StadiumTeamDialog
	root.add_child(stadium)
	stadium.show_teams([{"id": 4, "name": "Lions"}, {"id": 9, "name": "Bears"}])
	assert(stadium.selected_team_id() == 4 and stadium.entered_name() == "Lions")
	stadium.team_selector.select(1)
	stadium.team_selector.item_selected.emit(1)
	assert(stadium.selected_team_id() == 9 and stadium.entered_name() == "Bears")
	stadium.name_input.text = "City Bears"
	assert(stadium.entered_name() == "City Bears")
	stadium.name_input.text = "x".repeat(32)
	assert(stadium.entered_name().length() == 23, "Team input respects the saved XLAB limit")
	stadium.hide()
	stadium.free()
	var choice := preload("res://src/ui/tools/tool_choice_dialog.tscn").instantiate() as ToolChoiceDialog
	root.add_child(choice)
	choice.choice_requested.connect(func(index: int) -> void: selected_choice = index)
	choice.set_tools("Tools", "Pick one", [ToolCatalog.Tool.new("", "First", 25), ToolCatalog.Tool.new("", "Second", 75)])
	assert(not choice.choice_buttons[2].visible)
	choice.choice_buttons[1].pressed.emit()
	assert(selected_choice == 1 and choice.choice_buttons[1].text.contains("Second"))
	choice.free()
	var bridge := preload("res://src/ui/tools/bridge_selection_dialog.tscn").instantiate() as BridgeSelectionDialog
	root.add_child(bridge)
	bridge.choice_requested.connect(func(index: int) -> void: selected_choice = index)
	bridge.set_choices(4, "road", [{"name": "Test Bridge", "cost": 100, "cost_per_tile": 25}], false)
	assert(not bridge.choice_buttons[1].visible)
	assert(bridge.choice_labels[0].text.contains("$100"))
	bridge.choice_buttons[0].pressed.emit()
	assert(selected_choice == 0)
	bridge.free()
	print("PASS: Player dialog scene input, confirmation and selection")
