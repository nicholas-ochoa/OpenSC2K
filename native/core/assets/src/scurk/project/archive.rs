//! SCURK project archives: a ZIP file with a JSON manifest, a JSON palette,
//! MIF tile sets, resource files, and indexed PNG pixel images. The decoder
//! keeps the first error that stops it, as the script did.

use super::text::{basename, extension, is_identifier};
use super::{
    MAX_CHECKPOINTS, MAX_DATA_BYTES, MAX_DOCUMENTS, MAX_FILE_BYTES, MAX_LAYERS, MAX_MIF_BYTES,
    MAX_RESOURCES, MAX_STAMPS,
};
use super::{Node, index_palette, integer_in, valid_dimensions};
use sc2k_formats::json::{self, Object, Value};
use sc2k_formats::{png, zip};
use std::collections::HashSet;

pub const FORMAT: &str = "opensc2k-scurk";
pub const VERSION: i64 = 2;
pub const MANIFEST: &str = "project.json";
pub const PALETTE: &str = "palette.json";
pub const ORIGINAL_MIF: &str = "original.mif";

const MASK_CLEAR: i32 = 0;
const MASK_OPAQUE: i32 = 255;
const PNG_HEADER_SIZE: usize = 33;
const PNG_WIDTH_OFFSET: usize = 16;
const PNG_HEIGHT_OFFSET: usize = 20;
const MAX_EXTENSION_LENGTH: usize = 10;
const JSON_INDENT: &str = "\t";
const PALETTE_BYTES: usize = 768;

const MANIFEST_FIELDS: [&str; 4] = ["format", "version", "palette", "project"];
const PALETTE_FIELDS: [&str; 2] = ["kind", "colors"];
const PIXEL_FIELDS: [&str; 2] = ["image", "transparency_mask"];
const RGB_KIND: &str = "rgb";
const INDEX_KIND: &str = "index-encoding";

const MISSING_MEMBER: &str = "A project archive member is missing.";
const SIZE_LIMIT: &str = "The project exceeds the resource size limit.";
const PALETTE_INVALID: &str = "The project palette is invalid.";
const COLOR_INVALID: &str = "The project palette color is invalid.";

/// A decoded archive: the project record, and the RGB palette, which is empty
/// for the index palette.
pub struct Decoded {
    pub record: Node,
    pub palette_rgb: Vec<u8>,
}

/// The archive of a checked project record. An empty palette selects the index palette.
pub fn encode(record: &Node, palette_rgb: &[u8]) -> Result<Vec<u8>, String> {
    let palette = if palette_rgb.is_empty() {
        index_palette()
    } else {
        palette_rgb.to_vec()
    };

    if palette.len() != PALETTE_BYTES {
        return Err(PALETTE_INVALID.into());
    }

    let mut encoder = Encoder {
        members: Vec::new(),
        palette,
        error: String::new(),
    };
    let mut project = encoder.snapshot(record, "current");
    encoder.add(
        ORIGINAL_MIF,
        record
            .get("original_mif")
            .map(Node::as_bytes)
            .unwrap_or_default(),
    );
    project.set("original_mif", Node::Str(ORIGINAL_MIF.into()));

    if let Some(Node::Array(checkpoints)) = project.get_mut("checkpoints") {
        let sources = match record.get("checkpoints") {
            Some(Node::Array(sources)) => sources.as_slice(),
            _ => &[],
        };

        for (index, checkpoint) in checkpoints.iter_mut().enumerate() {
            let source = sources
                .get(index)
                .and_then(|entry| entry.get("snapshot"))
                .cloned()
                .unwrap_or(Node::Null);
            let snapshot = encoder.snapshot(&source, &format!("checkpoints/{index:04}"));
            checkpoint.set("snapshot", snapshot);
        }
    }

    if !encoder.error.is_empty() {
        return Err(encoder.error);
    }

    let colors = encoder
        .palette
        .chunks_exact(3)
        .map(|rgb| {
            Value::Array(
                rgb.iter()
                    .map(|channel| Value::Int(i64::from(*channel)))
                    .collect(),
            )
        })
        .collect();
    let mut palette = Object::new();
    palette.insert(
        "kind",
        Value::String(
            if palette_rgb.is_empty() {
                INDEX_KIND
            } else {
                RGB_KIND
            }
            .into(),
        ),
    );
    palette.insert("colors", Value::Array(colors));
    encoder.add(
        PALETTE,
        json::stringify(&Value::Object(palette), JSON_INDENT, true).as_bytes(),
    );

    let mut manifest = Object::new();
    manifest.insert("format", Value::String(FORMAT.into()));
    manifest.insert("version", Value::Int(VERSION));
    manifest.insert("palette", Value::String(PALETTE.into()));
    manifest.insert("project", project.to_json());
    encoder.add(
        MANIFEST,
        json::stringify(&Value::Object(manifest), JSON_INDENT, true).as_bytes(),
    );

    let mut members = encoder.members;
    members.sort_by(|a, b| a.0.cmp(&b.0));
    let borrowed: Vec<(String, &[u8])> = members
        .iter()
        .map(|(name, data)| (name.clone(), data.as_slice()))
        .collect();

    zip::encode(&borrowed, MAX_FILE_BYTES, MAX_FILE_BYTES, false)
}

