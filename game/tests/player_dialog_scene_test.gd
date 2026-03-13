extends SceneTree

var confirmations := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sign := preload("res://src/ui/tools/city_sign_dialog.tscn").instantiate() as CitySignDialog
	root.add_child(sign)
	sign.confirmed.connect(func() -> void: confirmations += 1)
	sign.show_text("Old sign")
	await process_frame
	assert(sign.text_input.owner == sign and sign.text_input.has_focus())
	sign.text_input.text = "A new sign"
	assert(sign.entered_text() == "A new sign")
	sign.get_ok_button().pressed.emit()
	assert(confirmations == 1 and not sign.visible)
	sign.show_text("")
	assert(sign.entered_text().is_empty())
	sign.hide()
	sign.free()
	print("PASS: Player dialog scene input, confirmation and ownership")
	quit()
