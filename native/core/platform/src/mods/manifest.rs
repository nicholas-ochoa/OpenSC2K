//! The info.json file of a mod folder: the identity of the mod, its main
//! script, and the facts that the Mods window shows. A manifest with a problem
//! keeps it in `error`, and the mod does not load.

use crate::text::{display, strip_edges};
use crate::versions;
use sc2k_formats::json::{self, Object, Value};

pub const FILE_NAME: &str = "info.json";
/// Event sources and the console use these names.
const RESERVED_IDS: [&str; 2] = ["console", "game"];
const SCRIPT_EXTENSIONS: [&str; 2] = ["js", "mjs"];
const MAX_ID_LENGTH: usize = 64;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Manifest {
    pub id: String,
    pub name: String,
    pub version: String,
    pub description: String,
    /// The path of the main script, relative to the mod folder.
    pub main: String,
    pub author: String,
    pub email: String,
    pub website: String,
    pub license: String,
    /// The oldest OpenSC2K version that the mod works with, or empty.
    pub game_version: String,
    /// The ids of the mods that must load first.
    pub dependencies: Vec<String>,
    pub error: String,
}

/// A mod id: a lowercase letter or digit, then up to 63 lowercase letters,
/// digits, ".", "_" and "-".
pub fn is_valid_id(id: &str) -> bool {
    let bytes = id.as_bytes();
    let allowed =
        |byte: &u8| byte.is_ascii_lowercase() || byte.is_ascii_digit() || b"._-".contains(byte);

    !bytes.is_empty()
        && bytes.len() <= MAX_ID_LENGTH
        && (bytes[0].is_ascii_lowercase() || bytes[0].is_ascii_digit())
        && bytes.iter().all(allowed)
        && !RESERVED_IDS.contains(&id)
}

/// The text of a field: a whole number without ".0", other values as text.
fn text(data: &Object, key: &str, fallback: &str) -> String {
    match data.get(key) {
        None | Some(Value::Null) => fallback.to_string(),
        Some(Value::Int(number)) => number.to_string(),
        Some(Value::Float(number)) if *number == number.floor() && number.is_finite() => {
            format!("{}", *number as i64)
        }
        Some(value) => strip_edges(&display(value)).to_string(),
    }
}

/// The text after the last dot of a file name, as Godot's `get_extension`.
fn extension(path: &str) -> &str {
    match path.rfind('.') {
        Some(dot) if path.rfind(['/', '\\']).is_none_or(|slash| dot > slash) => &path[dot + 1..],
        _ => "",
    }
}

/// An absolute path, as Godot's `is_absolute_path`.
fn is_absolute_path(path: &str) -> bool {
    path.starts_with(['/', '\\']) || path.contains(":/") || path.contains(":\\")
}

impl Manifest {
    /// Read the manifest of the folder `folder_name`. `text` is the info.json
    /// text, or `None` for a missing file; `main_exists` checks a script path.
    pub fn read(
        folder_name: &str,
        source: Option<&str>,
        current_game_version: &str,
        main_exists: impl Fn(&str) -> bool,
    ) -> Self {
        let mut manifest = Self {
            id: folder_name.to_lowercase(),
            name: folder_name.to_string(),
            ..Self::default()
        };

        let Some(source) = source else {
            manifest.error = format!("The folder has no {FILE_NAME} file.");

            return manifest;
        };

        let data = match json::parse(source) {
            Ok(Value::Object(data)) => data,
            Ok(_) => {
                manifest.error = format!("{FILE_NAME} must hold a JSON object.");

                return manifest;
            }
            Err(error) => {
                manifest.error = format!(
                    "{FILE_NAME} is not valid JSON: {} on line {}.",
                    error.message, error.line
                );

                return manifest;
            }
        };

        manifest.error = manifest
            .apply(&data, folder_name, current_game_version, main_exists)
            .err()
            .unwrap_or_default();
        manifest
    }

    fn apply(
        &mut self,
        data: &Object,
        folder_name: &str,
        current_game_version: &str,
        main_exists: impl Fn(&str) -> bool,
    ) -> Result<(), String> {
        self.id = text(data, "id", &self.id).to_lowercase();
        self.name = text(data, "name", "");
        self.version = text(data, "version", "");
        self.main = text(data, "main", "");
        self.description = text(data, "description", "");
        self.email = text(data, "email", "");
        self.website = text(data, "website", "");
        self.license = text(data, "license", "");
        self.game_version = text(data, "gameVersion", "");
        self.apply_author(data.get("author"));

        if !is_valid_id(&self.id) {
            return Err(format!(
                "The id \"{}\" is not valid. Use lowercase letters, digits, \".\", \"_\" and \"-\".",
                self.id
            ));
        }

        if self.name.is_empty() {
            self.name = folder_name.to_string();

            return Err(format!("{FILE_NAME} needs a \"name\"."));
        }

        if self.version.is_empty() {
            return Err(format!(
                "{FILE_NAME} needs a \"version\", such as \"1.0.0\"."
            ));
        }

        self.check_main(main_exists)?;
        self.apply_dependencies(data.get("dependencies"))?;

        if !self.game_version.is_empty()
            && versions::compare(current_game_version, &self.game_version) < 0
        {
            return Err(format!(
                "The mod needs OpenSC2K {} or newer.",
                self.game_version
            ));
        }

        Ok(())
    }

