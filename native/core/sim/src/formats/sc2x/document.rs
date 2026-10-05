//! SC2X file version 4: a ZIP archive with flat entries. Each binary structure is
//! `<ID>.bin` with its raw bytes; ZIP compresses every entry with DEFLATE.
//! `metadata.json` holds the city name, the file version, and the saved state
//! that no structure holds. Earlier archives also hold a copy of the schema as
//! `metadata.schema.json`, which a load ignores.
//!
//! A loaded file becomes a working document (`large_version` 4). The simulation
//! and the tools read its chunks in the extended layout. Its tile index, label
//! table, and record tables are runtime state that `join` rebuilds from the
//! saved structures and `split` saves again. See docs/sc2x-format.md.

use super::framing::{self, PreservedChunk, TextOccurrence};
use super::metadata::{self, Metadata};
use super::project::{self, SplitOptions, Working};
use super::scenario::{self, Scenario};
use super::xmic::Xmic;
use super::xsgn::Xsgn;
use super::xthg::Xthg;
use super::{collection, labels, limits};
use crate::formats::document::{Chunk, Document, Preserved, SC2X_VERSION, Sc2xState, ascii_byte, identity_kind};
use crate::formats::sc2::MAP_SIZES;
use crate::sim::ids::{sc2graph_layout, sc2label_layout, sc2misc_layout, sc2thing_layout};
use crate::sim::overlay::LAYERED_PLANES;
use crate::sim::things;
use sc2k_formats::json::{Object, Value};
use sc2k_formats::sha256::Sha256;
use sc2k_formats::zip;

pub const METADATA_ENTRY: &str = "metadata.json";
pub const SCHEMA_ENTRY: &str = "metadata.schema.json";
pub const ENTRY_SUFFIX: &str = ".bin";
pub const MAX_ARCHIVE_BYTES: i64 = 512 * 1024 * 1024;
pub const MAX_DATA_BYTES: i64 = 768 * 1024 * 1024;

const ZIP_SIGNATURE: u32 = 0x0403_4b50;
const EMPTY_ZIP_SIGNATURE: u32 = 0x0605_4b50;

/// The entry order after metadata. Missing optional entries are skipped.
pub const ENTRY_ORDER: [&str; 26] = [
    "MISC", "ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XLAB", "XMIC", "XTHG", "XBIT", "XTRF", "XPLT", "XVAL", "XCRM", "XPLC", "XFIR",
    "XPOP", "XROG", "XGRP", "XSGN", "SCEN", "TEXT", "PICT", "TMPL", "CUNK",
];
pub const REQUIRED_ENTRIES: [&str; 21] = [
    "MISC", "ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XLAB", "XMIC", "XTHG", "XBIT", "XTRF", "XPLT", "XVAL", "XCRM", "XPLC", "XFIR",
    "XPOP", "XROG", "XGRP", "XSGN",
];

/// Legacy containers and headers that metadata and ZIP replace.
pub const PROHIBITED_ENTRIES: [&str; 5] = ["FORM", "SCDH", "SCLG", "SIZE", "CNAM"];

/// Bytes per tile of each dense plane, in check order. The working tile index has two bytes per tile.
const DENSE_ENTRIES: [(&str, i64); 15] = [
    ("ALTM", 2),
    ("XTER", 1),
    ("XBLD", 1),
    ("XZON", 1),
    ("XUND", 1),
    ("XTXT", 1),
    ("XBIT", 1),
    ("XTRF", 1),
    ("XPLT", 1),
    ("XVAL", 1),
    ("XCRM", 1),
    ("XPLC", 1),
    ("XFIR", 1),
    ("XPOP", 1),
    ("XROG", 1),
];

/// Known structures that a working document keeps as one chunk. Repeated TEXT
/// chunks are the one exception.
const SINGLETONS: [&str; 24] = [
    "CNAM", "MISC", "ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XLAB", "XMIC", "XTHG", "XBIT", "XTRF", "XPLT", "XVAL", "XCRM", "XPLC",
    "XFIR", "XPOP", "XROG", "XGRP", "SCEN", "PICT", "TMPL",
];

