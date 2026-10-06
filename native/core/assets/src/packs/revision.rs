//! The revision of the content that an importer writes in each pack. A pack
//! with an older revision is out of date and needs a new import.

use sc2k_formats::json::{Object, Value};

/// The current revision of each pack kind.
const CURRENT: [(&str, i64); 4] = [("graphics", 1), ("sound", 1), ("music", 1), ("data", 1)];
/// Source platforms whose content changed alone. DOS and Macintosh graphics
/// use the Windows palette layout from 2; DOS graphics have the toolbar from 3.
const CURRENT_BY_PLATFORM: [(&str, &str, i64); 2] =
    [("graphics", "DOS", 3), ("graphics", "Macintosh", 2)];
/// Packs that importers wrote before they recorded a revision.
pub const UNRECORDED: i64 = 1;
/// A pack that a person made, not an importer.
pub const NOT_IMPORTED: i64 = -1;
pub const INVALID: i64 = -2;
const LEGACY_IMPORTED_NAME: &str = "Original SimCity 2000";

/// The revision of a manifest.
pub fn read(manifest: &Object) -> i64 {
    if let Some(value) = manifest.get("import_revision") {
        return match value {
            Value::Int(number) if *number >= 0 => *number,
            Value::Float(number) if *number == number.floor() && *number >= 0.0 => *number as i64,
            _ => INVALID,
        };
    }

    let legacy_name = manifest
        .get("name")
        .and_then(Value::as_str)
        .is_some_and(|name| name.starts_with(LEGACY_IMPORTED_NAME));

    if manifest.contains("source_platform") || manifest.contains("runtime_data") || legacy_name {
        return UNRECORDED;
    }

    NOT_IMPORTED
}

/// The revision that an importer of `kind` writes now.
pub fn current(kind: &str, platform: &str) -> i64 {
    CURRENT_BY_PLATFORM
        .iter()
        .find(|(known, source, _)| *known == kind && *source == platform)
        .map(|(_, _, revision)| *revision)
        .or_else(|| {
            CURRENT
                .iter()
                .find(|(known, _)| *known == kind)
                .map(|(_, revision)| *revision)
        })
        .unwrap_or(0)
}

pub fn is_outdated(kind: &str, revision: i64, platform: &str) -> bool {
    revision >= 0 && revision < current(kind, platform)
}

#[cfg(test)]
mod tests {
    use super::*;
    use sc2k_formats::json;

    fn manifest(text: &str) -> Object {
        json::parse(text).unwrap().as_object().cloned().unwrap()
    }

    #[test]
    fn revisions_follow_the_manifest() {
        assert_eq!(read(&manifest(r#"{"import_revision": 2.0}"#)), 2);
        assert_eq!(read(&manifest(r#"{"import_revision": -1}"#)), INVALID);
        assert_eq!(read(&manifest(r#"{"source_platform": "DOS"}"#)), UNRECORDED);
        assert_eq!(read(&manifest(r#"{"name": "Mine"}"#)), NOT_IMPORTED);
        assert_eq!(current("graphics", "DOS"), 3);
        assert!(
            is_outdated("graphics", 2, "DOS")
                && !is_outdated("sound", 1, "DOS")
                && !is_outdated("data", NOT_IMPORTED, "")
        );
    }
}
