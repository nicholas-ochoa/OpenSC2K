class_name ControlBinding
extends RefCounted
## One keyboard key or mouse button, with its modifier keys, that starts a
## player action. Keys use physical key codes, so a binding stays on the same
## key for every keyboard layout.

enum Device { KEY, MOUSE }

# Command is Cmd on macOS and Ctrl on other systems. Control is the separate
# Ctrl key on macOS only
const SHIFT := 1
const ALT := 2
const COMMAND := 4
const CONTROL := 8
const MODIFIER_NAMES: Array[Array] = [[COMMAND, "Command"], [CONTROL, "Ctrl"], [ALT, "Alt"], [SHIFT, "Shift"]]
const MOUSE_NAMES: Dictionary[int, String] = {
	MOUSE_BUTTON_LEFT: "Left", MOUSE_BUTTON_RIGHT: "Right", MOUSE_BUTTON_MIDDLE: "Middle",
	MOUSE_BUTTON_WHEEL_UP: "WheelUp", MOUSE_BUTTON_WHEEL_DOWN: "WheelDown",
	MOUSE_BUTTON_WHEEL_LEFT: "WheelLeft", MOUSE_BUTTON_WHEEL_RIGHT: "WheelRight",
	MOUSE_BUTTON_XBUTTON1: "Extra1", MOUSE_BUTTON_XBUTTON2: "Extra2",
}
const MOUSE_LABELS: Dictionary[int, String] = {
	MOUSE_BUTTON_LEFT: "Left button", MOUSE_BUTTON_RIGHT: "Right button", MOUSE_BUTTON_MIDDLE: "Middle button",
	MOUSE_BUTTON_WHEEL_UP: "Wheel up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel down",
	MOUSE_BUTTON_WHEEL_LEFT: "Wheel left", MOUSE_BUTTON_WHEEL_RIGHT: "Wheel right",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}
# Godot names some keys differently on each system, such as Option for Alt on
# macOS. The settings file uses these names on every system
const STORED_KEY_NAMES: Dictionary[int, String] = {
	KEY_ALT: "Alt", KEY_META: "Meta", KEY_CTRL: "Ctrl", KEY_SHIFT: "Shift",
}
const MODIFIER_KEYS: Dictionary[int, int] = {
	KEY_SHIFT: SHIFT, KEY_ALT: ALT, KEY_META: COMMAND, KEY_CTRL: COMMAND,
}

var device := Device.KEY
var code := 0
var modifiers := 0


func _init(value_device := Device.KEY, value_code := 0, value_modifiers := 0) -> void:
	device = value_device
	code = value_code
	modifiers = value_modifiers


static func key(value_code: int, value_modifiers := 0) -> ControlBinding:
	return ControlBinding.new(Device.KEY, value_code, value_modifiers)


static func mouse(button: int, value_modifiers := 0) -> ControlBinding:
	return ControlBinding.new(Device.MOUSE, button, value_modifiers)


static func is_macos() -> bool:
	return OS.has_feature("macos")


# Returns null for text that does not name a known key or mouse button.
static func from_text(text: String) -> ControlBinding:
	var parts := text.strip_edges().split(":", true, 1)

	if parts.size() != 2 or parts[0] not in ["key", "mouse"]:
		return null

	var names := parts[1].split("+")
	var value_modifiers := 0

	for index in names.size() - 1:
		var bit := _modifier_bit(names[index])

		if bit == 0:
			return null

		value_modifiers |= bit

	var name := names[names.size() - 1]

	if name.is_empty():
		return null

	if parts[0] == "mouse":
		var button: int = MOUSE_NAMES.find_key(name) if MOUSE_NAMES.values().has(name) else MOUSE_BUTTON_NONE

		return mouse(button, value_modifiers) if button != MOUSE_BUTTON_NONE else null

	var keycode: int = STORED_KEY_NAMES.find_key(name) if STORED_KEY_NAMES.values().has(name) else OS.find_keycode_from_string(name)

	if keycode == KEY_NONE:
		return null

	return key(keycode, value_modifiers)


static func _modifier_bit(name: String) -> int:
	for pair in MODIFIER_NAMES:
		if pair[1] == name:
			# Ctrl is the Command key on systems other than macOS
			return COMMAND if pair[0] == CONTROL and not is_macos() else pair[0]

	return 0


