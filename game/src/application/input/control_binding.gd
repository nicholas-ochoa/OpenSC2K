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
# full key names for tooltips, where the chip shows a symbol or a short name
const FULL_KEY_NAMES: Dictionary[int, String] = {
	KEY_ESCAPE: "Escape", KEY_TAB: "Tab", KEY_BACKTAB: "Back Tab", KEY_BACKSPACE: "Backspace",
	KEY_DELETE: "Delete", KEY_INSERT: "Insert", KEY_ENTER: "Enter", KEY_KP_ENTER: "Keypad Enter",
	KEY_PAGEUP: "Page Up", KEY_PAGEDOWN: "Page Down", KEY_HOME: "Home", KEY_END: "End",
	KEY_LEFT: "Left Arrow", KEY_UP: "Up Arrow", KEY_RIGHT: "Right Arrow", KEY_DOWN: "Down Arrow",
	KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_CAPSLOCK: "Caps Lock", KEY_NUMLOCK: "Num Lock",
	KEY_SCROLLLOCK: "Scroll Lock", KEY_PRINT: "Print Screen", KEY_PAUSE: "Pause", KEY_CLEAR: "Clear",
	KEY_SPACE: "Space", KEY_MINUS: "Minus (-)", KEY_EQUAL: "Equals (=)", KEY_BRACKETLEFT: "Left Bracket ([)",
	KEY_BRACKETRIGHT: "Right Bracket (])", KEY_BACKSLASH: "Backslash (\\)", KEY_SEMICOLON: "Semicolon (;)",
	KEY_APOSTROPHE: "Apostrophe (')", KEY_QUOTELEFT: "Grave Accent (`)", KEY_COMMA: "Comma (,)",
	KEY_PERIOD: "Period (.)", KEY_SLASH: "Slash (/)",
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


# any_command reads both Ctrl and Cmd as Command on every system, as the
# SCURK editor keys always have
static func event_modifiers(event: InputEventWithModifiers, any_command := false) -> int:
	var result := 0

	if any_command:
		result |= COMMAND if event.ctrl_pressed or event.meta_pressed else 0
		result |= SHIFT if event.shift_pressed else 0
		result |= ALT if event.alt_pressed else 0

		return result

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


# The tooltip text, with every modifier and key named in words, such as
# "Cmd+Shift+Keypad Subtract".
func full_text() -> String:
	var mac := is_macos()
	var names := PackedStringArray()

	for entry in [[CONTROL, "Ctrl", ""], [ALT, "Option", "Alt"], [SHIFT, "Shift", "Shift"], [COMMAND, "Cmd", "Ctrl"]]:
		if modifiers & entry[0]:
			names.append(entry[1] if mac else entry[2])

	if device == Device.MOUSE:
		names.append(MOUSE_LABELS.get(code, "Mouse %d" % code))
	else:
		names.append(full_key_name(code))

	return "+".join(names)


static func full_key_name(keycode: int) -> String:
	if keycode == KEY_ALT:
		return "Option" if is_macos() else "Alt"

	if keycode == KEY_META:
		return "Cmd" if is_macos() else "Super"

	if FULL_KEY_NAMES.has(keycode):
		return FULL_KEY_NAMES[keycode]

	if _is_letter_or_digit(keycode) and DisplayServer.get_name() != "headless":
		var layout_key := DisplayServer.keyboard_get_label_from_physical(keycode as Key)

		if layout_key != KEY_NONE:
			keycode = layout_key

	var name := OS.get_keycode_string(keycode)

	if name.begins_with("Kp "):
		return "Keypad " + name.substr(3)

	return name


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
func matches(event: InputEvent, ignore_shift := false, any_command := false) -> bool:
	var event_mods := 0

	if device == Device.KEY:
		if not event is InputEventKey:
			return false

		if not matches_key(event):
			return false

		event_mods = event_modifiers(event, any_command) & ~int(MODIFIER_KEYS.get(code, 0))

		# on macOS the Ctrl key reports the Control bit, not Command
		if code == KEY_CTRL:
			event_mods &= ~CONTROL
	else:
		if not event is InputEventMouseButton or event.button_index != code:
			return false

		if modifiers == 0:
			return true

		event_mods = event_modifiers(event, any_command)

	if ignore_shift and modifiers & SHIFT == 0:
		event_mods &= ~SHIFT

	return event_mods == modifiers


# true when a key event is for this key, without a check of modifiers
func matches_key(event: InputEventKey) -> bool:
	if device != Device.KEY:
		return false

	var physical: int = event.physical_keycode

	if physical == KEY_NONE:
		physical = event.keycode

	return physical == code or (_is_symbol(code) and event.keycode == code)


# True while this key is down, for a modifier action. A modifier key reads
# the modifier flags of the event, so a mouse event reports it too.
func is_held_in(event: InputEvent) -> bool:
	if device != Device.KEY:
		return false

	if event is InputEventKey and matches_key(event):
		return event.pressed

	if event is InputEventWithModifiers and is_modifier_key():
		match code:
			KEY_SHIFT:
				return event.shift_pressed
			KEY_ALT:
				return event.alt_pressed
			KEY_CTRL:
				return event.ctrl_pressed
			KEY_META:
				return event.meta_pressed

	return is_pressed()


# true while the key or button is down
func is_pressed() -> bool:
	if device == Device.MOUSE:
		return Input.is_mouse_button_pressed(code as MouseButton)

	if is_modifier_key():
		return Input.is_key_pressed(code as Key)

	return Input.is_physical_key_pressed(code as Key)