pub const FRESH_LABEL_TABLE_SIZE: usize = sc2label_layout::ORIGINAL_SIZE as usize;
const TEXT_ID: &str = "TEXT";
const PICTURE_SIGNATURE: u32 = 0x8000_0000;
const NEW_CITY_NAME: &str = "New City";

/// The entries of a working document in archive order.
#[derive(Debug, Default)]
pub struct Entries {
    pub members: Vec<(String, Vec<u8>)>,
    pub issues: Vec<String>,
}

impl Entries {
    fn add(&mut self, name: &str, data: Vec<u8>) {
        self.members.push((name.to_string(), data));
    }
}

pub fn is_archive(bytes: &[u8]) -> bool {
    bytes.len() >= 4 && {
        let signature = u32::from_le_bytes(bytes[0..4].try_into().expect("four bytes"));
        signature == ZIP_SIGNATURE || signature == EMPTY_ZIP_SIGNATURE
    }
}

pub fn entry_name(id: &str) -> String {
    format!("{id}{ENTRY_SUFFIX}")
}

/// A name that an unknown chunk can use as its own entry.
pub fn is_safe_chunk_id(id: &str) -> bool {
    id.chars().count() == 4
        && !ENTRY_ORDER.contains(&id)
        && !PROHIBITED_ENTRIES.contains(&id)
        && id
            .chars()
            .all(|character| character.is_ascii_uppercase() || character.is_ascii_digit())
}

/// A four-character chunk ID of printable ASCII.
pub fn is_chunk_id(id: &str) -> bool {
    id.chars().count() == 4 && id.chars().map(ascii_byte).all(|byte| (0x20..=0x7e).contains(&byte))
}

/// Godot's `strip_edges`: no characters up to the space at either end.
pub fn strip_edges(text: &str) -> &str {
    text.trim_matches(|character: char| (character as u32) <= 32)
}

