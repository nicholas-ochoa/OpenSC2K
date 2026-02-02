class_name CityQueryDialog
extends ColorRect

const ClassicStyle = preload("res://src/ui/classic_ui_style.gd")

signal close_requested(commit_rename: bool)
signal action_requested

var title_label: Label
var name_input: LineEdit
var tabs: TabContainer
var summary_rows: VBoxContainer
var text_view: TextEdit
var sprite_view: TextureRect
var sprite_caption: Label
var thing_panel: VBoxContainer
var thing_sprite_view: TextureRect
var thing_caption: Label
var rename_button: Button
var action_button: Button
var ok_button: Button


func _ready() -> void:
	name = "QueryOverlay"
	color = Color(0.0, 0.0, 0.0, 0.22)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 900
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "QueryDialog"
	panel.custom_minimum_size = Vector2(860, 600)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(
		"panel",
		ClassicStyle.create_box(Color("c0c0c0"), Color("404040"), 2, 8, 8)
	)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	_add_title_bar(column)
	_add_body(column)
	_add_buttons(column)


func show_query(
	query_title: String,
	facility_name: String,
	is_specific: bool,
	details_text: String,
	action_text: String,
	tile_texture: Texture2D,
	tile_caption: String,
	thing_texture: Texture2D,
	thing_caption_text: String,
) -> void:
	title_label.text = "Query — %s" % query_title
	name_input.visible = is_specific
	name_input.text = facility_name if is_specific else ""
	name_input.editable = false
	rename_button.visible = is_specific
	action_button.visible = not action_text.is_empty()
	action_button.text = action_text
	_populate_summary(details_text)
	tabs.current_tab = 0
	text_view.text = details_text
	text_view.scroll_vertical = 0
	sprite_view.texture = tile_texture
	sprite_caption.text = tile_caption
	thing_panel.visible = not thing_caption_text.is_empty()
	thing_sprite_view.texture = thing_texture
	thing_caption.text = thing_caption_text
	show()
	ok_button.grab_focus()


func rename_is_enabled() -> bool:
	return name_input.editable


func facility_name() -> String:
	return name_input.text


func close_query() -> void:
	hide()
	sprite_view.texture = null
	thing_sprite_view.texture = null


func _add_title_bar(column: VBoxContainer) -> void:
	var title_bar := ColorRect.new()
	title_bar.color = Color("000080")
	title_bar.custom_minimum_size = Vector2(0, 30)
	column.add_child(title_bar)
	var title_row := HBoxContainer.new()
	title_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_row.offset_left = 8
	title_row.offset_right = -4
	title_bar.add_child(title_row)
	title_label = Label.new()
	title_label.text = "Query"
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title_label)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(28, 24)
	close_button.pressed.connect(func() -> void: close_requested.emit(false))
	title_row.add_child(close_button)


func _add_body(column: VBoxContainer) -> void:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var text_column := VBoxContainer.new()
	text_column.custom_minimum_size = Vector2(580, 0)
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(text_column)
	name_input = LineEdit.new()
	name_input.max_length = 23
	name_input.editable = false
	name_input.add_theme_color_override("font_color", Color("101010"))
	name_input.add_theme_color_override("font_uneditable_color", Color("303030"))
	for state in ["normal", "focus", "read_only"]:
		name_input.add_theme_stylebox_override(
			state,
			ClassicStyle.create_box(Color("ffffff"), Color("808080"), 1, 8, 8)
		)
	text_column.add_child(name_input)
	tabs = TabContainer.new()
	tabs.add_theme_stylebox_override("panel", ClassicStyle.create_box(Color("eceeea"), Color("a0a5a0"), 1, 8, 8))
	tabs.add_theme_stylebox_override("tab_selected", ClassicStyle.create_box(Color("eceeea"), Color("a0a5a0"), 1, 10, 7))
	tabs.add_theme_stylebox_override("tab_unselected", ClassicStyle.create_box(Color("d2d5d2"), Color("a0a5a0"), 1, 10, 7))
	tabs.add_theme_color_override("font_selected_color", Color("202830"))
	tabs.add_theme_color_override("font_unselected_color", Color("505860"))
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_column.add_child(tabs)
	var summary := ScrollContainer.new()
	summary.name = "Overview"
	summary.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(summary)
	summary_rows = VBoxContainer.new()
	summary_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_rows.add_theme_constant_override("separation", 6)
	summary.add_child(summary_rows)
	text_view = TextEdit.new()
	text_view.name = "Technical details"
	text_view.editable = false
	text_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_view.add_theme_color_override("font_color", Color("101010"))
	text_view.add_theme_color_override("font_readonly_color", Color("101010"))
	for state in ["normal", "focus", "read_only"]:
		text_view.add_theme_stylebox_override(
			state,
			ClassicStyle.create_box(Color("ffffff"), Color("808080"), 1, 8, 8)
		)
	tabs.add_child(text_view)
	_add_image_column(body)


