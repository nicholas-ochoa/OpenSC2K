//! SCURK project archives for GDScript. The script keeps the project record.

use super::{bytes, failure, ints, success};
use godot::prelude::*;
use sc2k_assets::scurk::project::{Node, archive};

/// The items of an array value. Typed script arrays do not convert to an
/// untyped array, thus they are read by call.
fn items(value: &Variant) -> Vec<Variant> {
    if let Ok(array) = value.try_to::<VarArray>() {
        return array.iter_shared().collect();
    }

    let count = value.call("size", &[]).try_to::<i64>().unwrap_or(0);

    (0..count).map(|index| value.call("get", &[index.to_variant()])).collect()
}

fn entries(value: &Variant) -> Vec<(Variant, Variant)> {
    if let Ok(dictionary) = value.try_to::<VarDictionary>() {
        return dictionary.iter_shared().collect();
    }

    items(&value.call("keys", &[]))
        .into_iter()
        .map(|key| {
            let item = value.call("get", std::slice::from_ref(&key));
            (key, item)
        })
        .collect()
}

/// The record node of a script value. Unknown types become null.
fn node(value: &Variant) -> Node {
    match value.get_type() {
        VariantType::BOOL => Node::Bool(value.to::<bool>()),
        VariantType::INT => Node::Int(value.to::<i64>()),
        VariantType::FLOAT => Node::Float(value.to::<f64>()),
        VariantType::STRING | VariantType::STRING_NAME => Node::Str(value.to_string()),
        VariantType::ARRAY => Node::Array(items(value).iter().map(node).collect()),
        VariantType::DICTIONARY => Node::Object(entries(value).iter().map(|(key, item)| (key.to_string(), node(item))).collect()),
        VariantType::PACKED_BYTE_ARRAY => Node::Bytes(value.to::<PackedByteArray>().to_vec()),
        VariantType::PACKED_INT32_ARRAY => Node::Pixels(value.to::<PackedInt32Array>().to_vec()),
        _ => Node::Null,
    }
}

fn variant(node: &Node) -> Variant {
    match node {
        Node::Null => Variant::nil(),
        Node::Bool(value) => value.to_variant(),
        Node::Int(value) => value.to_variant(),
        Node::Float(value) => value.to_variant(),
        Node::Str(text) => GString::from(text.as_str()).to_variant(),
        Node::Array(values) => values.iter().map(variant).collect::<VarArray>().to_variant(),
        Node::Object(fields) => {
            let mut dictionary = VarDictionary::new();

            for (key, value) in fields {
                dictionary.set(key.as_str(), &variant(value));
            }

            dictionary.to_variant()
        }
        Node::Bytes(data) => bytes(data).to_variant(),
        Node::Pixels(pixels) => ints(pixels).to_variant(),
    }
}

/// SCURK project archives. See `scurk/project/archive.rs` of `sc2k_assets`.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeScurkArchive {}

#[godot_api]
impl NativeScurkArchive {
    /// `{ok, error, bytes}` for a checked project record. An empty palette
    /// selects the index palette.
    #[func]
    fn encode(record: VarDictionary, palette_rgb: PackedByteArray) -> VarDictionary {
        match archive::encode(&node(&record.to_variant()), palette_rgb.as_slice()) {
            Ok(file) => {
                let mut result = success();
                result.set("bytes", &bytes(&file));
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, record, palette_rgb}`.
    #[func]
    fn decode(data: PackedByteArray) -> VarDictionary {
        match archive::decode(data.as_slice()) {
            Ok(decoded) => {
                let mut result = success();
                result.set("record", &variant(&decoded.record));
                result.set("palette_rgb", &bytes(&decoded.palette_rgb));
                result
            }
            Err(error) => failure(&error),
        }
    }
}