/// Read an archive into a working document.
pub fn load(bytes: &[u8]) -> Result<Document, String> {
    let archive = zip::decode(bytes, MAX_ARCHIVE_BYTES, MAX_DATA_BYTES).map_err(|error| format!("SC2X archive: {error}"))?;

    for (name, _) in &archive.members {
        if name.contains('/') || name.contains('\\') {
            return Err(format!("SC2X entry {name} is in a folder; every entry must be at the archive root"));
        }
    }

    let metadata_bytes = archive.get(METADATA_ENTRY).ok_or("SC2X archive has no metadata.json")?;

    // the application rules decide validity; an included schema changes nothing
    let metadata = Metadata::parse_bytes(metadata_bytes)?;
    let edge = metadata.map_size;
    let unsupported = metadata.unsupported_features();
    metadata::phase_state_error(&metadata.phase_state)?;

    if !MAP_SIZES.contains(&edge) {
        let sizes: Vec<String> = MAP_SIZES.iter().map(i64::to_string).collect();

        return Err(format!(
            "This version cannot open a {edge} by {edge} city. SC2X files can describe it, but the game supports {}.",
            sizes.join(", ")
        ));
    }

    let mut entries: Vec<(&str, Vec<u8>)> = Vec::new();
    let mut preserved: Vec<Preserved> = Vec::new();
    let mut extras: Vec<(String, Vec<u8>)> = Vec::new();

    for (name, data) in &archive.members {
        if name == METADATA_ENTRY || name == SCHEMA_ENTRY {
            continue;
        }

        let id = name.strip_suffix(ENTRY_SUFFIX).unwrap_or(name);

        if !name.ends_with(ENTRY_SUFFIX) || !is_chunk_id(id) {
            extras.push((name.clone(), data.clone()));

            continue;
        }

        if PROHIBITED_ENTRIES.contains(&id) {
            return Err(format!("SC2X version 4 files must not contain {name}"));
        }

        if let Some(known) = ENTRY_ORDER.iter().find(|known| **known == id) {
            entries.push((known, data.clone()));
        } else {
            preserved.push(Preserved {
                chunk_id: id.to_string(),
                occurrence: 0,
                source_order: preserved.len() as u32,
                flags: framing::CHUNK_STORED,
                payload: data.clone(),
                entry: name.clone(),
            });
        }
    }

    let entry = |id: &str| entries.iter().find(|(name, _)| *name == id).map(|(_, data)| data.as_slice());

    if let Some(id) = REQUIRED_ENTRIES.iter().find(|id| entry(id).is_none()) {
        return Err(format!("SC2X archive has no {}", entry_name(id)));
    }

    check_sizes(&entry, edge)?;

    if let Some(data) = entry("CUNK") {
        let chunks = framing::decode_chunks(data).map_err(|error| format!("CUNK.bin: {error}"))?;

        for chunk in chunks {
            preserved.push(preserved_from_framing(chunk));
        }
    }

    let xmic = Xmic::decode(entry("XMIC").expect("required"), edge as usize)?;
    let xthg = Xthg::decode(entry("XTHG").expect("required"))?;
    let teams = metadata.stadium_teams.to_vec();
    let joined = project::join(
        edge as usize,
        entry("XTXT").expect("required"),
        &xmic,
        &xthg,
        &metadata.mayor_name,
        &teams,
    )?;

    let mut document = Document {
        map_size: edge,
        large_version: SC2X_VERSION,
        ..Document::default()
    };

    for id in REQUIRED_ENTRIES {
        let data = match id {
            "XTXT" => joined.xtxt.clone(),
            "XMIC" => joined.xmic.clone(),
            "XTHG" => joined.xthg.clone(),
            "XLAB" => joined.labels.clone(),
            _ => entry(id).expect("required").to_vec(),
        };

        let size = fixed_size(id, edge, &data);
        document.chunks.push(Chunk::new(id, data, size));
    }

    if let Some(data) = entry("SCEN") {
        document.chunks.push(Chunk::new("SCEN", data.to_vec(), -1));
    }

    let mut text_orders = Vec::new();

    if let Some(data) = entry(TEXT_ID) {
        for occurrence in framing::decode_text(data)? {
            document.chunks.push(Chunk::new(TEXT_ID, occurrence.payload, -1));
            text_orders.push(i64::from(occurrence.source_order));
        }
    }

    for id in ["PICT", "TMPL"] {
        if let Some(data) = entry(id) {
            document.chunks.push(Chunk::new(id, data.to_vec(), -1));
        }
    }

    document.sc2x = Some(Sc2xState {
        metadata,
        compat_labels: entry("XLAB").expect("required").to_vec(),
        object_ids: joined.object_ids.iter().map(|id| i64::from(*id)).collect(),
        object_kinds: kinds(&joined.xthg),
        object_names: joined.object_names.clone(),
        xmic_extension: collection::encode_extension(&joined.xmic_extension),
        xthg_extension: collection::encode_extension(&joined.xthg_extension),
        text_orders,
        preserved,
        extra_entries: extras,
        unsupported_features: unsupported,
        converted_from: String::new(),
    });

    Ok(document)
}

