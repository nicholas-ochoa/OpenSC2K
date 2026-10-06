//! Graphics packs: pack.json names a palette image, the indexed PNG image of
//! each city sprite, and the interface images, as GraphicsPack. The images are
//! indexed PNG files whose palette is the pack palette.

use super::{PathProblem, extension, path_join, path_problem, revision};
use sc2k_formats::json::{self, Object, Value};
use sc2k_formats::png;
use std::path::Path;

pub const FORMAT: &str = "opensc2k-graphics";
pub const UI_FIELDS: [&str; 5] = [
    "toolbar_art",
    "industry_icons",
    "city_map_icons",
    "simnation_sprites",
    "forest_protest_image",
];
const MAX_SPRITE_ID: i64 = 65535;

/// An indexed image and its 256 RGB colors. A pixel is a palette index, or -1.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct IndexedImage {
    pub width: usize,
    pub height: usize,
    pub pixels: Vec<i32>,
    pub palette: Vec<u8>,
}

/// One city sprite of a pack.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct SpriteImage {
    pub id: i64,
    /// The number of earlier sprites with this ID.
    pub duplicate_index: i64,
    pub width: usize,
    pub height: usize,
    pub pixels: Vec<i32>,
}

#[derive(Clone, Debug, Default)]
pub struct GraphicsPack {
    pub root: String,
    pub name: String,
    pub partial: bool,
    pub import_revision: i64,
    pub source_platform: String,
    pub redraw_small_highway_ground: bool,
    pub palette: Vec<u8>,
    pub scenario_palette: Option<Vec<u8>>,
    pub large_sprites: Vec<SpriteImage>,
    pub small_medium_sprites: Vec<SpriteImage>,
    pub ui: Vec<(String, IndexedImage)>,
    /// The manifest, for the loaders of the optional sections: `scurk`,
    /// `city_ui`, `desktop`, and `scenario_pictures`.
    pub manifest: Object,
}

impl GraphicsPack {
    /// The pack of a folder, or of the pack.json path in it.
    pub fn load(root: &str) -> Result<Self, String> {
        let root = root.strip_suffix("/pack.json").unwrap_or(root);
        let text = std::fs::read_to_string(Path::new(root).join("pack.json"))
            .map_err(|_| "Missing pack.json".to_string())?;
        let manifest = match json::parse(&text) {
            Ok(Value::Object(object)) => object,
            _ => return Err("pack.json must contain a JSON object".into()),
        };

        let version_one = matches!(manifest.get("version"), Some(Value::Int(1)))
            || matches!(manifest.get("version"), Some(Value::Float(v)) if *v == 1.0);

        if manifest.get("format").and_then(Value::as_str) != Some(FORMAT) || !version_one {
            return Err("Unsupported graphics pack format or version".into());
        }

        let name = manifest
            .get("name")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string();

        if name.trim().is_empty() {
            return Err("Graphics pack name is required".into());
        }

        let import_revision = revision::read(&manifest);

        if import_revision == revision::INVALID {
            return Err("import_revision must be a whole number that is not negative".into());
        }

        let flag = |key: &str, message: &str| match manifest.get(key) {
            None => Ok(false),
            Some(Value::Bool(value)) => Ok(*value),
            Some(_) => Err(message.to_string()),
        };
        let partial = flag("partial", "partial must be a boolean")?;
        let redraw = flag(
            "redraw_small_highway_ground",
            "redraw_small_highway_ground must be a boolean",
        )?;
        let mut pack = GraphicsPack {
            root: root.to_string(),
            name,
            partial,
            import_revision,
            source_platform: manifest
                .get("source_platform")
                .map(text_of)
                .unwrap_or_default(),
            redraw_small_highway_ground: redraw,
            ..GraphicsPack::default()
        };

        pack.palette = pack.read_png(manifest.get("palette"))?.palette;

        if !partial || manifest.contains("scenario_palette") {
            pack.scenario_palette = Some(pack.read_png(manifest.get("scenario_palette"))?.palette);
        }

        pack.large_sprites = pack.sprites(manifest.get("large_sprites"))?;
        pack.small_medium_sprites = pack.sprites(manifest.get("small_medium_sprites"))?;

        let empty = Object::new();
        let ui = match manifest.get("ui") {
            None if partial => &empty,
            Some(Value::Object(ui)) => ui,
            _ => return Err("ui must be an object".into()),
        };

        if let Some(field) = ui.keys().find(|field| !UI_FIELDS.contains(field)) {
            return Err(format!("Unknown UI image: {field}"));
        }

        for field in UI_FIELDS {
            if partial && !ui.contains(field) {
                continue;
            }

            let image = pack.read_png(ui.get(field))?;
            pack.ui.push((field.to_string(), image));
        }

        pack.manifest = manifest;

        Ok(pack)
    }