    /// "author" is a name, or an object { name, email, website }.
    fn apply_author(&mut self, value: Option<&Value>) {
        match value {
            Some(Value::Object(author)) => {
                self.author = text(author, "name", "");

                if self.email.is_empty() {
                    self.email = text(author, "email", "");
                }

                if self.website.is_empty() {
                    let url = text(author, "url", "");
                    self.website = text(author, "website", &url);
                }
            }
            None | Some(Value::Null) => {}
            Some(value) => self.author = strip_edges(&display(value)).to_string(),
        }
    }

    fn check_main(&self, main_exists: impl Fn(&str) -> bool) -> Result<(), String> {
        let main = &self.main;

        if main.is_empty() {
            return Err(format!(
                "{FILE_NAME} needs a \"main\" script, such as \"main.js\"."
            ));
        }

        if is_absolute_path(main) || main.replace('\\', "/").split('/').any(|part| part == "..") {
            return Err(format!(
                "The main script must be a path in the mod folder, not {main}."
            ));
        }

        if !SCRIPT_EXTENSIONS.contains(&extension(main).to_lowercase().as_str()) {
            return Err(format!(
                "The main script must be a .js or .mjs file, not {main}."
            ));
        }

        if !main_exists(main) {
            return Err(format!("The main script {main} is missing."));
        }

        Ok(())
    }

    fn apply_dependencies(&mut self, value: Option<&Value>) -> Result<(), String> {
        let items = match value {
            None => return Ok(()),
            Some(Value::Array(items)) => items,
            Some(_) => return Err("\"dependencies\" must be a list of mod ids.".into()),
        };

        for item in items {
            let dependency = display(item).to_lowercase();

            if !matches!(item, Value::String(_)) || dependency == self.id {
                return Err(format!(
                    "\"dependencies\" has a wrong mod id: {}.",
                    display(item)
                ));
            }

            if !self.dependencies.contains(&dependency) {
                self.dependencies.push(dependency);
            }
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn read(source: &str) -> Manifest {
        Manifest::read("My Mod", Some(source), "0.5.0", |main| main == "main.js")
    }

    #[test]
    fn a_complete_manifest_reads_its_fields() {
        let manifest = read(
            r#"{"id": "Llama.Mod", "name": " Llamas ", "version": 2, "main": "main.js",
            "author": {"name": "Ada", "url": "https://example.org"}, "dependencies": ["base", "BASE"], "gameVersion": "0.5"}"#,
        );
        assert_eq!(manifest.error, "");
        assert_eq!(
            (
                manifest.id.as_str(),
                manifest.name.as_str(),
                manifest.version.as_str()
            ),
            ("llama.mod", "Llamas", "2")
        );
        assert_eq!(
            (manifest.author.as_str(), manifest.website.as_str()),
            ("Ada", "https://example.org")
        );
        assert_eq!(manifest.dependencies, vec!["base".to_string()]);
    }

    #[test]
    fn problems_name_the_first_wrong_field() {
        assert_eq!(
            Manifest::read("m", None, "1.0", |_| true).error,
            "The folder has no info.json file."
        );
        assert_eq!(read("[]").error, "info.json must hold a JSON object.");
        assert!(
            read(r#"{"id": "game"}"#)
                .error
                .starts_with("The id \"game\" is not valid.")
        );
        assert_eq!(
            read(r#"{"id": "a"}"#).name,
            "My Mod",
            "a missing name keeps the folder name"
        );
        assert_eq!(
            read(r#"{"id": "a", "name": "A", "version": "1", "main": "../x.js"}"#).error,
            "The main script must be a path in the mod folder, not ../x.js."
        );
        assert_eq!(
            read(r#"{"id": "a", "name": "A", "version": "1", "main": "x.lua"}"#).error,
            "The main script must be a .js or .mjs file, not x.lua."
        );
        assert_eq!(
            read(r#"{"id": "a", "name": "A", "version": "1", "main": "x.js"}"#).error,
            "The main script x.js is missing."
        );
        assert_eq!(read(r#"{"id": "a", "name": "A", "version": "1", "main": "main.js", "dependencies": [1]}"#).error, "\"dependencies\" has a wrong mod id: 1.0.");
        assert_eq!(read(r#"{"id": "a", "name": "A", "version": "1", "main": "main.js", "gameVersion": "0.6"}"#).error, "The mod needs OpenSC2K 0.6 or newer.");
    }
}
