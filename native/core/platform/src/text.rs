//! Text rules that the engine scripts share.

use sc2k_formats::json::{self, Value};

/// The text without leading and trailing whitespace and control characters,
/// as Godot's `strip_edges`.
pub fn strip_edges(text: &str) -> &str {
    text.trim_matches(|character: char| character <= ' ')
}

/// True for an optional sign and one or more digits, as Godot's `is_valid_int`.
pub fn is_valid_int(text: &str) -> bool {
    let digits = text.strip_prefix(['+', '-']).unwrap_or(text);

    !digits.is_empty() && digits.bytes().all(|byte| byte.is_ascii_digit())
}

/// A JSON value as Godot's `str`: a whole float keeps ".0", as the engine
/// parses every JSON number as a float.
pub fn display(value: &Value) -> String {
    match value {
        Value::Null => "<null>".into(),
        Value::Bool(flag) => flag.to_string(),
        Value::Int(number) => format!("{number}.0"),
        Value::Float(number) if number.is_finite() && *number == number.floor() && number.abs() < 1e15 => {
            format!("{number:.1}")
        }
        Value::Float(number) => number.to_string(),
        Value::String(text) => text.clone(),
        other => json::stringify(other, "", false),
    }
}