/// The raw entries of a working document, in archive order. This also stores
/// the new identity counters and object identities in the document.
pub fn entries(document: &mut Document) -> Result<Entries, String> {
    if !document.is_sc2x() || document.sc2x.is_none() {
        return Err("The document is not an SC2X version 4 working document".into());
    }

    let edge = document.map_size;

    if let Some(id) = REQUIRED_ENTRIES.iter().find(|id| document.find(id).is_none()) {
        return Err(format!("City data has no {id}"));
    }

    let things = document.payload("XTHG").to_vec();
    let (ids, names) = reconciled_identities(document, &things);
    let state = document.sc2x.as_ref().expect("checked");

    let options = SplitOptions {
        signs: Some(Xsgn::decode(document.payload("XSGN"), edge as usize)?),
        object_ids: ids.iter().map(|id| u32::try_from(*id).unwrap_or(0)).collect(),
        object_names: names.clone(),
        next_sign_id: u32::try_from(state.metadata.next_sign_id).unwrap_or(0),
        next_object_id: u32::try_from(state.metadata.next_object_id).unwrap_or(0),
        xmic_extension: collection::decode_extension(&state.xmic_extension, "XMIC")?,
        xthg_extension: collection::decode_extension(&state.xthg_extension, "XTHG")?,
        ..SplitOptions::default()
    };

    let working = Working {
        edge: edge as usize,
        xtxt: document.payload("XTXT"),
        xmic: document.payload("XMIC"),
        xthg: &things,
        labels: document.payload("XLAB"),
        wide_labels: true,
    };

    let split = project::split(&working, options)?;
    let xmic = split.xmic.encode(edge as usize)?;
    let xthg = split.xthg.encode()?;
    let xsgn = split.xsgn.encode(edge as usize)?;

    let object_ids: Vec<i64> = split.xthg.things.iter().map(|thing| i64::from(thing.object_id)).collect();
    let chunk_payloads: Vec<(String, Vec<u8>)> = document
        .chunks
        .iter()
        .map(|chunk| (chunk.id.clone(), chunk.decoded.clone()))
        .collect();
    let payload = |id: &str| chunk_payloads.iter().find(|(name, _)| name == id).map(|(_, data)| data.clone());

    let state = document.sc2x.as_mut().expect("checked");
    state.object_ids = object_ids;
    state.object_names = names;
    state.object_kinds = kinds(&things);
    state.metadata.next_sign_id = i64::from(split.next_sign_id);
    state.metadata.next_object_id = i64::from(split.next_object_id);
    state.metadata.mayor_name = metadata::limit_name(&split.mayor_name);

    for (team, name) in split.team_names.iter().enumerate().take(metadata::TEAM_COUNT) {
        state.metadata.stadium_teams[team] = metadata::limit_name(name);
    }

    if state.metadata.city_name.is_empty() {
        state.metadata.city_name = NEW_CITY_NAME.into();
    }

    let mut result = Entries {
        members: Vec::new(),
        issues: split.issues.clone(),
    };

    result.add(METADATA_ENTRY, state.metadata.to_bytes());

    for id in REQUIRED_ENTRIES {
        let data = match id {
            "XTXT" => split.markers.clone(),
            "XMIC" => xmic.clone(),
            "XTHG" => xthg.clone(),
            "XSGN" => xsgn.clone(),
            "XLAB" => state.compat_labels.clone(),
            _ => payload(id).expect("required"),
        };

        result.add(&entry_name(id), data);
    }

    if let Some(data) = payload("SCEN") {
        result.add(&entry_name("SCEN"), data);
    }

    let occurrences: Vec<TextOccurrence> = chunk_payloads
        .iter()
        .filter(|(id, _)| id == TEXT_ID)
        .enumerate()
        .map(|(index, (_, data))| TextOccurrence {
            source_order: state.text_orders.get(index).map_or(index as u32, |order| *order as u32),
            source_occurrence: index as u32,
            payload: data.clone(),
        })
        .collect();

    if !occurrences.is_empty() {
        result.add(&entry_name(TEXT_ID), framing::encode_text(&occurrences));
    }

    for id in ["PICT", "TMPL"] {
        if let Some(data) = payload(id) {
            result.add(&entry_name(id), data);
        }
    }

    let framed: Vec<&Preserved> = state.preserved.iter().filter(|record| record.entry.is_empty()).collect();

    if !framed.is_empty() {
        let data = encode_chunks(&framed).map_err(|error| format!("CUNK.bin: {error}"))?;
        result.add(&entry_name("CUNK"), data);
    }

    for record in state.preserved.iter().filter(|record| !record.entry.is_empty()) {
        result.add(&record.entry, record.payload.clone());
    }

    for (name, data) in &state.extra_entries {
        result.add(name, data.clone());
    }

    for (name, data) in &result.members {
        if let Some(id) = name.strip_suffix(ENTRY_SUFFIX) {
            validate_entry(id, data, edge).map_err(|error| format!("{name}: {error}"))?;
        }
    }

    Ok(result)
}

/// The archive bytes of a working document.
pub fn encode(document: &mut Document) -> Result<Vec<u8>, String> {
    let prepared = entries(document)?;
    let members: Vec<(String, &[u8])> = prepared
        .members
        .iter()
        .map(|(name, data)| (name.clone(), data.as_slice()))
        .collect();

    if has_repeated_names(&members) {
        return Err("The ZIP member list is invalid or too long.".into());
    }

    zip::encode(&members, MAX_ARCHIVE_BYTES, MAX_DATA_BYTES, true)
}

/// A digest of the saved content: the raw entries without ZIP compression.
/// Equal digests mean that a save would write the same city.
pub fn content_digest(document: &mut Document) -> Result<Vec<u8>, String> {
    entries(document).map(|prepared| digest_entries(&prepared))
}

