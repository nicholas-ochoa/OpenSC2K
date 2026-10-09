//! A city document: the chunks of an SC2, SCN, SCLG, sc2kfix or SC2X file, and
//! the SC2X version 4 state outside the chunks. `parse` selects the reader by
//! the file signature; `serialize` writes the format of the document.
//!
//! This is the native form of `Sc2File`. The chunk list keeps each stored
//! payload, so an unchanged chunk of an original file writes its exact bytes.

use super::sc2::{self, FULL_MAP_CHUNKS, HALF_MAP_CHUNKS, MAP_SIZES, QUARTER_MAP_CHUNKS, RAW_CHUNKS};
use super::sc2x::metadata::{self, Metadata};
use super::{rle, sc2kfix, sc2x};
use crate::sim::grid;
use crate::sim::ids::{sc2misc_layout, sc2thing_layout};
use crate::sim::overlay::LAYERED_PLANES;

/// The large-map version of an SC2X version 4 working document.
pub const SC2X_VERSION: i64 = 4;

/// From this SCLG version, the data maps have one value per tile.
const FULL_RESOLUTION_VERSION: i64 = 3;

/// The CNAM payload: a length or flag byte, 30 ASCII bytes and a terminator.
pub const CITY_NAME_SIZE: usize = 32;
const CITY_NAME_TEXT: usize = 30;

/// The first CNAM byte of a city name chunk that the Windows game adds.
const CITY_NAME_FLAG: u8 = 0x1f;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Chunk {
    pub id: String,
    pub source_offset: usize,
    pub stored: Vec<u8>,
    pub decoded: Vec<u8>,
    /// -1 when the chunk has no fixed size.
    pub expected_size: i64,
    pub compressed: bool,
    pub dirty: bool,
}

impl Chunk {
    pub fn new(id: &str, decoded: Vec<u8>, expected_size: i64) -> Self {
        Self {
            id: id.to_string(),
            decoded,
            expected_size,
            ..Self::default()
        }
    }

    /// Replaces the decoded payload. A payload of the wrong size is refused.
    pub fn set_decoded(&mut self, value: Vec<u8>) -> bool {
        if self.expected_size >= 0 && value.len() as i64 != self.expected_size {
            return false;
        }

        self.decoded = value;
        self.dirty = true;

        true
    }

    /// The payload that a save writes: the original bytes of an unchanged chunk.
    pub fn payload_for_write(&self) -> Vec<u8> {
        if !self.dirty {
            return self.stored.clone();
        }

        if self.compressed {
            return rle::encode(&self.decoded);
        }

        self.decoded.clone()
    }
}

/// A chunk that a working document keeps for the next save, but does not use.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Preserved {
    pub chunk_id: String,
    pub occurrence: u32,
    pub source_order: u32,
    pub flags: u32,
    pub payload: Vec<u8>,
    /// The archive entry of the chunk, or empty when CUNK.bin holds it.
    pub entry: String,
}

/// SC2X version 4 state outside the working chunks. See `sc2x::document`.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Sc2xState {
    pub metadata: Metadata,
    /// The XLAB.bin compatibility table. Names never come from it.
    pub compat_labels: Vec<u8>,
    /// The persistent identity, name, and object type of each XTHG slot.
    pub object_ids: Vec<i64>,
    pub object_kinds: Vec<u8>,
    pub object_names: Vec<String>,
    /// Encoded XMIC and XTHG extension blocks that this version does not own.
    pub xmic_extension: Vec<u8>,
    pub xthg_extension: Vec<u8>,
    /// The source order of each TEXT occurrence.
    pub text_orders: Vec<i64>,
    pub preserved: Vec<Preserved>,
    /// Archive entries that are not structures, in archive order.
    pub extra_entries: Vec<(String, Vec<u8>)>,
    /// Required features that this version does not support; the city is read-only.
    pub unsupported_features: Vec<String>,
    /// The legacy file that a conversion read. A save never replaces it.
    pub converted_from: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Document {
    pub map_size: i64,
    /// 1 through 3 are SCLG versions. 4 marks an SC2X version 4 working document.
    pub large_version: i64,
    pub chunks: Vec<Chunk>,
    /// The bytes of the file, or empty after a change of layout.
    pub source_bytes: Vec<u8>,
    /// The FORM length was zero, so the reader used the file size, as sc2kfix does.
    pub repaired_form_length: bool,
    /// "sc2kfix" for an original city from an sc2kfix archive.
    pub source_format: String,
    pub sc2x: Option<Sc2xState>,
}

