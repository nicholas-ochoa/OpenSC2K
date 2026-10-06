//! The settings of the Godot build, which the native game shares.

use sc2k_platform::config::Config;
use sc2k_platform::dirs;
use std::path::PathBuf;

pub struct Settings {
    pub root: PathBuf,
    pub config: Config,
}

impl Settings {
    pub fn load() -> Self {
        let root = PathBuf::from(dirs::user_root().root);
        let text = std::fs::read_to_string(root.join("settings.cfg")).unwrap_or_default();

        Self {
            root,
            config: Config::parse(&text),
        }
    }

    /// A stored path setting: an absolute path, or a path in the portable folder.
    pub fn path(&self, section: &str, key: &str) -> Option<PathBuf> {
        let value = self.config.string(section, key, "");

        if value.is_empty() {
            return None;
        }

        let path = PathBuf::from(&value);

        Some(if path.is_absolute() { path } else { self.root.join(path) })
    }

    /// The graphics pack folder that the game uses.
    pub fn graphics_folder(&self) -> Option<PathBuf> {
        if self.config.string("graphics", "source", "auto") == "folder" {
            return self.path("graphics", "folder");
        }

        Some(self.root.join("packs/graphics"))
    }
}
