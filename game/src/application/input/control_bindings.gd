class_name ControlBindings
extends RefCounted
## The keys and mouse buttons for each player action. An action can have any
## number of bindings, or none.

var bindings: Dictionary[String, Array] = {}


static func defaults() -> ControlBindings:
	var result := ControlBindings.new()
	result.reset_to_defaults()

	return result


func reset_to_defaults() -> void:
	bindings.clear()

	for action in ControlActions.all():
		var list: Array[ControlBinding] = []

		for text in action.defaults:
			var binding := ControlBinding.from_text(text)

			if binding != null:
				list.append(binding)

		bindings[action.id] = list


func duplicate_set() -> ControlBindings:
	var result := ControlBindings.new()

	for id in bindings:
		result.bindings[id] = for_action(id).duplicate()

	return result


func for_action(id: String) -> Array[ControlBinding]:
	var list: Array[ControlBinding] = []
	list.assign(bindings.get(id, []))

	return list


func add(id: String, binding: ControlBinding) -> bool:
	if binding == null or not ControlActions.has(id):
		return false

	var list := for_action(id)

	for existing in list:
		if existing.equals(binding):
			return false

	list.append(binding)
	bindings[id] = list

	return true


func remove(id: String, index: int) -> void:
	var list := for_action(id)

	if index >= 0 and index < list.size():
		list.remove_at(index)
		bindings[id] = list


func remove_binding(id: String, binding: ControlBinding) -> void:
	var list := for_action(id)

	for index in range(list.size() - 1, -1, -1):
		if list[index].equals(binding):
			list.remove_at(index)

	bindings[id] = list


# Drag actions share buttons with click and press actions: a drag moves the map
# and a click without movement starts the other action. Modifier actions can
# share one key, because each one changes a different action.
static func _kinds_overlap(first: String, second: String) -> bool:
	if first == ControlActions.KIND_MODIFIER and second == ControlActions.KIND_MODIFIER:
		return false

	return (first == ControlActions.KIND_DRAG) == (second == ControlActions.KIND_DRAG)


# SCURK editor keys work only in the editor, so they can use city keys again.
# anywhere keys work on every screen
static func _scopes_overlap(first: String, second: String) -> bool:
	if first == ControlActions.SCOPE_ANYWHERE or second == ControlActions.SCOPE_ANYWHERE:
		return true

	return (first == ControlActions.SCOPE_SCURK) == (second == ControlActions.SCOPE_SCURK)


# actions, other than except_id, that already use this binding
func conflicts(binding: ControlBinding, except_id := "") -> Array[String]:
	var result: Array[String] = []
	var target := ControlActions.find(except_id)
	var kind := target.kind if target != null else ControlActions.KIND_PRESS
	var scope := target.scope if target != null else ControlActions.SCOPE_MAP

	for action in ControlActions.all():
		if (action.id == except_id or action.scope == ControlActions.SCOPE_FIXED or not _kinds_overlap(kind, action.kind)
				or not _scopes_overlap(scope, action.scope)):
			continue

		for existing in for_action(action.id):
			if existing.equals(binding):
				result.append(action.id)

				break

	return result


# The press, hold, or click action for an input event, or "" when there is none.
# A binding with the exact modifiers wins over a mouse binding without
# modifiers and over a held camera key with Shift down.
func action_for(event: InputEvent, kinds: Array = [ControlActions.KIND_PRESS, ControlActions.KIND_HOLD],
		scopes: Array = ControlActions.CITY_SCOPES) -> String:
	var loose_match := ""
	var any_command := ControlActions.SCOPE_SCURK in scopes

	for action in ControlActions.all():
		if action.scope not in scopes or action.kind not in kinds:
			continue

		for binding in for_action(action.id):
			if not binding.matches(event, action.kind == ControlActions.KIND_HOLD, any_command):
				continue

			if binding.matches(event, false, any_command) and (binding.device == ControlBinding.Device.KEY
					or binding.modifiers == ControlBinding.event_modifiers(event as InputEventWithModifiers, any_command)):
				return action.id

			if loose_match.is_empty():
				loose_match = action.id

	return loose_match


func has_mouse_button(id: String, button: int) -> bool:
	for binding in for_action(id):
		if binding.device == ControlBinding.Device.MOUSE and binding.code == button:
			return true

	return false


# true while any binding of the action is down
func is_held(id: String) -> bool:
	for binding in for_action(id):
		if binding.is_pressed():
			return true

	return false


# true while a key of the modifier action is down, as the event reports it
func modifier_held(id: String, event: InputEvent) -> bool:
	for binding in for_action(id):
		if binding.is_held_in(event):
			return true

	return false


# true when the key event is for a key of the action, pressed or released
func uses_key(id: String, event: InputEventKey) -> bool:
	for binding in for_action(id):
		if binding.matches_key(event):
			return true

	return false


# the first key binding, for menu shortcut hints
func first_key(id: String) -> ControlBinding:
	for binding in for_action(id):
		if binding.device == ControlBinding.Device.KEY:
			return binding

	return null


func to_texts(id: String) -> PackedStringArray:
	var texts := PackedStringArray()

	for binding in for_action(id):
		texts.append(binding.to_text())

	return texts


func equals(other: ControlBindings) -> bool:
	if other == null:
		return false

	for id in ControlActions.bindable_ids():
		if to_texts(id) != other.to_texts(id):
			return false

	return true
