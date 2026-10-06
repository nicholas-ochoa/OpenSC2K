//! Where an importer writes the files of a pack.

use std::fs;
use std::io::Write;
use std::path::Path;

pub trait Sink {
    /// Write a new file. Errors name the file by its relative path.
    fn write(&mut self, relative: &str, bytes: &[u8]) -> Result<(), String>;
}

/// The files of a pack folder. An existing file is never replaced.
pub struct Folder {
    pub root: String,
}

impl Sink for Folder {
    fn write(&mut self, relative: &str, bytes: &[u8]) -> Result<(), String> {
        let path = Path::new(&self.root).join(relative);
        let folder = path.parent().unwrap_or(Path::new(""));

        if path.is_file() || fs::create_dir_all(folder).is_err() {
            return Err(format!("Cannot create graphics pack file: {relative}"));
        }

        let mut file = fs::File::create(&path)
            .map_err(|_| format!("Cannot write graphics pack file: {relative}"))?;

        file.write_all(bytes)
            .and_then(|_| file.flush())
            .map_err(|_| format!("Cannot finish graphics pack file: {relative}"))
    }
}

/// Files in memory, in write order.
impl Sink for Vec<(String, Vec<u8>)> {
    fn write(&mut self, relative: &str, bytes: &[u8]) -> Result<(), String> {
        self.push((relative.to_string(), bytes.to_vec()));

        Ok(())
    }
}