pub fn digest_entries(prepared: &Entries) -> Vec<u8> {
    let mut hash = Sha256::new();

    for (name, data) in &prepared.members {
        hash.update(name.as_bytes());
        hash.update(&(data.len() as u64).to_le_bytes());
        hash.update(data);
    }

    hash.finish().to_vec()
}

/// A working document from a valid SC2, SCN, or SCLG document. The source stays
/// unchanged. The issues list links that the new structures cannot hold. An
/// import keeps record capacities above its map profile; a `fresh` city uses the profile.
pub fn from_legacy(source: &Document, fallback_name: &str, fresh: bool) -> Result<(Document, Vec<String>), String> {
    if source.is_sc2x() {
        return Err("The source city is already an SC2X version 4 document".into());
    }

    let edge = source.map_size;
    let profile = limits::profile_for(edge.max(0) as usize).ok_or_else(|| format!("No SC2X profile exists for a {edge} tile map"))?;
    let mut working = source.clone();

    if !working.enable_full_resolution_maps() {
        return Err("Cannot expand the data maps: city data is incomplete".into());
    }

    if let Some(id) = REQUIRED_ENTRIES.iter().find(|id| **id != "XSGN" && working.find(id).is_none()) {
        return Err(format!("City data has no {id}"));
    }

    let options = SplitOptions {
        signs: None,
        next_sign_id: 1,
        next_object_id: 1,
        facility_capacity: profile.facilities,
        thing_capacity: profile.things,
        sign_capacity: profile.signs,
        trim_free_tail: fresh,
        ..SplitOptions::default()
    };

    let split = project::split(
        &Working {
            edge: edge as usize,
            xtxt: working.payload("XTXT"),
            xmic: working.payload("XMIC"),
            xthg: working.payload("XTHG"),
            labels: working.payload("XLAB"),
            wide_labels: false,
        },
        options,
    )?;

    let mut metadata = Metadata {
        map_size: edge,
        city_name: metadata::limit_name(strip_edges(&source.city_name())),
        ..Metadata::default()
    };

    if metadata.city_name.is_empty() {
        metadata.city_name = if fallback_name.is_empty() {
            NEW_CITY_NAME.into()
        } else {
            metadata::limit_name(fallback_name)
        };
    }

    metadata.mayor_name = metadata::limit_name(&split.mayor_name);

    for (team, name) in split.team_names.iter().enumerate().take(metadata::TEAM_COUNT) {
        metadata.stadium_teams[team] = metadata::limit_name(name);
    }

    metadata.next_sign_id = i64::from(split.next_sign_id);
    metadata.next_object_id = i64::from(split.next_object_id);
    metadata.legacy = legacy_record(source);

    let mut issues = split.issues.clone();
    let mut preserved: Vec<Preserved> = Vec::new();
    let mut seen: Vec<(String, u32)> = Vec::new();
    let mut text_orders = Vec::new();
    let mut text_payloads = Vec::new();
    let mut scenario_data = Vec::new();
    let mut template = Vec::new();
    let mut picture = Vec::new();

    for (order, chunk) in source.chunks.iter().enumerate() {
        let id = chunk.id.as_str();

        let occurrence = match seen.iter_mut().find(|(name, _)| name == id) {
            Some((_, count)) => {
                *count += 1;
                *count - 1
            }
            None => {
                seen.push((id.to_string(), 1));
                0
            }
        };

        if id == TEXT_ID {
            text_orders.push(order as i64);
            text_payloads.push(chunk.decoded.clone());

            continue;
        }

        if id == "CNAM" && occurrence == 0 {
            continue;
        }

        let known = SINGLETONS.contains(&id);

        if known && occurrence == 0 {
            match id {
                "SCEN" => scenario_data = chunk.decoded.clone(),
                "TMPL" => template = chunk.decoded.clone(),
                "PICT" => picture = chunk.decoded.clone(),
                _ => {}
            }

            continue;
        }

        preserved.push(Preserved {
            chunk_id: id.to_string(),
            occurrence,
            source_order: order as u32,
            flags: if known { 0 } else { framing::CHUNK_STORED },
            payload: if known { chunk.decoded.clone() } else { chunk.stored.clone() },
            entry: String::new(),
        });
    }

    // an unknown chunk with one occurrence and a safe name keeps its own entry
    for record in &mut preserved {
        let single = seen.iter().any(|(name, count)| *name == record.chunk_id && *count == 1);

        if record.flags == framing::CHUNK_STORED && single && is_safe_chunk_id(&record.chunk_id) {
            record.entry = entry_name(&record.chunk_id);
        }
    }

    let superseded = |payload: Vec<u8>| Preserved {
        chunk_id: "TMPL".into(),
        occurrence: 0,
        source_order: source.chunks.len() as u32,
        flags: framing::CHUNK_SUPERSEDED,
        payload,
        entry: String::new(),
    };

    if !scenario_data.is_empty() {
        scenario_data = Scenario::from_legacy(&scenario_data)
            .map_err(|error| format!("SCEN: {error}"))?
            .to_schema2();

        if !template.is_empty() {
            match scenario::upgrade_template(&template) {
                Some(upgraded) => template = upgraded,
                None => {
                    preserved.push(superseded(template.clone()));
                    issues.push("TMPL has descriptors that SCEN schema 2 does not use; it was kept as superseded data".into());
                    template = Vec::new();
                }
            }
        }
    } else if !template.is_empty() {
        preserved.push(superseded(template.clone()));
        template = Vec::new();
    }

    preserved.sort_by_key(|record| record.source_order);

    let split_xmic = split.xmic.encode(edge as usize)?;
    let split_xthg = split.xthg.encode()?;
    let split_xsgn = split.xsgn.encode(edge as usize)?;

    let entry_data = |id: &str| -> Vec<u8> {
        match id {
            "XTXT" => split.markers.clone(),
            "XMIC" => split_xmic.clone(),
            "XTHG" => split_xthg.clone(),
            "XSGN" => split_xsgn.clone(),
            _ => working.payload(id).to_vec(),
        }
    };

    let xmic = Xmic::decode(&split_xmic, edge as usize)?;
    let xthg = Xthg::decode(&split_xthg)?;
    let teams = metadata.stadium_teams.to_vec();
    let joined = project::join(edge as usize, &split.markers, &xmic, &xthg, &metadata.mayor_name, &teams)?;

    let mut document = Document {
        map_size: edge,
        large_version: SC2X_VERSION,
        ..Document::default()
    };

    for id in REQUIRED_ENTRIES {
        let data = match id {
            "XTXT" => joined.xtxt.clone(),
            "XMIC" => joined.xmic.clone(),
            "XTHG" => joined.xthg.clone(),
            "XLAB" => joined.labels.clone(),
            _ => entry_data(id),
        };

        let size = fixed_size(id, edge, &data);
        document.chunks.push(Chunk::new(id, data, size));
    }

    if !scenario_data.is_empty() {
        document.chunks.push(Chunk::new("SCEN", scenario_data, -1));
    }

    for payload in text_payloads {
        document.chunks.push(Chunk::new(TEXT_ID, payload, -1));
    }

    if !picture.is_empty() {
        document.chunks.push(Chunk::new("PICT", picture, -1));
    }

    if !template.is_empty() {
        document.chunks.push(Chunk::new("TMPL", template, -1));
    }

    document.sc2x = Some(Sc2xState {
        metadata,
        compat_labels: split.residual_labels.clone(),
        object_ids: joined.object_ids.iter().map(|id| i64::from(*id)).collect(),
        object_kinds: kinds(&joined.xthg),
        object_names: joined.object_names.clone(),
        text_orders,
        preserved,
        ..Sc2xState::default()
    });

    Ok((document, issues))
}

