//! The JSON writer. The text matches Godot's `JSON.stringify(value, indent, sort_keys)`.

use super::Value;

/// The text of `value`. With an empty `indent`, the text has no line breaks.
/// With `sort_keys`, object keys are in code point order, as Godot's default.
pub fn stringify(value: &Value, indent: &str, sort_keys: bool) -> String {
    let mut output = String::new();
    let style = Style { indent, sort_keys };
    write(&mut output, value, &style, 0);

    output
}

struct Style<'a> {
    indent: &'a str,
    sort_keys: bool,
}

fn write(output: &mut String, value: &Value, style: &Style, level: usize) {
    let indent = style.indent;
    let line_end = if indent.is_empty() { "" } else { "\n" };

    match value {
        Value::Null => output.push_str("null"),
        Value::Bool(value) => output.push_str(if *value { "true" } else { "false" }),
        Value::Int(value) => output.push_str(&value.to_string()),
        Value::Float(value) => output.push_str(&float(*value)),
        Value::String(text) => string(output, text),
        Value::Array(items) => {
            if items.is_empty() {
                output.push_str("[]");

                return;
            }

            output.push('[');
            output.push_str(line_end);

            for (index, item) in items.iter().enumerate() {
                if index > 0 {
                    output.push(',');
                    output.push_str(line_end);
                }

                output.push_str(&indent.repeat(level + 1));
                write(output, item, style, level + 1);
            }

            output.push_str(line_end);
            output.push_str(&indent.repeat(level));
            output.push(']');
        }
        Value::Object(object) => {
            if object.is_empty() {
                output.push_str("{}");

                return;
            }

            output.push('{');
            output.push_str(line_end);

            let mut entries: Vec<&(String, Value)> = object.entries.iter().collect();

            if style.sort_keys {
                entries.sort_by(|a, b| a.0.cmp(&b.0));
            }

            for (index, (key, item)) in entries.into_iter().enumerate() {
                if index > 0 {
                    output.push(',');
                    output.push_str(line_end);
                }

                output.push_str(&indent.repeat(level + 1));
                string(output, key);
                output.push_str(if indent.is_empty() { ":" } else { ": " });
                write(output, item, style, level + 1);
            }

            output.push_str(line_end);
            output.push_str(&indent.repeat(level));
            output.push('}');
        }
    }
}

/// The escapes of Godot's `String.json_escape`.
fn string(output: &mut String, text: &str) {
    output.push('"');

    for character in text.chars() {
        match character {
            '\\' => output.push_str("\\\\"),
            '\u{8}' => output.push_str("\\b"),
            '\u{c}' => output.push_str("\\f"),
            '\n' => output.push_str("\\n"),
            '\r' => output.push_str("\\r"),
            '\t' => output.push_str("\\t"),
            '\u{b}' => output.push_str("\\v"),
            '"' => output.push_str("\\\""),
            other => output.push(other),
        }
    }

    output.push('"');
}

/// A float with 14 significant digits and no trailing zeros, as Godot writes it.
fn float(value: f64) -> String {
    if value == 0.0 {
        return "0.0".into();
    }

    if value.is_nan() {
        return "nan".into();
    }

    if value.is_infinite() {
        return if value > 0.0 { "inf".into() } else { "-inf".into() };
    }

    let magnitude = value.abs().log10().floor() as i32;
    let decimals = (14 - magnitude).max(1) as usize;
    let mut text = format!("{value:.decimals$}");

    if text.contains('.') {
        while text.ends_with('0') {
            text.pop();
        }

        if text.ends_with('.') {
            text.push('0');
        }
    }

    text
}
