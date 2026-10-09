//! The IFF city files of the original game: SC2 and SCN files (FORM type SCDH)
//! and the experimental large-map SCLG files.
//!
//! A file is a FORM header and a sequence of chunks. Each chunk has a printable
//! four-byte ID, a big-endian payload size, and the payload. Most chunks of a
//! known size use the Maxis run-length code. An SCLG file adds a SIZE header
//! with its layout version and map edge.

use super::rle;
use crate::sim::city::facility_capacity;
use crate::sim::ids::{sc2graph_layout, sc2label_layout, sc2microsim_layout, sc2misc_layout, sc2overlay_layout, sc2thing_layout};

pub const FORM_HEADER_SIZE: usize = 12;
pub const CHUNK_HEADER_SIZE: usize = 8;
/// The SCLG SIZE chunk: its header, the layout version, and the map edge.
pub const SIZE_HEADER_END: usize = FORM_HEADER_SIZE + CHUNK_HEADER_SIZE + 8;
const SIZE_PAYLOAD: u32 = 8;

/// The default map edge of an SC2 file.
pub const ORIGINAL_EDGE: i64 = 128;
pub const MAP_SIZES: [i64; 11] = [16, 32, 64, 128, 256, 384, 512, 640, 1024, 2048, 4096];
/// SCLG files end at 1024 tiles. Larger maps use SC2X version 4 only.
pub const SCLG_MAX_EDGE: i64 = 1024;
/// Legacy record tables of larger maps keep the 1024-tile capacities.
pub const LEGACY_MAX_FACTOR: i64 = 64;
/// The large-map version of an SC2 file.
pub const ORIGINAL_LARGE_VERSION: i64 = 2;
/// From this SCLG version, the data maps have one value per tile.
const FULL_RESOLUTION_VERSION: i64 = 3;

pub const FULL_MAP_CHUNKS: [&str; 7] = ["ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XBIT"];
/// Traffic, pollution, land value, and crime use half the map edge.
pub const HALF_MAP_CHUNKS: [&str; 4] = ["XTRF", "XPLT", "XVAL", "XCRM"];
/// The service and population maps use a quarter of the map edge.
pub const QUARTER_MAP_CHUNKS: [&str; 4] = ["XPLC", "XFIR", "XPOP", "XROG"];
/// Chunks of a known size that are stored without the run-length code.
pub const RAW_CHUNKS: [&str; 6] = ["CNAM", "ALTM", "TEXT", "SCEN", "PICT", "TMPL"];
const CITY_NAME_SIZE: i64 = 32;

/// One chunk as the file stores it, with its decoded payload.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Chunk {
    pub id: String,
    pub source_offset: usize,
    pub stored: Vec<u8>,
    pub decoded: Vec<u8>,
    /// -1 when the chunk has no fixed size.
    pub expected_size: i64,
    pub compressed: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Form {
    pub map_size: i64,
    pub large_version: i64,
    pub chunks: Vec<Chunk>,
    /// The FORM length was zero, and the reader used the file size instead.
    pub repaired_length: bool,
}

/// Sc2File.decoded_size for SC2, SCN, and SCLG files: the decoded payload
/// size of `id`, or -1 when the chunk has no fixed size.
pub fn decoded_size(id: &str, map_size: i64, large_version: i64) -> i64 {
    let edge = map_size;
    let full_resolution = large_version >= FULL_RESOLUTION_VERSION;

    if full_resolution && (HALF_MAP_CHUNKS.contains(&id) || QUARTER_MAP_CHUNKS.contains(&id)) {
        return edge * edge;
    }

    if edge > ORIGINAL_EDGE && large_version >= ORIGINAL_LARGE_VERSION {
        let factor = ((edge * edge) / (ORIGINAL_EDGE * ORIGINAL_EDGE)).min(LEGACY_MAX_FACTOR);

        match id {
            "XTXT" => return edge * edge * 2,
            "XMIC" => return facility_capacity(factor) * sc2microsim_layout::RECORD_SIZE,
            "XLAB" => {
                let signs = sc2overlay_layout::ORIGINAL_SIGN_COUNT;

                return (sc2overlay_layout::EXTRA_SIGN + signs * factor - signs) * sc2label_layout::RECORD_SIZE;
            }
            "XTHG" => return sc2thing_layout::ORIGINAL_COUNT * factor * sc2thing_layout::EXTENDED_RECORD_SIZE,
            _ => {}
        }
    }

    if id == "XTHG" && edge > ORIGINAL_EDGE {
        return sc2thing_layout::ORIGINAL_COUNT * sc2thing_layout::EXTENDED_RECORD_SIZE;
    }

    if FULL_MAP_CHUNKS.contains(&id) {
        return edge * edge * if id == "ALTM" { 2 } else { 1 };
    }

    if HALF_MAP_CHUNKS.contains(&id) {
        return (edge / 2) * (edge / 2);
    }

    if QUARTER_MAP_CHUNKS.contains(&id) {
        return (edge / 4) * (edge / 4);
    }

    match id {
        "CNAM" => CITY_NAME_SIZE,
        "MISC" => sc2misc_layout::SIZE,
        "XLAB" => sc2label_layout::ORIGINAL_SIZE,
        "XMIC" => sc2microsim_layout::ORIGINAL_SIZE,
        "XTHG" => sc2thing_layout::ORIGINAL_SIZE,
        "XGRP" => sc2graph_layout::SIZE,
        _ => -1,
    }
}

