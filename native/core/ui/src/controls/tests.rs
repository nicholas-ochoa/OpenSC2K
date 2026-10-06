use super::binding::modifiers::{COMMAND, SHIFT};
use super::{Binding, Bindings, Input, Kind, Scope, find};
use sc2k_platform::config::Config;

fn key(name: &str, modifiers: u8) -> Input {
    Input::Key {
        physical: name.into(),
        logical: name.into(),
        pressed: true,
        modifiers,
    }
}

#[test]
fn texts_round_trip() {
    for text in ["key:Command+Shift+S", "mouse:Middle", "key:Kp Add", "key:BracketRight"] {
        assert_eq!(Binding::from_text(text).unwrap().to_text(), text);
    }

    assert!(Binding::from_text("key:Nonsense").is_none());
    assert!(Binding::from_text("pad:A").is_none());
}

#[test]
fn modifiers_must_match_exactly() {
    let bindings = Bindings::defaults();
    let scopes = [Scope::Map, Scope::Global];
    let kinds = [Kind::Press, Kind::Hold];
    assert_eq!(bindings.action_for(&key("Z", 0), &kinds, &scopes), Some("tool_query"));
    assert_eq!(bindings.action_for(&key("Z", COMMAND), &kinds, &scopes), Some("undo"));
    // held camera keys work while Shift is down
    assert_eq!(bindings.action_for(&key("W", SHIFT), &kinds, &scopes), Some("camera_up"));
    let wheel = Input::Mouse {
        button: "WheelUp".into(),
        pressed: true,
        modifiers: SHIFT,
    };
    assert_eq!(bindings.action_for(&wheel, &kinds, &scopes), Some("zoom_in"));
}

#[test]
fn settings_keep_the_bindings() {
    let mut bindings = Bindings::defaults();
    bindings.add("speed_pause", Binding::key("P", 0));
    let mut config = Config::default();
    bindings.store(&mut config);
    let loaded = Bindings::load(&Config::parse(&config.to_text()));
    assert_eq!(loaded.for_action("speed_pause"), bindings.for_action("speed_pause"));
    assert_eq!(
        loaded.conflicts(&Binding::key("P", 0), "tool_bulldozer"),
        vec!["speed_pause".to_string()]
    );
    assert!(find("camera_up").is_some());
}
