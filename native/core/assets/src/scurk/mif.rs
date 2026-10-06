//! SCURK MIF tile sets: a MIFF/SC2K file with an INFO chunk and a TILE chunk of
//! SHAP pieces (sprite artwork) and NAME pieces (object names), as ScurkMif.

use crate::bytes::latin1;
use sc2k_formats::sprite;

pub const INFO_LENGTH: usize = 0x72;
const FILE_HEADER_LENGTH: usize = 12;
/// Macintosh SCURK writes a TILE length of 2, the size of the piece count.
const MAC_TILE_LENGTH: usize = 2;
const SHAPE_HEADER_LENGTH: usize = 10;
const NAME_HEADER_LENGTH: usize = 4;
const MAX_SHAPE_WIDTH: i64 = 255;
const MAX_ROW_BYTES: usize = 255;
const MAX_RUN: usize = 255;
/// Row and run commands of the sprite encoding.
const ROW_BLOCK: u8 = 1;
const TRANSPARENT_RUN: u8 = 3;
const PIXEL_RUN: u8 = 4;
/// The end of a sprite that SCURK writes, and the end that the game reads.
const SCURK_END: [u8; 4] = [2, 1, 2, 2];
const GAME_END: [u8; 2] = [0, 2];

/// A SHAP piece with artwork.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Shape {
    pub width: i64,
    pub height: i64,
    /// The offset of the pixels in the file.
    pub offset: usize,
    /// The pixels with the game's sprite end.
    pub encoded: Vec<u8>,
    /// The earlier shapes of the same sprite.
    pub duplicate_index: i64,
    /// True when a pixel is opaque, so the shape replaces the original sprite.
    pub opaque: bool,
}

/// One piece of the TILE chunk, kept byte for byte for a save.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Piece {
    pub tag: String,
    pub sprite_id: i64,
    pub raw: Vec<u8>,
    /// The artwork of a SHAP piece; sc2kfix writes empty shapes without one.
    pub shape: Option<Shape>,
    /// The text of a NAME piece.
    pub name: Option<String>,
}

/// A parsed tile set. A failed parse keeps the pieces that it read.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Mif {
    pub info: Vec<u8>,
    pub piece_count: usize,
    pub pieces: Vec<Piece>,
    pub error: String,
}

fn u16_be(data: &[u8], at: usize) -> usize {
    usize::from(u16::from_be_bytes([data[at], data[at + 1]]))
}

fn u32_be(data: &[u8], at: usize) -> usize {
    u32::from_be_bytes([data[at], data[at + 1], data[at + 2], data[at + 3]]) as usize
}

fn tag(data: &[u8], at: usize) -> String {
    latin1(&data[at..at + 4])
}

/// The pixels with the game's sprite end in place of the SCURK end.
pub fn normalize_pixel_end(bytes: &[u8]) -> Vec<u8> {
    match bytes.strip_suffix(&SCURK_END) {
        Some(body) => [body, &GAME_END].concat(),
        None => bytes.to_vec(),
    }
}

/// 1 for a shape with an opaque pixel, 0 for a blank shape, or the decode error.
pub fn shape_state(
    width: i64,
    height: i64,
    encoded: &[u8],
    allow_unpadded_odd_runs: bool,
) -> Result<bool, String> {
    let decoded = sprite::decode(
        encoded,
        width as i32,
        height as i32,
        allow_unpadded_odd_runs,
    )?;

    Ok(decoded.pixels.iter().any(|&pixel| pixel >= 0))
}

/// The SCURK encoding of palette indices; -1 is transparent. `None` when a
/// row needs more than 255 bytes.
pub fn encode_pixels(width: usize, height: usize, pixels: &[i32]) -> Option<Vec<u8>> {
    let mut encoded = Vec::new();

    for y in 0..height {
        let line = &pixels[y * width..(y + 1) * width];
        let mut row = Vec::new();
        let mut x = 0;

        while x < width {
            let transparent = line[x] < 0;
            let start = x;

            while x < width && (line[x] < 0) == transparent && x - start < MAX_RUN {
                x += 1;
            }

            let count = x - start;
            row.push(count as u8);

            if transparent {
                row.push(TRANSPARENT_RUN);
            } else {
                row.push(PIXEL_RUN);
                row.extend(line[start..x].iter().map(|&pixel| pixel as u8));

                if count % 2 == 1 {
                    row.push(0);
                }
            }
        }

        if row.len() > MAX_ROW_BYTES {
            return None;
        }

        encoded.push(row.len() as u8);
        encoded.push(ROW_BLOCK);
        encoded.extend(row);
    }

    encoded.extend_from_slice(&SCURK_END);

    Some(encoded)
}

