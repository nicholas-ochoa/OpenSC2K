class_name ControlsBindingList
extends VBoxContainer
## The Controls tab rows. Each row shows the bindings of one action, with a
## remove button for each binding and an add button that waits for the next
## key or mouse button. The chips wrap onto more lines when a row has many
## bindings. Each change applies at once through bindings_changed.

signal button_clicked
signal bindings_changed

const LABEL_WIDTH := 190

var pending := ControlBindings.defaults()
var capture_action := ""
var capture_overlay: PanelContainer
var capture_dialog: AcceptDialog
var capture_label: Label
var conflict_dialog: ConfirmationDialog
var _capture_modifier: InputEventKey
var _conflict_action := ""
var _conflict_binding: ControlBinding
var _conflicts: Array[String] = []
var _rows: Dictionary[String, HFlowContainer] = {}


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conflict_dialog = ConfirmationDialog.new()
	conflict_dialog.title = "Binding in use"
	conflict_dialog.ok_button_text = "Reassign"
	conflict_dialog.exclusive = true
	conflict_dialog.confirmed.connect(_reassign)
	conflict_dialog.confirmed.connect(button_clicked.emit)
	conflict_dialog.canceled.connect(button_clicked.emit)
	add_child(conflict_dialog, false, Node.INTERNAL_MODE_BACK)
	rebuild()


# The overlay covers the dialog content while the list waits for a binding.
func attach_capture_overlay(dialog: AcceptDialog) -> void:
	capture_dialog = dialog
	capture_overlay = PanelContainer.new()
	capture_overlay.name = "CaptureOverlay"
	capture_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	capture_overlay.visible = false
	capture_label = Label.new()
	capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capture_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	capture_overlay.add_child(capture_label)
	dialog.add_child(capture_overlay)


func show_bindings(value: ControlBindings) -> void:
	cancel_capture()
	pending = value.duplicate_set()
	rebuild()


func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	_rows.clear()

	for category in ControlActions.CATEGORIES:
		if get_child_count() > 0:
			add_child(HSeparator.new())

		var heading := Label.new()
		heading.text = category if category != "Fixed" else "Fixed controls"
		heading.add_theme_font_size_override("font_size", 15)
		add_child(heading)

		for action in ControlActions.all():
			if action.category == category:
				add_child(HSeparator.new())
				add_child(_action_row(action))


func _action_row(action: ControlActions.Action) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = action.id
	row.add_theme_constant_override("separation", 8)
	# long labels wrap, so the bindings start at the same place on every row
	var label := Label.new()
	label.name = "Label"
	label.text = action.label
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 28)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var chips := HFlowContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 4)
	row.add_child(chips)

	if action.scope == ControlActions.SCOPE_FIXED:
		var fixed := Label.new()
		fixed.text = tr("%s (fixed)") % (action.fixed_text if not action.fixed_text.is_empty()
			else ControlBinding.from_text(action.defaults[0]).display_text())
		fixed.theme_type_variation = &"HelpLabel"
		fixed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fixed.custom_minimum_size = Vector2(0, 28)
		chips.add_child(fixed)

		return row

	var list := pending.for_action(action.id)

	for index in list.size():
		chips.add_child(_chip(action.id, index, list[index]))

	var add := Button.new()
	add.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add.name = "Add"
	add.text = "+"
	add.tooltip_text = tr("Add a key or mouse button for %s") % action.label
	add.custom_minimum_size = Vector2(28, 28)
	add.pressed.connect(start_capture.bind(action.id))
	add.pressed.connect(button_clicked.emit)
	row.add_child(add)
	_rows[action.id] = chips

	return row


func _chip(id: String, index: int, binding: ControlBinding) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"PanelPadding5_2_5_2"
	chip.tooltip_text = binding.full_text()
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	chip.add_child(content)
	var text := Label.new()
	text.text = binding.display_text()
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(text)
	var remove := Button.new()
	remove.name = "Remove"
	remove.text = "✕"
	remove.flat = true
	remove.tooltip_text = tr("Remove %s") % binding.display_text()
	remove.pressed.connect(remove_binding.bind(id, index))
	remove.pressed.connect(button_clicked.emit)
	content.add_child(remove)

	return chip


