class_name LibraryRuminateWindows
extends Control

const WindowLayout = preload("res://src/ui/city_windows/library_window_layout.gd")
const TextWindowScene = preload("res://src/ui/city_windows/library_text_window.tscn")

const TEXT_RESOURCE_IDS := [3000, 3001, 3002, 3003]
# above the Query overlay, which stays open below the text
const OVERLAY_Z_INDEX := 1000

var window: PanelContainer
var margin: MarginContainer
var content: VBoxContainer
var buttons: HBoxContainer
var text_scroll: ScrollContainer
var text_label: Label
var ok_button: Button
var pages := PackedStringArray()
var page_index := -1
var viewport_size := Vector2i.ZERO


func _ready() -> void:
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = OVERLAY_Z_INDEX
	window = TextWindowScene.instantiate() as PanelContainer
	window.name = "LibraryText"
	margin = window.get_node("Margin")
	content = window.get_node("Margin/Content")
	buttons = window.get_node("Margin/Content/Buttons")
	text_scroll = window.get_node("Margin/Content/Scroll")
	text_label = window.get_node("Margin/Content/Scroll/Text")
	ok_button = window.get_node("Margin/Content/Buttons/OK")
	ok_button.pressed.connect(close_page)
	add_child(window)


# the original runs one modal text window for each resource, in order
func show_texts(texts: Dictionary, size_limit: Vector2i) -> void:
	pages = PackedStringArray()

	for resource_id in TEXT_RESOURCE_IDS:
		pages.append(str(texts[resource_id]).replace("\r\n", "\n").replace("\r", "\n"))

	viewport_size = size_limit
	page_index = 0
	show()
	_show_page()


func current_resource_id() -> int:
	if not visible or page_index < 0:
		return -1

	return TEXT_RESOURCE_IDS[page_index]


# OK or Escape ends the current text window and opens the next one
func close_page() -> void:
	if not visible:
		return

	page_index += 1

	if page_index >= pages.size():
		page_index = -1
		pages = PackedStringArray()
		hide()

		return

	_show_page()


func _show_page() -> void:
	text_label.text = pages[page_index]
	_fit_window()
	text_scroll.scroll_vertical = 0

	if ok_button.is_inside_tree():
		ok_button.grab_focus()


# the original grows each window to fit its complete text
func _fit_window() -> void:
	var width := WindowLayout.window_width(viewport_size)
	var panel_size := window.get_theme_stylebox("panel").get_minimum_size()
	var text_width := maxf(
		1.0,
		width - panel_size.x
		- margin.get_theme_constant("margin_left") - margin.get_theme_constant("margin_right"),
	)
	var frame_height := ceili(
		panel_size.y
		+ margin.get_theme_constant("margin_top") + margin.get_theme_constant("margin_bottom")
		+ content.get_theme_constant("separation") + buttons.get_combined_minimum_size().y
	)
	var text_height := mini(
		ceili(_text_height(text_width)),
		maxi(1, WindowLayout.max_window_height(viewport_size) - frame_height),
	)
	text_scroll.custom_minimum_size = Vector2(text_width, text_height)
	var window_rect := WindowLayout.rect(
		viewport_size, Vector2i(width, frame_height + text_height)
	)
	window.position = window_rect.position
	window.size = window_rect.size


# the label wraps at the final text width before it reports its height
func _text_height(text_width: float) -> float:
	text_label.size = Vector2(text_width, text_label.size.y)

	return text_label.get_minimum_size().y
