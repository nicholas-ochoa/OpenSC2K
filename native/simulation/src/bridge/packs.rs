//! Pack manifest rules for GDScript.

use godot::classes::FileAccess;
use godot::prelude::*;

use super::json_value;
use sc2k_assets::packs::{media, revision};

/// Pack manifest rules.
#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativePacks {}

#[godot_api]
impl NativePacks {
    /// The import revision of a manifest.
    #[func]
    fn read_revision(manifest: VarDictionary) -> i64 {
        revision::read(&json_value::object_from(&manifest))
    }

    /// The revision that an importer of `kind` writes now for `platform`.
    #[func]
    fn current_revision(kind: GString, platform: GString) -> i64 {
        revision::current(&kind.to_string(), &platform.to_string())
    }

    #[func]
    fn is_outdated(kind: GString, revision: i64, platform: GString) -> bool {
        revision::is_outdated(&kind.to_string(), revision, &platform.to_string())
    }

    /// `{error, name, revision, ids, paths}` of a sound or music pack.json.
    /// The files before an error passed their checks.
    #[func]
    fn media_manifest(text: GString, kind: GString, root: GString) -> VarDictionary {
        let manifest = media::read(&text.to_string(), &kind.to_string(), &root.to_string(), |path| {
            FileAccess::file_exists(path)
        });
        let mut result = VarDictionary::new();
        result.set("error", manifest.error.as_str());
        result.set("name", manifest.name.as_str());
        result.set("revision", manifest.revision);
        result.set("ids", &manifest.files.iter().map(|(id, _)| *id).collect::<PackedInt64Array>());
        result.set(
            "paths",
            &manifest
                .files
                .iter()
                .map(|(_, path)| GString::from(path.as_str()))
                .collect::<PackedStringArray>(),
        );
        result
    }
}
