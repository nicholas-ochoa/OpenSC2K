class_name LibraryRuminateWindows
extends Control

const WindowLayout = preload("res://src/ui/city_windows/library_window_layout.gd")
const ClassicStyle = preload("res://src/ui/shared/classic_ui_style.gd")

const TEXT_RESOURCE_IDS := [3000, 3001, 3002, 3003]
const BASE_Z_INDEX := 1000

var windows: Array[PanelContainer] = []
var text_views: Array[TextEdit] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	for resource_id in TEXT_RESOURCE_IDS:
		_add_text_window(resource_id)


func show_texts(texts: Dictionary, viewport_size: Vector2i) -> void:
	var window_rects := WindowLayout.rects(viewport_size, TEXT_RESOURCE_IDS.size())

	for index in TEXT_RESOURCE_IDS.size():
		var resource_id: int = TEXT_RESOURCE_IDS[index]
		text_views[index].text = (
			str(texts[resource_id]).replace("\r\n", "\n").replace("\r", "\n")
		)
		text_views[index].scroll_vertical = 0
		windows[index].position = window_rects[index].position
		windows[index].size = window_rects[index].size
		_bring_to_front(windows[index])
		windows[index].show()


func _add_text_window(resource_id: int) -> void:
	var window := PanelContainer.new()
	window.name = "LibraryText%d" % resource_id
	window.visible = false
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	window.add_theme_stylebox_override(
		"panel", ClassicStyle.create_box(Color("c0c0c0"), Color("404040"), 2)
	)
	window.gui_input.connect(_on_window_input.bind(window))

	var margin := MarginContainer.new()

	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)

	window.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var text_view := TextEdit.new()
	text_view.editable = false
	text_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_view.add_theme_color_override("font_color", Color("101010"))
	text_view.add_theme_color_override("font_readonly_color", Color("101010"))

	for state in ["normal", "focus", "read_only"]:
		text_view.add_theme_stylebox_override(
			state, ClassicStyle.create_box(Color("ffffff"), Color("808080"), 1)
		)

	text_view.gui_input.connect(_on_window_input.bind(window))
	column.add_child(text_view)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(button_row)
	var ok_button := Button.new()
	ok_button.text = "OK"
	ok_button.pressed.connect(window.hide)
	button_row.add_child(ok_button)

	add_child(window)
	windows.append(window)
	text_views.append(text_view)


func _on_window_input(event: InputEvent, window: PanelContainer) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		_bring_to_front(window)


func _bring_to_front(window: PanelContainer) -> void:
	for other in windows:
		if other != window and other.z_index > BASE_Z_INDEX:
			other.z_index -= 1

	window.z_index = BASE_Z_INDEX + windows.size()
