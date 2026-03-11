extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := preload("res://src/ui/settings/about_dialog.tscn")
	var dialog := scene.instantiate() as AboutDialog
	var second := scene.instantiate() as AboutDialog
	root.add_child(dialog)
	root.add_child(second)
	assert(dialog.artwork.owner == dialog and dialog.picture.owner == dialog)
	assert(dialog.picture != second.picture)
	assert(dialog.title == "About OpenSC2K" and dialog.exclusive)
	dialog.set_control_graphics(null)
	assert(not dialog.artwork.visible and dialog.get_label().visible)
	assert(dialog.min_size == Vector2i(560, 250))
	var graphics := CityUiGraphics.new()
	graphics.presentation["ABOUT.BMP"] = Image.create(480, 299, false, Image.FORMAT_RGB8)
	dialog.set_control_graphics(graphics)
	assert(dialog.artwork.visible and not dialog.get_label().visible)
	assert(dialog.picture.texture.get_size() == Vector2(480, 299))
	assert(dialog.project_text.position == Vector2(245, 94))
	assert(dialog.min_size == Vector2i(560, 350))
	assert(not second.artwork.visible and second.picture.texture == null)
	dialog.popup_centered()
	await process_frame
	assert(dialog.visible and dialog.artwork.size.x >= 480)
	dialog.get_ok_button().pressed.emit()
	assert(not dialog.visible)
	dialog.set_control_graphics(null)
	assert(not dialog.artwork.visible and dialog.picture.texture == null)
	dialog.free()
	second.free()
	print("PASS: About scene ownership, independent instances, artwork fallback and close")
	quit()