/// A working document from a city that the new-city tools made in the legacy
/// layout. A new city has no import data, so it keeps no legacy record and
/// starts with an empty compatibility label table.
pub fn from_new_city(source: &Document, city_name: &str, mayor_name: &str) -> Result<(Document, Vec<String>), String> {
    let (mut document, issues) = from_legacy(source, "", true)?;
    let state = document.sc2x.as_mut().expect("converted");
    let city = strip_edges(city_name);
    state.metadata.city_name = if city.is_empty() {
        NEW_CITY_NAME.into()
    } else {
        metadata::limit_name(city)
    };

    let mayor = strip_edges(mayor_name);

    if !mayor.is_empty() {
        let name = metadata::limit_name(mayor);
        state.metadata.mayor_name = name.clone();
        let chunk = document.find_mut("XLAB").expect("required");
        labels::write_wide(&mut chunk.decoded, 0, &name);
    }

    let state = document.sc2x.as_mut().expect("converted");
    state.metadata.legacy = Object::new();
    state.compat_labels = vec![0; FRESH_LABEL_TABLE_SIZE];
    state.preserved.clear();
    state.text_orders.clear();

    Ok((document, issues))
}

/// Checks one binary entry of a map with `edge` tiles.
pub fn validate_entry(name: &str, data: &[u8], edge: i64) -> Result<(), String> {
    let edge = edge.max(0) as usize;

    match name {
        "XMIC" => Xmic::decode(data, edge).map(|_| ()),
        "XTHG" => Xthg::decode(data).map(|_| ()),
        "XSGN" => Xsgn::decode(data, edge).map(|_| ()),
        "TEXT" => framing::decode_text(data).map(|_| ()),
        "CUNK" => framing::decode_chunks(data).map(|_| ()),
        "SCEN" => Scenario::from_schema2(data, edge).map(|_| ()),
        "TMPL" => scenario::parse_template(data).and_then(|descriptors| {
            if scenario::template_scenario_size(&descriptors) == Some(scenario::SCHEMA2_SIZE) {
                Ok(())
            } else {
                Err("TMPL does not describe SCEN schema 2".into())
            }
        }),
        _ => Ok(()),
    }
}

