extends SceneTree
## Read-only native inspection of supplied SCURK bitmap control resources.

var records: Array[Dictionary] = []
var content: Control
var status: Label
var page := 0


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	root.title = "SCURK control resource role audit (original files, read-only)"
	root.size = Vector2i(1800, 1350)
	root.content_scale_size = Vector2i(1200, 900)
	var inventory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../data/formats/graphics-inventory.json"))
	for record in inventory.entries:
		if record.source == "WINSCURK.EXE" and record.kind == "bitmap":
			records.append(record)
	if records.is_empty():
		print("No remaining SCURK bitmap records in the current coverage inventory.")
		quit()
		return
	var backdrop := ColorRect.new()
	backdrop.color = Color("c0c0c0")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	for i in 2:
		var button := Button.new()
		button.text = "Previous page" if i == 0 else "Next page"
		button.position = Vector2(12 + i * 225, 12)
		button.size = Vector2(210, 40)
		button.pressed.connect(func() -> void:
			page = posmod(page + (-1 if i == 0 else 1), ceili(records.size() / 16.0))
			_refresh()
		)
		root.add_child(button)
	content = Control.new()
	content.position = Vector2(12, 75)
	root.add_child(content)
	status = Label.new()
	status.position = Vector2(16, 870)
	status.add_theme_color_override("font_color", Color.BLACK)
	root.add_child(status)
	_refresh()


func _refresh() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for slot in 16:
		var index := page * 16 + slot
		if index >= records.size():
			break
		var record := records[index]
		var loaded := PeBitmapResource.load_numeric("res://../references/WINSCURK.EXE", int(record.id))
		assert(loaded.ok, str(loaded.error))
		var image: Image = loaded.image
		var p := Vector2((slot % 4) * 294, (slot / 4) * 195)
		var label := Label.new()
		label.text = "%d • %d × %d • %d-bit source" % [int(record.id), int(record.width), int(record.height), int(record.bits)]
		label.position = p
		label.add_theme_color_override("font_color", Color.BLACK)
		label.add_theme_font_size_override("font_size", 17)
		content.add_child(label)
		var zoom := minf(4, minf(270.0 / image.get_width(), 150.0 / image.get_height()))
		if zoom >= 1:
			zoom = floorf(zoom)
		var view := TextureRect.new()
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.texture = ImageTexture.create_from_image(image)
		view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		view.position = p + Vector2(5, 34)
		view.size = Vector2(image.get_size()) * zoom
		content.add_child(view)
	status.text = "Page %d/%d • supplied bitmap pixels for role inspection only • no original images are exported or changed" % [page + 1, ceili(records.size() / 16.0)]
