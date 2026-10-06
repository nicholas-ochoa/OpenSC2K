//! The sprite sets of the supplied games, as Sc2ImportSprites. A partial set
//! keeps its valid records and reports the others as warnings.

use super::has_range;
use crate::bytes::latin1;
use crate::scurk::mif::normalize_pixel_end;
use sc2k_formats::sprite;

const MAX_DIMENSION: usize = 4096;
const MAX_TOTAL_PIXELS: usize = 16 * 1024 * 1024;
const MAC_HEADER_SIZE: usize = 34;
const MAC_SHAPE_HEADER_SIZE: usize = 10;
const DATABASE_RECORD_SIZE: usize = 10;
const DOS_RECORD_SIZE: usize = 8;
const DOS_MAX_RECORDS: usize = 65536;
const NO_OFFSET: usize = 0xffff_ffff;
/// Sprite blocks: rows of runs, row data, and the end.
const BLOCK_SKIP: u8 = 0;
const BLOCK_ROW: u8 = 1;
const BLOCK_END: u8 = 2;

/// One sprite: encoded pixels, or decoded palette indices of a DOS sprite.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Sprite {
    pub sprite_id: i64,
    pub width: usize,
    pub height: usize,
    pub encoded: Vec<u8>,
    pub allow_unpadded_odd_runs: bool,
    /// The decoded indices of a DOS sprite; empty for an encoded sprite.
    pub indices: Vec<i32>,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct SpriteSet {
    pub sprites: Vec<Sprite>,
    pub warnings: Vec<String>,
    pub error: String,
}

fn u16_be(data: &[u8], at: usize) -> usize {
    usize::from(u16::from_be_bytes([data[at], data[at + 1]]))
}

fn u32_be(data: &[u8], at: usize) -> usize {
    u32::from_be_bytes([data[at], data[at + 1], data[at + 2], data[at + 3]]) as usize
}

fn u16_le(data: &[u8], at: usize) -> usize {
    usize::from(u16::from_le_bytes([data[at], data[at + 1]]))
}

fn u32_le(data: &[u8], at: usize) -> usize {
    u32::from_le_bytes([data[at], data[at + 1], data[at + 2], data[at + 3]]) as usize
}

/// The decode error of an encoded sprite, as SpriteEntry names it.
fn decode_error(sprite: &Sprite) -> Option<String> {
    sprite::decode(
        &sprite.encoded,
        sprite.width as i32,
        sprite.height as i32,
        sprite.allow_unpadded_odd_runs,
    )
    .err()
    .map(|error| format!("sprite {} at 0x0: {error}", sprite.sprite_id))
}

impl SpriteSet {
    fn finish(mut self, empty_error: &str) -> Self {
        if self.sprites.is_empty() {
            self.error = empty_error.to_string();
        }

        self
    }

    fn failed(message: &str) -> Self {
        Self {
            error: message.to_string(),
            ..Self::default()
        }
    }
}

/// A Macintosh tile set: a count and SHAP chunks, not the Windows MIF layout.
pub fn mac_tile_set(data: &[u8]) -> SpriteSet {
    if data.len() < MAC_HEADER_SIZE
        || latin1(&data[..4]) != "MIFF"
        || u32_be(data, 4) as i64 != data.len() as i64 - 8
        || latin1(&data[8..16]) != "SC2KINFO"
    {
        return SpriteSet::failed("Invalid Macintosh tile-set header.");
    }

    if u32_be(data, 16) != 4 || latin1(&data[20..28]) != "_MACTILE" || u32_be(data, 28) != 2 {
        return SpriteSet::failed("Unsupported Macintosh tile-set directory.");
    }

    let count = u16_be(data, 32);
    let mut cursor = MAC_HEADER_SIZE;
    let mut total_pixels = 0;
    let mut set = SpriteSet::default();

    for index in 0..count {
        if !has_range(data, cursor, 8) || latin1(&data[cursor..cursor + 4]) != "SHAP" {
            set.warnings.push(format!(
                "The Macintosh tile set ends before shape {index}. Kept preceding shapes."
            ));
            break;
        }

        let length = u32_be(data, cursor + 4);
        cursor += 8;

        if !has_range(data, cursor, length) {
            set.warnings.push(format!(
                "Macintosh shape {index} extends past the tile set. Kept preceding shapes."
            ));
            break;
        }

        let start = cursor;
        cursor += length;

        // empty SHAP chunks are placeholders with no ID or dimensions
        if length == 0 {
            continue;
        }

        if length < MAC_SHAPE_HEADER_SIZE
            || u32_be(data, start + 6) != length - MAC_SHAPE_HEADER_SIZE
        {
            set.warnings.push(format!(
                "Macintosh shape {index} has an invalid pixel length."
            ));
            continue;
        }

        let sprite_id = u16_be(data, start) as i64;
        let (width, height) = (u16_be(data, start + 2), u16_be(data, start + 4));

        if width < 1
            || height < 1
            || width > MAX_DIMENSION
            || height > MAX_DIMENSION
            || total_pixels + width * height > MAX_TOTAL_PIXELS
        {
            set.warnings.push(format!(
                "Macintosh shape {sprite_id} exceeds the decoded image limits."
            ));
            continue;
        }

        total_pixels += width * height;
        let sprite = Sprite {
            sprite_id,
            width,
            height,
            encoded: normalize_pixel_end(&data[start + MAC_SHAPE_HEADER_SIZE..cursor]),
            allow_unpadded_odd_runs: true,
            indices: Vec::new(),
        };

        match decode_error(&sprite) {
            Some(error) => set.warnings.push(error),
            None => set.sprites.push(sprite),
        }
    }

    if cursor != data.len() {
        set.warnings
            .push("The Macintosh tile-set size differs from its declared shapes.".into());
    }

    set.finish("No readable Macintosh tile-set shapes were found.")
}

