class_name ScurkInterfaceFeedback
extends RefCounted
## Routes user actions to interface feedback. State refreshes stay silent.


static func bind(node: Node, feedback: Callable) -> void:
	var watch_child := bind.bind(feedback)
	if node.child_entered_tree.is_connected(watch_child):
		return

	if node is BaseButton:
		if node.pressed.is_connected(feedback):
			return
		if not _forwards_feedback(node):
			node.pressed.connect(feedback)
		if node is OptionButton:
			node.item_selected.connect(feedback.unbind(1))
		# OptionButton emits item_selected. SCURK menus activate hidden action
		# buttons. Do not also watch their internal PopupMenu signals.
		if node is OptionButton or (node is MenuButton and node.get_parent().get_parent() is ScurkEditorToolbar):
			return
	elif node is PopupMenu:
		node.id_pressed.connect(feedback.unbind(1))
	elif node is AcceptDialog:
		node.confirmed.connect(feedback)
		node.canceled.connect(feedback)
	elif node is Window:
		node.close_requested.connect(feedback)
	elif node is TabBar:
		node.tab_clicked.connect(feedback.unbind(1))
	elif node is SpinBox:
		node.gui_input.connect(_spin_input.bind(node, feedback))
		node.get_line_edit().gui_input.connect(_spin_input.bind(node, feedback))
		node.get_line_edit().text_submitted.connect(feedback.unbind(1))
	elif node is ItemList or node is Tree:
		node.gui_input.connect(_list_input.bind(node, feedback))
	elif node is ScurkPaletteControl or node is ScurkPrintPreview:
		node.button_clicked.connect(feedback)

	node.child_entered_tree.connect(watch_child)
	for child in node.get_children(true):
		bind(child, feedback)


static func _forwards_feedback(button: BaseButton) -> bool:
	var parent := button.get_parent()
	while parent != null:
		if parent is AcceptDialog:
			return (button == parent.get_ok_button()
				or (parent is ConfirmationDialog and button == parent.get_cancel_button()))
		if parent is Window and button.pressed.is_connected(parent.close_requested.emit):
			return true
		parent = parent.get_parent()
	return false


static func _spin_input(event: InputEvent, spin: SpinBox, feedback: Callable) -> void:
	if not spin.editable:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			feedback.call()
	elif event is InputEventKey:
		for action in [&"ui_up", &"ui_down", &"ui_page_up", &"ui_page_down"]:
			if event.is_action_pressed(action, true):
				feedback.call()
				return


static func _list_input(event: InputEvent, list: Control, feedback: Callable) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			return
		if list is ItemList and list.get_item_at_position(event.position, true) >= 0:
			feedback.call()
		elif list is Tree and list.get_item_at_position(event.position) != null:
			feedback.call()
	elif event is InputEventKey:
		for action in [&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_home", &"ui_end", &"ui_page_up", &"ui_page_down", &"ui_accept"]:
			if event.is_action_pressed(action, true):
				feedback.call()
				return
