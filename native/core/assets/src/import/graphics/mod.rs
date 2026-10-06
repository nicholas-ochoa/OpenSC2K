//! Indexed graphics packs from the source records of a supplied game, as
//! Sc2ImportGraphics. A pack is a folder of PNG images and a `pack.json`.

pub mod dos_ui;
pub mod palette;
mod sink;

#[cfg(test)]
mod tests;

use self::palette::{
    Rgb, mac_color_table, mac_palette, rgb_bytes, rgb_colors, text_mode_bytes,
    windows_layout_index, windows_layout_palette,
};
use super::sprites::{self, SpriteSet};
use crate::packs::revision;
use crate::palette::{COLOR_COUNT, FAST_CYCLE_COUNT, SLOW_CYCLE_COUNT};
use sc2k_formats::json::{self, Object, Value};
use sc2k_formats::{bmp, png, sprite, sprite_archive};
use std::collections::HashSet;

pub use sink::{Folder, Sink};

const SHIFTED_FAST_CYCLE_COLORS: &str = "CULT1.RAW";
const SHIFTED_SLOW_CYCLE_COLORS: &str = "CULT2.RAW";
const MAC_FAST_CYCLE_TABLE: &str = "clut/500";
const MAC_SLOW_CYCLE_TABLE: &str = "clut/501";
const NETWORK_EDITION: &str = "Windows Network Edition";
const DOS: &str = "DOS";
const BMP_MIN_SIZE: usize = 54;
const BMP_BITS_OFFSET: usize = 28;
const BMP_COLORS_OFFSET: usize = 46;
const INDEXED_BITS: u16 = 8;
const WINDOWS_PALETTE_SIZE: usize = 1024;
const MAX_SPRITE_DIMENSION: i64 = 4096;
const LARGE_SPRITE_IDS: std::ops::Range<i64> = 1001..1500;
const LARGE_SPRITE_BASE: i64 = 1000;
const PALETTE_IMAGE_SIZE: i64 = 16;
/// The interface images of a graphics pack, as GraphicsPack.UI_FIELDS.
pub const UI_FIELDS: [&str; 5] = [
    "toolbar_art",
    "industry_icons",
    "city_map_icons",
    "simnation_sprites",
    "forest_protest_image",
];
/// Bitmap resources of the interface images: the field and the resource ID of type 2.
const UI_BITMAPS: [(&str, i64); 3] = [
    ("toolbar_art", 2),
    ("industry_icons", 178),
    ("city_map_icons", 247),
];
const UI_FILES: [(&str, &str); 2] = [
    ("simnation_sprites", "NEIGHBOR.BMP"),
    ("forest_protest_image", "403.BMP"),
];
/// Desktop sprite archives: the file name and the Macintosh `SPRT` resource ID.
const DESKTOP_ARCHIVES: [(&str, i64); 3] = [("LARGE", 129), ("SMALLMED", 128), ("SPECIAL", 130)];
const DOS_ARCHIVES: [&str; 3] = ["LARGE", "SMALL", "OTHER"];

/// One source record: a file when `kind` is empty, else a typed resource.
#[derive(Clone, Debug, Default)]
pub struct Resource {
    pub name: String,
    pub kind: String,
    pub id: i64,
    pub bytes: Vec<u8>,
    pub source: String,
}

/// An indexed interface image and its 256 RGB colors.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct UiImage {
    pub width: i64,
    pub height: i64,
    pub pixels: Vec<i32>,
    pub palette: Vec<u8>,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Outcome {
    pub error: String,
    pub warnings: Vec<String>,
    pub count: i64,
}

#[derive(Clone, Debug)]
enum Pixels {
    Encoded {
        bytes: Vec<u8>,
        offset: usize,
        allow_unpadded_odd_runs: bool,
    },
    Indices(Vec<i32>),
}

#[derive(Clone, Debug)]
struct Entry {
    sprite_id: i64,
    width: i64,
    height: i64,
    pixels: Pixels,
}

