//! One key or mouse button with its modifier keys. Keys use their Godot names,
//! by physical key position, so a binding stays on one key in every layout.

/// Modifier bits. Command is Cmd on macOS and Ctrl elsewhere; Control is the
/// separate Ctrl key of macOS.
pub mod modifiers {
    pub const SHIFT: u8 = 1;
    pub const ALT: u8 = 2;
    pub const COMMAND: u8 = 4;
    pub const CONTROL: u8 = 8;
}

use modifiers::{ALT, COMMAND, CONTROL, SHIFT};

const MODIFIER_NAMES: [(u8, &str); 4] = [(COMMAND, "Command"), (CONTROL, "Ctrl"), (ALT, "Alt"), (SHIFT, "Shift")];
pub const MOUSE_NAMES: [&str; 9] = [
    "Left",
    "Right",
    "Middle",
    "WheelUp",
    "WheelDown",
    "WheelLeft",
    "WheelRight",
    "Extra1",
    "Extra2",
];
const MOUSE_LABELS: [&str; 9] = [
    "Left button",
    "Right button",
    "Middle button",
    "Wheel up",
    "Wheel down",
    "Wheel left",
    "Wheel right",
    "Mouse 4",
    "Mouse 5",
];
/// The key names that bindings can use, as Godot names keys.
pub const KEY_NAMES: [&str; 97] = [
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z",
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "F1",
    "F2",
    "F3",
    "F4",
    "F5",
    "F6",
    "F7",
    "F8",
    "F9",
    "F10",
    "F11",
    "F12",
    "Escape",
    "Tab",
    "Backspace",
    "Enter",
    "Kp Enter",
    "Insert",
    "Delete",
    "Pause",
    "Home",
    "End",
    "Left",
    "Up",
    "Right",
    "Down",
    "PageUp",
    "PageDown",
    "Shift",
    "Ctrl",
    "Meta",
    "Alt",
    "CapsLock",
    "Space",
    "Minus",
    "Equal",
    "Plus",
    "BracketLeft",
    "BracketRight",
    "BackSlash",
    "Semicolon",
    "Apostrophe",
    "QuoteLeft",
    "Comma",
    "Period",
    "Slash",
    "Kp Add",
    "Kp Subtract",
    "Kp Multiply",
    "Kp Divide",
    "Kp Period",
    "Kp 0",
    "Kp 1",
    "Kp 2",
    "Kp 3",
    "Kp 4",
    "Kp 5",
    "Kp 6",
    "Kp 7",
    "Kp 8",
    "Kp 9",
];
/// The text of keys whose name is a word, for the binding chips.
const KEY_SYMBOLS: [(&str, &str); 16] = [
    ("Minus", "-"),
    ("Equal", "="),
    ("Plus", "+"),
    ("BracketLeft", "["),
    ("BracketRight", "]"),
    ("BackSlash", "\\"),
    ("Semicolon", ";"),
    ("Apostrophe", "'"),
    ("QuoteLeft", "`"),
    ("Comma", ","),
    ("Period", "."),
    ("Slash", "/"),
    ("Up", "↑"),
    ("Down", "↓"),
    ("Left", "←"),
    ("Right", "→"),
];
const MODIFIER_KEYS: [(&str, u8); 4] = [("Shift", SHIFT), ("Alt", ALT), ("Meta", COMMAND), ("Ctrl", COMMAND)];

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Device {
    Key,
    Mouse,
}

/// One input event, in the terms of the bindings.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Input {
    /// A key: its physical key name, the name of the key that the layout
    /// prints, whether it went down, and the modifier bits.
    Key {
        physical: String,
        logical: String,
        pressed: bool,
        modifiers: u8,
    },
    /// A mouse button or wheel step, by its name in `MOUSE_NAMES`.
    Mouse { button: String, pressed: bool, modifiers: u8 },
}

impl Input {
    pub fn modifiers(&self) -> u8 {
        match self {
            Input::Key { modifiers, .. } | Input::Mouse { modifiers, .. } => *modifiers,
        }
    }