impl Default for Document {
    fn default() -> Self {
        Self {
            map_size: sc2::ORIGINAL_EDGE,
            large_version: sc2::ORIGINAL_LARGE_VERSION,
            chunks: Vec::new(),
            source_bytes: Vec::new(),
            repaired_form_length: false,
            source_format: String::new(),
            sc2x: None,
        }
    }
}

/// The bytes that a save writes, and whether the save left the document unchanged.
pub struct Serialized {
    pub bytes: Vec<u8>,
    pub issues: Vec<String>,
}

impl Document {
    /// A document from file bytes. The signature selects the reader, not the
    /// file extension.
    pub fn parse(bytes: &[u8]) -> Result<Self, String> {
        if sc2kfix::is_archive(bytes) {
            return sc2kfix::load(bytes);
        }

        if sc2x::document::is_archive(bytes) {
            let mut document = sc2x::document::load(bytes)?;
            document.source_bytes = bytes.to_vec();

            return Ok(document);
        }

        let form = sc2::parse(bytes)?;

        let chunks = form
            .chunks
            .into_iter()
            .map(|chunk| Chunk {
                id: chunk.id,
                source_offset: chunk.source_offset,
                stored: chunk.stored,
                decoded: chunk.decoded,
                expected_size: chunk.expected_size,
                compressed: chunk.compressed,
                dirty: false,
            })
            .collect();

        let mut source_bytes = bytes.to_vec();

        // an unchanged save writes the repaired length, never the zero
        if form.repaired_length {
            let length = (source_bytes.len() - 8) as u32;
            source_bytes[4..8].copy_from_slice(&length.to_be_bytes());
        }

        Ok(Self {
            map_size: form.map_size,
            large_version: form.large_version,
            chunks,
            source_bytes,
            repaired_form_length: form.repaired_length,
            source_format: String::new(),
            sc2x: None,
        })
    }

    /// The bytes of the file. An unchanged original file writes its own bytes
    /// unless `force_rebuild` is set. A working document also stores its new
    /// identity counters, so this takes `&mut self`.
    pub fn serialize(&mut self, force_rebuild: bool) -> Result<Serialized, String> {
        if self.is_sc2x() {
            let bytes = sc2x::document::encode(self)?;

            return Ok(Serialized { bytes, issues: Vec::new() });
        }

        let changed = self.chunks.iter().any(|chunk| chunk.dirty);

        if !force_rebuild && !changed && !self.source_bytes.is_empty() {
            return Ok(Serialized {
                bytes: self.source_bytes.clone(),
                issues: Vec::new(),
            });
        }

        let payloads: Vec<(String, Vec<u8>)> = self
            .chunks
            .iter()
            .map(|chunk| (chunk.id.clone(), chunk.payload_for_write()))
            .collect();
        let chunks = payloads.iter().map(|(id, payload)| (id.as_str(), payload.as_slice()));

        Ok(Serialized {
            bytes: sc2::encode(self.map_size, self.large_version, chunks),
            issues: Vec::new(),
        })
    }

    /// A snapshot of the content that a save writes: the file bytes of an SC2
    /// or SCN city, or a digest of the raw entries of an SC2X version 4 city.
    /// Equal snapshots mean that a save would write the same city.
    pub fn content_snapshot(&mut self) -> Vec<u8> {
        if self.is_sc2x() {
            return sc2x::document::content_digest(self).unwrap_or_default();
        }

        self.serialize(false).map(|saved| saved.bytes).unwrap_or_default()
    }

    pub fn is_sc2x(&self) -> bool {
        self.large_version == SC2X_VERSION
    }

    pub fn is_extended(&self) -> bool {
        sc2::is_extended(self.map_size, self.large_version)
    }

    pub fn full_resolution_maps(&self) -> bool {
        self.large_version >= FULL_RESOLUTION_VERSION
    }

    pub fn find(&self, id: &str) -> Option<&Chunk> {
        self.chunks.iter().find(|chunk| chunk.id == id)
    }

    pub fn find_mut(&mut self, id: &str) -> Option<&mut Chunk> {
        self.chunks.iter_mut().find(|chunk| chunk.id == id)
    }

    /// The decoded payload of the first `id` chunk, or an empty slice.
    pub fn payload(&self, id: &str) -> &[u8] {
        self.find(id).map_or(&[], |chunk| chunk.decoded.as_slice())
    }

