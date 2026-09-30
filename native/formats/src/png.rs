//! Indexed PNG records. Editor-authored files keep duplicate palette indices:
//! the decoder rewrites the palette so that each decoded pixel reads as its
//! index. Zlib compression and pixel decoding stay with the caller.
use super::crc32;

pub const SIGNATURE: [u8; 8] = [137, 80, 78, 71, 13, 10, 26, 10];
pub const MAX_DIMENSION: u32 = 4096;

fn u32_be(bytes: &[u8], at: usize) -> u32 {
    u32::from_be_bytes([bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3]])
}

pub fn chunk(kind: &[u8; 4], payload: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(payload.len() + 12);
    out.extend_from_slice(&(payload.len() as u32).to_be_bytes());
    out.extend_from_slice(kind);
    out.extend_from_slice(payload);
    out.extend_from_slice(&crc32::calculate(&out[4..]).to_be_bytes());
    out
}

/// Scanlines with filter bytes, and the index that stands for -1 pixels.
pub struct Scanlines {
    pub raw: Vec<u8>,
    pub transparent: Option<u8>,
}

/// Checks the pixels of an 8-bit indexed image and makes its scanlines. A
/// pixel of -1 takes the first palette index that no pixel uses.
pub fn scanlines(width: i64, height: i64, pixels: &[i32]) -> Result<Scanlines, String> {
    if !(1..=i64::from(MAX_DIMENSION)).contains(&width) || !(1..=i64::from(MAX_DIMENSION)).contains(&height) {
        return Err("PNG dimensions must be 1 through 4096".into());
    }
    let (w, h) = (width as usize, height as usize);
    if pixels.len() != w * h {
        return Err("Invalid PNG pixels or palette".into());
    }
    let mut used = [false; 256];
    let mut has_transparency = false;
    for &pixel in pixels {
        if !(-1..=255).contains(&pixel) {
            return Err("PNG palette index must be -1 through 255".into());
        }
        if pixel == -1 {
            has_transparency = true;
        } else {
            used[pixel as usize] = true;
        }
    }
    let transparent = if has_transparency {
        match used.iter().position(|u| !u) {
            Some(index) => Some(index as u8),
            None => return Err("Indexed PNG needs an unused palette index for transparency".into()),
        }
    } else {
        None
    };
    let mut raw = Vec::with_capacity(h * (w + 1));
    for row in pixels.chunks_exact(w) {
        raw.push(0); // filter: none
        raw.extend(row.iter().map(|p| if *p == -1 { transparent.unwrap_or(0) } else { *p as u8 }));
    }
    Ok(Scanlines { raw, transparent })
}

/// A complete file. `palette` holds 256 RGB colors and `idat` the zlib stream.
pub fn assemble(width: u32, height: u32, palette: &[u8], transparent: Option<u8>, idat: &[u8]) -> Vec<u8> {
    let mut header = Vec::with_capacity(13);
    header.extend_from_slice(&width.to_be_bytes());
    header.extend_from_slice(&height.to_be_bytes());
    header.extend_from_slice(&[8, 3, 0, 0, 0]);
    let mut out = SIGNATURE.to_vec();
    out.extend(chunk(b"IHDR", &header));
    out.extend(chunk(b"PLTE", palette));
    if let Some(index) = transparent {
        let mut alpha = vec![255; usize::from(index) + 1];
        alpha[usize::from(index)] = 0;
        out.extend(chunk(b"tRNS", &alpha));
    }
    out.extend(chunk(b"IDAT", idat));
    out.extend(chunk(b"IEND", &[]));
    out
}

/// A checked file whose palette makes each decoded RGBA8 pixel read as a
/// little-endian index: opaque index i is (i, 0, 0, 0) and a transparent
/// index is (255, 255, 255, 255), or -1.
pub struct Rewritten {
    pub bytes: Vec<u8>,
    pub width: u32,
    pub height: u32,
    /// 256 RGB colors. Entries past the file's palette are black.
    pub palette: Vec<u8>,
}

// An index past a short palette decodes as entry 0.
fn index_palette_chunks(palette_count: usize, bit_depth: u8, alpha: &[u8; 256]) -> Vec<u8> {
    let mut colors = Vec::new();
    let mut transparency = Vec::new();
    for entry in 0..1_usize << bit_depth {
        let index = if entry < palette_count { entry } else { 0 };
        if alpha[index] == 255 {
            colors.extend_from_slice(&[index as u8, 0, 0]);
            transparency.push(0);
        } else {
            colors.extend_from_slice(&[255, 255, 255]);
            transparency.push(255);
        }
    }
    let mut out = chunk(b"PLTE", &colors);
    out.extend(chunk(b"tRNS", &transparency));
    out
}

