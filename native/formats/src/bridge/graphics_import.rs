//! The graphics pack importer for GDScript.

use godot::prelude::*;
use sc2k_assets::import::graphics::{self, Folder, Resource};

/// The source records of a script array of Sc2ImportResource objects. Typed
/// script arrays do not convert to an untyped array, thus they are read by call.
fn resources(records: &Variant) -> Vec<Resource> {
    let count = records.call("size", &[]).try_to::<i64>().unwrap_or(0);

    (0..count)
        .filter_map(|index| records.call("get", &[index.to_variant()]).try_to::<Gd<Object>>().ok())
        .map(|record| Resource {
            name: record.get("name").to_string(),
            kind: record.get("type").to_string(),
            id: record.get("id").try_to::<i64>().unwrap_or(-1),
            bytes: record
                .get("bytes")
                .try_to::<PackedByteArray>()
                .map(|bytes| bytes.to_vec())
                .unwrap_or_default(),
            source: record.get("source").to_string(),
        })
        .collect()
}

/// The graphics pack importer. See `import/graphics` of `sc2k_assets`.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeGraphicsImport {}

#[godot_api]
impl NativeGraphicsImport {
    /// `{error, warnings, count}`. Writes the pack files below `folder`.
    #[func]
    fn export(records: Variant, platform: GString, label: GString, folder: GString) -> VarDictionary {
        let mut sink = Folder { root: folder.to_string() };
        let outcome = graphics::export(&resources(&records), &platform.to_string(), &label.to_string(), &mut sink);
        let mut result = VarDictionary::new();
        result.set("error", outcome.error.as_str());
        result.set(
            "warnings",
            &outcome.warnings.iter().map(GString::from).collect::<PackedStringArray>(),
        );
        result.set("count", outcome.count);
        result
    }
}