impl Entry {
    fn decode(&self) -> Result<Vec<i32>, String> {
        match &self.pixels {
            Pixels::Indices(indices) => Ok(indices.clone()),
            Pixels::Encoded {
                bytes,
                offset,
                allow_unpadded_odd_runs,
            } => sprite::decode(
                bytes,
                self.width as i32,
                self.height as i32,
                *allow_unpadded_odd_runs,
            )
            .map(|decoded| decoded.pixels)
            .map_err(|error| format!("sprite {} at 0x{offset:x}: {error}", self.sprite_id)),
        }
    }
}

#[derive(Default)]
struct Group {
    entries: Vec<Entry>,
    ids: HashSet<i64>,
}

impl Group {
    fn push(&mut self, entry: Entry) {
        self.ids.insert(entry.sprite_id);
        self.entries.push(entry);
    }
}

/// Write a graphics pack of `resources` to `sink`. The caller checks the
/// written pack and removes it after an error.
pub fn export(resources: &[Resource], platform: &str, label: &str, sink: &mut dyn Sink) -> Outcome {
    let mut importer = Importer::default();
    importer.read(resources, platform);

    if importer.outcome.error.is_empty() {
        importer.export(platform, label, sink);
    }

    importer.outcome
}

#[derive(Default)]
struct Importer {
    outcome: Outcome,
    files: Vec<(String, usize)>,
    typed: Vec<(String, usize)>,
    resources: Vec<Resource>,
    palette: Option<Vec<Rgb>>,
    scenario_palette: Option<Vec<Rgb>>,
    ui: Vec<(String, UiImage)>,
    large: Group,
    small: Group,
    sprite_index_map: Vec<i32>,
}

impl Importer {
    fn file(&self, name: &str) -> Option<&Resource> {
        self.files
            .iter()
            .find(|(key, _)| key == name)
            .map(|(_, index)| &self.resources[*index])
    }

    fn typed(&self, key: &str) -> Option<&Resource> {
        self.typed
            .iter()
            .find(|(known, _)| known == key)
            .map(|(_, index)| &self.resources[*index])
    }

    fn warn(&mut self, message: impl Into<String>) {
        self.outcome.warnings.push(message.into());
    }

    fn read(&mut self, resources: &[Resource], platform: &str) {
        self.resources = resources.to_vec();

        for (index, resource) in resources.iter().enumerate() {
            if resource.kind.is_empty() {
                let name = resource.name.to_uppercase();

                if !self.files.iter().any(|(known, _)| *known == name) {
                    self.files.push((name, index));
                }
            } else {
                let source_file = resource
                    .source
                    .rsplit(['/', '\\'])
                    .next()
                    .unwrap_or_default();

                if source_file.to_uppercase().contains("SCURK") {
                    continue;
                }

                let key = format!("{}/{}", resource.kind, resource.id);

                if !self.typed.iter().any(|(known, _)| *known == key) {
                    self.typed.push((key, index));
                }
            }
        }

        self.palette = self.bmp_palette("PAL_MSTR.BMP");
        self.scenario_palette = self.bmp_palette("PAL_MAC.BMP");
        self.read_shifted_palettes();

        for (field, id) in UI_BITMAPS {
            if platform == NETWORK_EDITION {
                continue;
            }

            if let Some(resource) = self.typed(&format!("2/{id}")).cloned() {
                self.add_ui(field, &resource, false);
            }
        }

        // the DOS version has its toolbar as a raw image
        if platform == DOS
            && let (Some(raw), Some(colors)) = (self.file("TOOL.RAW"), self.file("MINE.PAL"))
        {
            match dos_ui::toolbar(&raw.bytes, &colors.bytes) {
                Ok(toolbar) => self.set_ui("toolbar_art", toolbar),
                Err(error) => self.warn(format!("toolbar_art: {error}")),
            }
        }

        for (field, name) in UI_FILES {
            if let Some(resource) = self.file(name).cloned() {
                self.add_ui(field, &resource, true);
            }
        }

        if self.palette.is_none() && !self.ui.is_empty() {
            // UI-only packs never replace the active city palette.
            self.palette = Some(rgb_colors(&self.ui[0].1.palette));
            self.warn("No city palette was found. Only interface images can be imported.");
        } else {
            self.read_sprites();
        }

        if self.palette.is_none() {
            self.outcome.error = "No readable city palette or interface bitmap was found.".into();
        } else if self.large.entries.is_empty()
            && self.small.entries.is_empty()
            && self.ui.is_empty()
        {
            self.outcome.error = "No convertible graphics were found.".into();
        }
    }

