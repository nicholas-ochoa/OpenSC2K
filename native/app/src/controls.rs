//! Window events in the terms of the control bindings: the Godot key names of
//! physical keys and mouse buttons, and the modifier bits.

use sc2k_ui::controls::{Input, modifier_bits};
use winit::event::{ElementState, KeyEvent, MouseButton};
use winit::keyboard::{Key, KeyCode, ModifiersState, NamedKey, PhysicalKey};

/// The binding name of a physical key, by its position on a US keyboard.
#[rustfmt::skip]
pub fn key_name(code: KeyCode) -> Option<&'static str> {
    use KeyCode::*;

    Some(match code {
        KeyA => "A", KeyB => "B", KeyC => "C", KeyD => "D", KeyE => "E", KeyF => "F", KeyG => "G", KeyH => "H", KeyI => "I", KeyJ => "J",
        KeyK => "K", KeyL => "L", KeyM => "M", KeyN => "N", KeyO => "O", KeyP => "P", KeyQ => "Q", KeyR => "R", KeyS => "S", KeyT => "T",
        KeyU => "U", KeyV => "V", KeyW => "W", KeyX => "X", KeyY => "Y", KeyZ => "Z",
        Digit0 => "0", Digit1 => "1", Digit2 => "2", Digit3 => "3", Digit4 => "4", Digit5 => "5", Digit6 => "6", Digit7 => "7", Digit8 => "8",
        Digit9 => "9",
        F1 => "F1", F2 => "F2", F3 => "F3", F4 => "F4", F5 => "F5", F6 => "F6", F7 => "F7", F8 => "F8", F9 => "F9", F10 => "F10", F11 => "F11",
        F12 => "F12",
        Escape => "Escape", Tab => "Tab", Backspace => "Backspace", Enter => "Enter", NumpadEnter => "Kp Enter", Insert => "Insert",
        Delete => "Delete", Pause => "Pause", Home => "Home", End => "End", ArrowLeft => "Left", ArrowUp => "Up", ArrowRight => "Right",
        ArrowDown => "Down", PageUp => "PageUp", PageDown => "PageDown", ShiftLeft | ShiftRight => "Shift", ControlLeft | ControlRight => "Ctrl",
        SuperLeft | SuperRight => "Meta", AltLeft | AltRight => "Alt", CapsLock => "CapsLock", Space => "Space", Minus => "Minus",
        Equal => "Equal", BracketLeft => "BracketLeft", BracketRight => "BracketRight", Backslash => "BackSlash", Semicolon => "Semicolon",
        Quote => "Apostrophe", Backquote => "QuoteLeft", Comma => "Comma", Period => "Period", Slash => "Slash", NumpadAdd => "Kp Add",
        NumpadSubtract => "Kp Subtract", NumpadMultiply => "Kp Multiply", NumpadDivide => "Kp Divide", NumpadDecimal => "Kp Period",
        Numpad0 => "Kp 0", Numpad1 => "Kp 1", Numpad2 => "Kp 2", Numpad3 => "Kp 3", Numpad4 => "Kp 4", Numpad5 => "Kp 5", Numpad6 => "Kp 6",
        Numpad7 => "Kp 7", Numpad8 => "Kp 8", Numpad9 => "Kp 9",
        MediaPlayPause => "MediaPlay", MediaTrackNext => "MediaNext", MediaTrackPrevious => "MediaPrevious", MediaStop => "MediaStop",
        _ => return None,
    })
}

/// The binding name of the key that the layout prints, for symbol keys.
fn logical_name(key: &Key) -> String {
    match key {
        Key::Character(text) => match text.as_str() {
            "+" => "Plus".into(),
            "=" => "Equal".into(),
            "-" => "Minus".into(),
            "[" => "BracketLeft".into(),
            "]" => "BracketRight".into(),
            "\\" => "BackSlash".into(),
            ";" => "Semicolon".into(),
            "'" => "Apostrophe".into(),
            "`" => "QuoteLeft".into(),
            "," => "Comma".into(),
            "." => "Period".into(),
            "/" => "Slash".into(),
            other => other.to_uppercase(),
        },
        Key::Named(NamedKey::Space) => "Space".into(),
        _ => String::new(),
    }
}

pub fn modifiers(state: ModifiersState) -> u8 {
    modifier_bits(state.shift_key(), state.alt_key(), state.control_key(), state.super_key(), false)
}

/// The binding input of a key event, or none for a key without a name.
pub fn key_input(event: &KeyEvent, state: ModifiersState) -> Option<Input> {
    let PhysicalKey::Code(code) = event.physical_key else {
        return None;
    };

    Some(Input::Key {
        physical: key_name(code)?.into(),
        logical: logical_name(&event.logical_key),
        pressed: event.state == ElementState::Pressed,
        modifiers: modifiers(state),
    })
}

pub fn mouse_input(button: MouseButton, pressed: bool, state: ModifiersState) -> Option<Input> {
    let name = match button {
        MouseButton::Left => "Left",
        MouseButton::Right => "Right",
        MouseButton::Middle => "Middle",
        MouseButton::Back => "Extra1",
        MouseButton::Forward => "Extra2",
        MouseButton::Other(_) => return None,
    };

    Some(Input::Mouse {
        button: name.into(),
        pressed,
        modifiers: modifiers(state),
    })
}

/// A wheel step as a button press.
pub fn wheel_input(up: bool, state: ModifiersState) -> Input {
    Input::Mouse {
        button: if up { "WheelUp" } else { "WheelDown" }.into(),
        pressed: true,
        modifiers: modifiers(state),
    }
}

/// The id of a held key for the camera motion.
pub fn key_id(event: &KeyEvent) -> i64 {
    match event.physical_key {
        PhysicalKey::Code(code) => code as i64,
        PhysicalKey::Unidentified(_) => -1,
    }
}
