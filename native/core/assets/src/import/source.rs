//! The supplied game files of an import, found by file contents and record
//! names rather than a release hash list, as Sc2ImportSource.

use super::container::Container;
use std::fs;
use std::io::Read;
use std::path::Path;

const MAX_FILE_BYTES: u64 = 64 * 1024 * 1024;
const MAX_FILES: usize = 20000;
const MAX_DEPTH: usize = 12;
const MAX_SOURCE_BYTES: u64 = 256 * 1024 * 1024;
/// A disc can hold several versions in separate folders; the first of these imports.
const PLATFORM_PREFERENCE: [&str; 4] = ["Windows", "Windows 3.x", "Macintosh", "DOS"];
const DISC_IMAGES: [&str; 6] = ["iso", "cue", "img", "toast", "cdr", "dmg"];
const ARCHIVES: [&str; 4] = ["pkg", "zip", "7z", "rar"];
const EXECUTABLES: [&str; 3] = ["exe", "dll", "wad"];
const LOOSE: [&str; 17] = [
    "wav", "mid", "midi", "xmi", "voc", "bmp", "pal", "dat", "idx", "mif", "hed", "bin", "raw",
    "rsc", "spr", "scl", "db",
];
const APPLE_HEADERS: [u32; 2] = [0x0005_1607, 0x0005_1600];
/// The string resources of the game programs.
const GAME_STRING_IDS: [i64; 2] = [178, 247];

/// Why a file of the source was not read.
enum ReadProblem {
    Unreadable,
    TooLarge,
}

/// One record of the source with the path of its file.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Record {
    pub name: String,
    pub kind: String,
    pub id: i64,
    pub bytes: Vec<u8>,
    pub source: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Source {
    pub platform: String,
    pub records: Vec<Record>,
    pub warnings: Vec<String>,
    /// Information that does not make the import partial.
    pub notes: Vec<String>,
    pub error: String,
    pub root: String,
    files: Vec<String>,
    platforms: Vec<(String, Vec<String>)>,
    bytes_read: u64,
    network: bool,
}

impl Default for Source {
    fn default() -> Self {
        Self {
            platform: "Unknown platform".into(),
            records: Vec::new(),
            warnings: Vec::new(),
            notes: Vec::new(),
            error: String::new(),
            root: String::new(),
            files: Vec::new(),
            platforms: Vec::new(),
            bytes_read: 0,
            network: false,
        }
    }
}

/// The file name without an ISO 9660 version suffix or a final dot.
pub fn original_name(name: &str) -> String {
    let mut result = name;

    if let Some(version) = result.rfind(';').filter(|&version| version > 0)
        && is_valid_int(&result[version + 1..])
    {
        result = &result[..version];
    }

    // ISO 9660 names without an extension can end in a dot
    if result.ends_with('.') && result.chars().count() > 1 {
        result = &result[..result.len() - 1];
    }

    result.to_string()
}

fn is_valid_int(text: &str) -> bool {
    let digits = text.strip_prefix(['+', '-']).unwrap_or(text);

    !digits.is_empty() && digits.bytes().all(|byte| byte.is_ascii_digit())
}

fn file_name(path: &str) -> &str {
    path.rsplit('/').next().unwrap_or(path)
}

fn base_dir(path: &str) -> String {
    match path.rfind('/') {
        Some(0) => "/".into(),
        Some(slash) => path[..slash].to_string(),
        None => String::new(),
    }
}

fn path_join(folder: &str, name: &str) -> String {
    if folder.ends_with('/') {
        format!("{folder}{name}")
    } else {
        format!("{folder}/{name}")
    }
}

fn extension(name: &str) -> String {
    super::super::packs::extension(name).to_lowercase()
}

fn is_link(path: &str) -> bool {
    fs::symlink_metadata(path).is_ok_and(|metadata| metadata.file_type().is_symlink())
}

