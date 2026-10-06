//! Settings files in the text format of Godot's ConfigFile: `[section]` lines,
//! then `key=value` lines. A value is a Godot value literal. The reader keeps
//! the order of sections and keys, and the text of literals it does not know,
//! so a write keeps every setting.

/// A setting value.
#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Bool(bool),
    Int(i64),
    Float(f64),
    Str(String),
    Array(Vec<Value>),
    /// A typed array, such as `Array[int]([1, 2])`: the element type and the items.
    Typed(String, Vec<Value>),
    /// A literal of another type, such as `Vector2i(1, 2)`, kept as text.
    Raw(String),
}

impl Value {
    pub fn as_str(&self) -> Option<&str> {
        match self {
            Value::Str(text) => Some(text),
            _ => None,
        }
    }

    pub fn as_bool(&self) -> Option<bool> {
        match self {
            Value::Bool(value) => Some(*value),
            _ => None,
        }
    }

    pub fn as_f64(&self) -> Option<f64> {
        match self {
            Value::Int(value) => Some(*value as f64),
            Value::Float(value) => Some(*value),
            _ => None,
        }
    }

    pub fn as_i64(&self) -> Option<i64> {
        match self {
            Value::Int(value) => Some(*value),
            Value::Float(value) if value.fract() == 0.0 => Some(*value as i64),
            _ => None,
        }
    }

    /// The literal text of the value.
    pub fn literal(&self) -> String {
        match self {
            Value::Bool(value) => value.to_string(),
            Value::Int(value) => value.to_string(),
            Value::Float(value) => float_literal(*value),
            Value::Str(text) => format!("\"{}\"", text.replace('\\', "\\\\").replace('"', "\\\"")),
            Value::Array(items) => format!(
                "[{}]",
                items
                    .iter()
                    .map(Value::literal)
                    .collect::<Vec<_>>()
                    .join(", ")
            ),
            Value::Typed(kind, items) => {
                format!("Array[{kind}]({})", Value::Array(items.clone()).literal())
            }
            Value::Raw(text) => text.clone(),
        }
    }
}