/// Whether the file needs the SCLG form: a map that is not 128 tiles or
/// full-resolution data maps.
pub fn is_extended(map_size: i64, large_version: i64) -> bool {
    map_size != ORIGINAL_EDGE || large_version >= FULL_RESOLUTION_VERSION
}

fn u32_at(bytes: &[u8], offset: usize) -> u32 {
    u32::from_be_bytes([bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3]])
}

fn ascii(bytes: &[u8]) -> String {
    bytes.iter().take_while(|&&byte| byte != 0).map(|&byte| byte as char).collect()
}

fn is_chunk_id(bytes: &[u8]) -> bool {
    bytes.iter().all(|byte| (0x20..=0x7e).contains(byte))
}

fn valid_sclg(large_version: i64, map_size: i64) -> bool {
    (1..=3).contains(&large_version)
        && MAP_SIZES.contains(&map_size)
        && !(map_size == ORIGINAL_EDGE && large_version != FULL_RESOLUTION_VERSION)
        && !(map_size < ORIGINAL_EDGE && large_version == 1)
        && map_size <= SCLG_MAX_EDGE
}

/// Read the FORM header, the SCLG SIZE header, and every chunk. Decode each
/// compressed chunk and check each chunk of a known size.
pub fn parse(bytes: &[u8]) -> Result<Form, String> {
    if bytes.len() < FORM_HEADER_SIZE {
        return Err("File is shorter than the 12-byte FORM header".into());
    }

    if &bytes[0..4] != b"FORM" {
        return Err("File does not start with FORM".into());
    }

    let form_type = &bytes[8..12];

    if form_type != b"SCDH" && form_type != b"SCLG" {
        return Err("FORM type is not SCDH or experimental SCLG".into());
    }

    // Some saves of the original game have a zero FORM length. As sc2kfix
    // does, an original city file then uses its file size.
    let declared_length = u32_at(bytes, 4) as usize;
    let repaired_length = declared_length == 0 && form_type == b"SCDH";

    if declared_length != bytes.len() - 8 && !repaired_length {
        return Err("FORM length does not match the file size".into());
    }

    let mut form = Form {
        map_size: ORIGINAL_EDGE,
        large_version: ORIGINAL_LARGE_VERSION,
        chunks: Vec::new(),
        repaired_length,
    };
    let mut offset = FORM_HEADER_SIZE;

    if form_type == b"SCLG" {
        if bytes.len() < SIZE_HEADER_END || &bytes[12..16] != b"SIZE" || u32_at(bytes, 16) != SIZE_PAYLOAD {
            return Err("Experimental SIZE header is missing".into());
        }

        form.large_version = i64::from(u32_at(bytes, 20));
        form.map_size = i64::from(u32_at(bytes, 24));

        if !valid_sclg(form.large_version, form.map_size) {
            return Err("Unsupported experimental city version or size".into());
        }

        offset = SIZE_HEADER_END;
    }

    while offset < bytes.len() {
        if offset + CHUNK_HEADER_SIZE > bytes.len() {
            return Err(format!("Chunk header at 0x{:x} is truncated", offset));
        }

        let id_bytes = &bytes[offset..offset + 4];

        if !is_chunk_id(id_bytes) {
            return Err(format!("Chunk ID at 0x{:x} is not printable ASCII", offset));
        }

        let id = ascii(id_bytes);
        let payload_start = offset + CHUNK_HEADER_SIZE;
        let payload_end = payload_start + u32_at(bytes, offset + 4) as usize;

        if payload_end > bytes.len() {
            return Err(format!("Chunk {} at 0x{:x} extends past the file", id, offset));
        }

        let stored = bytes[payload_start..payload_end].to_vec();
        let expected_size = decoded_size(&id, form.map_size, form.large_version);
        let compressed = expected_size >= 0 && !RAW_CHUNKS.contains(&id.as_str());

        let decoded = if compressed {
            rle::decode(&stored, Some(expected_size as usize)).map_err(|error| format!("Chunk {}: {}", id, error))?
        } else {
            if expected_size >= 0 && stored.len() as i64 != expected_size {
                return Err(format!("Chunk {} has {} bytes; expected {}", id, stored.len(), expected_size));
            }

            stored.clone()
        };

        form.chunks.push(Chunk {
            id,
            source_offset: offset,
            stored,
            decoded,
            expected_size,
            compressed,
        });
        offset = payload_end;
    }

    Ok(form)
}

