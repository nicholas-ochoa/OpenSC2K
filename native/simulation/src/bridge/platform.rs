//! Platform rules for GDScript: the release check, version comparison, and
//! the mod manifests and load order.

use godot::classes::FileAccess;
use godot::prelude::*;

use sc2k_platform::mods::catalog::{self, Found};
use sc2k_platform::mods::manifest::{FILE_NAME, Manifest};
use sc2k_platform::release::{self, Status, Transport};
use sc2k_platform::versions;

fn strings(values: &PackedStringArray) -> Vec<String> {
    values.as_slice().iter().map(GString::to_string).collect()
}

/// The last part of a path, as Godot's `get_file`.
fn file_name(path: &str) -> &str {
    path.rsplit(['/', '\\']).next().unwrap_or(path)
}

fn path_join(folder: &str, name: &str) -> String {
    if folder.is_empty() || folder.ends_with('/') {
        format!("{folder}{name}")
    } else {
        format!("{folder}/{name}")
    }
}

fn read_manifest(folder: &str, game_version: &str) -> Manifest {
    let path = path_join(folder, FILE_NAME);
    let source = FileAccess::file_exists(&path).then(|| FileAccess::get_file_as_string(&path).to_string());

    Manifest::read(file_name(folder), source.as_deref(), game_version, |main| {
        FileAccess::file_exists(&path_join(folder, main))
    })
}

fn manifest_value(folder: &str, manifest: &Manifest) -> VarDictionary {
    let mut result = VarDictionary::new();

    for (key, value) in [
        ("id", &manifest.id),
        ("name", &manifest.name),
        ("version", &manifest.version),
        ("description", &manifest.description),
        ("main", &manifest.main),
        ("author", &manifest.author),
        ("email", &manifest.email),
        ("website", &manifest.website),
        ("license", &manifest.license),
        ("game_version", &manifest.game_version),
        ("error", &manifest.error),
    ] {
        result.set(key, value.as_str());
    }

    result.set("folder", folder);
    result.set(
        "dependencies",
        &manifest
            .dependencies
            .iter()
            .map(|id| GString::from(id.as_str()))
            .collect::<PackedStringArray>(),
    );
    result
}

/// Platform rules.
#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativePlatform {}

#[godot_api]
impl NativePlatform {
    /// Compare dotted versions: -1, 0, or 1.
    #[func]
    fn compare_versions(first: GString, second: GString) -> i64 {
        versions::compare(&first.to_string(), &second.to_string())
    }

    /// The fields of the manifest of a mod folder.
    #[func]
    fn mod_manifest(folder: GString, game_version: GString) -> VarDictionary {
        let folder = folder.to_string();

        manifest_value(&folder, &read_manifest(&folder, &game_version.to_string()))
    }

    /// The manifests of the mod `folders`, given in name order, in load order.
    #[func]
    fn mod_catalog(folders: PackedStringArray, game_version: GString) -> VarArray {
        let game_version = game_version.to_string();
        let found = strings(&folders)
            .into_iter()
            .map(|folder| Found {
                manifest: read_manifest(&folder, &game_version),
                folder,
            })
            .collect();
        let mut result = VarArray::new();

        for item in catalog::catalog(found) {
            result.push(&manifest_value(&item.folder, &item.manifest).to_variant());
        }

        result
    }

    /// The three numbers of a release tag, or an empty array.
    #[func]
    fn parse_version(value: GString) -> PackedInt32Array {
        release::parse_version(&value.to_string()).map_or(PackedInt32Array::new(), |parts| parts.iter().map(|&part| part as i32).collect())
    }

    #[func]
    fn normalized_version(value: GString) -> GString {
        GString::from(release::normalized_version(&value.to_string()).as_str())
    }

    #[func]
    fn is_newer(candidate: GString, current: GString) -> bool {
        release::is_newer(&candidate.to_string(), &current.to_string())
    }

    #[func]
    fn is_due(last_check: i64, now: i64) -> bool {
        release::is_due(last_check, now)
    }

    /// Seconds until GitHub accepts requests again, or -1.
    #[func]
    fn retry_seconds(headers: PackedStringArray, now: i64) -> i64 {
        release::retry_seconds(&strings(&headers), now).unwrap_or(-1)
    }

    /// The value of a response header, or an empty string.
    #[func]
    fn header_value(headers: PackedStringArray, name: GString) -> GString {
        GString::from(release::header_value(&strings(&headers), &name.to_string()))
    }

    #[func]
    fn wait_text(seconds: i64) -> GString {
        GString::from(release::wait_text(seconds).as_str())
    }

    #[func]
    fn status_text(checked_at: i64, error: GString, bias_minutes: i64) -> GString {
        GString::from(release::status_text(checked_at, &error.to_string(), bias_minutes).as_str())
    }

    /// `{status, version, url, message}` of a finished request. `transport`
    /// is "success", "connect", "tls", "timeout", or "other" with `code`.
    #[func]
    fn read_response(
        transport: GString,
        code: i64,
        response_code: i64,
        headers: PackedStringArray,
        body: PackedByteArray,
        current: GString,
        now: i64,
    ) -> VarDictionary {
        let transport = match transport.to_string().as_str() {
            "success" => Transport::Success,
            "connect" => Transport::Connect,
            "tls" => Transport::Tls,
            "timeout" => Transport::Timeout,
            _ => Transport::Other(code),
        };
        let outcome = release::read_response(
            transport,
            response_code,
            &strings(&headers),
            body.as_slice(),
            &current.to_string(),
            now,
        );
        let status = match outcome.status {
            Status::UpdateAvailable => 0,
            Status::UpToDate => 1,
            Status::Failed => 2,
        };
        let mut result = VarDictionary::new();
        result.set("status", status);
        result.set("version", outcome.version.as_str());
        result.set("url", outcome.url.as_str());
        result.set("message", outcome.message.as_str());
        result
    }
}
