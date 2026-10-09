//! The value tree of a project record.

use sc2k_formats::json::{Object, Value};

#[derive(Clone, Debug, PartialEq)]
pub enum Node {
    Null,
    Bool(bool),
    Int(i64),
    Float(f64),
    Str(String),
    Array(Vec<Node>),
    /// Entries keep their insertion order, as a script dictionary.
    Object(Vec<(String, Node)>),
    Bytes(Vec<u8>),
    Pixels(Vec<i32>),
}

impl Node {
    pub fn empty_object() -> Self {
        Node::Object(Vec::new())
    }

    pub fn get(&self, key: &str) -> Option<&Node> {
        match self {
            Node::Object(entries) => entries.iter().find(|(name, _)| name == key).map(|(_, value)| value),
            _ => None,
        }
    }

    pub fn get_mut(&mut self, key: &str) -> Option<&mut Node> {
        match self {
            Node::Object(entries) => entries.iter_mut().find(|(name, _)| name == key).map(|(_, value)| value),
            _ => None,
        }
    }

    /// Set `key`. An existing key keeps its position; a new key comes last.
    pub fn set(&mut self, key: &str, value: Node) {
        if let Node::Object(entries) = self {
            match entries.iter_mut().find(|(name, _)| name == key) {
                Some(slot) => slot.1 = value,
                None => entries.push((key.to_string(), value)),
            }
        }
    }

    pub fn keys(&self) -> Vec<String> {
        match self {
            Node::Object(entries) => entries.iter().map(|(name, _)| name.clone()).collect(),
            _ => Vec::new(),
        }
    }

    pub fn is_object(&self) -> bool {
        matches!(self, Node::Object(_))
    }

    pub fn as_str(&self) -> Option<&str> {
        match self {
            Node::Str(text) => Some(text),
            _ => None,
        }
    }

    pub fn as_bytes(&self) -> &[u8] {
        match self {
            Node::Bytes(bytes) => bytes,
            _ => &[],
        }
    }

    pub fn as_pixels(&self) -> &[i32] {
        match self {
            Node::Pixels(pixels) => pixels,
            _ => &[],
        }
    }

    /// The number of entries of an object or an array.
    pub fn len(&self) -> usize {
        match self {
            Node::Object(entries) => entries.len(),
            Node::Array(items) => items.len(),
            _ => 0,
        }
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// The script `int()` of a number: floats truncate toward zero.
    pub fn to_int(&self) -> i64 {
        match self {
            Node::Int(value) => *value,
            Node::Float(value) => *value as i64,
            Node::Bool(value) => i64::from(*value),
            _ => 0,
        }
    }

    pub fn from_json(value: &Value) -> Self {
        match value {
            Value::Null => Node::Null,
            Value::Bool(value) => Node::Bool(*value),
            Value::Int(value) => Node::Int(*value),
            Value::Float(value) => Node::Float(*value),
            Value::String(text) => Node::Str(text.clone()),
            Value::Array(items) => Node::Array(items.iter().map(Node::from_json).collect()),
            Value::Object(object) => Node::Object(
                object
                    .entries
                    .iter()
                    .map(|(key, item)| (key.clone(), Node::from_json(item)))
                    .collect(),
            ),
        }
    }

    /// The JSON value. Byte and pixel arrays have no JSON form; they become null.
    pub fn to_json(&self) -> Value {
        match self {
            Node::Null | Node::Bytes(_) | Node::Pixels(_) => Value::Null,
            Node::Bool(value) => Value::Bool(*value),
            Node::Int(value) => Value::Int(*value),
            Node::Float(value) => Value::Float(*value),
            Node::Str(text) => Value::String(text.clone()),
            Node::Array(items) => Value::Array(items.iter().map(Node::to_json).collect()),
            Node::Object(entries) => {
                let mut object = Object::new();

                for (key, item) in entries {
                    object.insert(key, item.to_json());
                }

                Value::Object(object)
            }
        }
    }
}