fn put_u32(output: &mut Vec<u8>, value: usize) {
    output.extend_from_slice(&u32::try_from(value).unwrap_or(u32::MAX).to_be_bytes());
}

/// Write a FORM file of `chunks`, given as chunk IDs and stored payloads.
pub fn encode<'a>(map_size: i64, large_version: i64, chunks: impl IntoIterator<Item = (&'a str, &'a [u8])>) -> Vec<u8> {
    let extended = is_extended(map_size, large_version);
    let mut output = Vec::new();
    output.extend_from_slice(b"FORM");
    put_u32(&mut output, 0);
    output.extend_from_slice(if extended { b"SCLG" } else { b"SCDH" });

    if extended {
        output.extend_from_slice(b"SIZE");
        put_u32(&mut output, SIZE_PAYLOAD as usize);
        put_u32(&mut output, large_version.max(0) as usize);
        put_u32(&mut output, map_size.max(0) as usize);
    }

    for (id, payload) in chunks {
        let mut id_bytes = [b' '; 4];

        for (target, source) in id_bytes.iter_mut().zip(id.bytes()) {
            *target = source;
        }

        output.extend_from_slice(&id_bytes);
        put_u32(&mut output, payload.len());
        output.extend_from_slice(payload);
    }

    let body = output.len() - 8;
    output[4..8].copy_from_slice(&u32::try_from(body).unwrap_or(u32::MAX).to_be_bytes());

    output
}

#[cfg(test)]
mod tests {
    use super::*;

    fn chunk(id: &str, payload: &[u8]) -> Vec<u8> {
        let mut bytes = id.as_bytes().to_vec();
        bytes.extend_from_slice(&(payload.len() as u32).to_be_bytes());
        bytes.extend_from_slice(payload);
        bytes
    }

    fn form(form_type: &[u8; 4], body: &[u8]) -> Vec<u8> {
        let mut bytes = b"FORM".to_vec();
        bytes.extend_from_slice(&((body.len() + 4) as u32).to_be_bytes());
        bytes.extend_from_slice(form_type);
        bytes.extend_from_slice(body);
        bytes
    }

    #[test]
    fn decoded_sizes_follow_the_map_size_and_version() {
        assert_eq!(decoded_size("ALTM", 128, 2), 32768);
        assert_eq!(decoded_size("XTRF", 128, 2), 4096);
        assert_eq!(decoded_size("XPLC", 128, 2), 1024);
        assert_eq!(decoded_size("XPLC", 128, 3), 16384);
        assert_eq!(decoded_size("XTXT", 256, 2), 256 * 256 * 2);
        assert_eq!(decoded_size("XTXT", 256, 1), 256 * 256);
        assert_eq!(decoded_size("XTHG", 64, 2), sc2thing_layout::ORIGINAL_SIZE);
        assert_eq!(
            decoded_size("XTHG", 256, 1),
            sc2thing_layout::ORIGINAL_COUNT * sc2thing_layout::EXTENDED_RECORD_SIZE
        );
        assert_eq!(
            decoded_size("XMIC", 1024, 2),
            facility_capacity(64) * sc2microsim_layout::RECORD_SIZE
        );
        assert_eq!(decoded_size("MISC", 16, 2), sc2misc_layout::SIZE);
        assert_eq!(decoded_size("TEXT", 128, 2), -1);
    }

