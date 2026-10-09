//! Result values that cross to GDScript.
//!
//! A `Value::Object` names a GDScript class. The bridge sends it as a Dictionary
//! with a `__class` key, and GDScript builds that object and sets each field.

use super::geom::{Rect2i, Vec2i};

#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Nil,
    Bool(bool),
    Int(i64),
    Float(f64),
    Str(String),
    Vec2i(Vec2i),
    Rect2i(Rect2i),
    Bytes(Vec<u8>),
    Ints32(Vec<i32>),
    Ints64(Vec<i64>),
    Strings(Vec<String>),
    Array(Vec<Value>),
    /// An ordered Dictionary. GDScript keeps insertion order.
    Dict(Vec<(Value, Value)>),
    Object(&'static str, Vec<(&'static str, Value)>),
}

pub trait ToValue {
    fn to_value(&self) -> Value;
}

impl ToValue for Value {
    fn to_value(&self) -> Value {
        self.clone()
    }
}

impl ToValue for bool {
    fn to_value(&self) -> Value {
        Value::Bool(*self)
    }
}

impl ToValue for i64 {
    fn to_value(&self) -> Value {
        Value::Int(*self)
    }
}

impl ToValue for f64 {
    fn to_value(&self) -> Value {
        Value::Float(*self)
    }
}

impl ToValue for String {
    fn to_value(&self) -> Value {
        Value::Str(self.clone())
    }
}

impl ToValue for Vec2i {
    fn to_value(&self) -> Value {
        Value::Vec2i(*self)
    }
}

impl ToValue for Rect2i {
    fn to_value(&self) -> Value {
        Value::Rect2i(*self)
    }
}

impl<T: ToValue> ToValue for Vec<T> {
    fn to_value(&self) -> Value {
        Value::Array(self.iter().map(ToValue::to_value).collect())
    }
}

impl<T: ToValue> ToValue for Box<T> {
    fn to_value(&self) -> Value {
        (**self).to_value()
    }
}

impl<T: ToValue> ToValue for Option<T> {
    fn to_value(&self) -> Value {
        match self {
            Some(value) => value.to_value(),
            None => Value::Nil,
        }
    }
}

/// PackedInt32Array fields.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Ints32(pub Vec<i32>);

impl ToValue for Ints32 {
    fn to_value(&self) -> Value {
        Value::Ints32(self.0.clone())
    }
}

/// PackedInt64Array fields.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Ints64(pub Vec<i64>);

impl ToValue for Ints64 {
    fn to_value(&self) -> Value {
        Value::Ints64(self.0.clone())
    }
}

/// PackedStringArray fields.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Strings(pub Vec<String>);

impl ToValue for Strings {
    fn to_value(&self) -> Value {
        Value::Strings(self.0.clone())
    }
}

/// PackedByteArray fields.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Bytes(pub Vec<u8>);

impl ToValue for Bytes {
    fn to_value(&self) -> Value {
        Value::Bytes(self.0.clone())
    }
}

/// An ordered Dictionary with string keys, such as Dictionary[String, int].
#[derive(Clone, Debug, Default, PartialEq)]
pub struct OrderedMap<T>(pub Vec<(String, T)>);

impl<T> OrderedMap<T> {
    pub fn new() -> Self {
        Self(Vec::new())
    }

    pub fn get(&self, key: &str) -> Option<&T> {
        self.0.iter().find(|(name, _)| name == key).map(|(_, value)| value)
    }

    pub fn get_mut(&mut self, key: &str) -> Option<&mut T> {
        self.0.iter_mut().find(|(name, _)| name == key).map(|(_, value)| value)
    }

    /// Dictionary assignment: an existing key keeps its position.
    pub fn set(&mut self, key: &str, value: T) {
        match self.get_mut(key) {
            Some(slot) => *slot = value,
            None => self.0.push((key.to_string(), value)),
        }
    }

    pub fn erase(&mut self, key: &str) {
        self.0.retain(|(name, _)| name != key);
    }

    pub fn has(&self, key: &str) -> bool {
        self.get(key).is_some()
    }

    pub fn len(&self) -> usize {
        self.0.len()
    }

    pub fn is_empty(&self) -> bool {
        self.0.is_empty()
    }
}

impl<T: ToValue> ToValue for OrderedMap<T> {
    fn to_value(&self) -> Value {
        Value::Dict(
            self.0
                .iter()
                .map(|(key, value)| (Value::Str(key.clone()), value.to_value()))
                .collect(),
        )
    }
}

/// A Rust field name as its GDScript property name. `type_` is `type`.
pub const fn field_name(name: &'static str) -> &'static str {
    let bytes = name.as_bytes();

    if bytes.len() > 1 && bytes[bytes.len() - 1] == b'_' {
        let (head, _) = bytes.split_at(bytes.len() - 1);

        match std::str::from_utf8(head) {
            Ok(text) => text,
            Err(_) => name,
        }
    } else {
        name
    }
}

/// Declare a struct that converts to a named GDScript object. Each field
/// becomes a GDScript property of the same name.
#[macro_export]
macro_rules! gd_object {
    (
        $(#[$meta:meta])*
        pub struct $name:ident as $class:literal {
            $( $(#[$field_meta:meta])* pub $field:ident : $kind:ty = $default:expr ),* $(,)?
        }
    ) => {
        $(#[$meta])*
        #[derive(Clone, Debug, PartialEq)]
        pub struct $name {
            $( $(#[$field_meta])* pub $field: $kind ),*
        }

        impl Default for $name {
            fn default() -> Self {
                Self { $( $field: $default ),* }
            }
        }

        impl $crate::sim::value::ToValue for $name {
            fn to_value(&self) -> $crate::sim::value::Value {
                $crate::sim::value::Value::Object(
                    $class,
                    vec![ $( ($crate::sim::value::field_name(stringify!($field)), $crate::sim::value::ToValue::to_value(&self.$field)) ),* ],
                )
            }
        }
    };
}

/// Declare a PhaseResult subclass. It holds the common fields in `base`, and
/// GDScript receives the base fields and its own fields as one object.
#[macro_export]
macro_rules! gd_phase_result {
    (
        $(#[$meta:meta])*
        pub struct $name:ident as $class:literal {
            $( $(#[$field_meta:meta])* pub $field:ident : $kind:ty = $default:expr ),* $(,)?
        }
    ) => {
        $(#[$meta])*
        #[derive(Clone, Debug, PartialEq)]
        pub struct $name {
            pub base: $crate::sim::phase::PhaseBase,
            $( $(#[$field_meta])* pub $field: $kind ),*
        }

        impl Default for $name {
            fn default() -> Self {
                Self { base: Default::default(), $( $field: $default ),* }
            }
        }

        impl $crate::sim::value::ToValue for $name {
            fn to_value(&self) -> $crate::sim::value::Value {
                #[allow(unused_mut)]
                let mut fields = self.base.fields();
                $( fields.push(($crate::sim::value::field_name(stringify!($field)), $crate::sim::value::ToValue::to_value(&self.$field))); )*

                $crate::sim::value::Value::Object($class, fields)
            }
        }

        impl $crate::sim::phase::PhaseResultLike for $name {
            fn base(&self) -> &$crate::sim::phase::PhaseBase {
                &self.base
            }

            fn base_mut(&mut self) -> &mut $crate::sim::phase::PhaseBase {
                &mut self.base
            }
        }

        impl $name {
            #[allow(dead_code)]
            pub fn failed(message: impl Into<String>) -> Self {
                let mut result = Self::default();
                result.base.error = message.into();
                result
            }
        }
    };
}
