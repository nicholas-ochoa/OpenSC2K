class_name LibraryRuminateWindows
extends Control

const WindowLayout = preload("res://src/ui/city_windows/library_window_layout.gd")
const TextWindowScene = preload("res://src/ui/city_windows/library_text_window.tscn")

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
	var window := TextWindowScene.instantiate() as PanelContainer
	window.name = "LibraryText%d" % resource_id
	window.gui_input.connect(_on_window_input.bind(window))
	var text_view: TextEdit = window.get_node("Margin/Content/Text")
	text_view.gui_input.connect(_on_window_input.bind(window))
	window.get_node("Margin/Content/Buttons/OK").pressed.connect(window.hide)
	window.hide()
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
