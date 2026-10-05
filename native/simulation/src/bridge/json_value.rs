//! Conversion between Godot values and JSON values.

use godot::prelude::*;
use sc2k_formats::json::{Object as JsonObject, Value};

/// The JSON value of a Godot value. Vectors become arrays of their components;
/// other unknown types become null.
pub fn from_variant(value: &Variant) -> Value {
    match value.get_type() {
        VariantType::NIL => Value::Null,
        VariantType::BOOL => Value::Bool(value.to::<bool>()),
        VariantType::INT => Value::Int(value.to::<i64>()),
        VariantType::FLOAT => Value::Float(value.to::<f64>()),
        VariantType::STRING | VariantType::STRING_NAME => Value::String(value.to_string()),
        VariantType::DICTIONARY => Value::Object(object_from(&value.to::<VarDictionary>())),
        VariantType::ARRAY => Value::Array(value.to::<VarArray>().iter_shared().map(|item| from_variant(&item)).collect()),
        VariantType::PACKED_BYTE_ARRAY => ints(value.to::<PackedByteArray>().as_slice().iter().map(|item| i64::from(*item))),
        VariantType::PACKED_INT32_ARRAY => ints(value.to::<PackedInt32Array>().as_slice().iter().map(|item| i64::from(*item))),
        VariantType::PACKED_INT64_ARRAY => ints(value.to::<PackedInt64Array>().as_slice().iter().copied()),
        VariantType::PACKED_STRING_ARRAY => Value::Array(
            value
                .to::<PackedStringArray>()
                .as_slice()
                .iter()
                .map(|item| Value::String(item.to_string()))
                .collect(),
        ),
        VariantType::VECTOR2I => {
            let point = value.to::<Vector2i>();
            ints([i64::from(point.x), i64::from(point.y)].into_iter())
        }
        _ => Value::Null,
    }
}

pub fn object_from(dictionary: &VarDictionary) -> JsonObject {
    let mut object = JsonObject::new();

    for (key, value) in dictionary.iter_shared() {
        object.insert(&key.to_string(), from_variant(&value));
    }

    object
}

/// The Godot value of a JSON value.
pub fn to_variant(value: &Value) -> Variant {
    match value {
        Value::Null => Variant::nil(),
        Value::Bool(value) => value.to_variant(),
        Value::Int(value) => value.to_variant(),
        Value::Float(value) => value.to_variant(),
        Value::String(text) => GString::from(text.as_str()).to_variant(),
        Value::Array(items) => {
            let mut array = VarArray::new();

            for item in items {
                array.push(&to_variant(item));
            }

            array.to_variant()
        }
        Value::Object(object) => dictionary_from(object).to_variant(),
    }
}

pub fn dictionary_from(object: &JsonObject) -> VarDictionary {
    let mut dictionary = VarDictionary::new();

    for (key, value) in &object.entries {
        dictionary.set(key.as_str(), &to_variant(value));
    }

    dictionary
}

fn ints(values: impl Iterator<Item = i64>) -> Value {
    Value::Array(values.map(Value::Int).collect())
}
