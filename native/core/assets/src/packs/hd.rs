//! HD sprite packs: full-color art that replaces the look of indexed city
//! sprites, as HdSpritePack. Refer to docs/hd-sprite-pack-format.md.

use super::{PathProblem, extension, path_join, path_problem};
use sc2k_formats::json::{self, Value};
use sc2k_formats::png;
use std::collections::HashMap;

pub const FORMAT: &str = "opensc2k-hd-sprites";
const MAX_EDGE: u32 = 4096;
/// Each frame of a strip has two more rows in the GPU atlas.
const MAX_STRIP_HEIGHT: u32 = 8190;
const MAX_FRAMES: i64 = 32;
const FRAME_RATES: [i64; 2] = [5, 8];
/// Decoded RGBA bytes of all images. Each image counts one time.
const MAX_DECODED_BYTES: usize = 512 * 1024 * 1024;

/// An RGBA image with straight alpha.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Image {
    pub width: u32,
    pub height: u32,
    pub pixels: Vec<u8>,
}

/// The art of one indexed sprite.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct HdSprite {
    pub image: std::sync::Arc<Image>,
    /// The logical rows that the art covers, from the bottom of the sprite.
    pub height: i64,
    /// Equal frames from top to bottom, each the size of `image`.
    pub animation: Option<std::sync::Arc<Image>>,
    pub frames: i64,
    pub fps: i64,
}

#[derive(Clone, Debug, Default)]
pub struct HdPack {
    pub name: String,
    pub redraw_small_highway_ground: bool,
    pub sprites: HashMap<i64, HdSprite>,
    /// The indexed size that each record needs.
    pub logical_sizes: HashMap<i64, (i64, i64)>,
}

fn whole(value: Option<&Value>) -> i64 {
    match value {
        Some(Value::Int(number)) => *number,
        Some(Value::Float(number)) if number.fract() == 0.0 => *number as i64,
        _ => -1,
    }
}

struct Loader {
    root: String,
    images: HashMap<String, std::sync::Arc<Image>>,
    decoded_bytes: usize,
}

impl Loader {
    fn image(&mut self, value: Option<&Value>) -> Result<std::sync::Arc<Image>, String> {
        let path = value
            .and_then(Value::as_str)
            .filter(|path| !path.is_empty())
            .ok_or("PNG path must be a nonempty string")?;

        match path_problem(path) {
            Some(PathProblem::NotRelative) => return Err("PNG paths must be relative and use forward slashes".into()),
            Some(PathProblem::BadComponent) => return Err("PNG paths must not contain empty, dot, or parent components".into()),
            None => {}
        }

        if extension(path).to_lowercase() != "png" {
            return Err("HD sprites must be PNG files".into());
        }

        if let Some(image) = self.images.get(path) {
            return Ok(image.clone());
        }

        let bytes = std::fs::read(path_join(&self.root, path)).map_err(|_| format!("Cannot read {path}"))?;
        let decoded = png::decode_rgba(&bytes).map_err(|_| format!("Cannot read {path}"))?;

        if decoded.width > MAX_EDGE || decoded.height > MAX_STRIP_HEIGHT {
            return Err(format!("{path} is too large"));
        }

        self.decoded_bytes += decoded.pixels.len();

        if self.decoded_bytes > MAX_DECODED_BYTES {
            return Err(format!(
                "The HD sprites use more than {} MiB of memory",
                MAX_DECODED_BYTES / 1048576
            ));
        }

        let image = std::sync::Arc::new(Image {
            width: decoded.width,
            height: decoded.height,
            pixels: decoded.pixels,
        });
        self.images.insert(path.to_string(), image.clone());

        Ok(image)
    }
}