func remove_binding(id: String, index: int) -> void:
	pending.remove(id, index)
	rebuild()
	bindings_changed.emit()


func start_capture(id: String) -> void:
	var action := ControlActions.find(id)

	if action == null or action.scope == ControlActions.SCOPE_FIXED:
		return

	capture_action = id
	_capture_modifier = null

	# Esc cancels the capture, not the settings dialog
	if capture_dialog != null:
		capture_dialog.dialog_close_on_escape = false
	_show_capture_text("Press a key or mouse button for %s.\nPress Esc to cancel." % action.label)


func _show_capture_text(text: String) -> void:
	if capture_overlay == null:
		return

	capture_label.text = text
	capture_overlay.show()
	capture_overlay.move_to_front()


func cancel_capture() -> void:
	capture_action = ""
	_capture_modifier = null

	if capture_dialog != null:
		capture_dialog.set_deferred("dialog_close_on_escape", true)

	if capture_overlay != null:
		capture_overlay.hide()


func is_capturing() -> bool:
	return not capture_action.is_empty()


func _input(event: InputEvent) -> void:
	if is_capturing() and capture_input(event):
		get_viewport().set_input_as_handled()


# Returns true when the event belongs to the capture, so no dialog button or
# field receives it.
func capture_input(event: InputEvent) -> bool:
	var kind := ControlActions.find(capture_action).kind

	if event is InputEventKey:
		var key_event := event as InputEventKey
		var binding := ControlBinding.from_event(key_event)

		if key_event.echo or binding == null:
			return true

		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			cancel_capture()

			return true

		# a modifier key alone becomes a binding when it is released without
		# another key
		if binding.is_modifier_key():
			if key_event.pressed:
				_capture_modifier = key_event
			elif _capture_modifier != null and kind in [ControlActions.KIND_HOLD, ControlActions.KIND_MODIFIER]:
				finish_capture(ControlBinding.from_event(_capture_modifier))

			return true

		if key_event.pressed:
			if kind == ControlActions.KIND_DRAG:
				_show_capture_text("Move map (drag) needs a mouse button.\nPress Esc to cancel.")

				return true

			# a modifier action is one key. other modifier keys held with it do not count
			if kind == ControlActions.KIND_MODIFIER:
				binding.modifiers = 0

			finish_capture(binding)

		return true

	if event is InputEventMouseButton:
		if not event.pressed:
			return true

		if event.button_index == MOUSE_BUTTON_LEFT:
			_show_capture_text("The left button always uses the current tool.\nPress another button, or Esc to cancel.")

			return true

		if kind == ControlActions.KIND_MODIFIER:
			_show_capture_text("%s needs a key.\nPress Esc to cancel." % ControlActions.find(capture_action).label)

			return true

		var binding := ControlBinding.from_event(event)

		if binding != null:
			finish_capture(binding)

		return true

	return event is InputEventMouseMotion


func finish_capture(binding: ControlBinding) -> void:
	var id := capture_action
	cancel_capture()

	if binding == null or id.is_empty():
		return

	var conflicts := pending.conflicts(binding, id)

	if conflicts.is_empty():
		pending.add(id, binding)
		rebuild()
		bindings_changed.emit()

		return

	_conflict_action = id
	_conflict_binding = binding
	_conflicts = conflicts
	var names := PackedStringArray()

	for other in conflicts:
		names.append(ControlActions.find(other).label)

	conflict_dialog.dialog_text = "%s is already bound to %s. Reassign it?" % [binding.display_text(), ", ".join(names)]
	conflict_dialog.popup_centered()


func _reassign() -> void:
	if _conflict_binding == null:
		return

	for other in _conflicts:
		pending.remove_binding(other, _conflict_binding)

	pending.add(_conflict_action, _conflict_binding)
	_conflict_binding = null
	_conflicts.clear()
	rebuild()
	bindings_changed.emit()


func chip_count(id: String) -> int:
	return pending.for_action(id).size()
