//! The manifests of the packs that the importers write and that players make:
//! pack.json with a format, a version, a name, and the files of the pack.

pub mod graphics;
pub mod hd;
pub mod media;
pub mod revision;

use sc2k_formats::json::Value;

/// Why a relative path of a manifest is refused.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PathProblem {
    /// Absolute, with a drive or URL colon, with a backslash, or empty.
    NotRelative,
    /// An empty, dot, or parent component.
    BadComponent,
}

/// The problem of a manifest file path, or `None` for a path inside the pack.
pub fn path_problem(path: &str) -> Option<PathProblem> {
    let absolute = path.starts_with(['/', '\\']) || path.contains(":/") || path.contains(":\\");

    if absolute || path.contains(':') || path.contains('\\') || path.is_empty() {
        return Some(PathProblem::NotRelative);
    }

    if path.split('/').any(|part| part.is_empty() || part == "." || part == "..") {
        return Some(PathProblem::BadComponent);
    }

    None
}

/// The text after the last dot of a file name, as Godot's `get_extension`.
pub fn extension(path: &str) -> &str {
    match path.rfind('.') {
        Some(dot) if path.rfind(['/', '\\']).is_none_or(|slash| dot > slash) => &path[dot + 1..],
        _ => "",
    }
}

/// `root` joined with `relative`, as Godot's `path_join`.
pub fn path_join(root: &str, relative: &str) -> String {
    if root.is_empty() || root.ends_with('/') {
        format!("{root}{relative}")
    } else {
        format!("{root}/{relative}")
    }
}

/// True for the number 1 of a JSON value.
fn is_one(value: Option<&Value>) -> bool {
    match value {
        Some(Value::Int(number)) => *number == 1,
        Some(Value::Float(number)) => *number == 1.0,
        _ => false,
    }
}

/// A nonempty name after the whitespace is removed.
fn has_name(value: Option<&Value>) -> bool {
    value
        .and_then(Value::as_str)
        .is_some_and(|name| !name.trim_matches(|character: char| character <= ' ').is_empty())
}

/// True when the manifest has `format`, version 1, and a name.
pub fn has_header(manifest: &sc2k_formats::json::Object, format: &str) -> bool {
    manifest.get("format").and_then(Value::as_str) == Some(format) && is_one(manifest.get("version")) && has_name(manifest.get("name"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn paths_stay_inside_the_pack() {
        assert_eq!(path_problem("sounds/500.wav"), None);
        assert_eq!(path_problem("/abs.wav"), Some(PathProblem::NotRelative));
        assert_eq!(path_problem("c:x.wav"), Some(PathProblem::NotRelative));
        assert_eq!(path_problem("a\\b.wav"), Some(PathProblem::NotRelative));
        assert_eq!(path_problem("a/../b.wav"), Some(PathProblem::BadComponent));
        assert_eq!(path_problem("a//b.wav"), Some(PathProblem::BadComponent));
        assert_eq!(extension("a.b/c"), "");
        assert_eq!(path_join("root/", "x"), "root/x");
    }
}
