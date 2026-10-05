//! The file operations of a mod in its folder. Each path is relative to
//! the folder; `Sandbox::resolve` checks it first.

use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::Path;
use std::time::UNIX_EPOCH;

use super::Sandbox;

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum EntryKind {
    File,
    Directory,
    Other,
}

impl EntryKind {
    pub fn name(self) -> &'static str {
        match self {
            EntryKind::File => "file",
            EntryKind::Directory => "directory",
            EntryKind::Other => "other",
        }
    }

    fn of(metadata: &fs::Metadata) -> EntryKind {
        if metadata.is_file() {
            EntryKind::File
        } else if metadata.is_dir() {
            EntryKind::Directory
        } else {
            EntryKind::Other
        }
    }
}

/// A file or a folder: its name, kind, size in bytes, and the time of the
/// last change in milliseconds since 1970.
#[derive(Debug, PartialEq)]
pub struct FileEntry {
    pub name: String,
    pub kind: EntryKind,
    pub size: u64,
    pub modified: i64,
}

impl FileEntry {
    fn new(name: String, metadata: &fs::Metadata) -> FileEntry {
        let modified = metadata
            .modified()
            .ok()
            .and_then(|time| time.duration_since(UNIX_EPOCH).ok())
            .map_or(0, |duration| duration.as_millis() as i64);

        FileEntry {
            name,
            kind: EntryKind::of(metadata),
            size: metadata.len(),
            modified,
        }
    }
}

impl Sandbox {
    pub fn read(&self, relative: &str) -> Result<Vec<u8>, String> {
        let path = self.resolve(relative)?;

        fs::read(&path).map_err(|error| failure("read", relative, error))
    }

    /// Writes the bytes to a file, or adds them at its end. Makes the
    /// missing folders of the path.
    pub fn write(&self, relative: &str, bytes: &[u8], append: bool) -> Result<(), String> {
        let path = self.resolve(relative)?;

        if path == self.root || path.is_dir() {
            return Err(format!("Cannot write {relative}: it is a folder"));
        }

        self.make_parent(&path, relative)?;
        let mut file = OpenOptions::new()
            .write(true)
            .create(true)
            .append(append)
            .truncate(!append)
            .open(&path)
            .map_err(|error| failure("write", relative, error))?;

        file.write_all(bytes).map_err(|error| failure("write", relative, error))
    }

    pub fn exists(&self, relative: &str) -> Result<bool, String> {
        Ok(self.resolve(relative)?.exists())
    }

    /// The file or folder, or None when it does not exist.
    pub fn stat(&self, relative: &str) -> Result<Option<FileEntry>, String> {
        let path = self.resolve(relative)?;

        let Ok(metadata) = fs::metadata(&path) else {
            return Ok(None);
        };

        let name = path.file_name().map_or(String::new(), |name| name.to_string_lossy().into_owned());

        Ok(Some(FileEntry::new(name, &metadata)))
    }

    /// The files and folders in a folder, by name.
    pub fn list(&self, relative: &str) -> Result<Vec<FileEntry>, String> {
        let path = self.resolve(relative)?;
        let reader = fs::read_dir(&path).map_err(|error| failure("list", relative, error))?;
        let mut entries = Vec::new();

        for item in reader {
            let item = item.map_err(|error| failure("list", relative, error))?;
            let name = item.file_name().to_string_lossy().into_owned();

            match fs::metadata(item.path()) {
                Ok(metadata) => entries.push(FileEntry::new(name, &metadata)),
                Err(_) => entries.push(FileEntry {
                    name,
                    kind: EntryKind::Other,
                    size: 0,
                    modified: 0,
                }),
            }
        }

        entries.sort_by(|first, second| first.name.cmp(&second.name));

        Ok(entries)
    }

    /// Makes a folder and the missing folders above it.
    pub fn make_folder(&self, relative: &str) -> Result<(), String> {
        let path = self.resolve(relative)?;

        fs::create_dir_all(&path).map_err(|error| failure("make the folder", relative, error))
    }

    /// Removes a file, or a folder. A folder that has files needs
    /// `recursive`. A link is removed, not the place that it points to.
    /// Returns false when nothing was there.
    pub fn remove(&self, relative: &str, recursive: bool) -> Result<bool, String> {
        let path = self.resolve(relative)?;

        if path == self.root {
            return Err("A mod cannot remove its own folder".to_string());
        }

        let Ok(metadata) = fs::symlink_metadata(&path) else {
            return Ok(false);
        };

        let result = if !metadata.is_dir() {
            fs::remove_file(&path)
        } else if recursive {
            fs::remove_dir_all(&path)
        } else {
            fs::remove_dir(&path)
        };

        result.map(|_| true).map_err(|error| failure("remove", relative, error))
    }

    /// Moves or renames a file or a folder. Replaces a file at the new path.
    pub fn rename(&self, from: &str, to: &str) -> Result<(), String> {
        let source = self.resolve(from)?;
        let target = self.resolve(to)?;

        if source == self.root || target == self.root {
            return Err("A mod cannot move its own folder".to_string());
        }

        self.make_parent(&target, to)?;

        fs::rename(&source, &target).map_err(|error| failure("move", from, error))
    }

    fn make_parent(&self, path: &Path, relative: &str) -> Result<(), String> {
        match path.parent() {
            Some(parent) if !parent.is_dir() => fs::create_dir_all(parent).map_err(|error| failure("make the folder for", relative, error)),
            _ => Ok(()),
        }
    }
}

fn failure(action: &str, relative: &str, error: std::io::Error) -> String {
    format!("Cannot {action} {relative}: {error}")
}
