//! Sound and music packs: pack.json maps each original resource id to a file
//! of the pack, as MediaPack.

use super::{PathProblem, extension, has_header, path_join, path_problem, revision};
use sc2k_formats::json::{self, Value};

const SOUND_IDS: std::ops::RangeInclusive<i64> = 500..=529;
const MUSIC_IDS: std::ops::RangeInclusive<i64> = 10000..=10018;
const SOUND_EXTENSIONS: [&str; 1] = ["wav"];
const MUSIC_EXTENSIONS: [&str; 6] = ["mid", "midi", "wav", "ogg", "mp3", "flac"];

/// A manifest that passed its checks up to `error`. The files before the
/// error passed; the caller decodes them in order.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct MediaManifest {
    pub name: String,
    pub revision: i64,
    /// Each resource id and the full path of its file, in manifest order.
    pub files: Vec<(i64, String)>,
    pub error: String,
}

/// The decimal text of a whole number without a sign or leading zeros.
fn canonical_id(key: &str) -> Option<i64> {
    let number: i64 = key.parse().ok()?;

    (number.to_string() == key).then_some(number)
}

/// Check the manifest `text` of a pack of `kind` ("sound" or "music") in `root`.
pub fn read(
    text: &str,
    kind: &str,
    root: &str,
    file_exists: impl Fn(&str) -> bool,
) -> MediaManifest {
    let mut manifest = MediaManifest {
        revision: revision::NOT_IMPORTED,
        ..MediaManifest::default()
    };

    let Some(data) = json::parse(text)
        .ok()
        .and_then(|value| value.as_object().cloned())
    else {
        manifest.error = format!("Cannot read {kind} pack.json: {root}");

        return manifest;
    };

    let files = match data.get("files") {
        Some(Value::Object(files)) if has_header(&data, &format!("opensc2k-{kind}")) => files,
        _ => {
            manifest.error = format!("Invalid {kind} manifest format, version, name, or files");

            return manifest;
        }
    };

    manifest.name = data
        .get("name")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    manifest.revision = revision::read(&data);

    if manifest.revision == revision::INVALID {
        manifest.error = "import_revision must be a whole number that is not negative".into();

        return manifest;
    }

    let (ids, extensions): (_, &[&str]) = if kind == "sound" {
        (SOUND_IDS, &SOUND_EXTENSIONS)
    } else {
        (MUSIC_IDS, &MUSIC_EXTENSIONS)
    };

    for (key, value) in &files.entries {
        let id = canonical_id(key).filter(|id| ids.contains(id));

        let (Some(id), Value::String(relative)) = (id, value) else {
            manifest.error = format!("Invalid {kind} resource ID or path: {key}");

            return manifest;
        };

        match path_problem(relative) {
            Some(PathProblem::NotRelative) => {
                manifest.error = "Media paths must be relative and use forward slashes".into()
            }
            Some(PathProblem::BadComponent) => {
                manifest.error =
                    "Media paths cannot contain empty, dot, or parent components".into()
            }
            None => {}
        }

        if !manifest.error.is_empty() {
            return manifest;
        }

        let full = path_join(root, relative);

        if !extensions.contains(&extension(relative).to_lowercase().as_str()) || !file_exists(&full)
        {
            manifest.error = format!("Missing or unsupported media file: {full}");

            return manifest;
        }

        manifest.files.push((id, full));
    }

    manifest
}

#[cfg(test)]
mod tests {
    use super::*;

    fn read_sound(text: &str) -> MediaManifest {
        read(text, "sound", "packs/sound", |path| path.ends_with(".wav"))
    }

    #[test]
    fn manifests_list_their_files() {
        let manifest = read_sound(
            r#"{"format": "opensc2k-sound", "version": 1, "name": "Mine", "files": {"500": "a.wav", "501": "b.wav"}}"#,
        );
        assert_eq!(manifest.error, "");
        assert_eq!(
            manifest.files,
            vec![
                (500, "packs/sound/a.wav".to_string()),
                (501, "packs/sound/b.wav".to_string())
            ]
        );
    }

    #[test]
    fn the_first_problem_stops_the_check() {
        let header = r#""format": "opensc2k-sound", "version": 1, "name": "Mine""#;
        assert_eq!(
            read_sound("[]").error,
            "Cannot read sound pack.json: packs/sound"
        );
        assert_eq!(
            read_sound(r#"{"format": "x"}"#).error,
            "Invalid sound manifest format, version, name, or files"
        );
        let bad = read_sound(&format!(
            r#"{{{header}, "files": {{"500": "a.wav", "0501": "b.wav"}}}}"#
        ));
        assert_eq!(
            (bad.error.as_str(), bad.files.len()),
            ("Invalid sound resource ID or path: 0501", 1)
        );
        assert_eq!(
            read_sound(&format!(r#"{{{header}, "files": {{"500": "../a.wav"}}}}"#)).error,
            "Media paths cannot contain empty, dot, or parent components"
        );
        assert_eq!(
            read_sound(&format!(r#"{{{header}, "files": {{"500": "a.ogg"}}}}"#)).error,
            "Missing or unsupported media file: packs/sound/a.ogg"
        );
    }
}