    /// The decoded size of `id` in this document, or -1 when it varies.
    pub fn decoded_size(&self, id: &str) -> i64 {
        // a working document keeps the record capacities of its file
        if self.is_sc2x() {
            match id {
                "XTXT" => return self.map_size * self.map_size * LAYERED_PLANES,
                "XMIC" | "XTHG" | "XLAB" | "XSGN" => return self.find(id).map_or(-1, |chunk| chunk.decoded.len() as i64),
                "CNAM" => return -1,
                _ => {}
            }
        }

        sc2::decoded_size(id, self.map_size, self.large_version)
    }

    pub fn city_name(&self) -> String {
        if let Some(state) = &self.sc2x {
            return state.metadata.city_name.clone();
        }

        let data = self.payload("CNAM");

        if data.len() < 2 {
            return String::new();
        }

        let end = data[1..].iter().position(|byte| *byte == 0).map_or(data.len(), |offset| offset + 1);

        // each byte is one Latin-1 character
        data[1..end].iter().map(|byte| char::from(*byte)).collect()
    }

    /// SC2 and SCN names hold 30 ASCII bytes. An SC2X name holds 64 characters.
    pub fn set_city_name(&mut self, value: &str) -> bool {
        if let Some(state) = &mut self.sc2x {
            let name = metadata::limit_name(value);

            if name.is_empty() {
                return false;
            }

            state.metadata.city_name = name;

            return true;
        }

        let Some(chunk) = self.find_mut("CNAM") else {
            return false;
        };

        if chunk.decoded.len() != CITY_NAME_SIZE {
            return false;
        }

        let encoded: Vec<u8> = value.chars().take(CITY_NAME_TEXT).map(ascii_byte).collect();
        let mut changed = chunk.decoded.clone();
        changed[1..1 + encoded.len()].copy_from_slice(&encoded);
        changed[encoded.len() + 1] = 0;

        chunk.set_decoded(changed)
    }

    /// Some supplied cities have no CNAM chunk. The Windows game stores 0x1f in
    /// the first byte. Other files put CNAM last, so the new chunk goes at the end.
    pub fn add_city_name_chunk(&mut self) {
        if self.is_sc2x() || self.find("CNAM").is_some() {
            return;
        }

        let mut payload = vec![0_u8; CITY_NAME_SIZE];
        payload[0] = CITY_NAME_FLAG;
        let mut chunk = Chunk::new("CNAM", Vec::new(), CITY_NAME_SIZE as i64);
        chunk.set_decoded(payload);
        self.chunks.push(chunk);
    }

    pub fn misc_u32(&self, offset: i64) -> u32 {
        let data = self.payload("MISC");
        let offset = offset as usize;

        data.get(offset..offset + 4)
            .map_or(0, |bytes| u32::from_be_bytes(bytes.try_into().expect("four bytes")))
    }

    pub fn set_misc_u32(&mut self, offset: i64, value: u32) -> bool {
        let Some(chunk) = self.find_mut("MISC") else {
            return false;
        };

        let offset = offset as usize;

        let Some(bytes) = chunk.decoded.get_mut(offset..offset + 4) else {
            return false;
        };

        bytes.copy_from_slice(&value.to_be_bytes());
        chunk.dirty = true;

        true
    }

    /// Gives an empty original map a new edge, with empty chunks of the new sizes.
    pub fn resize_empty_map(&mut self, edge: i64) -> bool {
        if !MAP_SIZES.contains(&edge) || (self.is_sc2x() && edge != self.map_size) {
            return false;
        }

        if edge == self.map_size {
            return true;
        }

        let native_maps = self.full_resolution_maps();
        self.map_size = edge;
        self.large_version = if native_maps {
            FULL_RESOLUTION_VERSION
        } else {
            sc2::ORIGINAL_LARGE_VERSION
        };
        self.source_bytes.clear();

        for index in 0..self.chunks.len() {
            let id = self.chunks[index].id.clone();
            let resized = FULL_MAP_CHUNKS.contains(&id.as_str())
                || HALF_MAP_CHUNKS.contains(&id.as_str())
                || QUARTER_MAP_CHUNKS.contains(&id.as_str())
                || ["XTHG", "XMIC", "XLAB"].contains(&id.as_str());

            if !resized {
                continue;
            }

            let size = self.decoded_size(&id);
            let chunk = &mut self.chunks[index];
            chunk.expected_size = size;
            chunk.set_decoded(vec![0; size.max(0) as usize]);
        }

        self.set_misc_u32(sc2misc_layout::TILE_COUNTS, (self.map_size * self.map_size) as u32);

        true
    }