impl Source {
    /// Scan an asset file or a game folder. `selected` is an absolute, simplified path.
    pub fn scan(selected: &str) -> Self {
        let mut source = Self::default();
        let selected_path = Path::new(selected);

        if selected_path.is_file() {
            let extension = extension(file_name(selected));

            if DISC_IMAGES.contains(&extension.as_str()) {
                source.error = "Mount the disc image first. Then select the mounted disc or the game folder on it. Most file managers mount a disc image when you open it.".into();

                return source;
            }

            if ARCHIVES.contains(&extension.as_str()) {
                source.error = "Install the game or extract its files first. For GOG, select the installed game folder or macOS .app instead of the installer.".into();

                return source;
            }

            if fs::metadata(selected).is_ok_and(|metadata| metadata.len() > MAX_FILE_BYTES) {
                source.error = "This file exceeds the import size limit. Install the game or extract its files first, then select its game folder or macOS .app.".into();

                return source;
            }

            source.root = base_dir(selected);
            source.files.push(selected.to_string());
            let root = source.root.clone();
            source.list(&root, 0);
        } else if selected_path.is_dir() {
            source.root = selected.to_string();
            source.list(selected, 0);
        } else {
            source.error = "Select an existing game folder or asset file.".into();

            return source;
        }

        let mut visited: Vec<String> = Vec::new();

        for file in source.files.clone() {
            if source.bytes_read >= MAX_SOURCE_BYTES {
                source.warnings.push("The asset scan reached its memory limit. Select one game's folder to include the remaining files.".into());
                break;
            }

            if visited.contains(&file) {
                continue;
            }

            visited.push(file.clone());
            source.read(&file, file == selected);
        }

        match source.platforms.len() {
            1 => source.platform = source.platforms[0].0.clone(),
            0 if !source.records.is_empty() => source.platform = "Unidentified SC2K".into(),
            0 => {}
            _ => {
                let folder = source.preferred_folder();
                let names: Vec<String> = source
                    .platforms
                    .iter()
                    .map(|(family, _)| family.clone())
                    .collect();

                if !folder.is_empty() && folder != source.root && selected_path.is_dir() {
                    let mut chosen = Self::scan(&folder);

                    if chosen.error.is_empty() && chosen.platforms.len() == 1 {
                        chosen.notes.push(format!(
                            "This disc or folder contains more than one version ({}). Imported the {} version from {folder}. To import another version, select its folder.",
                            names.join(", "),
                            chosen.platform
                        ));

                        return chosen;
                    }
                }

                source.error = format!(
                    "This folder contains assets from multiple platforms ({}). Select one game's folder.",
                    names.join(", ")
                );
            }
        }

        if source.platform == "Windows" && source.network {
            source.platform = "Windows Network Edition".into();
        }

        if source.records.is_empty() && source.error.is_empty() {
            source.error = "No readable SC2K assets were found. Select the installed or extracted game files, or a mounted game disc. An installer or an unopened disc image cannot be read.".into();
        }

        source
    }

    fn list(&mut self, folder: &str, depth: usize) {
        if depth > MAX_DEPTH || self.files.len() >= MAX_FILES {
            self.warnings.push("The folder scan reached its limit. Select a smaller game folder to include the remaining files.".into());
            return;
        }

        let Ok(entries) = fs::read_dir(folder) else {
            self.warnings
                .push(format!("Cannot read folder: {}", file_name(folder)));
            return;
        };

        let (mut files, mut folders): (Vec<String>, Vec<String>) = (Vec::new(), Vec::new());

        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().into_owned();
            let path = path_join(folder, &name);
            let target = Path::new(&path);

            if target.is_dir() {
                folders.push(name);
            } else if target.is_file() {
                files.push(name);
            }
        }

        files.sort();
        folders.sort();

        for name in files {
            let path = path_join(folder, &name);

            if !is_link(&path) {
                self.files.push(path);
            }

            if self.files.len() >= MAX_FILES {
                self.warnings
                    .push("The folder contains too many files. Select one game's folder.".into());
                return;
            }
        }