    /// An indexed PNG file of the pack, by its relative path in the manifest.
    pub fn read_png(&self, relative: Option<&Value>) -> Result<IndexedImage, String> {
        let path = relative
            .and_then(Value::as_str)
            .filter(|path| !path.is_empty())
            .ok_or("PNG path must be a nonempty string")?;

        match path_problem(path) {
            Some(PathProblem::NotRelative) => {
                return Err("PNG paths must be relative and use forward slashes".into());
            }
            Some(PathProblem::BadComponent) => {
                return Err("PNG paths must not contain empty, dot, or parent components".into());
            }
            None => {}
        }

        if extension(path).to_lowercase() != "png" {
            return Err("Graphics files must be PNG".into());
        }

        let full = path_join(&self.root, path);
        let bytes =
            std::fs::read(&full).map_err(|_| format!("{path}: PNG file does not exist: {full}"))?;
        let decoded =
            png::decode_indexed(&bytes, true).map_err(|error| format!("{path}: {error}"))?;

        Ok(IndexedImage {
            width: decoded.width as usize,
            height: decoded.height as usize,
            pixels: decoded.pixels,
            palette: decoded.palette,
        })
    }

    fn sprites(&self, records: Option<&Value>) -> Result<Vec<SpriteImage>, String> {
        let records = match records {
            None => &[][..],
            Some(Value::Array(records)) => records.as_slice(),
            Some(_) => return Err("Sprite lists must be nonempty arrays".into()),
        };

        if records.is_empty() && !self.partial {
            return Err("Sprite lists must be nonempty arrays".into());
        }

        let mut sprites: Vec<SpriteImage> = Vec::with_capacity(records.len());
        let mut counts = std::collections::HashMap::new();

        for record in records {
            let Value::Object(record) = record else {
                return Err("Sprite record must be an object".into());
            };

            let id = match record.get("id") {
                Some(Value::Int(id)) => *id as f64,
                Some(Value::Float(id)) => *id,
                _ => return Err("Sprite id must be an integer".into()),
            };

            if id.fract() != 0.0 || !(0.0..=MAX_SPRITE_ID as f64).contains(&id) {
                return Err("Sprite id must be 0 through 65535".into());
            }

            let image = self.read_png(record.get("png"))?;

            if image.palette != self.palette {
                return Err(format!(
                    "Sprite palette differs from the pack palette: {}",
                    record.get("png").map(text_of).unwrap_or_default()
                ));
            }

            let id = id as i64;
            let duplicate = counts.entry(id).or_insert(0);
            sprites.push(SpriteImage {
                id,
                duplicate_index: *duplicate,
                width: image.width,
                height: image.height,
                pixels: image.pixels,
            });
            *duplicate += 1;
        }

        Ok(sprites)
    }

    pub fn ui_image(&self, field: &str) -> Option<&IndexedImage> {
        self.ui
            .iter()
            .find(|(name, _)| name == field)
            .map(|(_, image)| image)
    }
}

fn text_of(value: &Value) -> String {
    match value {
        Value::String(text) => text.clone(),
        other => json::stringify(other, "", false),
    }
}