/// A float as Godot writes it: a whole number keeps ".0".
fn float_literal(value: f64) -> String {
    if value.fract() == 0.0 && value.abs() < 1e15 {
        format!("{value:.1}")
    } else {
        value.to_string()
    }
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Config {
    pub sections: Vec<(String, Vec<(String, Value)>)>,
}

impl Config {
    pub fn get(&self, section: &str, key: &str) -> Option<&Value> {
        self.sections
            .iter()
            .find(|(name, _)| name == section)
            .and_then(|(_, entries)| entries.iter().find(|(name, _)| name == key))
            .map(|(_, value)| value)
    }

    pub fn string(&self, section: &str, key: &str, default: &str) -> String {
        self.get(section, key)
            .and_then(Value::as_str)
            .unwrap_or(default)
            .to_string()
    }

    pub fn bool(&self, section: &str, key: &str, default: bool) -> bool {
        self.get(section, key)
            .and_then(Value::as_bool)
            .unwrap_or(default)
    }

    pub fn float(&self, section: &str, key: &str, default: f64) -> f64 {
        self.get(section, key)
            .and_then(Value::as_f64)
            .unwrap_or(default)
    }

    pub fn int(&self, section: &str, key: &str, default: i64) -> i64 {
        self.get(section, key)
            .and_then(Value::as_i64)
            .unwrap_or(default)
    }

    /// Set a value. A new section or key comes last.
    pub fn set(&mut self, section: &str, key: &str, value: Value) {
        let index = match self.sections.iter().position(|(name, _)| name == section) {
            Some(index) => index,
            None => {
                self.sections.push((section.to_string(), Vec::new()));
                self.sections.len() - 1
            }
        };
        let entries = &mut self.sections[index].1;

        match entries.iter_mut().find(|(name, _)| name == key) {
            Some(slot) => slot.1 = value,
            None => entries.push((key.to_string(), value)),
        }
    }

    pub fn parse(text: &str) -> Self {
        let mut config = Config::default();
        let mut section = String::new();
        let mut lines = text.lines().peekable();

        while let Some(line) = lines.next() {
            let line = line.trim();

            if line.is_empty() || line.starts_with(';') {
                continue;
            }

            if let Some(name) = line
                .strip_prefix('[')
                .and_then(|rest| rest.strip_suffix(']'))
            {
                section = name.to_string();

                if !config.sections.iter().any(|(known, _)| *known == section) {
                    config.sections.push((section.clone(), Vec::new()));
                }

                continue;
            }

            let Some((key, value)) = line.split_once('=') else {
                continue;
            };

            // a string or a bracketed literal can span lines
            let mut literal = value.to_string();

            while !complete(&literal) {
                let Some(next) = lines.next() else {
                    break;
                };

                literal.push('\n');
                literal.push_str(next);
            }

            config.set(&section, key.trim(), parse_value(literal.trim()));
        }

        config
    }

    pub fn to_text(&self) -> String {
        let mut text = String::new();

        for (index, (name, entries)) in self.sections.iter().enumerate() {
            if index > 0 {
                text.push('\n');
            }

            text.push_str(&format!("[{name}]\n\n"));

            for (key, value) in entries {
                text.push_str(&format!("{key}={}\n", value.literal()));
            }
        }

        text
    }
}

/// True when the quotes and brackets of a literal close.
fn complete(literal: &str) -> bool {
    let mut depth = 0_i32;
    let mut quoted = false;
    let mut escaped = false;

    for character in literal.chars() {
        if quoted {
            match character {
                _ if escaped => escaped = false,
                '\\' => escaped = true,
                '"' => quoted = false,
                _ => {}
            }

            continue;
        }

        match character {
            '"' => quoted = true,
            '[' | '(' | '{' => depth += 1,
            ']' | ')' | '}' => depth -= 1,
            _ => {}
        }
    }

    !quoted && depth <= 0
}

fn parse_value(literal: &str) -> Value {
    match literal {
        "true" => return Value::Bool(true),
        "false" => return Value::Bool(false),
        _ => {}
    }

    if let Some(inner) = literal
        .strip_prefix('"')
        .and_then(|rest| rest.strip_suffix('"'))
    {
        return Value::Str(unescape(inner));
    }

    if let Ok(value) = literal.parse::<i64>() {
        return Value::Int(value);
    }

    if literal.starts_with(|c: char| c.is_ascii_digit() || c == '-' || c == '.')
        && let Ok(value) = literal.parse::<f64>()
    {
        return Value::Float(value);
    }

    if let Some((kind, rest)) = literal
        .strip_prefix("Array[")
        .and_then(|rest| rest.split_once("]("))
        && let Some(Value::Array(items)) = rest.strip_suffix(')').map(parse_value)
    {
        return Value::Typed(kind.to_string(), items);
    }

    if let Some(inner) = literal
        .strip_prefix('[')
        .and_then(|rest| rest.strip_suffix(']'))
    {
        return Value::Array(
            split_items(inner)
                .iter()
                .map(|item| parse_value(item))
                .collect(),
        );
    }

    Value::Raw(literal.to_string())
}

fn unescape(text: &str) -> String {
    let mut result = String::new();
    let mut characters = text.chars();

    while let Some(character) = characters.next() {
        if character != '\\' {
            result.push(character);
            continue;
        }

        match characters.next() {
            Some('n') => result.push('\n'),
            Some('t') => result.push('\t'),
            Some(other) => result.push(other),
            None => {}
        }
    }

    result
}

/// The items of an array literal, split at commas outside quotes and brackets.
fn split_items(inner: &str) -> Vec<String> {
    let mut items = Vec::new();
    let mut current = String::new();
    let mut depth = 0;
    let mut quoted = false;
    let mut escaped = false;

    for character in inner.chars() {
        if quoted {
            current.push(character);

            match character {
                _ if escaped => escaped = false,
                '\\' => escaped = true,
                '"' => quoted = false,
                _ => {}
            }

            continue;
        }

        match character {
            '"' => quoted = true,
            '[' | '(' | '{' => depth += 1,
            ']' | ')' | '}' => depth -= 1,
            ',' if depth == 0 => {
                items.push(current.trim().to_string());
                current.clear();
                continue;
            }
            _ => {}
        }

        current.push(character);
    }

    if !current.trim().is_empty() {
        items.push(current.trim().to_string());
    }

    items
}

#[cfg(test)]
mod tests {
    use super::{Config, Value};

    const TEXT: &str = "[graphics]\n\nhd_effects=0\nsource=\"folder\"\nzoom_graphics=Array[int]([1, 2, 2])\n\n[audio]\n\nmusic_volume=0.18\nshuffle=true\nwindow=Vector2i(3, 4)\n";

    #[test]
    fn settings_keep_their_values_and_order() {
        let config = Config::parse(TEXT);
        assert_eq!(config.string("graphics", "source", ""), "folder");
        assert_eq!(
            config.get("graphics", "zoom_graphics"),
            Some(&Value::Typed(
                "int".into(),
                vec![Value::Int(1), Value::Int(2), Value::Int(2)]
            ))
        );
        assert!(
            config
                .to_text()
                .contains("zoom_graphics=Array[int]([1, 2, 2])")
        );
        assert_eq!(config.float("audio", "music_volume", 0.0), 0.18);
        assert!(config.bool("audio", "shuffle", false));
        assert_eq!(
            config.get("audio", "window"),
            Some(&Value::Raw("Vector2i(3, 4)".into()))
        );
        let again = Config::parse(&config.to_text());
        assert_eq!(again.sections.len(), 2);
        assert_eq!(again.get("audio", "window"), config.get("audio", "window"));
    }

    #[test]
    fn strings_escape_quotes() {
        let mut config = Config::default();
        config.set("general", "name", Value::Str("a \"b\" \\ c".into()));
        assert_eq!(
            Config::parse(&config.to_text()).string("general", "name", ""),
            "a \"b\" \\ c"
        );
    }
}
