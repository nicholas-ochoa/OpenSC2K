//! The bindings of every action, as ControlBindings, and their settings.

use super::actions::{self, Kind, Scope};
use super::binding::{Binding, Device, Input};
use sc2k_platform::config::{Config, Value};
use std::collections::HashMap;

const SECTION: &str = "controls";
const PREFIX: &str = "binding/";
const VERSION_KEY: &str = "bindings_version";
const VERSION: i64 = 1;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Bindings {
    pub bindings: HashMap<String, Vec<Binding>>,
}

/// Drag actions share buttons with click and press actions. Modifier actions
/// can share one key, because each changes a different action.
fn kinds_overlap(first: Kind, second: Kind) -> bool {
    if first == Kind::Modifier && second == Kind::Modifier {
        return false;
    }

    (first == Kind::Drag) == (second == Kind::Drag)
}

/// SCURK keys work only in the editor, so they can use city keys again.
fn scopes_overlap(first: Scope, second: Scope) -> bool {
    first == Scope::Anywhere || second == Scope::Anywhere || (first == Scope::Scurk) == (second == Scope::Scurk)
}

impl Bindings {
    pub fn defaults() -> Self {
        let mut result = Self::default();

        for action in actions::actions() {
            result.bindings.insert(
                action.id.clone(),
                action.defaults.iter().filter_map(|text| Binding::from_text(text)).collect(),
            );
        }

        result
    }

    /// The bindings of the settings, over the defaults.
    pub fn load(config: &Config) -> Self {
        let mut result = Self::defaults();

        for id in actions::bindable_ids() {
            let Some(texts) = config.get(SECTION, &format!("{PREFIX}{id}")).and_then(Value::strings) else {
                continue;
            };
            let mut list: Vec<Binding> = Vec::new();

            for binding in texts.iter().filter_map(|text| Binding::from_text(text)) {
                if !list.contains(&binding) {
                    list.push(binding);
                }
            }

            result.bindings.insert(id.to_string(), list);
        }

        result
    }

    /// Write every bindable action to the controls section.
    pub fn store(&self, config: &mut Config) {
        for id in actions::bindable_ids() {
            let texts = self.for_action(id).iter().map(|binding| Value::Str(binding.to_text())).collect();
            config.set(SECTION, &format!("{PREFIX}{id}"), Value::Packed("PackedStringArray".into(), texts));
        }

        config.set(SECTION, VERSION_KEY, Value::Int(VERSION));
    }

    pub fn for_action(&self, id: &str) -> &[Binding] {
        self.bindings.get(id).map_or(&[], Vec::as_slice)
    }

    pub fn add(&mut self, id: &str, binding: Binding) -> bool {
        if actions::find(id).is_none() || self.for_action(id).contains(&binding) {
            return false;
        }

        self.bindings.entry(id.to_string()).or_default().push(binding);

        true
    }

    pub fn remove(&mut self, id: &str, index: usize) {
        if let Some(list) = self.bindings.get_mut(id)
            && index < list.len()
        {
            list.remove(index);
        }
    }

    /// The actions other than `except` that already use `binding`.
    pub fn conflicts(&self, binding: &Binding, except: &str) -> Vec<String> {
        let target = actions::find(except);
        let kind = target.map_or(Kind::Press, |action| action.kind);
        let scope = target.map_or(Scope::Map, |action| action.scope);

        actions::actions()
            .iter()
            .filter(|action| {
                action.id != except
                    && action.scope != Scope::Fixed
                    && kinds_overlap(kind, action.kind)
                    && scopes_overlap(scope, action.scope)
            })
            .filter(|action| self.for_action(&action.id).contains(binding))
            .map(|action| action.id.clone())
            .collect()
    }

    /// The press or hold action of an input, or none. A binding with the exact
    /// modifiers wins over a mouse binding without modifiers and over a held
    /// camera key with Shift down.
    pub fn action_for(&self, input: &Input, kinds: &[Kind], scopes: &[Scope]) -> Option<&'static str> {
        let mut loose = None;

        for action in actions::actions() {
            if !scopes.contains(&action.scope) || !kinds.contains(&action.kind) {
                continue;
            }

            for binding in self.for_action(&action.id) {
                if !binding.matches(input, action.kind == Kind::Hold) {
                    continue;
                }

                if binding.matches(input, false) && (binding.device == Device::Key || binding.modifiers == input.modifiers()) {
                    return Some(action.id.as_str());
                }

                loose = loose.or(Some(action.id.as_str()));
            }
        }

        loose
    }

    /// True when the key of `input` is a key of the action, pressed or released.
    pub fn uses_key(&self, id: &str, input: &Input) -> bool {
        self.for_action(id).iter().any(|binding| binding.matches_key(input))
    }

    pub fn has_mouse_button(&self, id: &str, button: &str) -> bool {
        self.for_action(id)
            .iter()
            .any(|binding| binding.device == Device::Mouse && binding.code == button)
    }

    /// The first key binding, for menu shortcut hints.
    pub fn first_key(&self, id: &str) -> Option<&Binding> {
        self.for_action(id).iter().find(|binding| binding.device == Device::Key)
    }
}