# Returns null for an event that cannot be a binding, such as a key release.
static func from_event(event: InputEvent) -> ControlBinding:
	if event is InputEventKey:
		var keycode: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode

		if keycode == KEY_NONE:
			return null

		return key(keycode, event_modifiers(event) & ~int(MODIFIER_KEYS.get(keycode, 0)))

	if event is InputEventMouseButton and MOUSE_NAMES.has(event.button_index):
		return mouse(event.button_index, event_modifiers(event))

	return null


static func event_modifiers(event: InputEventWithModifiers) -> int:
	var result := 0

	if event.shift_pressed:
		result |= SHIFT

	if event.alt_pressed:
		result |= ALT

	if is_macos():
		if event.meta_pressed:
			result |= COMMAND

		if event.ctrl_pressed:
			result |= CONTROL
	elif event.ctrl_pressed:
		result |= COMMAND

	return result


func to_text() -> String:
	var text := "mouse:" if device == Device.MOUSE else "key:"

	for pair in MODIFIER_NAMES:
		if modifiers & pair[0]:
			text += pair[1] + "+"

	if device == Device.MOUSE:
		return text + MOUSE_NAMES.get(code, "")

	return text + STORED_KEY_NAMES.get(code, OS.get_keycode_string(code))


func equals(other: ControlBinding) -> bool:
	return other != null and device == other.device and code == other.code and modifiers == other.modifiers


func is_modifier_key() -> bool:
	return device == Device.KEY and MODIFIER_KEYS.has(code)


# the Godot key value with modifier masks, as menus use for shortcut hints
func key_with_masks() -> int:
	var value := code

	if modifiers & SHIFT:
		value |= KEY_MASK_SHIFT

	if modifiers & ALT:
		value |= KEY_MASK_ALT

	if modifiers & COMMAND:
		value |= KEY_MASK_META if is_macos() else KEY_MASK_CTRL

	if modifiers & CONTROL:
		value |= KEY_MASK_CTRL

	return value


func display_text() -> String:
	if device == Device.MOUSE:
		return _modifier_prefix(modifiers) + MOUSE_LABELS.get(code, "Mouse %d" % code)

	var label := code

	# show the letter that this layout prints on the physical key
	if _is_letter_or_digit(code) and DisplayServer.get_name() != "headless":
		var layout_key := DisplayServer.keyboard_get_label_from_physical(code as Key)

		if layout_key != KEY_NONE:
			label = layout_key

	return ScurkContextMenu.key_hint((key_with_masks() & KEY_MODIFIER_MASK) | label)


# macOS menus show modifier symbols. Other systems show names joined with "+"
static func _modifier_prefix(value: int) -> String:
	var text := ""

	for entry in [[CONTROL, "⌃", ""], [ALT, "⌥", "Alt+"], [SHIFT, "⇧", "Shift+"], [COMMAND, "⌘", "Ctrl+"]]:
		if value & entry[0]:
			text += entry[1] if is_macos() else entry[2]

	return text


static func _is_letter_or_digit(keycode: int) -> bool:
	return (keycode >= KEY_A and keycode <= KEY_Z) or (keycode >= KEY_0 and keycode <= KEY_9)


# printable symbol keys also match the layout key code, so "+" and "=" work on
# layouts that put them on other physical keys
static func _is_symbol(keycode: int) -> bool:
	return keycode > KEY_SPACE and keycode < 127 and not _is_letter_or_digit(keycode)


# Modifiers must match exactly, so Z does not start when Command+Z is pressed.
# ignore_shift lets held camera keys work while Shift is down. A mouse binding
# without modifiers matches the button with any modifiers.
func matches(event: InputEvent, ignore_shift := false) -> bool:
	var event_mods := 0

	if device == Device.KEY:
		if not event is InputEventKey:
			return false

		var physical: int = event.physical_keycode

		if physical == KEY_NONE:
			physical = event.keycode

		if physical != code and not (_is_symbol(code) and event.keycode == code):
			return false

		event_mods = event_modifiers(event) & ~int(MODIFIER_KEYS.get(code, 0))

		# on macOS the Ctrl key reports the Control bit, not Command
		if code == KEY_CTRL:
			event_mods &= ~CONTROL
	else:
		if not event is InputEventMouseButton or event.button_index != code:
			return false

		if modifiers == 0:
			return true

		event_mods = event_modifiers(event)

	if ignore_shift and modifiers & SHIFT == 0:
		event_mods &= ~SHIFT

	return event_mods == modifiers


# true while the key or button is down
func is_pressed() -> bool:
	if device == Device.MOUSE:
		return Input.is_mouse_button_pressed(code as MouseButton)

	if is_modifier_key():
		return Input.is_key_pressed(code as Key)

	return Input.is_physical_key_pressed(code as Key)