/// CUNK.bin of preserved chunks. A chunk ID must have four bytes.
pub fn encode_chunks(records: &[&Preserved]) -> Result<Vec<u8>, String> {
    let mut values = Vec::with_capacity(records.len());

    for record in records {
        let id = record.chunk_id.as_bytes();

        if id.len() != 4 {
            return Err("A preserved chunk ID is not four bytes".into());
        }

        values.push(PreservedChunk {
            chunk_id: [id[0], id[1], id[2], id[3]],
            occurrence: record.occurrence,
            source_order: record.source_order,
            flags: record.flags,
            payload: record.payload.clone(),
        });
    }

    let data = framing::encode_chunks(&values);
    framing::decode_chunks(&data)?;

    Ok(data)
}

fn preserved_from_framing(chunk: PreservedChunk) -> Preserved {
    Preserved {
        chunk_id: String::from_utf8_lossy(&chunk.chunk_id).into_owned(),
        occurrence: chunk.occurrence,
        source_order: chunk.source_order,
        flags: chunk.flags,
        payload: chunk.payload,
        entry: String::new(),
    }
}

fn has_repeated_names(members: &[(String, &[u8])]) -> bool {
    let mut names: Vec<&str> = members.iter().map(|(name, _)| name.as_str()).collect();
    names.sort_unstable();

    names.windows(2).any(|pair| pair[0] == pair[1])
}

/// The payload size that a chunk keeps for its document; -1 lets it vary.
fn fixed_size(id: &str, edge: i64, data: &[u8]) -> i64 {
    // the layered tile index
    if id == "XTXT" {
        return edge * edge * LAYERED_PLANES;
    }

    if let Some((_, bytes)) = DENSE_ENTRIES.iter().find(|(name, _)| *name == id) {
        return edge * edge * bytes;
    }

    match id {
        "MISC" => sc2misc_layout::SIZE,
        "XGRP" => sc2graph_layout::SIZE,
        "XMIC" | "XTHG" | "XLAB" => data.len() as i64,
        _ => -1,
    }
}