/// The SHAP payload of new artwork.
pub fn shape_payload(
    sprite_id: i64,
    width: i64,
    height: i64,
    pixels: &[i32],
) -> Result<Vec<u8>, String> {
    if !(0..=0xffff).contains(&sprite_id) {
        return Err("SHAP sprite ID is outside the 16-bit range".into());
    }

    if width <= 0 || height <= 0 || width > MAX_SHAPE_WIDTH || height > 0xffff {
        return Err("SHAP dimensions are invalid".into());
    }

    if pixels.len() as i64 != width * height {
        return Err("SHAP pixel count does not match its dimensions".into());
    }

    if pixels.iter().any(|&pixel| !(-1..=0xff).contains(&pixel)) {
        return Err("SHAP palette index is invalid".into());
    }

    let data = encode_pixels(width as usize, height as usize, pixels)
        .ok_or("SHAP pixels cannot be encoded")?;
    let mut payload = Vec::with_capacity(SHAPE_HEADER_LENGTH + data.len());
    payload.extend_from_slice(&(sprite_id as u16).to_be_bytes());
    payload.extend_from_slice(&(width as u16).to_be_bytes());
    payload.extend_from_slice(&(height as u16).to_be_bytes());
    payload.extend_from_slice(&(data.len() as u32).to_be_bytes());
    payload.extend(data);

    Ok(payload)
}

/// The NAME payload of an object name. Other characters than ASCII become spaces.
pub fn name_payload(sprite_id: i64, text: &str) -> Result<Vec<u8>, String> {
    if !(0..=0xffff).contains(&sprite_id) {
        return Err("NAME sprite ID is outside the 16-bit range".into());
    }

    let mut bytes: Vec<u8> = text
        .chars()
        .map(|character| {
            if character.is_ascii() {
                character as u8
            } else {
                b' '
            }
        })
        .collect();

    if bytes.len() + 1 > 0xffff {
        return Err("NAME text is too long".into());
    }

    bytes.push(0);
    let mut payload = Vec::with_capacity(NAME_HEADER_LENGTH + bytes.len());
    payload.extend_from_slice(&(sprite_id as u16).to_be_bytes());
    payload.extend_from_slice(&(bytes.len() as u16).to_be_bytes());
    payload.extend(bytes);

    Ok(payload)
}

impl Mif {
    fn fail(mut self, message: impl Into<String>) -> Self {
        self.error = message.into();
        self
    }

    /// Parse a tile set.
    pub fn parse(bytes: &[u8]) -> Self {
        let mif = Self::default();

        if bytes.len() < FILE_HEADER_LENGTH {
            return mif.fail("file is shorter than the MIFF header");
        }

        if tag(bytes, 0) != "MIFF" || tag(bytes, 8) != "SC2K" {
            return mif.fail("file does not have a MIFF/SC2K header");
        }

        if u32_be(bytes, 4) as i64 != bytes.len() as i64 - 8 {
            return mif.fail("MIFF length does not match the file size");
        }

        let mut position = FILE_HEADER_LENGTH;

        if position + 8 > bytes.len() || tag(bytes, position) != "INFO" {
            return mif.fail("INFO chunk is missing");
        }

        let info_length = u32_be(bytes, position + 4);
        position += 8;

        if position + info_length > bytes.len() {
            return mif.fail("INFO chunk extends past the file");
        }

        let mut mif = Self {
            info: bytes[position..position + info_length].to_vec(),
            ..Self::default()
        };
        position += info_length;

        if position + 10 > bytes.len() || tag(bytes, position) != "TILE" {
            return mif.fail("TILE chunk is missing");
        }

        let tile_length = u32_be(bytes, position + 4);
        position += 8;
        let mut tile_end = position + tile_length;

        if tile_length == MAC_TILE_LENGTH && tile_end < bytes.len() {
            tile_end = bytes.len();
        }

        if tile_end != bytes.len() {
            return mif.fail("TILE chunk length does not match the file size");
        }

        mif.piece_count = u16_be(bytes, position);
        position += 2;
        let mut duplicates: Vec<(i64, i64)> = Vec::new();

        for index in 0..mif.piece_count {
            if position + 8 > tile_end {
                return mif.fail(format!("piece {index} header extends past the TILE chunk"));
            }

            let piece_tag = tag(bytes, position);
            let start = position + 8;
            let end = start + u32_be(bytes, position + 4);

            if end > tile_end {
                return mif.fail(format!("piece {index} extends past the TILE chunk"));
            }

            let parsed = match piece_tag.as_str() {
                "SHAP" => mif.parse_shape(bytes, start, end, &mut duplicates),
                "NAME" => mif.parse_name(bytes, start, end),
                _ => Err(format!("piece {index} has unknown tag {piece_tag}")),
            };

            if let Err(error) = parsed {
                return mif.fail(error);
            }

            position = end;
        }

        if position != tile_end {
            return mif.fail("TILE chunk has data after its declared pieces");
        }

        mif
    }

