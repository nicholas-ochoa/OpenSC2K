//! Reading the fields of result values. Day phases return their results as
//! values; the speed controller collects their events.

use sc2k_sim::sim::value::Value;

/// The field `name` of an object or dictionary.
pub fn field<'a>(value: &'a Value, name: &str) -> Option<&'a Value> {
    match value {
        Value::Object(_, fields) => fields.iter().find(|(key, _)| *key == name).map(|(_, value)| value),
        Value::Dict(entries) => entries
            .iter()
            .find(|(key, _)| matches!(key, Value::Str(text) if text == name))
            .map(|(_, value)| value),
        _ => None,
    }
}

/// The items of an array field, or none.
pub fn items(value: &Value, name: &str) -> Vec<Value> {
    match field(value, name) {
        Some(Value::Array(items)) => items.clone(),
        _ => Vec::new(),
    }
}

pub fn boolean(value: &Value, name: &str) -> bool {
    matches!(field(value, name), Some(Value::Bool(true)))
}

pub fn int(value: &Value, name: &str, fallback: i64) -> i64 {
    match field(value, name) {
        Some(Value::Int(number)) => *number,
        _ => fallback,
    }
}

pub fn text(value: &Value, name: &str) -> String {
    match field(value, name) {
        Some(Value::Str(text)) => text.clone(),
        _ => String::new(),
    }
}

/// The strings of a string array field.
pub fn strings(value: &Value, name: &str) -> Vec<String> {
    match field(value, name) {
        Some(Value::Strings(items)) => items.clone(),
        Some(Value::Array(items)) => items
            .iter()
            .filter_map(|item| match item {
                Value::Str(text) => Some(text.clone()),
                _ => None,
            })
            .collect(),
        _ => Vec::new(),
    }
}

/// The integers of an int array field.
pub fn ints(value: &Value, name: &str) -> Vec<i32> {
    match field(value, name) {
        Some(Value::Ints32(items)) => items.clone(),
        Some(Value::Ints64(items)) => items.iter().map(|item| *item as i32).collect(),
        _ => Vec::new(),
    }
}

/// The class name of an object value.
pub fn class(value: &Value) -> &str {
    match value {
        Value::Object(name, _) => name,
        _ => "",
    }
}

/// Set `name` of an object, or add it at the end.
pub fn set(value: &mut Value, name: &'static str, new: Value) {
    if let Value::Object(_, fields) = value {
        match fields.iter_mut().find(|(key, _)| *key == name) {
            Some(slot) => slot.1 = new,
            None => fields.push((name, new)),
        }
    }
}
