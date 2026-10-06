//! The folder for settings, packs, cities, and other user files. A "data"
//! folder beside an exported executable selects portable mode. Path text
//! follows the Godot string rules, thus stored settings stay the same.

use std::fs;
use std::path::Path;

pub const PORTABLE_FOLDER: &str = "data";

/// The selected folder for user files.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Root {
    pub root: String,
    pub portable: bool,
    /// A message when the portable folder cannot be written.
    pub error: String,
}

/// Select the root from the executable folder. `user_root` is the Godot user
/// folder, which the root is when the portable folder is not used.
pub fn select(executable_folder: &str, allow_portable: bool, user_root: &str) -> Root {
    let portable_root = simplify(&join(executable_folder, PORTABLE_FOLDER));
    let portable = allow_portable && Path::new(&portable_root).is_dir();
    let root = if portable {
        portable_root
    } else {
        simplify(user_root)
    };
    let error = if portable && !writable(&root) {
        format!(
            "Cannot write to the portable data folder:\n{root}\n\nMove OpenSC2K to a folder that you can write to, or remove the data folder."
        )
    } else {
        String::new()
    };

    Root {
        root,
        portable,
        error,
    }
}

/// A path for a settings file. Paths in the portable folder are relative, thus
/// the folder can move to a different drive or location. `ignore_case` is true
/// on Windows, where paths do not use letter case.
pub fn stored_path(value: &str, root: &str, portable: bool, ignore_case: bool) -> String {
    if !portable || value.is_empty() {
        return value.to_string();
    }

    let same = |a: &str, b: &str| {
        if ignore_case {
            a.to_lowercase() == b.to_lowercase()
        } else {
            a == b
        }
    };
    let full = simplify(value);
    let prefix = format!("{root}/");
    let prefix_length = prefix.chars().count();

    if same(&full, root) {
        return ".".to_string();
    }

    let start: String = full.chars().take(prefix_length).collect();

    if same(&start, &prefix) {
        return full.chars().skip(prefix_length).collect();
    }

    value.to_string()
}

/// A path from a settings file. A relative path is in the portable folder.
pub fn loaded_path(value: &str, root: &str, portable: bool) -> String {
    if !portable || value.is_empty() || is_absolute(value) {
        return value.to_string();
    }

    simplify(&join(root, value))
}

/// Godot's `path_join`.
pub fn join(folder: &str, name: &str) -> String {
    if folder.is_empty() {
        name.to_string()
    } else if folder.ends_with('/') || name.starts_with('/') {
        format!("{folder}{name}")
    } else {
        format!("{folder}/{name}")
    }
}

/// Godot's `is_absolute_path`.
pub fn is_absolute(path: &str) -> bool {
    path.starts_with(['/', '\\'])
        || (path.len() > 1 && (path.contains(":/") || path.contains(":\\")))
}

/// Godot's `simplify_path`: it keeps the drive or protocol, removes "." and
/// empty parts, and resolves ".." where a part comes before it.
pub fn simplify(path: &str) -> String {
    let (drive, rest) = split_drive(path);
    let mut rest = rest.replace('\\', "/");

    while rest.contains("//") {
        rest = rest.replace("//", "/");
    }

    let mut parts: Vec<&str> = rest.split('/').filter(|part| !part.is_empty()).collect();
    let mut index = 0;

    while index < parts.len() {
        if parts[index] == "." {
            parts.remove(index);
        } else if parts[index] == ".." && index > 0 {
            parts.drain(index - 1..=index);
            index -= 1;
        } else {
            index += 1;
        }
    }

    format!("{drive}{}", parts.join("/"))
}

fn split_drive(path: &str) -> (&str, &str) {
    if let Some(position) = path.find("://")
        && position > 0
        && path[..position].chars().all(|c| c.is_ascii_alphanumeric())
    {
        return path.split_at(position + 3);
    }

    if path.starts_with("//") || path.starts_with("\\\\") {
        return path.split_at(2);
    }

    if path.starts_with(['/', '\\']) {
        return path.split_at(1);
    }

    let colon = path.find(":/").or_else(|| path.find(":\\"));

    match (colon, path.find('/')) {
        (Some(colon), Some(slash)) if colon < slash => path.split_at(colon + 2),
        _ => ("", path),
    }
}

fn writable(folder: &str) -> bool {
    let probe = join(folder, &format!(".write-test-{}", std::process::id()));

    if fs::File::create(&probe).is_err() {
        return false;
    }

    let _ = fs::remove_file(&probe);

    true
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn simplify_follows_godot() {
        assert_eq!(simplify("/a/./b//c/../d/"), "/a/b/d");
        assert_eq!(simplify("user://x/../y"), "user://y");
        assert_eq!(simplify("C:\\Games\\..\\SC2K"), "C:/SC2K");
        assert_eq!(simplify("../a/b"), "../a/b");
        assert_eq!(simplify("a/b/../../.."), "..");
        assert_eq!(simplify("//server/share/./x"), "//server/share/x");
    }

    #[test]
    fn portable_paths_are_relative() {
        let root = "/apps/OpenSC2K/data";
        assert_eq!(stored_path(root, root, true, false), ".");
        assert_eq!(
            stored_path("/apps/OpenSC2K/data/packs/sound/", root, true, false),
            "packs/sound"
        );
        assert_eq!(
            stored_path("/apps/OpenSC2K/data-old/packs", root, true, false),
            "/apps/OpenSC2K/data-old/packs"
        );
        assert_eq!(stored_path("/APPS/OpenSC2K/DATA/x", root, true, true), "x");
        assert_eq!(
            stored_path("/apps/OpenSC2K/data/x", root, false, false),
            "/apps/OpenSC2K/data/x"
        );
        assert_eq!(loaded_path(".", root, true), root);
        assert_eq!(
            loaded_path("packs/../cities", root, true),
            "/apps/OpenSC2K/data/cities"
        );
        assert_eq!(loaded_path("/games/OST", root, true), "/games/OST");
        assert_eq!(loaded_path("packs", root, false), "packs");
    }

    #[test]
    fn a_missing_data_folder_selects_the_user_folder() {
        let selected = select("/nonexistent/OpenSC2K", true, "/users/me/./OpenSC2K/");
        assert_eq!(
            selected,
            Root {
                root: "/users/me/OpenSC2K".into(),
                portable: false,
                error: String::new()
            }
        );
    }
}
