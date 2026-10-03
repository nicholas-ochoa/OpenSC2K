class_name HoverFocusRouter
extends Node
## Gives mouse hover and the mouse wheel to the window under the cursor.
##
## An embedded window that has focus gets every mouse event, also when the
## cursor is over the city or another window. Before the root window routes a
## motion or wheel event, this moves the focus to the dialog under the cursor,
## or releases it when the cursor is over the main view. Popups, modal dialogs,
## a held button, and a text field that has focus keep the current focus.

const WHEEL_BUTTONS: Array[MouseButton] = [
	MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT,
]

var root: Window
var _windows: Array[Window] = []
var _popups: Array[Popup] = []


func attach(value: Window) -> void:
	root = value
	root.window_input.connect(route)
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

	for window in root.find_children("*", "Window", true, false):
		_on_node_added(window)


# route one event of the root window. tests call this before push_input. the
# signal gives window pixels; the windows use the stretched viewport space
func route(event: InputEvent) -> void:
	var point := Vector2.ZERO

	if event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).button_mask != 0:
			return

		point = (event as InputEventMouseMotion).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index in WHEEL_BUTTONS:
		point = (event as InputEventMouseButton).position
	else:
		return

	if root == null or not root.gui_embed_subwindows or _has_blocking_window():
		return

	var target := window_at(viewport_point(point, root.get_final_transform()))
	var focused := focused_window()

	if target == focused:
		return

	if focused != null and _is_typing(focused):
		return

	if target != null:
		target.grab_focus()
	elif focused != null:
		release_focus(focused)


# a window pixel in the viewport space, as Viewport.push_input converts it
static func viewport_point(point: Vector2, final_transform: Transform2D) -> Vector2:
	return final_transform.affine_inverse() * point


# the topmost managed window whose frame contains `point`, or null
func window_at(point: Vector2) -> Window:
	var result: Window = null

	for window in _windows:
		if not window.visible or window.mouse_passthrough or not _frame(window).has_point(Vector2i(point)):
			continue

		if result == null or _is_above(window, result):
			result = window

	return result


func focused_window() -> Window:
	for window in _windows:
		if window.visible and window.has_focus():
			return window

	return null


# an unfocusable window that takes the focus releases the focused one
static func release_focus(window: Window) -> void:
	var unfocusable := window.unfocusable
	window.unfocusable = true
	window.grab_focus()
	window.unfocusable = unfocusable


func _on_node_added(node: Node) -> void:
	if node is Popup:
		if not _popups.has(node):
			_popups.append(node)
	elif node is Window and node != root and not _windows.has(node):
		_windows.append(node)


func _on_node_removed(node: Node) -> void:
	if node is Popup:
		_popups.erase(node)
	elif node is Window:
		_windows.erase(node)


# an open menu or a modal dialog keeps the focus. a tooltip passes the mouse
func _has_blocking_window() -> bool:
	for popup in _popups:
		if popup.visible and not popup.mouse_passthrough:
			return true

	for window in _windows:
		if window.visible and window.exclusive:
			return true

	return false


static func _is_typing(window: Window) -> bool:
	var owner := window.gui_get_focus_owner()

	return owner is LineEdit or owner is TextEdit


# the window and its title bar
static func _frame(window: Window) -> Rect2i:
	var rect := Rect2i(window.position, window.size)

	if not window.borderless:
		var title := window.get_theme_constant("title_height")
		rect.position.y -= title
		rect.size.y += title

	return rect


# a later sibling window draws above an earlier one
static func _is_above(left: Window, right: Window) -> bool:
	return left.get_index() > right.get_index() if left.get_parent() == right.get_parent() else left.has_focus()
