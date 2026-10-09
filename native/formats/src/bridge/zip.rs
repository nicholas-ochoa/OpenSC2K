//! ZIP archives.

use super::{bytes, failure, success};
use godot::prelude::*;
use sc2k_formats::zip;

/// ZIP archives in memory. See `zip/mod.rs` of `sc2k_formats`.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeZip {}

#[godot_api]
impl NativeZip {
    /// `{ok, error, bytes}`. `names` gives the member order; `members` maps
    /// each name to its bytes.
    #[func]
    fn encode(
        names: PackedStringArray,
        members: VarDictionary,
        max_file_bytes: i64,
        max_data_bytes: i64,
        always_deflate: bool,
    ) -> VarDictionary {
        if names.len() != members.len() {
            return failure("The ZIP member list is invalid or too long.");
        }

        let mut data: Vec<(String, PackedByteArray)> = Vec::with_capacity(names.len());

        for name in names.as_slice() {
            let Some(value) = members.get(&name.to_variant()) else {
                return failure("The ZIP member path is invalid.");
            };

            let Ok(payload) = value.try_to::<PackedByteArray>() else {
                return failure("The ZIP member path is invalid.");
            };

            data.push((name.to_string(), payload));
        }

        let borrowed: Vec<(String, &[u8])> = data.iter().map(|(name, payload)| (name.clone(), payload.as_slice())).collect();

        match zip::encode(&borrowed, max_file_bytes, max_data_bytes, always_deflate) {
            Ok(file) => {
                let mut result = success();
                result.set("bytes", &bytes(&file));
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, order, members}`: the member names in central directory
    /// order, and a dictionary of their bytes.
    #[func]
    fn decode(archive: PackedByteArray, max_file_bytes: i64, max_data_bytes: i64) -> VarDictionary {
        match zip::decode(archive.as_slice(), max_file_bytes, max_data_bytes) {
            Ok(decoded) => {
                let mut order = PackedStringArray::new();
                let mut members = VarDictionary::new();

                for (name, data) in &decoded.members {
                    order.push(name.as_str());
                    members.set(name.as_str(), &bytes(data));
                }

                let mut result = success();
                result.set("order", &order);
                result.set("members", &members);
                result
            }
            Err(error) => failure(&error),
        }
    }
}
