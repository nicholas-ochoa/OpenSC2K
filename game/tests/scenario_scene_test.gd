extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var dialog := preload("res://src/ui/startup/scenario_intro_dialog.tscn").instantiate() as ScenarioIntroDialog
	root.add_child(dialog)
	var picture := Image.create(260, 260, false, Image.FORMAT_RGB8)
	dialog.set_briefing("Test", picture, "First\r\nSecond")
	assert(dialog.title == "Scenario: Test" and dialog.text_view.text == "First\nSecond")
	assert(dialog.picture_view.owner == dialog and dialog.text_view.owner == dialog)
	assert(dialog.picture_view.texture.get_size() == Vector2(260, 260))
	assert(not dialog.text_view.editable and dialog.get_ok_button().text == "Begin Scenario")
	dialog.show_briefing("No picture", null, "Text only")
	await process_frame
	assert(dialog.visible and dialog.picture_view.texture == null)
	assert(dialog.text_view.size.x > 0)
	dialog.get_ok_button().pressed.emit()
	assert(not dialog.visible)
	dialog.free()
	print("PASS: Scenario scene ownership, briefing, missing image and Begin Scenario")
	quit()
