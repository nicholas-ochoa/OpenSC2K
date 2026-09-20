extends "res://tests/support/scene_case.gd"


func run() -> void:
	var dialog := preload("res://src/ui/startup/scenario_intro_dialog.tscn").instantiate() as ScenarioIntroDialog
	root.add_child(dialog)
	var picture := Image.create(260, 260, false, Image.FORMAT_RGB8)
	dialog.set_briefing("Test", picture, "Extended Description: First\r\nSecond")
	assert(dialog.text_view.text == "First\nSecond")
	assert(dialog.picture_view.texture.get_size() == Vector2(260, 260))
	dialog.show_briefing("No picture", null, "Text only")
	await process_frame
	assert(dialog.visible and dialog.picture_view.texture == null)
	assert(dialog.text_view.size.x > 0)

	dialog.set_briefing("Long briefing", null, "Briefing paragraph.\n".repeat(100))
	await process_frame
	await process_frame
	assert(dialog.text_view.size.y > dialog.text_scroll.size.y)
	assert(dialog.text_view.size.x <= dialog.text_scroll.size.x)
	dialog.text_scroll.scroll_vertical = 100
	assert(dialog.text_scroll.scroll_vertical > 0)
	dialog.set_briefing("Next briefing", null, "Next scenario")
	assert(dialog.text_scroll.scroll_vertical == 0)
	dialog.get_ok_button().pressed.emit()
	assert(not dialog.visible)
	dialog.free()
	print("PASS: Scenario briefing, missing image and Begin Scenario")
