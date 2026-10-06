//! DOS and Macintosh SCURK tile sets for the city view, as sc2kfix loads them.
//!
//! A DOS .TIL file is a small archive of LARGE, OTHER, and SMALL sprite files
//! and their .HED directories. A Macintosh tile set is a MIFF file with the
//! _MAC INFO tag. Their sprites use the DOS and Macintosh palette, so each
//! pixel converts to the Windows palette with the sc2kfix table.

use crate::bytes::latin1;
use crate::import::sprites::{self, Sprite};
use sc2k_formats::sprite;
use std::collections::HashSet;

const DOS_DIRECTORY_ENTRY: usize = 16;
const DOS_NAME_LENGTH: usize = 12;
const DOS_SIGNATURE: &[u8] = b"LARGE.DAT";
const MIFF_SIGNATURE: &[u8] = b"MIFF";
const MAC_TAG: &[u8] = b"_MAC";
const MAC_TAG_OFFSET: usize = 20;
/// A sprite of one row is a placeholder, as sc2kfix reads it.
pub const MIN_HEIGHT: usize = 2;
const SMALL_FIRST: i64 = 0;
const MEDIUM_FIRST: i64 = 500;
const LARGE_FIRST: i64 = 1000;
const SPRITE_COUNT: i64 = 1500;
/// The sprite files and the sprite ID range that each supplies. SMALL also
/// holds medium sprites; OTHER replaces them first.
const SECTIONS: [(&str, i64, i64); 3] = [
    ("LARGE", LARGE_FIRST, SPRITE_COUNT),
    ("OTHER", MEDIUM_FIRST, LARGE_FIRST),
    ("SMALL", SMALL_FIRST, LARGE_FIRST),
];

/// A sprite with Windows palette indices.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Converted {
    pub sprite_id: i64,
    pub width: usize,
    pub height: usize,
    pub pixels: Vec<i32>,
}

pub fn is_dos(bytes: &[u8]) -> bool {
    bytes.len() > DOS_DIRECTORY_ENTRY
        && latin1(&bytes[..DOS_SIGNATURE.len()]).as_bytes() == DOS_SIGNATURE
}

pub fn is_mac(bytes: &[u8]) -> bool {
    bytes.len() > MAC_TAG_OFFSET + MAC_TAG.len()
        && latin1(&bytes[..MIFF_SIGNATURE.len()]).as_bytes() == MIFF_SIGNATURE
        && latin1(&bytes[MAC_TAG_OFFSET..MAC_TAG_OFFSET + MAC_TAG.len()]).as_bytes() == MAC_TAG
}

/// The sc2kfix DOS and Macintosh palette table (L_InitDOSMacPaletteIdxTable)
/// for DOS pixels. Index 232 uses the static colour 0x34, as sc2kfix does for
/// a sprite other than Hangar 1. sc2kfix maps index 1 to 0; the Windows copies
/// of the DOS tile sets use 17, as for the other indices below 204.
pub fn dos_index(index: i32) -> i32 {
    match index {
        ..0 => index,
        0..204 => index + 16,
        204..210 => 0x0a + index - 204,
        210..224 => 0xe8 + index - 210,
        224..232 => index,
        232 => 0x34,
        233..240 => 0xb3 + index - 232,
        255 => 0xff,
        _ => 0,
    }
}

/// Macintosh pixels: 0xfc is the transparent-looking 0x61, and 0xff is black.
pub fn mac_index(index: i32) -> i32 {
    match index {
        0xfc => 0x61,
        0xff => 0,
        _ => dos_index(index),
    }
}

/// The sprites of a DOS tile set.
pub fn dos(bytes: &[u8]) -> Result<Vec<Converted>, String> {
    let files = dos_files(bytes);
    let file = |name: &str| {
        files
            .iter()
            .find(|(known, _)| known == name)
            .map(|(_, data)| data.as_slice())
    };
    let mut result = Vec::new();
    let mut ids = HashSet::new();

    for (name, first, end) in SECTIONS {
        let (Some(header), Some(data)) =
            (file(&format!("{name}.HED")), file(&format!("{name}.DAT")))
        else {
            continue;
        };

        for entry in sprites::dos(header, data).sprites {
            if entry.sprite_id < first || entry.sprite_id >= end || ids.contains(&entry.sprite_id) {
                continue;
            }

            if let Some(converted) = convert(&entry, dos_index) {
                ids.insert(converted.sprite_id);
                result.push(converted);
            }
        }
    }

    if result.is_empty() {
        return Err("No DOS tile set sprites were found.".into());
    }

    Ok(result)
}

