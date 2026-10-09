//! Verified city saves. A save writes a new temporary file beside the target,
//! closes it, reads it back, and checks it before it replaces the target. A
//! failure keeps the last save.

use super::document::Document;
use super::sc2x::document::{self as sc2x_document, Entries, MAX_ARCHIVE_BYTES, MAX_DATA_BYTES};
use sc2k_formats::zip;
use std::fs;
use std::io::Write;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

/// Compress the entries of a working document, then write and check the archive.
/// Returns the bytes of the file.
pub fn write_entries(path: &Path, entries: &Entries) -> Result<Vec<u8>, String> {
    let members: Vec<(String, &[u8])> = entries.members.iter().map(|(name, data)| (name.clone(), data.as_slice())).collect();
    let bytes = zip::encode(&members, MAX_ARCHIVE_BYTES, MAX_DATA_BYTES, true)?;
    write_verified(path, &bytes, Some(entries))?;

    Ok(bytes)
}

/// Write `bytes` to a temporary file beside `path`, read it back, check it, and
/// then replace `path`. An SC2X file must load again with the `expected` entries.
pub fn write_verified(path: &Path, bytes: &[u8], expected: Option<&Entries>) -> Result<(), String> {
    let stamp = SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |time| time.as_micros());
    let temporary = path.with_file_name(format!(
        "{}.{stamp}.tmp",
        path.file_name()
            .map_or_else(String::new, |name| name.to_string_lossy().into_owned())
    ));

    let written = fs::File::create(&temporary)
        .map_err(|error| format!("Cannot open save output: {error}"))
        .and_then(|mut file| {
            file.write_all(bytes)
                .and_then(|()| file.flush())
                .map_err(|error| format!("Cannot write save output: {error}"))
        });

    if let Err(error) = written {
        let _ = fs::remove_file(&temporary);

        return Err(error);
    }

    if let Err(error) = verify(&temporary, bytes, expected) {
        let _ = fs::remove_file(&temporary);

        return Err(error);
    }

    if let Err(error) = fs::rename(&temporary, path) {
        let _ = fs::remove_file(&temporary);

        return Err(format!("Cannot replace the saved city: {error}"));
    }

    Ok(())
}

fn verify(path: &Path, bytes: &[u8], expected: Option<&Entries>) -> Result<(), String> {
    let stored = fs::read(path).ok().filter(|stored| stored == bytes);

    let Some(stored) = stored else {
        return Err("The saved file does not match the city data. The previous save is unchanged.".into());
    };

    let Some(expected) = expected else {
        return Ok(());
    };

    let mut reloaded = Document::parse(&stored)
        .map_err(|error| format!("The saved file does not load again: {error}. The previous save is unchanged."))?;

    match sc2x_document::entries(&mut reloaded) {
        Ok(actual) if actual.members == expected.members => Ok(()),
        _ => Err("The saved file loads with different city data. The previous save is unchanged.".into()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn folder(name: &str) -> std::path::PathBuf {
        let path = std::env::temp_dir().join(format!("opensc2k-store-{}-{name}", std::process::id()));
        let _ = fs::remove_dir_all(&path);
        fs::create_dir_all(&path).unwrap();

        path
    }

    #[test]
    fn a_save_replaces_the_target_and_leaves_no_temporary_file() {
        let root = folder("replace");
        let target = root.join("city.SC2");
        fs::write(&target, b"old").unwrap();

        write_verified(&target, b"new", None).unwrap();

        assert_eq!(fs::read(&target).unwrap(), b"new");
        assert_eq!(fs::read_dir(&root).unwrap().count(), 1);
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn a_save_that_does_not_load_again_keeps_the_last_save() {
        let root = folder("reject");
        let target = root.join("city.sc2x");
        fs::write(&target, b"old").unwrap();
        let expected = Entries::default();

        let error = write_verified(&target, &[1, 2, 3], Some(&expected)).unwrap_err();

        assert!(error.starts_with("The saved file does not load again"), "{error}");
        assert_eq!(fs::read(&target).unwrap(), b"old");
        assert_eq!(fs::read_dir(&root).unwrap().count(), 1);
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn a_missing_folder_reports_the_open_error() {
        let target = std::env::temp_dir().join("opensc2k-missing-folder").join("city.SC2");
        let error = write_verified(&target, b"x", None).unwrap_err();

        assert!(error.starts_with("Cannot open save output: "), "{error}");
    }
}
