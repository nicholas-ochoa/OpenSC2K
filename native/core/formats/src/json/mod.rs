//! JSON values, as the game reads and writes them.
//!
//! The reader follows the Godot JSON parser: every number becomes a `Float`,
//! and object keys keep their first position. `integral` turns floats that hold
//! whole numbers back into integers. The writer makes the text of Godot's
//! `JSON.stringify`: an indent string, `": "` after keys, and no sorting.

mod parse;
mod write;

#[cfg(test)]
mod tests;

pub use parse::{ParseError, parse};
pub use write::stringify;

/// JSON numbers are doubles. Integers above this cannot keep every value.
pub const EXACT_INTEGER_MAX: f64 = 9_007_199_254_740_992.0;

#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Null,
    Bool(bool),
    Int(i64),
    Float(f64),
    String(String),
    Array(Vec<Value>),
    Object(Object),
}

impl Value {
    pub fn as_object(&self) -> Option<&Object> {
        match self {
            Value::Object(object) => Some(object),
            _ => None,
        }
    }

    pub fn as_array(&self) -> Option<&[Value]> {
        match self {
            Value::Array(items) => Some(items),
            _ => None,
        }
    }

    pub fn as_str(&self) -> Option<&str> {
        match self {
            Value::String(text) => Some(text),
            _ => None,
        }
    }

    pub fn as_bool(&self) -> Option<bool> {
        match self {
            Value::Bool(value) => Some(*value),
            _ => None,
        }
    }

    /// The value as a whole number: an integer, or a finite float without a
    /// fraction. This is the integer test of the metadata rules.
    pub fn as_whole(&self) -> Option<f64> {
        match self {
            Value::Int(value) => Some(*value as f64),
            Value::Float(value) if value.is_finite() && *value == value.floor() => Some(*value),
            _ => None,
        }
    }

    /// Whether the value is an integer, or a float without a fraction.
    pub fn is_integral(&self) -> bool {
        match self {
            Value::Int(_) => true,
            Value::Float(value) => *value == value.floor(),
            _ => false,
        }
    }

    /// The value as `i64`, as GDScript `int()` converts it.
    pub fn to_int(&self) -> i64 {
        match self {
            Value::Int(value) => *value,
            Value::Float(value) => *value as i64,
            Value::Bool(value) => i64::from(*value),
            _ => 0,
        }
    }

    /// A copy where each float without a fraction, up to the exact integer
    /// limit, is an integer. A save then writes 3 and not 3.0.
    pub fn integral(&self) -> Value {
        match self {
            Value::Float(value) if *value == value.floor() && value.abs() <= EXACT_INTEGER_MAX => Value::Int(*value as i64),
            Value::Array(items) => Value::Array(items.iter().map(Value::integral).collect()),
            Value::Object(object) => Value::Object(Object {
                entries: object.entries.iter().map(|(key, value)| (key.clone(), value.integral())).collect(),
            }),
            other => other.clone(),
        }
    }
}

/// A JSON object. Keys keep the order of their first insertion.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Object {
    pub entries: Vec<(String, Value)>,
}

impl Object {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn get(&self, key: &str) -> Option<&Value> {
        self.entries.iter().find(|(name, _)| name == key).map(|(_, value)| value)
    }

    pub fn contains(&self, key: &str) -> bool {
        self.get(key).is_some()
    }

    /// Sets `key`. An existing key keeps its position.
    pub fn insert(&mut self, key: &str, value: Value) {
        match self.entries.iter_mut().find(|(name, _)| name == key) {
            Some(entry) => entry.1 = value,
            None => self.entries.push((key.to_string(), value)),
        }
    }

    pub fn keys(&self) -> impl Iterator<Item = &str> {
        self.entries.iter().map(|(key, _)| key.as_str())
    }

    pub fn len(&self) -> usize {
        self.entries.len()
    }

    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }
}