struct Encoder {
    members: Vec<(String, Vec<u8>)>,
    palette: Vec<u8>,
    error: String,
}

impl Encoder {
    /// Add or replace a member.
    fn add(&mut self, path: &str, data: &[u8]) {
        match self.members.iter_mut().find(|(name, _)| name == path) {
            Some(slot) => slot.1 = data.to_vec(),
            None => self.members.push((path.to_string(), data.to_vec())),
        }
    }

    /// The pixel record of an image member. A transparency mask member holds
    /// the clear pixels when the image uses every palette index.
    fn pixels(&mut self, value: &[i32], width: i64, height: i64, path: &str) -> Node {
        let mut descriptor = Node::empty_object();
        descriptor.set("image", Node::Str(path.into()));
        let used: HashSet<i32> = value.iter().copied().collect();
        let mask_needed = used.contains(&-1) && used.len() == 257;
        let mut image = value.to_vec();

        if mask_needed {
            let mask: Vec<i32> = value
                .iter()
                .map(|&color| if color == -1 { MASK_CLEAR } else { MASK_OPAQUE })
                .collect();
            image
                .iter_mut()
                .filter(|color| **color == -1)
                .for_each(|color| *color = 0);

            match png::encode_indexed(width, height, &mask, &index_palette()) {
                Ok(bytes) => {
                    let mask_path = format!("{}.mask.png", basename(path));
                    self.add(&mask_path, &bytes);
                    descriptor.set("transparency_mask", Node::Str(mask_path));
                }
                Err(error) => {
                    self.error = error;

                    return Node::empty_object();
                }
            }
        }

        match png::encode_indexed(width, height, &image, &self.palette) {
            Ok(bytes) => {
                self.add(path, &bytes);

                descriptor
            }
            Err(error) => {
                self.error = error;

                Node::empty_object()
            }
        }
    }

    fn snapshot(&mut self, value: &Node, prefix: &str) -> Node {
        let mut record = value.clone();
        let mif_path = format!("{prefix}/current.mif");
        self.add(
            &mif_path,
            value
                .get("current_mif")
                .map(Node::as_bytes)
                .unwrap_or_default(),
        );
        record.set("current_mif", Node::Str(mif_path));

        let mut keys = value.get("documents").map(Node::keys).unwrap_or_default();
        keys.sort();

        for (index, key) in keys.iter().enumerate() {
            let directory = format!("{prefix}/documents/{index:04}");
            let Some(document) = record
                .get_mut("documents")
                .and_then(|documents| documents.get_mut(key))
            else {
                continue;
            };
            let width = document.get("width").map(Node::to_int).unwrap_or_default();
            let height = document.get("height").map(Node::to_int).unwrap_or_default();
            let original = document
                .get("original_pixels")
                .map(Node::as_pixels)
                .unwrap_or_default()
                .to_vec();
            let descriptor = self.pixels(
                &original,
                width,
                height,
                &format!("{directory}/original.png"),
            );
            document.set("original_pixels", descriptor);

            if let Some(Node::Array(layers)) = document.get_mut("layers") {
                for (layer_index, layer) in layers.iter_mut().enumerate() {
                    let pixels = layer
                        .get("pixels")
                        .map(Node::as_pixels)
                        .unwrap_or_default()
                        .to_vec();
                    let descriptor = self.pixels(
                        &pixels,
                        width,
                        height,
                        &format!("{directory}/layers/{layer_index:04}.png"),
                    );
                    layer.set("pixels", descriptor);
                }
            }
        }

        let mut keys = value.get("resources").map(Node::keys).unwrap_or_default();
        keys.sort();

        for (index, key) in keys.iter().enumerate() {
            let mut kind = extension(key).to_lowercase();

            if kind.is_empty()
                || kind.chars().count() > MAX_EXTENSION_LENGTH
                || !is_identifier(&kind)
            {
                kind = "bin".into();
            }

            let path = format!("{prefix}/resources/{index:04}.{kind}");
            let data = value
                .get("resources")
                .and_then(|resources| resources.get(key))
                .map(Node::as_bytes)
                .unwrap_or_default();
            self.add(&path, data);

            if let Some(resources) = record.get_mut("resources") {
                resources.set(key, Node::Str(path));
            }
        }

        if let Some(Node::Array(stamps)) = record.get_mut("stamps") {
            for (index, stamp) in stamps.iter_mut().enumerate() {
                let width = stamp.get("width").map(Node::to_int).unwrap_or_default();
                let height = stamp.get("height").map(Node::to_int).unwrap_or_default();
                let pixels = stamp
                    .get("pixels")
                    .map(Node::as_pixels)
                    .unwrap_or_default()
                    .to_vec();
                let descriptor = self.pixels(
                    &pixels,
                    width,
                    height,
                    &format!("{prefix}/stamps/{index:04}.png"),
                );
                stamp.set("pixels", descriptor);
            }
        }

        record
    }
}

