//! The path text rules of the script strings that the archive uses.

/// The position of the extension dot, when it comes after the last folder separator.
fn extension_dot(path: &str) -> Option<usize> {
    let dot = path.rfind('.')?;
    let separator = path.rfind(['/', '\\']);

    if separator.is_some_and(|separator| dot < separator) {
        None
    } else {
        Some(dot)
    }
}

/// Godot's `get_extension`.
pub fn extension(path: &str) -> &str {
    extension_dot(path).map_or("", |dot| &path[dot + 1..])
}

/// Godot's `get_basename`.
pub fn basename(path: &str) -> &str {
    extension_dot(path).map_or(path, |dot| &path[..dot])
}

/// Godot's `is_valid_identifier`: ASCII letters, digits, and underscores, and no first digit.
pub fn is_identifier(text: &str) -> bool {
    !text.is_empty() && !text.starts_with(|c: char| c.is_ascii_digit()) && text.chars().all(|c| c.is_ascii_alphanumeric() || c == '_')
}
