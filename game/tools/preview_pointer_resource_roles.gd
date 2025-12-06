extends SceneTree
## Read-only role inspector. Original masks are composed over review backgrounds.

var records: Array[Dictionary] = []
var content: Control
var status: Label
var page := 0
var show_hotspot := false
var selected: Dictionary = {}


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	root.title = "Icon and cursor roles (original files, read-only)"
	root.size = Vector2i(1800, 1350)
	root.content_scale_size = Vector2i(1200, 900)
	var inventory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../data/formats/graphics-inventory.json"))
	for source in ["SIMCITY.EXE", "WINSCURK.EXE"]:
		for kind in ["icon", "cursor"]:
			for record in inventory.entries:
				if record.source == source and record.kind == kind:
					var groups := []
					for group in inventory.entries:
						if group.source == source and group.kind == kind + "_group" and group.members.has(record.id):
							groups.append(int(group.id))
					record.groups = groups
					records.append(record)
	var background := ColorRect.new()
	background.color = Color("c0c0c0")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	for i in 2:
		var button := Button.new()
		button.text = "Previous sheet" if i == 0 else "Next sheet"
		button.position = Vector2(12 + i * 220, 12)
		button.size = Vector2(210, 40)
		button.pressed.connect(func() -> void:
			page = posmod(page + (-1 if i == 0 else 1), ceili(records.size() / 24.0))
			selected = {}
			_refresh()
		)
		root.add_child(button)
	var check := CheckButton.new()
	check.text = "Mark hotspot"
	check.position = Vector2(465, 12)
	check.toggled.connect(func(value: bool) -> void: show_hotspot = value; _refresh())
	root.add_child(check)
	content = Control.new()
	content.position = Vector2(12, 75)
	root.add_child(content)
	status = _label("", Vector2(16, 866), 16, root)
	_refresh()


func _refresh() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	if not selected.is_empty():
		_detail()
		return
	for slot in 24:
		var index := page * 24 + slot
		if index >= records.size():
			break
		var record := records[index]
		var p := Vector2((slot % 6) * 196, int(slot / 6) * 195)
		_label("%s %s %d\ngroup %s" % ["City" if record.source == "SIMCITY.EXE" else "SCURK", record.kind, int(record.id), str(record.groups)], p, 15, content)
		var decoded := _load(record)
		var view := _image(decoded, p + Vector2(12, 47), 4, 0)
		view.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				selected = record
				_refresh()
		)
	status.text = "Sheet %d/%d • 153 original images • click for detail • no source export or modification" % [page + 1, ceili(records.size() / 24.0)]


func _detail() -> void:
	var decoded := _load(selected)
	_label("%s • %s %d • group %s • %d×%d • hotspot %s • %d XOR pixels" % [selected.source, selected.kind, int(selected.id), str(selected.groups), decoded.width, decoded.height, str(decoded.hotspot), decoded.inverting_pixels], Vector2.ZERO, 18, content)
	_image(decoded, Vector2(12, 80), 16, 1)
	_image(decoded, Vector2(600, 80), 16, 2)
	status.text = "Light and dark background composition • Previous/Next returns to sheets"


func _load(record: Dictionary) -> Dictionary:
	var decoded := PeIconCursorResource.load_image("res://../references/" + str(record.source), int(record.id), record.kind == "cursor")
	assert(decoded.ok, str(decoded.error))
	return decoded


func _image(decoded: Dictionary, position: Vector2, zoom: int, backdrop: int) -> TextureRect:
	var background := Image.create(decoded.width, decoded.height, false, Image.FORMAT_RGBA8)
	for y in int(decoded.height):
		for x in int(decoded.width):
			var color := Color("e5e5e5") if backdrop == 1 else Color("20364c")
			if backdrop == 0:
				color = Color("ffffff") if (int(x / 8) + int(y / 8)) % 2 == 0 else Color("73999c")
			background.set_pixel(x, y, color)
	var image := PeIconCursorResource.composite(decoded, background)
	if show_hotspot:
		image.set_pixelv(decoded.hotspot, Color.RED)
	var view := TextureRect.new()
	view.texture = ImageTexture.create_from_image(image)
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.position = position
	view.size = Vector2(image.get_size()) * zoom
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