    /// The DOS, Macintosh, and Network Edition palettes, in that order, when
    /// the Windows palette bitmap is missing.
    fn read_shifted_palettes(&mut self) {
        if self.palette.is_none()
            && let Some(bytes) = self.file("MINE.PAL").map(|resource| resource.bytes.clone())
            && bytes.len() == COLOR_COUNT * 3
        {
            self.palette = Some(rgb_colors(&bytes));
            let fast = self
                .file(SHIFTED_FAST_CYCLE_COLORS)
                .map(|resource| rgb_colors(&resource.bytes))
                .unwrap_or_default();
            let slow = self
                .file(SHIFTED_SLOW_CYCLE_COLORS)
                .map(|resource| rgb_colors(&resource.bytes))
                .unwrap_or_default();
            self.use_windows_layout(&fast, &slow);
        }

        if self.palette.is_none()
            && let Some(colors) = self
                .typed("pltt/0")
                .and_then(|resource| mac_palette(&resource.bytes))
        {
            self.palette = Some(colors);
            let fast = self
                .typed(MAC_FAST_CYCLE_TABLE)
                .map(|resource| mac_color_table(&resource.bytes))
                .unwrap_or_default();
            let slow = self
                .typed(MAC_SLOW_CYCLE_TABLE)
                .map(|resource| mac_color_table(&resource.bytes))
                .unwrap_or_default();
            self.use_windows_layout(&fast, &slow);
        }

        if self.palette.is_none()
            && let Some(mut bytes) = self.file("SC2K.PAL").map(|resource| resource.bytes.clone())
        {
            if bytes.len() != WINDOWS_PALETTE_SIZE {
                bytes = text_mode_bytes(&bytes);
            }

            if bytes.len() == WINDOWS_PALETTE_SIZE {
                self.palette = Some(
                    bytes
                        .chunks_exact(4)
                        .map(|bgr| [bgr[2], bgr[1], bgr[0]])
                        .collect(),
                );
            }
        }
    }

    fn read_sprites(&mut self) {
        for (name, id) in DESKTOP_ARCHIVES {
            let resource = self
                .file(&format!("{name}.DAT"))
                .or_else(|| self.typed(&format!("SPRT/{id}")))
                .cloned();

            if let Some(resource) = resource
                && self.file(&format!("{name}.HED")).is_none()
            {
                self.add_desktop(&resource, name == "LARGE");
            }
        }

        for name in DOS_ARCHIVES {
            let (Some(data), Some(header)) = (
                self.file(&format!("{name}.DAT")),
                self.file(&format!("{name}.HED")),
            ) else {
                continue;
            };
            let decoded = sprites::dos(&header.bytes, &data.bytes);
            self.outcome
                .warnings
                .extend(decoded.warnings.iter().cloned());

            if !decoded.error.is_empty() {
                self.warn(format!("{name}: {}", decoded.error));
            } else {
                let group = if name == "LARGE" {
                    &mut self.large
                } else {
                    &mut self.small
                };
                append(group, &decoded);
            }
        }

        if (self.large.entries.is_empty() || self.small.entries.is_empty())
            && let Some(resource) = self.typed("TSET/1")
        {
            let tiles = sprites::mac_tile_set(&resource.bytes);
            self.add_tile_groups(&tiles);
        }

        if (self.large.entries.is_empty() || self.small.entries.is_empty())
            && let Some(resource) = self.file("TILES.DB")
        {
            let tiles = sprites::tiles_database(&resource.bytes);
            self.add_tile_groups(&tiles);
        }
    }

    fn add_tile_groups(&mut self, tiles: &SpriteSet) {
        let need_large = self.large.entries.is_empty();
        let need_small = self.small.entries.is_empty();
        self.outcome.warnings.extend(tiles.warnings.iter().cloned());

        if !tiles.error.is_empty() {
            self.warn(tiles.error.clone());
        }

        for entry in tiles.sprites.iter().map(entry) {
            let large = entry.sprite_id >= LARGE_SPRITE_BASE;

            if (large && !need_large) || (!large && !need_small) {
                continue;
            }

            if large {
                &mut self.large
            } else {
                &mut self.small
            }
            .push(entry);
        }
    }