    fn parse_shape(
        &mut self,
        bytes: &[u8],
        start: usize,
        end: usize,
        duplicates: &mut Vec<(i64, i64)>,
    ) -> Result<(), String> {
        if end - start < SHAPE_HEADER_LENGTH {
            return Err("SHAP payload is shorter than its header".into());
        }

        let sprite_id = u16_be(bytes, start) as i64;
        let (width, height) = (
            u16_be(bytes, start + 2) as i64,
            u16_be(bytes, start + 4) as i64,
        );

        if start + SHAPE_HEADER_LENGTH + u32_be(bytes, start + 6) != end {
            return Err(format!(
                "SHAP sprite {sprite_id} has an invalid pixel length"
            ));
        }

        let mut piece = Piece {
            tag: "SHAP".into(),
            sprite_id,
            raw: bytes[start..end].to_vec(),
            ..Piece::default()
        };

        // sc2kfix writes an empty shape for each sprite that a tile set keeps;
        // the record stays for a save, and the sprite keeps its original artwork
        if width <= 0 || height <= 0 {
            self.pieces.push(piece);

            return Ok(());
        }

        let offset = start + SHAPE_HEADER_LENGTH;
        let duplicate_index = match duplicates.iter_mut().find(|(id, _)| *id == sprite_id) {
            Some(entry) => {
                entry.1 += 1;
                entry.1 - 1
            }
            None => {
                duplicates.push((sprite_id, 1));
                0
            }
        };
        let encoded = normalize_pixel_end(&bytes[offset..end]);
        let opaque = shape_state(width, height, &encoded, true)
            .map_err(|error| format!("sprite {sprite_id} at 0x{offset:x}: {error}"))?;
        piece.shape = Some(Shape {
            width,
            height,
            offset,
            encoded,
            duplicate_index,
            opaque,
        });
        self.pieces.push(piece);

        Ok(())
    }

    fn parse_name(&mut self, bytes: &[u8], start: usize, end: usize) -> Result<(), String> {
        if end - start < NAME_HEADER_LENGTH {
            return Err("NAME payload is shorter than its header".into());
        }

        let sprite_id = u16_be(bytes, start) as i64;

        if start + NAME_HEADER_LENGTH + u16_be(bytes, start + 2) != end {
            return Err(format!("NAME {sprite_id} has an invalid text length"));
        }

        let mut text = &bytes[start + NAME_HEADER_LENGTH..end];

        while let Some((&0, rest)) = text.split_last() {
            text = rest;
        }

        self.pieces.push(Piece {
            tag: "NAME".into(),
            sprite_id,
            raw: bytes[start..end].to_vec(),
            shape: None,
            name: Some(latin1(text)),
        });

        Ok(())
    }
}

/// The file of a tile set. A Macintosh tile set saves with the Windows INFO length.
pub fn to_bytes(info: &[u8], pieces: &[(String, Vec<u8>)]) -> Result<Vec<u8>, String> {
    if pieces.len() > 0xffff {
        return Err("TILE piece count is too large".into());
    }

    let mut tile = (pieces.len() as u16).to_be_bytes().to_vec();

    for (piece_tag, payload) in pieces {
        if piece_tag.chars().count() != 4 {
            return Err("TILE piece has an invalid tag".into());
        }

        tile.extend(piece_tag.chars().map(|character| {
            if character.is_ascii() {
                character as u8
            } else {
                b' '
            }
        }));
        tile.extend_from_slice(&(payload.len() as u32).to_be_bytes());
        tile.extend_from_slice(payload);
    }

    let mut info = info.to_vec();
    info.resize(INFO_LENGTH, 0);
    let mut bytes = b"MIFF\0\0\0\0SC2KINFO".to_vec();
    bytes.extend_from_slice(&(info.len() as u32).to_be_bytes());
    bytes.extend(info);
    bytes.extend_from_slice(b"TILE");
    bytes.extend_from_slice(&(tile.len() as u32).to_be_bytes());
    bytes.extend(tile);
    let size = (bytes.len() - 8) as u32;
    bytes[4..8].copy_from_slice(&size.to_be_bytes());

    Ok(bytes)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_saved_tile_set_parses_again() {
        let shape = shape_payload(7, 2, 1, &[5, -1]).unwrap();
        let name = name_payload(7, "Park").unwrap();
        let bytes = to_bytes(
            b"NIW_",
            &[("SHAP".into(), shape.clone()), ("NAME".into(), name)],
        )
        .unwrap();
        let mif = Mif::parse(&bytes);
        assert_eq!(mif.error, "");
        assert_eq!((mif.info.len(), mif.piece_count), (INFO_LENGTH, 2));
        assert_eq!(mif.pieces[0].raw, shape);
        assert!(
            mif.pieces[0]
                .shape
                .as_ref()
                .is_some_and(|shape| shape.opaque && shape.encoded.ends_with(&GAME_END))
        );
        assert_eq!(mif.pieces[1].name.as_deref(), Some("Park"));
    }

    #[test]
    fn malformed_files_report_their_problem() {
        assert_eq!(
            Mif::parse(b"MIFF").error,
            "file is shorter than the MIFF header"
        );
        assert_eq!(
            Mif::parse(b"MIFF\0\0\0\x04SC2K").error,
            "INFO chunk is missing"
        );
        assert!(
            shape_payload(1, 256, 1, &[0; 256])
                .unwrap_err()
                .contains("dimensions")
        );
        assert_eq!(
            encode_pixels(2, 1, &[-1, -1]).unwrap(),
            vec![2, 1, 2, 3, 2, 1, 2, 2]
        );
    }
}
