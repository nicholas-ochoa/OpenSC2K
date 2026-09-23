class_name ScurkContextMenu
extends PopupMenu
## Keeps custom shortcut hints in one column and forwards outside right-clicks.

var hints: Dictionary[int, String] = {}
var hint_labels: Array[Label] = []
var base_end_padding := 0


func _ready() -> void:
	base_end_padding = get_theme_constant("item_end_padding")
	about_to_popup.connect(_layout_hints)
	id_focused.connect(_update_hint_colors)
	window_input.connect(_outside_click)


func reset_hints() -> void:
	hints.clear()
	for label in hint_labels:
		label.free()
	hint_labels.clear()


func _layout_hints() -> void:
	for label in hint_labels:
		label.free()
	hint_labels.clear()
	if hints.is_empty():
		return
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var width := 0.0
	for hint in hints.values():
		width = maxf(width, font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var spacing := get_theme_constant("v_separation")
	var padding := base_end_padding + ceili(width) + get_theme_constant("h_separation") * 2
	add_theme_constant_override("item_end_padding", padding)
	# Use the menu's scrolling content so hints follow the rows when it scrolls.
	var content := _find_scroll(self).get_child(0, true) as Control
	var top := spacing * 0.5
	for index in item_count:
		var height := font.get_height(font_size)
		if is_item_separator(index):
			height = get_theme_stylebox("separator").get_minimum_size().y
			for style in ["labeled_separator_left", "labeled_separator_right"]:
				height = maxf(height, get_theme_stylebox(style).get_minimum_size().y)
		elif is_item_checkable(index):
			height = maxf(height, get_theme_icon("checked").get_height())
		if hints.has(index):
			var label := Label.new()
			label.text = hints[index]
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_override("font", font)
			label.add_theme_font_size_override("font_size", font_size)
			content.add_child(label)
			label.anchor_left = 1.0
			label.anchor_right = 1.0
			label.offset_left = -base_end_padding - width
			label.offset_right = -base_end_padding
			label.offset_top = top
			label.offset_bottom = top + height
			label.set_meta("item", index)
			hint_labels.append(label)
		top += height + spacing
	_update_hint_colors(-1)


func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for child in node.get_children(true):
		var found := _find_scroll(child)
		if found != null:
			return found
	return null


func _update_hint_colors(id: int) -> void:
	for label in hint_labels:
		var index: int = label.get_meta("item")
		var role := "font_disabled_color" if is_item_disabled(index) else "font_hover_color" if get_item_id(index) == id else "font_accelerator_color"
		label.add_theme_color_override("font_color", get_theme_color(role))


func _outside_click(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if get_visible_rect().has_point(event.position):
		return
	var target := get_parent().get_viewport()
	var forwarded := event.duplicate() as InputEventMouseButton
	forwarded.position = target.get_screen_transform().affine_inverse() * (get_screen_transform() * event.position)
	forwarded.global_position = forwarded.position
	set_input_as_handled()
	hide()
	target.push_input.call_deferred(forwarded, true)