impl HdPack {
    /// The pack of a folder, or of the pack.json path in it.
    pub fn load(root: &str) -> Result<Self, String> {
        let root = root.strip_suffix("/pack.json").unwrap_or(root);
        let text = std::fs::read_to_string(std::path::Path::new(root).join("pack.json")).map_err(|_| "Missing pack.json".to_string())?;
        let manifest = match json::parse(&text) {
            Ok(Value::Object(object)) => object,
            _ => return Err("pack.json must contain a JSON object".into()),
        };

        if manifest.get("format").and_then(Value::as_str) != Some(FORMAT) || whole(manifest.get("version")) != 1 {
            return Err("Unsupported HD sprite pack format or version".into());
        }

        let name = manifest.get("name").and_then(Value::as_str).unwrap_or_default().to_string();

        if name.trim().is_empty() {
            return Err("HD sprite pack name is required".into());
        }

        let redraw = match manifest.get("redraw_small_highway_ground") {
            None => false,
            Some(Value::Bool(value)) => *value,
            Some(_) => return Err("redraw_small_highway_ground must be a boolean".into()),
        };
        let records = match manifest.get("sprites") {
            Some(Value::Array(records)) if !records.is_empty() => records,
            _ => return Err("sprites must be a nonempty array".into()),
        };
        let mut loader = Loader {
            root: root.to_string(),
            images: HashMap::new(),
            decoded_bytes: 0,
        };
        let mut pack = HdPack {
            name,
            redraw_small_highway_ground: redraw,
            ..HdPack::default()
        };

        for record in records {
            let Value::Object(record) = record else {
                return Err("Sprite record must be an object".into());
            };

            let id = whole(record.get("id"));

            if !(0..=65535).contains(&id) {
                return Err("Sprite id must be 0 through 65535".into());
            }

            if pack.sprites.contains_key(&id) {
                return Err(format!("Sprite {id} occurs more than one time"));
            }

            let logical = match record.get("logical_size") {
                Some(Value::Array(size)) if size.len() == 2 => (whole(Some(&size[0])), whole(Some(&size[1]))),
                _ => (-1, -1),
            };

            if logical.0 < 1 || logical.1 < 1 {
                return Err(format!("Sprite {id}: logical_size must be two positive integers"));
            }

            let height = record.get("display_height").map_or(logical.1, |value| whole(Some(value)));

            if height < logical.1 || height > i64::from(MAX_EDGE) {
                return Err(format!(
                    "Sprite {id}: display_height must be from the logical height through {MAX_EDGE}"
                ));
            }

            let image = loader.image(record.get("png"))?;

            if image.width > MAX_EDGE || image.height > MAX_EDGE {
                return Err(format!("Sprite {id}: images must be at most {MAX_EDGE} pixels on each side"));
            }

            let mut sprite = HdSprite {
                image,
                height,
                animation: None,
                frames: 1,
                fps: 8,
            };

            if let Some(animation) = record.get("animation") {
                let Value::Object(animation) = animation else {
                    return Err(format!("Sprite {id}: animation must be an object"));
                };

                sprite.frames = whole(animation.get("frames"));
                sprite.fps = animation.get("fps").map_or(8, |value| whole(Some(value)));

                if !(2..=MAX_FRAMES).contains(&sprite.frames) {
                    return Err(format!("Sprite {id}: an animation has 2 through {MAX_FRAMES} frames"));
                }

                if !FRAME_RATES.contains(&sprite.fps) {
                    return Err(format!("Sprite {id}: the animation rate must be 5 or 8 frames each second"));
                }

                let strip = loader.image(animation.get("png"))?;

                if strip.width != sprite.image.width || i64::from(strip.height) != i64::from(sprite.image.height) * sprite.frames {
                    return Err(format!(
                        "Sprite {id}: the animation must stack frames of the size of the still image"
                    ));
                }

                if i64::from(strip.height) + sprite.frames * 2 > i64::from(MAX_STRIP_HEIGHT) {
                    return Err(format!("Sprite {id}: the animation is too tall for the sprite atlas"));
                }

                sprite.animation = Some(strip);
            }

            pack.sprites.insert(id, sprite);
            pack.logical_sizes.insert(id, logical);
        }

        Ok(pack)
    }
}