    #[test]
    fn a_city_round_trips_with_compressed_and_raw_chunks() {
        let name = [0x1fu8; 32];
        let misc = vec![7u8; sc2misc_layout::SIZE as usize];
        let encoded_misc = rle::encode(&misc);
        let mut body = chunk("CNAM", &name);
        body.extend(chunk("MISC", &encoded_misc));
        body.extend(chunk("TEXT", b"any size"));
        let bytes = form(b"SCDH", &body);

        let parsed = parse(&bytes).expect("a valid city");
        assert_eq!((parsed.map_size, parsed.large_version), (128, 2));
        assert_eq!(parsed.chunks.len(), 3);
        assert_eq!(parsed.chunks[0].decoded, name);
        assert!(!parsed.chunks[0].compressed);
        assert_eq!(parsed.chunks[1].decoded, misc);
        assert!(parsed.chunks[1].compressed);
        assert_eq!(parsed.chunks[1].source_offset, FORM_HEADER_SIZE + CHUNK_HEADER_SIZE + name.len());
        assert_eq!(parsed.chunks[2].expected_size, -1);

        let written = encode(
            parsed.map_size,
            parsed.large_version,
            parsed.chunks.iter().map(|chunk| (chunk.id.as_str(), chunk.stored.as_slice())),
        );
        assert_eq!(written, bytes);
    }

    #[test]
    fn an_sclg_city_keeps_its_size_header() {
        let mut body = b"SIZE".to_vec();
        body.extend_from_slice(&8u32.to_be_bytes());
        body.extend_from_slice(&3u32.to_be_bytes());
        body.extend_from_slice(&64u32.to_be_bytes());
        body.extend(chunk("XPLC", &rle::encode(&vec![0u8; 64 * 64])));
        let bytes = form(b"SCLG", &body);

        let parsed = parse(&bytes).expect("a valid large city");
        assert_eq!((parsed.map_size, parsed.large_version), (64, 3));
        assert_eq!(parsed.chunks[0].decoded.len(), 64 * 64);
        let written = encode(
            64,
            3,
            parsed.chunks.iter().map(|chunk| (chunk.id.as_str(), chunk.stored.as_slice())),
        );
        assert_eq!(written, bytes);
    }

    #[test]
    fn invalid_files_report_the_first_error() {
        let cases: Vec<(Vec<u8>, &str)> = vec![
            (b"FORM".to_vec(), "File is shorter than the 12-byte FORM header"),
            (b"FROM\0\0\0\x04SCDH".to_vec(), "File does not start with FORM"),
            (b"FORM\0\0\0\x05SCDH".to_vec(), "FORM length does not match the file size"),
            (form(b"SCXX", &[]), "FORM type is not SCDH or experimental SCLG"),
            (form(b"SCLG", &[]), "Experimental SIZE header is missing"),
            (form(b"SCDH", b"MISC\0\0"), "Chunk header at 0xc is truncated"),
            (form(b"SCDH", b"MI\x01C\0\0\0\0"), "Chunk ID at 0xc is not printable ASCII"),
            (form(b"SCDH", b"TEXT\0\0\0\x09"), "Chunk TEXT at 0xc extends past the file"),
            (form(b"SCDH", &chunk("CNAM", &[0; 4])), "Chunk CNAM has 4 bytes; expected 32"),
            (form(b"SCDH", &chunk("MISC", &[0x80])), "Chunk MISC: Control byte 0x80 is reserved"),
        ];

        for (bytes, message) in cases {
            assert_eq!(parse(&bytes).unwrap_err(), message);
        }

        let mut body = b"SIZE".to_vec();
        body.extend_from_slice(&8u32.to_be_bytes());
        body.extend_from_slice(&2u32.to_be_bytes());
        body.extend_from_slice(&128u32.to_be_bytes());
        assert_eq!(
            parse(&form(b"SCLG", &body)).unwrap_err(),
            "Unsupported experimental city version or size"
        );
    }

    #[test]
    fn an_original_city_with_a_zero_form_length_uses_its_file_size() {
        let mut bytes = form(b"SCDH", &chunk("CNAM", &[b'A'; 32]));
        let intact = parse(&bytes).expect("an intact city");
        assert!(!intact.repaired_length);

        bytes[4..8].copy_from_slice(&[0; 4]);
        let repaired = parse(&bytes).expect("a repaired city");
        assert!(repaired.repaired_length);
        assert_eq!(repaired.chunks.len(), 1);
        assert_eq!(repaired.chunks[0].decoded, vec![b'A'; 32]);

        let mut experimental = form(b"SCLG", &[]);
        experimental[4..8].copy_from_slice(&[0; 4]);
        assert_eq!(parse(&experimental).unwrap_err(), "FORM length does not match the file size");
    }
}