/// The sprites of a Macintosh tile set.
pub fn mac(bytes: &[u8]) -> Result<Vec<Converted>, String> {
    let decoded = sprites::mac_tile_set(bytes);
    let result: Vec<Converted> = decoded
        .sprites
        .iter()
        .filter_map(|entry| convert(entry, mac_index))
        .collect();

    if result.is_empty() {
        let error = if decoded.error.is_empty() {
            "No Macintosh tile set sprites were found.".into()
        } else {
            decoded.error
        };

        return Err(error);
    }

    Ok(result)
}

/// The sprite files of a DOS tile set, by name. Each directory entry holds a
/// 12-byte name and a little-endian offset; a file ends at the next offset.
fn dos_files(bytes: &[u8]) -> Vec<(String, Vec<u8>)> {
    let mut entries: Vec<(String, usize)> = Vec::new();
    let mut position = 0;
    let mut data_start = bytes.len();

    while position + DOS_DIRECTORY_ENTRY <= data_start.min(bytes.len()) {
        let name = latin1(&bytes[position..position + DOS_NAME_LENGTH]);
        let at = position + DOS_NAME_LENGTH;
        let offset =
            u32::from_le_bytes([bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3]]) as usize;

        if name.is_empty() || offset > bytes.len() {
            break;
        }

        entries.push((name.to_uppercase(), offset));
        data_start = data_start.min(offset);
        position += DOS_DIRECTORY_ENTRY;
    }

    let mut files: Vec<(String, Vec<u8>)> = Vec::new();

    for (index, (name, start)) in entries.iter().enumerate() {
        let end = entries
            .get(index + 1)
            .map_or(bytes.len(), |next| next.1)
            .max(*start);
        let data = bytes[*start..end].to_vec();

        match files.iter_mut().find(|(known, _)| known == name) {
            Some(slot) => slot.1 = data,
            None => files.push((name.clone(), data)),
        }
    }

    files
}

/// A sprite with converted indices, or nothing for a placeholder or a sprite
/// that does not decode.
fn convert(entry: &Sprite, map: fn(i32) -> i32) -> Option<Converted> {
    if entry.height < MIN_HEIGHT {
        return None;
    }

    let pixels = if entry.indices.is_empty() {
        sprite::decode(
            &entry.encoded,
            entry.width as i32,
            entry.height as i32,
            entry.allow_unpadded_odd_runs,
        )
        .ok()?
        .pixels
    } else {
        entry.indices.clone()
    };
    let pixels: Vec<i32> = pixels.into_iter().map(map).collect();

    if entry.width < 1
        || pixels.len() != entry.width * entry.height
        || !pixels.iter().all(|pixel| (-1..=255).contains(pixel))
    {
        return None;
    }

    Some(Converted {
        sprite_id: entry.sprite_id,
        width: entry.width,
        height: entry.height,
        pixels,
    })
}

#[cfg(test)]
mod tests {
    use super::{dos_files, dos_index, is_dos, is_mac, mac_index};

    #[test]
    fn indices_follow_the_sc2kfix_table() {
        assert_eq!(
            [dos_index(0), dos_index(1), dos_index(203), dos_index(204)],
            [16, 17, 219, 0x0a]
        );
        assert_eq!(
            [
                dos_index(212),
                dos_index(224),
                dos_index(232),
                dos_index(233)
            ],
            [0xea, 224, 0x34, 0xb4]
        );
        assert_eq!(
            [dos_index(250), dos_index(255), dos_index(-1)],
            [0, 0xff, -1]
        );
        assert_eq!(
            [mac_index(0xfc), mac_index(0xff), mac_index(20)],
            [0x61, 0, 36]
        );
    }

    #[test]
    fn dos_archives_name_their_files() {
        let mut bytes = b"LARGE.DAT\0\0\0".to_vec();
        bytes.extend(32_u32.to_le_bytes());
        bytes.extend(b"large.hed\0\0\0");
        bytes.extend(34_u32.to_le_bytes());
        bytes.extend([1, 2, 3]);
        assert!(is_dos(&bytes) && !is_mac(&bytes));
        let files = dos_files(&bytes);
        assert_eq!(
            files,
            [
                ("LARGE.DAT".into(), vec![1, 2]),
                ("LARGE.HED".into(), vec![3])
            ]
        );
    }
}
