class_name VisualTimeEdit
extends LineEdit
## Display a saved fractional hour as HH:MM without changing it until edited.

@warning_ignore_start("integer_division")

signal value_changed(value: float)

var value := 12.0:
	set(next):
		value = clampf(next, 0.0, 23.99)
		_show_time()


func _ready() -> void:
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_submitted.connect(func(_text: String) -> void: commit())
	focus_exited.connect(commit)
	_show_time()


func _show_time() -> void:
	var minutes := clampi(roundi(value * 60.0), 0, 1439)
	text = "%02d:%02d" % [minutes / 60, minutes % 60]


func commit() -> void:
	var next := pending_value()
	if is_equal_approx(next, value):
		_show_time()
		return
	value = next
	value_changed.emit(value)


func pending_value() -> float:
	var parts := text.strip_edges().split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return value
	var hours := int(parts[0])
	var minutes := int(parts[1])
	if hours < 0 or hours > 23 or minutes < 0 or minutes > 59:
		return value
	# Merely focusing an existing rounded display must retain its saved precision.
	if hours * 60 + minutes == roundi(value * 60.0):
		return value
	return hours + minutes / 60.0


func _gui_input(event: InputEvent) -> void:
	if editable and event is InputEventKey and event.pressed and event.keycode in [KEY_UP, KEY_DOWN]:
		commit()
		var previous := value
		value += 0.25 if event.keycode == KEY_UP else -0.25
		if value != previous:
			value_changed.emit(value)
		accept_event()