func _populate_summary(details: String) -> void:
	for child in summary_rows.get_children():
		summary_rows.remove_child(child)
		child.queue_free()
	var lines := details.split("\n")
	for index in range(1, lines.size()):
		var line := lines[index].strip_edges()
		if line == "Advanced tile data":
			break
		if line.is_empty():
			continue
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", ClassicStyle.create_box(Color("f4f4ef"), Color("d3d3cc"), 1, 12, 10))
		summary_rows.add_child(card)
		var split := line.find(":")
		if split > 0:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			card.add_child(row)
			var label := Label.new()
			label.text = line.left(split)
			label.custom_minimum_size.x = 145
			label.add_theme_color_override("font_color", Color("555b62"))
			row.add_child(label)
			var value := _summary_label(line.substr(split + 1).strip_edges())
			value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(value)
		else:
			card.add_child(_summary_label(line))


func _summary_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("202830"))
	label.add_theme_font_size_override("font_size", 16)
	return label


func _add_image_column(body: HBoxContainer) -> void:
	var image_panel := PanelContainer.new()
	image_panel.custom_minimum_size = Vector2(240, 0)
	image_panel.add_theme_stylebox_override(
		"panel",
		ClassicStyle.create_box(Color("ffffff"), Color("808080"), 1, 8, 8)
	)
	body.add_child(image_panel)
	var image_column := VBoxContainer.new()
	image_column.add_theme_constant_override("separation", 6)
	image_panel.add_child(image_column)
	sprite_caption = Label.new()
	sprite_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sprite_caption.add_theme_color_override("font_color", Color("101010"))
	image_column.add_child(sprite_caption)
	sprite_view = TextureRect.new()
	sprite_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_view.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	sprite_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image_column.add_child(sprite_view)
	thing_panel = VBoxContainer.new()
	thing_panel.add_theme_constant_override("separation", 4)
	thing_panel.visible = false
	image_column.add_child(thing_panel)
	thing_panel.add_child(HSeparator.new())
	thing_caption = Label.new()
	thing_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thing_caption.add_theme_color_override("font_color", Color("101010"))
	thing_panel.add_child(thing_caption)
	thing_sprite_view = TextureRect.new()
	thing_sprite_view.custom_minimum_size = Vector2(220, 160)
	thing_sprite_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	thing_sprite_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thing_sprite_view.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	thing_panel.add_child(thing_sprite_view)


func _add_buttons(column: VBoxContainer) -> void:
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	column.add_child(button_row)
	rename_button = Button.new()
	rename_button.text = "Rename"
	rename_button.pressed.connect(_enable_rename)
	button_row.add_child(rename_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(spacer)
	action_button = Button.new()
	action_button.visible = false
	action_button.pressed.connect(func() -> void: action_requested.emit())
	button_row.add_child(action_button)
	ok_button = Button.new()
	ok_button.text = "OK"
	ok_button.custom_minimum_size = Vector2(70, 30)
	ok_button.pressed.connect(func() -> void: close_requested.emit(true))
	button_row.add_child(ok_button)


func _enable_rename() -> void:
	name_input.editable = true
	name_input.grab_focus()
	name_input.select_all()
