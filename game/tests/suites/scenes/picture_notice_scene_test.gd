extends "res://tests/support/scene_case.gd"


func run() -> void:
	var scene := preload("res://src/ui/shared/picture_notice_dialog.tscn")
	var notice := scene.instantiate() as PictureNoticeDialog
	var second := scene.instantiate() as PictureNoticeDialog
	root.add_child(notice)
	root.add_child(second)
	var picture := Image.create(155, 100, false, Image.FORMAT_RGB8)
	notice.configure("TestNotice", "Test notice", "Image", "Message", picture, "First\r\nSecond\rThird")
	assert(notice.message_label.text == "First\nSecond\nThird")
	assert(notice.picture_view.texture.get_size() == Vector2(155, 100))
	assert(second.picture_view.texture == null and second.message_label.text.is_empty())
	assert(notice.picture_view.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	assert(not notice.get_label().visible and notice.exclusive)
	notice.show_message("Updated\r\nmessage", true)
	await process_frame
	assert(notice.visible and notice.message_label.text == "Updated\nmessage")
	notice.get_ok_button().pressed.emit()
	assert(not notice.visible)
	notice.set_picture(null)
	assert(notice.picture_view.texture == null)
	notice.free()
	second.free()
	print("PASS: Picture notice scene ownership, isolation, text, image sizing and close")