    fn use_windows_layout(&mut self, fast: &[Rgb], slow: &[Rgb]) {
        if fast.len() != FAST_CYCLE_COUNT || slow.len() != SLOW_CYCLE_COUNT {
            self.warn(
                "The source has no complete palette cycle colors. Animated colors can look wrong.",
            );
        }

        let source = self.palette.take().unwrap_or_default();
        self.palette = Some(windows_layout_palette(&source, fast, slow));
        self.sprite_index_map = (0..COLOR_COUNT as i32).map(windows_layout_index).collect();
    }

    fn bmp_palette(&self, name: &str) -> Option<Vec<Rgb>> {
        let bytes = &self.file(name)?.bytes;

        if bytes.len() < BMP_MIN_SIZE
            || u16::from_le_bytes([bytes[BMP_BITS_OFFSET], bytes[BMP_BITS_OFFSET + 1]])
                != INDEXED_BITS
            || ![0, COLOR_COUNT as u32].contains(&u32::from_le_bytes(
                bytes[BMP_COLORS_OFFSET..BMP_COLORS_OFFSET + 4]
                    .try_into()
                    .unwrap(),
            ))
        {
            return None;
        }

        bmp::decode_indexed(bytes, true)
            .ok()
            .map(|decoded| rgb_colors(&decoded.palette))
    }

    fn set_ui(&mut self, field: &str, image: UiImage) {
        match self.ui.iter_mut().find(|(known, _)| known == field) {
            Some(slot) => slot.1 = image,
            None => self.ui.push((field.to_string(), image)),
        }
    }

    fn add_ui(&mut self, field: &str, resource: &Resource, file_header: bool) {
        match bmp::decode_indexed(&resource.bytes, file_header) {
            Ok(decoded) => self.set_ui(
                field,
                UiImage {
                    width: decoded.width as i64,
                    height: decoded.height as i64,
                    pixels: decoded.pixels,
                    palette: decoded.palette,
                },
            ),
            Err(error) => self.warn(format!("{field}: {error}")),
        }
    }

    fn add_desktop(&mut self, resource: &Resource, large: bool) {
        let entries = match sprite_archive::parse(&resource.bytes) {
            Ok(entries) => entries,
            Err(error) => return self.warn(format!("{}: {error}", resource.name)),
        };

        for record in entries {
            if record.width > MAX_SPRITE_DIMENSION || record.height > MAX_SPRITE_DIMENSION {
                self.warn(format!(
                    "Sprite {} has excessive dimensions.",
                    record.sprite_id
                ));
                continue;
            }

            let entry = Entry {
                sprite_id: record.sprite_id,
                width: record.width,
                height: record.height,
                pixels: Pixels::Encoded {
                    bytes: record.encoded,
                    offset: record.offset,
                    allow_unpadded_odd_runs: false,
                },
            };

            if let Err(error) = entry.decode() {
                self.warn(format!("{}: {error}", resource.name));
                continue;
            }

            if large {
                &mut self.large
            } else {
                &mut self.small
            }
            .push(entry);
        }
    }