/// The project record and palette of an archive.
pub fn decode(bytes: &[u8]) -> Result<Decoded, String> {
    let archive = zip::decode(bytes, MAX_FILE_BYTES, MAX_FILE_BYTES)?;
    let mut members: Vec<(String, Vec<u8>)> = Vec::new();

    // later members with a name replace earlier ones, as in a script dictionary
    for (name, data) in archive.members {
        match members.iter_mut().find(|(existing, _)| *existing == name) {
            Some(slot) => slot.1 = data,
            None => members.push((name, data)),
        }
    }

    let mut decoder = Decoder {
        members,
        used: HashSet::new(),
        palette_rgb: Vec::new(),
        error: String::new(),
        data_bytes: 0,
    };
    let manifest = decoder.json(Some(&Node::Str(MANIFEST.into())));

    if !decoder.error.is_empty() {
        return Err(decoder.error);
    }

    if manifest.get("format").and_then(Node::as_str) != Some(FORMAT)
        || !integer_in(manifest.get("version"), VERSION, VERSION)
    {
        return Err("The project archive format or version is not supported.".into());
    }

    if manifest
        .keys()
        .iter()
        .any(|key| !MANIFEST_FIELDS.contains(&key.as_str()))
    {
        return Err("The project archive manifest has an unsupported field.".into());
    }

    let palette = decoder.json(manifest.get("palette"));

    if palette
        .keys()
        .iter()
        .any(|key| !PALETTE_FIELDS.contains(&key.as_str()))
    {
        return Err("The project palette has an unsupported field.".into());
    }

    let kind = palette
        .get("kind")
        .and_then(Node::as_str)
        .filter(|kind| [RGB_KIND, INDEX_KIND].contains(kind));
    let colors = match palette.get("colors") {
        Some(Node::Array(colors)) if colors.len() == PALETTE_BYTES / 3 => colors,
        _ => return Err(PALETTE_INVALID.into()),
    };

    let Some(kind) = kind.filter(|_| decoder.error.is_empty()) else {
        return Err(PALETTE_INVALID.into());
    };

    for color in colors {
        let Node::Array(channels) = color else {
            return Err(COLOR_INVALID.into());
        };

        if channels.len() != 3 {
            return Err(COLOR_INVALID.into());
        }

        for channel in channels {
            if !integer_in(Some(channel), 0, 255) {
                return Err(COLOR_INVALID.into());
            }

            decoder.palette_rgb.push(channel.to_int() as u8);
        }
    }

    if kind == INDEX_KIND && decoder.palette_rgb != index_palette() {
        return Err("The project index palette is invalid.".into());
    }

    let Some(source) = manifest
        .get("project")
        .filter(|project| project.is_object())
    else {
        return Err("The project record is invalid.".into());
    };

    let mut record = decoder.snapshot(source);

    if !decoder.error.is_empty() {
        return Err(decoder.error);
    }

    let original = decoder.blob(source.get("original_mif"));
    record.set("original_mif", Node::Bytes(original));

    match record.get_mut("checkpoints") {
        None => {}
        Some(Node::Array(checkpoints)) if checkpoints.len() <= MAX_CHECKPOINTS => {
            for entry in checkpoints.iter_mut() {
                let Some(snapshot) = entry
                    .get("snapshot")
                    .filter(|snapshot| snapshot.is_object())
                else {
                    return Err("The project checkpoint is invalid.".into());
                };
                let snapshot = decoder.snapshot(&snapshot.clone());
                entry.set("snapshot", snapshot);

                if !decoder.error.is_empty() {
                    return Err(decoder.error);
                }
            }
        }
        Some(_) => return Err("The project history is invalid.".into()),
    }

    if !decoder.error.is_empty() {
        return Err(decoder.error);
    }

    if let Some((path, _)) = decoder
        .members
        .iter()
        .find(|(path, _)| !decoder.used.contains(path))
    {
        return Err(format!(
            "The project archive contains an unreferenced member: {path}"
        ));
    }

    let palette_rgb = if kind == RGB_KIND {
        decoder.palette_rgb
    } else {
        Vec::new()
    };

    Ok(Decoded {
        record,
        palette_rgb,
    })
}