fn check_sizes<'a>(entry: &dyn Fn(&str) -> Option<&'a [u8]>, edge: i64) -> Result<(), String> {
    for (id, bytes) in DENSE_ENTRIES {
        let expected = edge * edge * bytes;
        let size = entry(id).map_or(0, <[u8]>::len) as i64;

        if size != expected {
            return Err(format!("{} has {size} bytes; a {edge} tile map needs {expected}", entry_name(id)));
        }
    }

    let misc = entry("MISC").map_or(0, <[u8]>::len) as i64;

    if misc != sc2misc_layout::SIZE {
        return Err(format!("MISC.bin has {misc} bytes; expected {}", sc2misc_layout::SIZE));
    }

    let graphs = entry("XGRP").map_or(0, <[u8]>::len) as i64;

    if graphs != sc2graph_layout::SIZE {
        return Err(format!("XGRP.bin has {graphs} bytes; expected {}", sc2graph_layout::SIZE));
    }

    let label_table = entry("XLAB").map_or(0, <[u8]>::len);

    if label_table < FRESH_LABEL_TABLE_SIZE || !label_table.is_multiple_of(sc2label_layout::RECORD_SIZE as usize) {
        return Err("XLAB.bin must be a table of 25-byte labels with at least 256 records".into());
    }

    for id in ["XSGN", "SCEN", "TEXT", "TMPL", "CUNK"] {
        if let Some(data) = entry(id) {
            validate_entry(id, data, edge).map_err(|error| format!("{}: {error}", entry_name(id)))?;
        }
    }

    if entry("TMPL").is_some() && entry("SCEN").is_none() {
        return Err("TMPL.bin describes SCEN.bin, but the archive has no SCEN.bin".into());
    }

    if let Some(data) = entry("PICT") {
        picture_error(data)?;
    }

    Ok(())
}

fn picture_error(data: &[u8]) -> Result<(), String> {
    if data.len() < 8 || u32::from_be_bytes(data[0..4].try_into().expect("four bytes")) != PICTURE_SIGNATURE {
        return Err("PICT.bin header is invalid".into());
    }

    let width = usize::from(u16::from_le_bytes([data[4], data[5]]));
    let height = usize::from(u16::from_le_bytes([data[6], data[7]]));
    let pixels = data.len() - 8;

    if pixels != width * height && pixels != height * (width + 1) {
        return Err("PICT.bin size does not match its dimensions".into());
    }

    Ok(())
}

/// The object type of each XTHG slot.
pub fn kinds(things_data: &[u8]) -> Vec<u8> {
    let count = things::count(things_data).max(0) as usize;

    (0..count)
        .map(|record| things_data[record * sc2thing_layout::RECORD_SIZE as usize])
        .collect()
}

/// A slot keeps its identity and name while it holds the same type of object.
/// A freed or reused slot gets a new identity when the city is saved.
fn reconciled_identities(document: &Document, things_data: &[u8]) -> (Vec<i64>, Vec<String>) {
    let count = things::count(things_data).max(0) as usize;
    let mut ids = vec![0_i64; count];
    let mut names = vec![String::new(); count];

    let Some(state) = &document.sc2x else {
        return (ids, names);
    };

    for record in 0..count {
        let kind = things_data[record * sc2thing_layout::RECORD_SIZE as usize];

        let same = kind != 0
            && record < state.object_ids.len()
            && record < state.object_kinds.len()
            && identity_kind(state.object_kinds[record]) == identity_kind(kind);

        if same {
            ids[record] = state.object_ids[record];
            names[record] = state.object_names.get(record).cloned().unwrap_or_default();
        }
    }

    (ids, names)
}

/// The source container, its chunk order, and CNAM bytes that are not the name.
fn legacy_record(source: &Document) -> Object {
    let extended = source.is_extended();
    let order = source.chunks.iter().map(|chunk| Value::String(chunk.id.clone())).collect();

    let mut origin = Object::new();
    origin.insert("format", Value::String(if extended { "SCLG" } else { "SCDH" }.into()));
    origin.insert("version", Value::Int(if extended { source.large_version } else { 0 }));
    origin.insert("map_size", Value::Int(source.map_size));
    origin.insert("chunk_order", Value::Array(order));

    let mut result = Object::new();
    result.insert("source", Value::Object(origin));

    if let Some(chunk) = source.find("CNAM") {
        let data = &chunk.decoded;
        let end = data
            .iter()
            .skip(1)
            .position(|byte| *byte == 0)
            .map_or(data.len(), |offset| offset + 1);
        let trailing = &data[(end + 1).min(data.len())..];

        let mut name = Object::new();
        name.insert("first_byte", Value::Int(data.first().map_or(0, |byte| i64::from(*byte))));
        name.insert("trailing_hex", Value::String(sc2k_formats::sha256::hex(trailing)));
        result.insert("cnam", Value::Object(name));
    }

    result
}
