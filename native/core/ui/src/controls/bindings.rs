//! The bindings of every action, as ControlBindings, and their settings.

use super::actions::{self, Kind, Scope};
use super::binding::{Binding, Device, Input};
use sc2k_platform::config::{Config, Value};
use std::collections::HashMap;

const SECTION: &str = "controls";
const PREFIX: &str = "binding/";
const VERSION_KEY: &str = "bindings_version";
const VERSION: i64 = 2;
/// Version 2 moves Budget to Command+B, the Ctrl+B of the original menu, so
/// that a held B can bulldoze.
const BUDGET_VERSION: i64 = 2;
const BUDGET_ID: &str = "window_budget";
const BUDGET_KEY: &str = "key:B";
const NEW_BUDGET_KEY: &str = "key:Command+B";

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

        if config.int(SECTION, VERSION_KEY, 0) < BUDGET_VERSION {
            result.migrate_budget_key();
        }

        result.drop_used_defaults(config);

        result
    }

    /// Earlier versions opened the budget with B. The new key moves across
    /// only when no other action uses it.
    fn migrate_budget_key(&mut self) {
        let (Some(old_key), Some(new_key)) = (Binding::from_text(BUDGET_KEY), Binding::from_text(NEW_BUDGET_KEY)) else {
            return;
        };

        let Some(list) = self.bindings.get_mut(BUDGET_ID) else {
            return;
        };

        if !list.contains(&old_key) {
            return;
        }

        list.retain(|binding| *binding != old_key);

        if self.conflicts(&new_key, BUDGET_ID).is_empty() {
            self.add(BUDGET_ID, new_key);
        }
    }

    /// An action that the settings do not list yet, such as a new action,
    /// keeps only the default bindings that no saved action uses.
    fn drop_used_defaults(&mut self, config: &Config) {
        if !config.sections.iter().any(|(name, _)| name == SECTION) {
            return;
        }

        for id in actions::bindable_ids() {
            if config.get(SECTION, &format!("{PREFIX}{id}")).is_some() {
                continue;
            }

            let used: Vec<Binding> = self
                .for_action(id)
                .iter()
                .filter(|binding| !self.conflicts(binding, id).is_empty())
                .cloned()
                .collect();

            if let Some(list) = self.bindings.get_mut(id) {
                list.retain(|binding| !used.contains(binding));
            }
        }
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
