extends SceneTree
## Read-only source role inspector for SimCity PE and standalone bitmap images.

var records: Array[Dictionary] = []
var content: Control
var status: Label
var page := 0


func _initialize() -> void:
	var screen := 0

	for candidate in DisplayServer.get_screen_count():
		if DisplayServer.screen_get_position(candidate).x < DisplayServer.screen_get_position(screen).x:
			screen = candidate

	root.current_screen = screen
	root.position = DisplayServer.screen_get_position(screen) + Vector2i(40, 40)
	call_deferred("_build")


func _build() -> void:
	root.title = "SimCity bitmap roles (original files, read-only)"
	root.size = Vector2i(1800, 1350)
	root.content_scale_size = Vector2i(1200, 900)
	var inventory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../data/formats/graphics-inventory.json"))

	for record in inventory.entries:
		if (record.source == "SIMCITY.EXE" and record.kind == "bitmap") or record.kind == "bitmap_file":
			records.append(record)

	if records.is_empty():
		print("No matching source bitmap records remain.")
		quit()

		return

	var background := ColorRect.new()
	background.color = Color("c0c0c0")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	for i in 2:
		var button := Button.new()
		button.text = "Previous sheet" if i == 0 else "Next sheet"
		button.position = Vector2(12 + i * 230, 12)
		button.size = Vector2(215, 40)
		button.pressed.connect(func() -> void:
			page = posmod(page + (-1 if i == 0 else 1), ceili(records.size() / 12.0))
			_sheet()
		)
		root.add_child(button)

	content = Control.new()
	content.position = Vector2(12, 75)
	root.add_child(content)
	status = _label("", Vector2(16, 870), 16, root)
	_sheet()


func _clear() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()


func _sheet() -> void:
	_clear()

	for slot in 12:
		var index := page * 12 + slot

		if index >= records.size():
			break

		var record := records[index]
		var image := _load_image(record)
		var p := Vector2((slot % 4) * 294, (slot / 4) * 260)
		_label("%s / %s\n%d × %d • %d-bit" % [record.source, str(record.id), int(record.width), int(record.height), int(record.bits)], p, 16, content)
		var zoom := minf(4, minf(270.0 / image.get_width(), 195.0 / image.get_height()))

		if zoom >= 1:
			zoom = floorf(zoom)

		var view := _image(image, p + Vector2(5, 56), zoom)
		view.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_detail(record)
		)

	status.text = "Sheet %d/%d • %d source images • click for detail • no source image export or modification" % [page + 1, ceili(records.size() / 12.0), records.size()]


func _detail(record: Dictionary) -> void:
	_clear()
	var image := _load_image(record)
	var zoom := maxf(1, floorf(minf(1120.0 / image.get_width(), 715.0 / image.get_height())))
	_label("%s / %s • %d × %d • %d×" % [record.source, str(record.id), image.get_width(), image.get_height(), int(zoom)], Vector2(10, 0), 22, content)
	_image(image, Vector2(10, 45), zoom)
	status.text = "Use Previous or Next sheet to return • original pixels for source role review only"


func _load_image(record: Dictionary) -> Image:
	var path := "res://../references/SIMCITY2000/" + str(record.source)

	if record.kind == "bitmap_file":
		var image := Image.load_from_file(path)
		assert(image != null)

		return image

	var result := PeBitmapResource.load_named(path, record.id) if record.id is String else PeBitmapResource.load_numeric(path, int(record.id))
	assert(result.ok, str(result.error))

	return result.image


func _image(image: Image, position: Vector2, zoom: float) -> TextureRect:
	var view := TextureRect.new()
	view.texture = ImageTexture.create_from_image(image)
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.position = position
	view.size = Vector2(image.get_size()) * zoom
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(view)

	return view


func _label(text: String, position: Vector2, font_size: int, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)

	return label