/// The rows of an encoded sprite, or `None` for a malformed one.
fn sprite_rows(bytes: &[u8]) -> Option<usize> {
    let mut cursor = 0;
    let mut rows = 0;

    while cursor + 2 <= bytes.len() {
        let (size, mode) = (usize::from(bytes[cursor]), bytes[cursor + 1]);
        cursor += 2;

        if mode == BLOCK_END {
            return Some(rows);
        }

        if (mode != BLOCK_SKIP && mode != BLOCK_ROW) || !has_range(bytes, cursor, size) {
            return None;
        }

        if mode == BLOCK_ROW {
            rows += 1;
        }

        cursor += size;
    }

    None
}

/// A tile database: a directory of ids and sizes, then the encoded sprites.
pub fn tiles_database(data: &[u8]) -> SpriteSet {
    if data.len() < 2 {
        return SpriteSet::failed("Truncated tile database.");
    }

    let count = u16_le(data, 0);
    let sizes = 2 + count * DATABASE_RECORD_SIZE;
    let mut cursor = sizes + count * 4;

    if count == 0 || cursor > data.len() {
        return SpriteSet::failed("Invalid tile database directory.");
    }

    let mut set = SpriteSet::default();

    for index in 0..count {
        let length = u32_le(data, sizes + index * 4);
        let metadata = 2 + index * DATABASE_RECORD_SIZE;
        let sprite_id = u16_le(data, metadata) as i64;
        let mut height = u16_le(data, metadata + 6);
        let width = u16_le(data, metadata + 8);

        if !has_range(data, cursor, length) {
            set.warnings.push(format!(
                "Tile database ends before sprite {sprite_id}. Kept preceding sprites."
            ));
            break;
        }

        let raw = &data[cursor..cursor + length];
        let encoded = normalize_pixel_end(raw);
        let allow_unpadded_odd_runs = encoded != raw;
        cursor += length;

        if let Some(rows) =
            sprite_rows(&encoded).filter(|&rows| rows > height && rows <= MAX_DIMENSION)
        {
            set.warnings.push(format!("Tile database sprite {sprite_id} stores {rows} rows but declares {height}. Recovered all rows."));
            height = rows;
        }

        if width < 1 || height < 1 || width > MAX_DIMENSION || height > MAX_DIMENSION {
            set.warnings.push(format!(
                "Tile database sprite {sprite_id} has invalid dimensions."
            ));
            continue;
        }

        let sprite = Sprite {
            sprite_id,
            width,
            height,
            encoded,
            allow_unpadded_odd_runs,
            indices: Vec::new(),
        };

        match decode_error(&sprite) {
            Some(error) => set.warnings.push(error),
            None => set.sprites.push(sprite),
        }
    }

    set.finish("No readable tile database sprites were found.")
}

/// The DOS sprites of a directory of offsets and sizes and their data file.
pub fn dos(header: &[u8], data: &[u8]) -> SpriteSet {
    if header.is_empty()
        || !header.len().is_multiple_of(DOS_RECORD_SIZE)
        || header.len() / DOS_RECORD_SIZE > DOS_MAX_RECORDS
    {
        return SpriteSet::failed("Invalid DOS sprite directory.");
    }

    let records = header.len() / DOS_RECORD_SIZE;
    let mut offsets: Vec<usize> = Vec::new();

    for index in 0..records {
        let offset = u32_le(header, index * DOS_RECORD_SIZE);

        if offset < data.len() && !offsets.contains(&offset) {
            offsets.push(offset);
        }
    }

    offsets.sort_unstable();
    let end_of = |offset: usize| {
        offsets
            .binary_search(&offset)
            .ok()
            .map(|position| offsets.get(position + 1).copied().unwrap_or(data.len()))
    };
    let mut set = SpriteSet::default();

    for id in 0..records {
        let offset = u32_le(header, id * DOS_RECORD_SIZE);

        if offset == NO_OFFSET {
            continue;
        }

        let height = usize::from(header[id * DOS_RECORD_SIZE + 4]);
        let width = usize::from(header[id * DOS_RECORD_SIZE + 5]);

        let Some(end) = end_of(offset).filter(|_| width != 0 && height != 0) else {
            set.warnings.push(format!(
                "DOS sprite {id} has an invalid offset or dimension."
            ));
            continue;
        };

        match sprite::decode_dos(data, offset, end, width, height) {
            Ok(decoded) => set.sprites.push(Sprite {
                sprite_id: id as i64,
                width,
                height,
                indices: decoded.pixels,
                ..Sprite::default()
            }),
            Err(error) => set.warnings.push(format!("DOS sprite {id}: {error}")),
        }
    }

    set.finish("No readable DOS sprites were found.")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn databases_keep_their_readable_sprites() {
        let mut data = vec![1, 0];
        data.extend_from_slice(&[7, 0, 0, 0, 0, 0, 1, 0, 1, 0]);
        let sprite = [2, 1, 1, 3, 0, 2];
        data.extend_from_slice(&(sprite.len() as u32).to_le_bytes());
        data.extend_from_slice(&sprite);
        let set = tiles_database(&data);
        assert_eq!(set.error, "");
        assert_eq!(
            (
                set.sprites[0].sprite_id,
                set.sprites[0].width,
                set.sprites[0].height
            ),
            (7, 1, 1)
        );
        assert_eq!(
            tiles_database(&[0, 0]).error,
            "Invalid tile database directory."
        );
        assert_eq!(dos(&[], &[]).error, "Invalid DOS sprite directory.");
        assert_eq!(
            mac_tile_set(b"MIFF").error,
            "Invalid Macintosh tile-set header."
        );
    }
}
