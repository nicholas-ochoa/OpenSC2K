//! The folder of a mod. A mod script can read and write files only in its
//! folder, and import only modules from it. `Sandbox` turns a path relative
//! to the folder into a full path, and refuses each path that leaves it:
//! an absolute path, too many `..` parts, or a link to a place outside.
//!
//! The rules for names are the same on each system, thus a mod that works
//! on one system works on the others. A name cannot have the characters
//! that Windows refuses, cannot end with a dot or a space, and cannot be a
//! Windows device name such as `CON` or `NUL`.

mod files;

use std::fs;
use std::path::{Path, PathBuf};

pub use files::FileEntry;

// the characters that a file name cannot have on Windows
const FORBIDDEN_CHARACTERS: [char; 7] = ['<', '>', ':', '"', '|', '?', '*'];
// the device names of Windows, which are not files in any folder
const DEVICE_NAMES: [&str; 22] = [
    "con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4",
    "lpt5", "lpt6", "lpt7", "lpt8", "lpt9",
];

pub struct Sandbox {
    // the canonical path of the folder: absolute, without links
    root: PathBuf,
}

impl Sandbox {
    pub fn new(root: &Path) -> Result<Sandbox, String> {
        let root = fs::canonicalize(root).map_err(|error| format!("Cannot open the folder {}: {error}", root.display()))?;

        if !root.is_dir() {
            return Err(format!("{} is not a folder", root.display()));
        }

        Ok(Sandbox { root })
    }

    #[cfg(test)]
    pub fn root(&self) -> &Path {
        &self.root
    }

    /// The full path of `relative`, a path in the folder. `/` and `\`
    /// separate the names. An empty path or `.` is the folder itself.
    pub fn resolve(&self, relative: &str) -> Result<PathBuf, String> {
        let names = names(relative)?;
        let mut path = self.root.clone();

        for name in names {
            path.push(name);
        }

        self.check_links(&path, relative)?;

        Ok(path)
    }

    /// The canonical path of a module file. QuickJS gives the full path,
    /// which it made from the path of the importing module.
    pub fn module_path(&self, name: &str) -> Result<PathBuf, String> {
        let path = Path::new(name);

        if !path.is_absolute() {
            return Err(format!(
                "A mod imports only its own files, by a path such as ./{name}. Cannot import {name}"
            ));
        }

        let canonical = fs::canonicalize(path).map_err(|error| format!("Cannot load the module {name}: {error}"))?;

        if !canonical.starts_with(&self.root) {
            return Err(format!("A mod imports only files in its own folder. Cannot import {name}"));
        }

        Ok(canonical)
    }

    /// Refuses a path whose deepest existing part is a link to a place
    /// outside the folder. The parts after it do not exist yet, and
    /// `names` permits only plain names there.
    fn check_links(&self, path: &Path, relative: &str) -> Result<(), String> {
        let mut existing = path;

        while fs::symlink_metadata(existing).is_err() {
            match existing.parent() {
                Some(parent) => existing = parent,
                None => return Err(outside(relative)),
            }
        }

        let canonical = fs::canonicalize(existing).map_err(|error| format!("Cannot open {relative}: {error}"))?;

        if canonical.starts_with(&self.root) {
            Ok(())
        } else {
            Err(outside(relative))
        }
    }
}

/// The name of a script file in error stacks and the base path of its
/// imports. QuickJS separates the names of a module path with `/`, and the
/// Windows form `\\?\C:\...` of a canonical path is not a module path.
pub fn script_name(path: &Path) -> String {
    let text = path.to_string_lossy();

    if !cfg!(windows) {
        return text.into_owned();
    }

    let plain = text
        .strip_prefix(r"\\?\")
        .filter(|rest| !rest.starts_with(r"UNC\"))
        .unwrap_or(&text);

    plain.replace('\\', "/")
}

/// The names of a relative path, after `.` and `..`.
fn names(relative: &str) -> Result<Vec<&str>, String> {
    if relative.contains('\0') {
        return Err("A path cannot contain a NUL character".to_string());
    }

    if relative.starts_with(['/', '\\']) {
        return Err(format!("A path must be relative to the mod folder, not {relative}"));
    }

    let mut names = Vec::new();

    for name in relative.split(['/', '\\']) {
        match name {
            "" | "." => {}
            ".." => {
                if names.pop().is_none() {
                    return Err(outside(relative));
                }
            }
            _ => {
                check_name(name, relative)?;
                names.push(name);
            }
        }
    }

    Ok(names)
}

fn check_name(name: &str, relative: &str) -> Result<(), String> {
    if name.contains(FORBIDDEN_CHARACTERS) || name.chars().any(char::is_control) {
        return Err(format!(
            "The path {relative} has a character that a file name cannot have: < > : \" | ? * or a control character"
        ));
    }

    if name.ends_with(['.', ' ']) {
        return Err(format!("A file name cannot end with a dot or a space: {relative}"));
    }

    let stem = name.split('.').next().unwrap_or_default().trim_end().to_ascii_lowercase();

    if DEVICE_NAMES.contains(&stem.as_str()) {
        return Err(format!("{name} is a device name of Windows and cannot be a file name: {relative}"));
    }

    Ok(())
}

fn outside(relative: &str) -> String {
    format!("A mod can use only the files in its own folder. {relative} is outside it")
}

#[cfg(test)]
mod tests;
