use super::binding::modifiers::{COMMAND, SHIFT};
use super::{Binding, Bindings, Input, Kind, Scope, find};
use sc2k_platform::config::{Config, Value};

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

/// Write saved bindings of one action, as the settings file stores them.
fn save(config: &mut Config, id: &str, texts: &[&str]) {
    let values = texts.iter().map(|text| Value::Str(text.to_string())).collect();
    config.set(
        "controls",
        &format!("binding/{id}"),
        Value::Packed("PackedStringArray".into(), values),
    );
}

#[test]
fn version_one_settings_move_budget_off_the_bulldoze_key() {
    let mut config = Config::default();
    save(&mut config, "window_budget", &["key:B"]);
    config.set("controls", "bindings_version", Value::Int(1));
    let loaded = Bindings::load(&config);
    assert_eq!(loaded.for_action("window_budget"), [Binding::key("B", COMMAND)]);
    assert_eq!(loaded.for_action("tool_bulldoze_modifier"), [Binding::key("B", 0)]);

    // a saved action keeps B, and the new action does without it
    save(&mut config, "speed_pause", &["key:B"]);
    let loaded = Bindings::load(&config);
    assert_eq!(loaded.for_action("speed_pause"), [Binding::key("B", 0)]);
    assert!(loaded.for_action("tool_bulldoze_modifier").is_empty());
    assert_eq!(loaded.for_action("tool_center_modifier"), [Binding::key("Alt", 0)]);
}