struct Decoder {
    members: Vec<(String, Vec<u8>)>,
    used: HashSet<String>,
    palette_rgb: Vec<u8>,
    error: String,
    data_bytes: i64,
}

impl Decoder {
    fn member(&mut self, path: Option<&Node>) -> Vec<u8> {
        let found = path
            .and_then(Node::as_str)
            .and_then(|path| self.members.iter().find(|(name, _)| name == path));

        match found {
            Some((name, data)) => {
                self.used.insert(name.clone());

                data.clone()
            }
            None => {
                self.error = MISSING_MEMBER.into();

                Vec::new()
            }
        }
    }

    /// A JSON object member. The script read the text up to its first NUL byte.
    fn json(&mut self, path: Option<&Node>) -> Node {
        let bytes = self.member(path);

        if !self.error.is_empty() {
            return Node::empty_object();
        }

        let end = bytes
            .iter()
            .position(|byte| *byte == 0)
            .unwrap_or(bytes.len());
        let text = String::from_utf8_lossy(&bytes[..end]);

        match json::parse(&text) {
            Ok(value @ Value::Object(_)) => Node::from_json(&value),
            _ => {
                self.error = "A project JSON member is invalid.".into();

                Node::empty_object()
            }
        }
    }

    fn charge(&mut self, size: i64) -> bool {
        self.data_bytes += size;

        if self.data_bytes > MAX_DATA_BYTES {
            self.error = SIZE_LIMIT.into();
        }

        self.error.is_empty()
    }

    fn blob(&mut self, path: Option<&Node>) -> Vec<u8> {
        let bytes = self.member(path);

        if bytes.len() > MAX_MIF_BYTES {
            self.error = "A project resource exceeds its size limit.".into();
        }

        if !self.charge(bytes.len() as i64) {
            return Vec::new();
        }

        bytes
    }

    fn image(&mut self, path: Option<&Node>, width: i64, height: i64, colors: &[u8]) -> Vec<i32> {
        let bytes = self.member(path);

        if !self.error.is_empty() {
            return Vec::new();
        }

        // check the dimensions before the PNG decoder allocates its output
        let dimension = |offset: usize| {
            i64::from(u32::from_be_bytes([
                bytes[offset],
                bytes[offset + 1],
                bytes[offset + 2],
                bytes[offset + 3],
            ]))
        };

        if bytes.len() < PNG_HEADER_SIZE
            || dimension(PNG_WIDTH_OFFSET) != width
            || dimension(PNG_HEIGHT_OFFSET) != height
        {
            self.error = "A project PNG has the wrong dimensions.".into();

            return Vec::new();
        }

        match png::decode_indexed(&bytes, true) {
            Ok(decoded) if decoded.palette == colors => decoded.pixels,
            Ok(_) => {
                self.error = "A project PNG has the wrong ordered palette.".into();

                Vec::new()
            }
            Err(error) => {
                self.error = error;

                Vec::new()
            }
        }
    }