    /// Widens the record tables of a large SCLG version 1 map to version 2.
    pub fn upgrade_large_limits(&mut self) {
        if self.map_size == sc2::ORIGINAL_EDGE || self.large_version >= sc2::ORIGINAL_LARGE_VERSION {
            return;
        }

        self.large_version = sc2::ORIGINAL_LARGE_VERSION;
        self.source_bytes.clear();

        for id in ["XTXT", "XMIC", "XLAB", "XTHG"] {
            let size = self.decoded_size(id);

            let Some(chunk) = self.find_mut(id) else {
                continue;
            };

            let old = chunk.decoded.clone();
            chunk.expected_size = size;
            let mut expanded = vec![0_u8; size.max(0) as usize];

            if id == "XTHG" {
                let original = sc2thing_layout::ORIGINAL_SIZE as usize;
                let half = expanded.len() / 2;
                expanded[..original].copy_from_slice(&old[..original]);
                expanded[half..half + original].copy_from_slice(&old[original..original * 2]);
            } else {
                expanded[..old.len()].copy_from_slice(&old);
            }

            chunk.set_decoded(expanded);
        }
    }

    /// Gives each data map one value per tile (SCLG version 3).
    pub fn enable_full_resolution_maps(&mut self) -> bool {
        if self.full_resolution_maps() {
            return true;
        }

        let mut expanded: Vec<(&str, Vec<u8>)> = Vec::new();

        for id in HALF_MAP_CHUNKS.iter().chain(QUARTER_MAP_CHUNKS.iter()) {
            let size = self.decoded_size(id);

            match self.find(id) {
                Some(chunk) if chunk.decoded.len() as i64 == size => expanded.push((id, grid::expand(&chunk.decoded, self.map_size))),
                _ => return false,
            }
        }

        self.upgrade_large_limits();
        self.large_version = FULL_RESOLUTION_VERSION;
        self.source_bytes.clear();

        for (id, data) in expanded {
            let size = self.decoded_size(id);
            let chunk = self.find_mut(id).expect("checked");
            chunk.expected_size = size;
            chunk.set_decoded(data);
        }

        true
    }

    /// A working document gives a new identity to a moving-object slot whose
    /// object was freed or changed type. The next save assigns the new object ID.
    pub fn reconcile_object_identities(&mut self) {
        let Some(things) = self.find("XTHG").map(|chunk| chunk.decoded.clone()) else {
            return;
        };

        let Some(state) = &mut self.sc2x else {
            return;
        };

        let count = crate::sim::things::count(&things).max(0) as usize;
        let previous = state.object_kinds.len();
        state.object_ids.resize(count, 0);
        state.object_names.resize(count, String::new());
        state.object_kinds.resize(count, 0);

        for record in 0..count {
            let kind = things[record * sc2thing_layout::RECORD_SIZE as usize];

            if record >= previous || identity_kind(state.object_kinds[record]) != identity_kind(kind) {
                state.object_ids[record] = 0;
                state.object_names[record] = String::new();
                state.object_kinds[record] = kind;
            }
        }
    }

    /// A chunk of an original file with its decoded size and compression.
    pub fn original_chunk(&self, id: &str, decoded: Vec<u8>) -> Chunk {
        let expected_size = self.decoded_size(id);
        let mut chunk = Chunk::new(id, decoded, expected_size);
        chunk.compressed = expected_size >= 0 && !RAW_CHUNKS.contains(&id);
        chunk.dirty = true;

        chunk
    }
}

/// A train changes between the rail and subway types as it moves. It stays the
/// same object, so both types have one identity kind.
pub fn identity_kind(kind: u8) -> u8 {
    let kind_value = i64::from(kind);

    if kind_value == sc2thing_layout::TYPE_SUBWAY_ENGINE || kind_value == sc2thing_layout::TYPE_SUBWAY_CAR {
        return kind - 2;
    }

    kind
}

/// The ASCII byte of a character. Other characters become spaces, as Godot's
/// `to_ascii_buffer` makes them.
pub fn ascii_byte(character: char) -> u8 {
    if character.is_ascii() { character as u8 } else { b' ' }
}