    pub fn pressed(&self) -> bool {
        match self {
            Input::Key { pressed, .. } | Input::Mouse { pressed, .. } => *pressed,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct Binding {
    pub device: Device,
    /// The key name, or the mouse button name.
    pub code: String,
    pub modifiers: u8,
}

/// The modifier bits of held keys. `any_command` reads Ctrl and Cmd as Command
/// on every system, as the SCURK editor keys always have.
pub fn modifier_bits(shift: bool, alt: bool, control: bool, meta: bool, any_command: bool) -> u8 {
    let mut bits = 0;

    if shift {
        bits |= SHIFT;
    }

    if alt {
        bits |= ALT;
    }

    if any_command {
        if control || meta {
            bits |= COMMAND;
        }
    } else if cfg!(target_os = "macos") {
        if meta {
            bits |= COMMAND;
        }

        if control {
            bits |= CONTROL;
        }
    } else if control {
        bits |= COMMAND;
    }

    bits
}

fn is_letter_or_digit(name: &str) -> bool {
    name.len() == 1 && name.chars().all(|c| c.is_ascii_alphanumeric())
}

/// Printable symbol keys also match the key that the layout prints, so "+"
/// and "=" work on layouts that put them on other physical keys.
fn is_symbol(name: &str) -> bool {
    KEY_SYMBOLS.iter().take(12).any(|(key, _)| *key == name)
}

impl Binding {
    pub fn key(name: &str, modifiers: u8) -> Self {
        Self {
            device: Device::Key,
            code: name.into(),
            modifiers,
        }
    }

    pub fn mouse(name: &str, modifiers: u8) -> Self {
        Self {
            device: Device::Mouse,
            code: name.into(),
            modifiers,
        }
    }

    /// The binding of a settings text such as "key:Command+S" or "mouse:Middle".
    pub fn from_text(text: &str) -> Option<Self> {
        let (device, rest) = text.trim().split_once(':')?;
        let names: Vec<&str> = rest.split('+').collect();
        let (name, modifier_names) = names.split_last()?;
        let mut modifiers = 0;

        for modifier in modifier_names {
            let (bit, _) = MODIFIER_NAMES.iter().find(|(_, known)| known == modifier)?;

            // Ctrl is the Command key on systems other than macOS
            modifiers |= if *bit == CONTROL && !cfg!(target_os = "macos") {
                COMMAND
            } else {
                *bit
            };
        }

        match device {
            "mouse" if MOUSE_NAMES.contains(name) => Some(Self::mouse(name, modifiers)),
            "key" if KEY_NAMES.contains(name) => Some(Self::key(name, modifiers)),
            _ => None,
        }
    }

    /// The binding of a key or button press, or none for a release.
    pub fn from_input(input: &Input) -> Option<Self> {
        match input {
            Input::Key {
                physical,
                pressed: true,
                modifiers,
                ..
            } if KEY_NAMES.contains(&physical.as_str()) => {
                let own = MODIFIER_KEYS.iter().find(|(key, _)| key == physical).map_or(0, |(_, bit)| *bit);

                Some(Self::key(physical, modifiers & !own))
            }
            Input::Mouse {
                button,
                pressed: true,
                modifiers,
            } if MOUSE_NAMES.contains(&button.as_str()) => Some(Self::mouse(button, *modifiers)),
            _ => None,
        }
    }

    pub fn to_text(&self) -> String {
        let mut text = String::from(if self.device == Device::Mouse { "mouse:" } else { "key:" });

        for (bit, name) in MODIFIER_NAMES {
            if self.modifiers & bit != 0 {
                text.push_str(name);
                text.push('+');
            }
        }

        text + &self.code
    }

    pub fn is_modifier_key(&self) -> bool {
        self.device == Device::Key && MODIFIER_KEYS.iter().any(|(key, _)| *key == self.code)
    }

    /// True when `input` is this key, pressed or released, without a check of modifiers.
    pub fn matches_key(&self, input: &Input) -> bool {
        match input {
            Input::Key { physical, logical, .. } => {
                self.device == Device::Key && (*physical == self.code || (is_symbol(&self.code) && *logical == self.code))
            }
            Input::Mouse { .. } => false,
        }
    }

    /// Modifiers match exactly, so Z does not start when Command+Z is down.
    /// `ignore_shift` lets held camera keys work while Shift is down. A mouse
    /// binding without modifiers matches the button with any modifiers.
    pub fn matches(&self, input: &Input, ignore_shift: bool) -> bool {
        let mut held = input.modifiers();

        match (self.device, input) {
            (Device::Key, Input::Key { .. }) => {
                if !self.matches_key(input) {
                    return false;
                }

                held &= !MODIFIER_KEYS.iter().find(|(key, _)| *key == self.code).map_or(0, |(_, bit)| *bit);

                // on macOS the Ctrl key reports the Control bit, not Command
                if self.code == "Ctrl" {
                    held &= !CONTROL;
                }
            }
            (Device::Mouse, Input::Mouse { button, .. }) => {
                if *button != self.code {
                    return false;
                }

                if self.modifiers == 0 {
                    return true;
                }
            }
            _ => return false,
        }

        if ignore_shift && self.modifiers & SHIFT == 0 {
            held &= !SHIFT;
        }

        held == self.modifiers
    }

    /// The chip text: macOS symbols or names joined with "+", then the key.
    pub fn display_text(&self) -> String {
        let mac = cfg!(target_os = "macos");
        let mut text = String::new();

        for (bit, symbol, name) in [
            (CONTROL, "⌃", ""),
            (ALT, "⌥", "Alt+"),
            (SHIFT, "⇧", "Shift+"),
            (COMMAND, "⌘", "Ctrl+"),
        ] {
            if self.modifiers & bit != 0 {
                text.push_str(if mac { symbol } else { name });
            }
        }

        if self.device == Device::Mouse {
            let index = MOUSE_NAMES.iter().position(|name| *name == self.code).unwrap_or(0);

            return text + MOUSE_LABELS[index];
        }

        let key = KEY_SYMBOLS
            .iter()
            .find(|(name, _)| *name == self.code)
            .map_or(self.code.as_str(), |(_, symbol)| symbol);

        if !is_letter_or_digit(key) && key.starts_with("Kp ") {
            return text + "Keypad " + &key[3..];
        }

        text + key
    }
}