    fn pixels(&mut self, value: Option<&Node>, width: i64, height: i64) -> Vec<i32> {
        let Some(value) =
            value.filter(|value| value.is_object() && self.charge(width * height * 2))
        else {
            if self.error.is_empty() {
                self.error = "The project pixel record is invalid.".into();
            }

            return Vec::new();
        };

        if value
            .keys()
            .iter()
            .any(|key| !PIXEL_FIELDS.contains(&key.as_str()))
        {
            self.error = "The project pixel record has an unsupported field.".into();

            return Vec::new();
        }

        let colors = self.palette_rgb.clone();
        let mut result = self.image(value.get("image"), width, height, &colors);

        if !self.error.is_empty() {
            return Vec::new();
        }

        if let Some(mask_path) = value.get("transparency_mask") {
            let mask = self.image(Some(mask_path), width, height, &index_palette());

            if !self.error.is_empty() {
                return Vec::new();
            }

            for (pixel, mask) in result.iter_mut().zip(mask) {
                if (mask != MASK_CLEAR && mask != MASK_OPAQUE) || *pixel < 0 {
                    self.error = "The project transparency mask is invalid.".into();

                    return Vec::new();
                }

                if mask == MASK_CLEAR {
                    *pixel = -1;
                }
            }
        }

        result
    }

    /// Replace the member paths of a snapshot with their data.
    fn snapshot(&mut self, value: &Node) -> Node {
        let mut record = value.clone();
        let mif = self.blob(value.get("current_mif"));
        record.set("current_mif", Node::Bytes(mif));

        if let Some(documents) = record.get_mut("documents") {
            if !documents.is_object() || documents.len() > MAX_DOCUMENTS {
                self.error = "The project documents are invalid.".into();

                return Node::empty_object();
            }

            if let Node::Object(entries) = documents {
                for (_, document) in entries.iter_mut() {
                    if !document.is_object()
                        || !valid_dimensions(document.get("width"), document.get("height"))
                    {
                        self.error = "The project document size is invalid.".into();

                        return Node::empty_object();
                    }

                    if !matches!(document.get("layers"), Some(Node::Array(layers)) if !layers.is_empty() && layers.len() <= MAX_LAYERS)
                    {
                        self.error = "The project layers are invalid.".into();

                        return Node::empty_object();
                    }

                    let width = document.get("width").map(Node::to_int).unwrap_or_default();
                    let height = document.get("height").map(Node::to_int).unwrap_or_default();
                    let original = self.pixels(
                        document.get("original_pixels").cloned().as_ref(),
                        width,
                        height,
                    );
                    document.set("original_pixels", Node::Pixels(original));

                    if let Some(Node::Array(layers)) = document.get_mut("layers") {
                        for layer in layers.iter_mut() {
                            if !layer.is_object() {
                                self.error = "The project layer is invalid.".into();

                                return Node::empty_object();
                            }

                            let pixels =
                                self.pixels(layer.get("pixels").cloned().as_ref(), width, height);
                            layer.set("pixels", Node::Pixels(pixels));

                            if !self.error.is_empty() {
                                return Node::empty_object();
                            }
                        }
                    }
                }
            }
        }

        if let Some(resources) = record.get_mut("resources") {
            if !resources.is_object() || resources.len() > MAX_RESOURCES {
                self.error = "The project resources are invalid.".into();

                return Node::empty_object();
            }

            if let Node::Object(entries) = resources {
                for (_, resource) in entries.iter_mut() {
                    let data = self.blob(Some(&resource.clone()));
                    *resource = Node::Bytes(data);
                }
            }
        }

        if let Some(stamps) = record.get_mut("stamps") {
            let Node::Array(items) = stamps else {
                self.error = "The project stamps are invalid.".into();

                return Node::empty_object();
            };

            if items.len() > MAX_STAMPS {
                self.error = "The project stamps are invalid.".into();

                return Node::empty_object();
            }

            for stamp in items.iter_mut() {
                if !stamp.is_object() || !valid_dimensions(stamp.get("width"), stamp.get("height"))
                {
                    self.error = "The project stamp size is invalid.".into();

                    return Node::empty_object();
                }

                let width = stamp.get("width").map(Node::to_int).unwrap_or_default();
                let height = stamp.get("height").map(Node::to_int).unwrap_or_default();
                let pixels = self.pixels(stamp.get("pixels").cloned().as_ref(), width, height);
                stamp.set("pixels", Node::Pixels(pixels));

                if !self.error.is_empty() {
                    return Node::empty_object();
                }
            }
        }

        record
    }
}