    fn export(&mut self, platform: &str, label: &str, sink: &mut dyn Sink) {
        let mut manifest = Object::new();
        manifest.insert("format", Value::String("opensc2k-graphics".into()));
        manifest.insert("version", Value::Int(1));
        manifest.insert("name", Value::String(format!("{label} Graphics")));
        manifest.insert("source_platform", Value::String(platform.into()));
        manifest.insert("partial", Value::Bool(true));
        manifest.insert("palette", Value::String("palette.png".into()));
        manifest.insert(
            "import_revision",
            Value::Int(revision::current("graphics", platform)),
        );
        let indices: Vec<i32> = (0..COLOR_COUNT as i32).collect();
        let palette = rgb_bytes(self.palette.as_deref().unwrap_or_default());
        self.png(
            sink,
            "palette.png",
            PALETTE_IMAGE_SIZE,
            PALETTE_IMAGE_SIZE,
            &indices,
            &palette,
        );

        if let Some(scenario) = &self.scenario_palette {
            let scenario = rgb_bytes(scenario);
            self.png(
                sink,
                "scenario-palette.png",
                PALETTE_IMAGE_SIZE,
                PALETTE_IMAGE_SIZE,
                &indices,
                &scenario,
            );
            manifest.insert(
                "scenario_palette",
                Value::String("scenario-palette.png".into()),
            );
        }

        for (field, large) in [("large_sprites", true), ("small_medium_sprites", false)] {
            let entries = std::mem::take(if large {
                &mut self.large.entries
            } else {
                &mut self.small.entries
            });
            let mut records = Vec::new();

            for (index, entry) in entries.iter().enumerate() {
                if !self.outcome.error.is_empty() {
                    return;
                }

                let mut pixels = entry.decode().unwrap_or_default();

                if !self.sprite_index_map.is_empty() {
                    pixels
                        .iter_mut()
                        .filter(|pixel| **pixel >= 0)
                        .for_each(|pixel| *pixel = self.sprite_index_map[*pixel as usize]);
                }

                let relative = format!("{field}/{index:04}-{}.png", entry.sprite_id);
                self.png(
                    sink,
                    &relative,
                    entry.width,
                    entry.height,
                    &pixels,
                    &palette,
                );
                let mut record = Object::new();
                record.insert("id", Value::Int(entry.sprite_id));
                record.insert("png", Value::String(relative));
                records.push(Value::Object(record));
                self.outcome.count += 1;
            }

            if large {
                &mut self.large.entries
            } else {
                &mut self.small.entries
            }
            .extend(entries);
            manifest.insert(field, Value::Array(records));
        }

        let mut ui = Object::new();

        for (field, image) in std::mem::take(&mut self.ui) {
            let relative = format!("ui/{field}.png");
            self.png(
                sink,
                &relative,
                image.width,
                image.height,
                &image.pixels,
                &image.palette,
            );
            ui.insert(&field, Value::String(relative));
            self.outcome.count += 1;
            self.ui.push((field, image));
        }

        manifest.insert("ui", Value::Object(ui));
        self.warn_missing();
        self.write(
            sink,
            "pack.json",
            json::stringify(&Value::Object(manifest), "\t", true).as_bytes(),
        );
    }

    fn warn_missing(&mut self) {
        if self.large.entries.is_empty() || self.small.entries.is_empty() {
            self.warn("Graphics are missing a city sprite size group. The pack needs a compatible base set for that group.");
        } else {
            let missing = LARGE_SPRITE_IDS
                .filter(|id| !self.large.ids.contains(id))
                .count();

            if missing > 0 {
                self.warn(format!("Graphics are missing {missing} standard large sprite IDs. This can occur in demos or incomplete copies."));
            }
        }

        if self.ui.len() < UI_FIELDS.len() {
            self.warn(format!(
                "Graphics include {} of {} core interface images. Missing interface artwork uses the available base images or built-in controls.",
                self.ui.len(),
                UI_FIELDS.len()
            ));
        }
    }

    fn png(
        &mut self,
        sink: &mut dyn Sink,
        path: &str,
        width: i64,
        height: i64,
        pixels: &[i32],
        palette: &[u8],
    ) {
        if !self.outcome.error.is_empty() {
            return;
        }

        match png::encode_indexed(width, height, pixels, palette) {
            Ok(bytes) => self.write(sink, path, &bytes),
            Err(error) => self.outcome.error = error,
        }
    }

    fn write(&mut self, sink: &mut dyn Sink, relative: &str, bytes: &[u8]) {
        if self.outcome.error.is_empty()
            && let Err(error) = sink.write(relative, bytes)
        {
            self.outcome.error = error;
        }
    }
}

fn entry(sprite: &sprites::Sprite) -> Entry {
    let pixels = if sprite.indices.is_empty() {
        Pixels::Encoded {
            bytes: sprite.encoded.clone(),
            offset: 0,
            allow_unpadded_odd_runs: sprite.allow_unpadded_odd_runs,
        }
    } else {
        Pixels::Indices(sprite.indices.clone())
    };

    Entry {
        sprite_id: sprite.sprite_id,
        width: sprite.width as i64,
        height: sprite.height as i64,
        pixels,
    }
}

fn append(group: &mut Group, set: &SpriteSet) {
    for sprite in &set.sprites {
        group.push(entry(sprite));
    }
}
