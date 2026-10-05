//! Conversions between Godot values and `JsData`. A vector or a rectangle
//! becomes an object with named fields. A Godot value without a JavaScript
//! form, such as an Object or a Callable, becomes its text.

use godot::builtin::{AnyArray, AnyDictionary};
use godot::prelude::*;

use sc2k_scripting::value::{JsData, MAX_DEPTH};

pub fn to_variant(data: &JsData) -> Variant {
    match data {
        JsData::Undefined | JsData::Null => Variant::nil(),
        JsData::Bool(value) => value.to_variant(),
        JsData::Int(value) => value.to_variant(),
        JsData::Float(value) => value.to_variant(),
        JsData::String(text) => GString::from(text.as_str()).to_variant(),
        JsData::Array(items) => {
            let mut array = VarArray::new();

            for item in items {
                array.push(&to_variant(item));
            }

            array.to_variant()
        }
        JsData::Object(entries) => {
            let mut dictionary = VarDictionary::new();

            for (key, item) in entries {
                dictionary.set(&GString::from(key.as_str()).to_variant(), &to_variant(item));
            }

            dictionary.to_variant()
        }
    }
}

pub fn from_variant(value: &Variant) -> JsData {
    copy_variant(value, 0)
}

fn copy_variant(value: &Variant, depth: usize) -> JsData {
    if depth >= MAX_DEPTH {
        return JsData::Undefined;
    }

    // a value that does not convert as its type says becomes its text
    copy_typed(value, depth).unwrap_or_else(|| JsData::String(value.to_string()))
}

fn copy_typed(value: &Variant, depth: usize) -> Option<JsData> {
    let data = match value.get_type() {
        VariantType::NIL => JsData::Null,
        VariantType::BOOL => JsData::Bool(value.try_to::<bool>().ok()?),
        VariantType::INT => JsData::Int(value.try_to::<i64>().ok()?),
        VariantType::FLOAT => JsData::Float(value.try_to::<f64>().ok()?),
        VariantType::STRING | VariantType::STRING_NAME | VariantType::NODE_PATH => JsData::String(value.to_string()),
        VariantType::VECTOR2 => {
            let vector = value.try_to::<Vector2>().ok()?;

            point(vector.x as f64, vector.y as f64)
        }
        VariantType::VECTOR2I => {
            let vector = value.try_to::<Vector2i>().ok()?;

            JsData::object(vec![("x", JsData::Int(vector.x as i64)), ("y", JsData::Int(vector.y as i64))])
        }
        VariantType::VECTOR3I => {
            let vector = value.try_to::<Vector3i>().ok()?;

            JsData::object(vec![
                ("x", JsData::Int(vector.x as i64)),
                ("y", JsData::Int(vector.y as i64)),
                ("z", JsData::Int(vector.z as i64)),
            ])
        }
        VariantType::RECT2I => {
            let rect = value.try_to::<Rect2i>().ok()?;

            JsData::object(vec![
                ("x", JsData::Int(rect.position.x as i64)),
                ("y", JsData::Int(rect.position.y as i64)),
                ("width", JsData::Int(rect.size.x as i64)),
                ("height", JsData::Int(rect.size.y as i64)),
            ])
        }
        VariantType::COLOR => {
            let color = value.try_to::<Color>().ok()?;

            JsData::object(vec![
                ("r", JsData::Float(color.r as f64)),
                ("g", JsData::Float(color.g as f64)),
                ("b", JsData::Float(color.b as f64)),
                ("a", JsData::Float(color.a as f64)),
            ])
        }
        // AnyArray and AnyDictionary also take typed collections, such as Array[String]
        VariantType::ARRAY => {
            let array = value.try_to::<AnyArray>().ok()?;

            JsData::Array(array.iter_shared().map(|item| copy_variant(&item, depth + 1)).collect())
        }
        VariantType::DICTIONARY => {
            let dictionary = value.try_to::<AnyDictionary>().ok()?;

            JsData::Object(
                dictionary
                    .iter_shared()
                    .map(|(key, item)| (key.to_string(), copy_variant(&item, depth + 1)))
                    .collect(),
            )
        }
        VariantType::PACKED_BYTE_ARRAY => ints(value.try_to::<PackedByteArray>().ok()?.as_slice().iter().map(|item| *item as i64)),
        VariantType::PACKED_INT32_ARRAY => ints(value.try_to::<PackedInt32Array>().ok()?.as_slice().iter().map(|item| *item as i64)),
        VariantType::PACKED_INT64_ARRAY => ints(value.try_to::<PackedInt64Array>().ok()?.as_slice().iter().copied()),
        VariantType::PACKED_FLOAT32_ARRAY => JsData::Array(
            value
                .try_to::<PackedFloat32Array>()
                .ok()?
                .as_slice()
                .iter()
                .map(|item| JsData::Float(*item as f64))
                .collect(),
        ),
        VariantType::PACKED_FLOAT64_ARRAY => JsData::Array(
            value
                .try_to::<PackedFloat64Array>()
                .ok()?
                .as_slice()
                .iter()
                .map(|item| JsData::Float(*item))
                .collect(),
        ),
        VariantType::PACKED_STRING_ARRAY => JsData::Array(
            value
                .try_to::<PackedStringArray>()
                .ok()?
                .as_slice()
                .iter()
                .map(|item| JsData::String(item.to_string()))
                .collect(),
        ),
        VariantType::PACKED_VECTOR2_ARRAY => JsData::Array(
            value
                .try_to::<PackedVector2Array>()
                .ok()?
                .as_slice()
                .iter()
                .map(|item| point(item.x as f64, item.y as f64))
                .collect(),
        ),
        _ => return None,
    };

    Some(data)
}

fn point(x: f64, y: f64) -> JsData {
    JsData::object(vec![("x", JsData::Float(x)), ("y", JsData::Float(y))])
}

fn ints(values: impl Iterator<Item = i64>) -> JsData {
    JsData::Array(values.map(JsData::Int).collect())
}