        for name in folders {
            let path = path_join(folder, &name);

            if !name.starts_with('.') && !is_link(&path) {
                self.list(&path, depth + 1);
            }
        }
    }

    /// The bytes of a file within the limits.
    fn read_bytes(&mut self, path: &str) -> Result<Vec<u8>, ReadProblem> {
        let mut file = fs::File::open(path).map_err(|_| ReadProblem::Unreadable)?;
        let length = file.metadata().map_or(0, |metadata| metadata.len());

        if length > MAX_FILE_BYTES || self.bytes_read + length > MAX_SOURCE_BYTES {
            return Err(ReadProblem::TooLarge);
        }

        let mut bytes = Vec::with_capacity(length as usize);
        file.read_to_end(&mut bytes)
            .map_err(|_| ReadProblem::Unreadable)?;
        self.bytes_read += bytes.len() as u64;

        Ok(bytes)
    }

    fn read(&mut self, path: &str, explicitly_selected: bool) {
        let name = original_name(file_name(path));
        let upper = name.to_uppercase();
        let extension = extension(&name);
        let resource_fork = extension == "rsrc" || name.starts_with("._");
        let executable = EXECUTABLES.contains(&extension.as_str());
        let mac_candidate =
            extension == "bin" || upper.contains("SIMCITY") || upper.contains("SIM CITY");
        let loose = LOOSE.contains(&extension.as_str());

        if !explicitly_selected && !resource_fork && !executable && !loose && !mac_candidate {
            return;
        }

        let bytes = match self.read_bytes(path) {
            Ok(bytes) => bytes,
            Err(ReadProblem::Unreadable) => {
                return self.warnings.push(format!("Cannot read {name}"));
            }
            Err(ReadProblem::TooLarge) => {
                return self.warnings.push(format!(
                    "Skipped large container {name}. Select its extracted files."
                ));
            }
        };

        let apple = bytes.len() >= 4
            && APPLE_HEADERS.contains(&u32::from_be_bytes([
                bytes[0], bytes[1], bytes[2], bytes[3],
            ]));

        if resource_fork || apple {
            return self.accept(Container::macintosh(&bytes), "Macintosh", &name, path);
        }

        if bytes.starts_with(b"MZ") {
            let parsed = Container::windows(&bytes);

            if parsed.error.is_empty() {
                self.network = self.network || upper == "2KCLIENT.EXE";
                let header = if bytes.len() >= 64 {
                    u32::from_le_bytes([bytes[60], bytes[61], bytes[62], bytes[63]]) as usize
                } else {
                    0
                };
                let family = if bytes.get(header..header + 2) == Some(b"NE".as_slice()) {
                    "Windows 3.x"
                } else {
                    "Windows"
                };
                let named = upper.contains("SC2000")
                    || upper.contains("SC2K")
                    || upper.contains("SIMCITY")
                    || upper == "SIMDEMO.EXE"
                    || upper == "2KCLIENT.EXE";
                let strings = parsed
                    .resources
                    .iter()
                    .any(|resource| resource.kind == "2" && GAME_STRING_IDS.contains(&resource.id));

                // setup programs and support DLLs can use another Windows ABI; their
                // resource tables alone must not mark a second game platform
                self.accept(
                    parsed,
                    if named || strings { family } else { "" },
                    &name,
                    path,
                );
            } else if explicitly_selected && upper != "SC2000.EXE" && upper != "SC2K.EXE" {
                self.warnings.push(format!("{name}: {}", parsed.error));
            }

            return;
        }

        if upper == "SC2000.DAT" {
            return self.accept(Container::named_archive(&bytes), "DOS", &name, path);
        }

        if (explicitly_selected || mac_candidate) && (!loose || extension == "bin") {
            let parsed = Container::macintosh(&bytes);

            if parsed.error.is_empty() {
                return self.accept(parsed, "Macintosh", &name, path);
            }

            let fork_path = path_join(path, "..namedfork/rsrc");

            if Path::new(&fork_path).is_file() {
                match self.read_bytes(&fork_path) {
                    Ok(fork) => self.accept(Container::macintosh(&fork), "Macintosh", &name, path),
                    Err(_) => self
                        .warnings
                        .push(format!("Cannot read the resource fork for {name}")),
                }

                return;
            }
        }

        if loose {
            self.records.push(Record {
                name: upper,
                kind: String::new(),
                id: -1,
                bytes,
                source: path.to_string(),
            });
        }
    }

    fn accept(&mut self, parsed: Container, family: &str, name: &str, path: &str) {
        if !parsed.error.is_empty() {
            self.warnings.push(format!("{name}: {}", parsed.error));
            return;
        }

        if parsed.resources.is_empty() {
            return;
        }

        if !family.is_empty() {
            let folder = base_dir(path);

            match self.platforms.iter_mut().find(|(known, _)| known == family) {
                Some((_, folders)) => folders.push(folder),
                None => self.platforms.push((family.to_string(), vec![folder])),
            }
        }

        self.records
            .extend(parsed.resources.into_iter().map(|resource| Record {
                name: resource.name,
                kind: resource.kind,
                id: resource.id,
                bytes: resource.bytes,
                source: path.to_string(),
            }));
    }

    /// The folder of the preferred version when no other version is inside it.
    fn preferred_folder(&self) -> String {
        for family in PLATFORM_PREFERENCE {
            let Some((_, folders)) = self.platforms.iter().find(|(known, _)| known == family)
            else {
                continue;
            };

            let folder = common_folder(folders);
            let separate = !folder.is_empty()
                && self
                    .platforms
                    .iter()
                    .filter(|(other, _)| other != family)
                    .flat_map(|(_, paths)| paths)
                    .all(|path| *path != folder && !path.starts_with(&format!("{folder}/")));

            if separate {
                return folder;
            }
        }

        String::new()
    }
}

/// The deepest folder that holds each of `paths`.
fn common_folder(paths: &[String]) -> String {
    let Some(first) = paths.first() else {
        return String::new();
    };

    let mut common = first.clone();

    for path in paths {
        while !common.is_empty() && *path != common && !path.starts_with(&format!("{common}/")) {
            let parent = base_dir(&common);
            common = if parent == common {
                String::new()
            } else {
                parent
            };
        }
    }

    common
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names_lose_their_disc_suffixes() {
        assert_eq!(original_name("SIMCITY.EXE;1"), "SIMCITY.EXE");
        assert_eq!(original_name("README."), "README");
        assert_eq!(original_name("."), ".");
        assert_eq!(common_folder(&["/a/b/c".into(), "/a/b/d".into()]), "/a/b");
    }

    #[test]
    fn a_missing_path_is_refused() {
        assert_eq!(
            Source::scan("/no/such/folder").error,
            "Select an existing game folder or asset file."
        );
    }
}