pub fn rewrite(bytes: &[u8], strict_palette: bool) -> Result<Rewritten, String> {
    if bytes.len() < 8 || bytes[..8] != SIGNATURE {
        return Err("Invalid PNG signature".into());
    }
    let mut rewritten = bytes[..8].to_vec();
    let mut palette: Vec<u8> = Vec::new();
    let mut alpha = [255_u8; 256];
    let mut position = 8;
    let mut palette_count = 0;
    let mut bit_depth = 8_u8;
    let (mut width, mut height) = (0_u32, 0_u32);
    let (mut has_data, mut ended_data, mut has_alpha, mut finished) = (false, false, false, false);
    while position + 12 <= bytes.len() {
        let length = u32_be(bytes, position) as usize;
        if length > bytes.len() - position - 12 {
            return Err("PNG chunk extends past the file".into());
        }
        let kind = &bytes[position + 4..position + 8];
        let payload = &bytes[position + 8..position + 8 + length];
        if crc32::calculate(&bytes[position + 4..position + 8 + length]) != u32_be(bytes, position + 8 + length) {
            return Err("Invalid PNG chunk checksum".into());
        }
        if width == 0 && kind != b"IHDR" {
            return Err("PNG must start with IHDR".into());
        }
        if has_data && kind != b"IDAT" {
            ended_data = true;
        }
        match kind {
            b"IHDR" => {
                if width != 0 || length != 13 {
                    return Err("Invalid PNG header".into());
                }
                width = u32_be(payload, 0);
                height = u32_be(payload, 4);
                if !(1..=MAX_DIMENSION).contains(&width) || !(1..=MAX_DIMENSION).contains(&height) {
                    return Err("PNG dimensions must be 1 through 4096".into());
                }
                bit_depth = payload[8];
                if payload[9] != 3 || ![1, 2, 4, 8].contains(&bit_depth) || (strict_palette && bit_depth != 8) {
                    return Err(if strict_palette {
                        "PNG must use 8-bit indexed color"
                    } else {
                        "PNG must use 1-, 2-, 4-, or 8-bit indexed color"
                    }
                    .into());
                }
                if payload[10] != 0 || payload[11] != 0 || payload[12] > 1 {
                    return Err("Unsupported PNG encoding".into());
                }
            }
            b"PLTE" => {
                if !palette.is_empty()
                    || has_data
                    || has_alpha
                    || length == 0
                    || !length.is_multiple_of(3)
                    || length / 3 > 1 << bit_depth
                    || (strict_palette && length != 768)
                {
                    return Err(if strict_palette {
                        "PNG must have one 256-color palette before pixel data"
                    } else {
                        "PNG must have one valid indexed palette before pixel data"
                    }
                    .into());
                }
                palette_count = length / 3;
                palette = payload.to_vec();
                palette.resize(768, 0);
                // The index palette replaces this chunk before the first IDAT.
                position += length + 12;
                continue;
            }
            b"tRNS" => {
                if has_alpha || has_data || palette.is_empty() || length < 1 || length > palette_count {
                    return Err("Invalid PNG transparency table".into());
                }
                has_alpha = true;
                for (index, value) in payload.iter().enumerate() {
                    // no partial alpha, and even invisible pixels keep their index
                    if *value != 0 && *value != 255 {
                        return Err("PNG transparency must be fully clear or opaque".into());
                    }
                    alpha[index] = *value;
                }
                position += length + 12;
                continue;
            }
            b"IDAT" => {
                if palette.is_empty() || ended_data {
                    return Err("Invalid PNG pixel-data order".into());
                }
                if !has_data {
                    rewritten.extend(index_palette_chunks(palette_count, bit_depth, &alpha));
                }
                has_data = true;
            }
            b"IEND" => {
                if length != 0 || !has_data {
                    return Err("Invalid PNG end chunk".into());
                }
                finished = true;
            }
            _ => {
                if kind[0] & 32 == 0 {
                    let name: String = kind.iter().map(|b| char::from(*b)).collect();
                    return Err(format!("Unsupported critical PNG chunk: {name}"));
                }
                // omit color profiles and other editor metadata
                position += length + 12;
                continue;
            }
        }
        // The checksum is verified, so the original chunk bytes are reused.
        rewritten.extend_from_slice(&bytes[position..position + length + 12]);
        position += length + 12;
        if finished {
            break;
        }
    }
    if !finished || position != bytes.len() {
        return Err("PNG is incomplete or has trailing bytes".into());
    }
    Ok(Rewritten {
        bytes: rewritten,
        width,
        height,
        palette,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn file(pixels: &[i32], width: i64) -> Vec<u8> {
        let lines = scanlines(width, pixels.len() as i64 / width, pixels).unwrap();
        // a stored zlib stream is enough for the record checks
        assemble(
            width as u32,
            (pixels.len() as i64 / width) as u32,
            &[7; 768],
            lines.transparent,
            &lines.raw,
        )
    }

    #[test]
    fn scanlines_pick_an_unused_transparent_index() {
        let lines = scanlines(2, 2, &[0, -1, 2, 1]).unwrap();
        assert_eq!(lines.transparent, Some(3));
        assert_eq!(lines.raw, vec![0, 0, 3, 0, 2, 1]);
        let all: Vec<i32> = (0..256).chain([-1]).collect();
        assert!(scanlines(257, 1, &all).is_err());
        assert_eq!(scanlines(0, 1, &[]).err().unwrap(), "PNG dimensions must be 1 through 4096");
    }

    #[test]
    fn rewrite_replaces_the_palette() {
        let rewritten = rewrite(&file(&[1, -1], 2), true).unwrap();
        assert_eq!((rewritten.width, rewritten.height), (2, 1));
        assert_eq!(&rewritten.palette[..3], &[7, 7, 7]);
        // signature, IHDR, index PLTE (768 + 12), index tRNS (256 + 12), 3-byte IDAT, IEND
        assert_eq!(rewritten.bytes.len(), 8 + 25 + 780 + 268 + 15 + 12);
    }

    #[test]
    fn rewrite_rejects_damage() {
        let mut bytes = file(&[1, 2], 2);
        bytes[20] ^= 1;
        assert_eq!(rewrite(&bytes, true).err().unwrap(), "Invalid PNG chunk checksum");
        assert_eq!(rewrite(&[1, 2, 3], true).err().unwrap(), "Invalid PNG signature");
        let mut trailing = file(&[1, 2], 2);
        trailing.push(0);
        assert_eq!(rewrite(&trailing, true).err().unwrap(), "PNG is incomplete or has trailing bytes");
    }
}
