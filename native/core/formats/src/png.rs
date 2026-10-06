//! Indexed PNG files. Editor-authored files keep duplicate palette indices, so
//! a decoded pixel is its palette index, never a color.
use super::crc32;

pub const SIGNATURE: [u8; 8] = [137, 80, 78, 71, 13, 10, 26, 10];
pub const MAX_DIMENSION: u32 = 4096;

/// The IHDR color type of indexed images.
const INDEXED: u8 = 3;
const BIT_DEPTHS: [u8; 4] = [1, 2, 4, 8];

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

    // 8-bit indexed; deflate, adaptive filters and no interlacing
    header.extend_from_slice(&[8, INDEXED, 0, 0, 0]);
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

                if payload[9] != INDEXED || !BIT_DEPTHS.contains(&bit_depth) || (strict_palette && bit_depth != 8) {
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

/// An 8-bit RGBA file of `rgba` pixels, with no filters.
pub fn encode_rgba(width: u32, height: u32, rgba: &[u8]) -> Result<Vec<u8>, String> {
    let row = width as usize * 4;

    if width == 0 || height == 0 || rgba.len() != row * height as usize {
        return Err("Invalid PNG pixels".into());
    }

    let mut raw = Vec::with_capacity((row + 1) * height as usize);

    for line in rgba.chunks_exact(row) {
        raw.push(0);
        raw.extend_from_slice(line);
    }

    let mut header = Vec::with_capacity(13);
    header.extend_from_slice(&width.to_be_bytes());
    header.extend_from_slice(&height.to_be_bytes());
    header.extend_from_slice(&[8, RGBA_COLOR, 0, 0, 0]);
    let mut out = SIGNATURE.to_vec();
    out.extend(chunk(b"IHDR", &header));
    out.extend(chunk(b"IDAT", &miniz_oxide::deflate::compress_to_vec_zlib(&raw, 6)));
    out.extend(chunk(b"IEND", &[]));

    Ok(out)
}

/// The PNG color type of 8-bit RGBA pixels.
const RGBA_COLOR: u8 = 6;

/// The Adam7 passes: first column, first row, column step, and row step.
const ADAM7: [(usize, usize, usize, usize); 7] = [
    (0, 0, 8, 8),
    (4, 0, 8, 8),
    (0, 4, 4, 8),
    (2, 0, 4, 4),
    (0, 2, 2, 4),
    (1, 0, 2, 2),
    (0, 1, 1, 2),
];
const DECODE_ERROR: &str = "Cannot decode PNG pixel data";

/// A decoded indexed image: one palette index for each pixel, or -1 for a
/// transparent index, and 256 RGB colors.
pub struct Decoded {
    pub width: u32,
    pub height: u32,
    pub pixels: Vec<i32>,
    pub palette: Vec<u8>,
}

/// An 8-bit indexed file: the pixels deflate at the default level.
pub fn encode_indexed(width: i64, height: i64, pixels: &[i32], palette: &[u8]) -> Result<Vec<u8>, String> {
    let lines = scanlines(width, height, pixels)?;

    if palette.len() != 768 {
        return Err("Invalid PNG pixels or palette".into());
    }

    let idat = miniz_oxide::deflate::compress_to_vec_zlib(&lines.raw, 6);

    Ok(assemble(width as u32, height as u32, palette, lines.transparent, &idat))
}

/// The fields of the chunks that the pixel decoder needs.
struct Layout {
    bit_depth: usize,
    interlaced: bool,
    palette_count: usize,
    alpha: [u8; 256],
    data: Vec<u8>,
}

fn layout(bytes: &[u8]) -> Layout {
    let mut layout = Layout {
        bit_depth: 8,
        interlaced: false,
        palette_count: 0,
        alpha: [255; 256],
        data: Vec::new(),
    };
    let mut position = 8;

    while position + 12 <= bytes.len() {
        let length = u32_be(bytes, position) as usize;
        let payload = &bytes[position + 8..position + 8 + length];

        match &bytes[position + 4..position + 8] {
            b"IHDR" => {
                layout.bit_depth = usize::from(payload[8]);
                layout.interlaced = payload[12] == 1;
            }
            b"PLTE" => layout.palette_count = length / 3,
            b"tRNS" => layout.alpha[..length].copy_from_slice(payload),
            b"IDAT" => layout.data.extend_from_slice(payload),
            _ => {}
        }

        position += length + 12;
    }

    layout
}

fn paeth(left: u8, up: u8, corner: u8) -> u8 {
    let estimate = i16::from(left) + i16::from(up) - i16::from(corner);
    let (to_left, to_up, to_corner) = (
        (estimate - i16::from(left)).abs(),
        (estimate - i16::from(up)).abs(),
        (estimate - i16::from(corner)).abs(),
    );

    if to_left <= to_up && to_left <= to_corner {
        left
    } else if to_up <= to_corner {
        up
    } else {
        corner
    }
}

/// Undo the filter of each scanline of one image. Indexed pixels filter by whole bytes.
fn unfilter(data: &[u8], line_bytes: usize, rows: usize) -> Result<Vec<u8>, String> {
    let mut output = vec![0_u8; line_bytes * rows];

    for row in 0..rows {
        let start = row * (line_bytes + 1);
        let line = data.get(start..start + line_bytes + 1).ok_or(DECODE_ERROR)?;
        let (filter, line) = (line[0], &line[1..]);

        for column in 0..line_bytes {
            let left = if column > 0 { output[row * line_bytes + column - 1] } else { 0 };
            let up = if row > 0 { output[(row - 1) * line_bytes + column] } else { 0 };
            let corner = if row > 0 && column > 0 {
                output[(row - 1) * line_bytes + column - 1]
            } else {
                0
            };
            let predicted = match filter {
                0 => 0,
                1 => left,
                2 => up,
                3 => ((u16::from(left) + u16::from(up)) / 2) as u8,
                4 => paeth(left, up, corner),
                _ => return Err(DECODE_ERROR.into()),
            };
            output[row * line_bytes + column] = line[column].wrapping_add(predicted);
        }
    }

    Ok(output)
}

/// The palette indices of one image of `width` by `rows`, and the bytes that it used.
fn read_indices(data: &[u8], width: usize, rows: usize, bit_depth: usize) -> Result<(Vec<usize>, usize), String> {
    if width == 0 || rows == 0 {
        return Ok((Vec::new(), 0));
    }

    let line_bytes = (width * bit_depth).div_ceil(8);
    let raw = unfilter(data, line_bytes, rows)?;
    let mask = (1_usize << bit_depth) - 1;
    let mut indices = Vec::with_capacity(width * rows);

    for row in raw.chunks_exact(line_bytes) {
        for column in 0..width {
            let bit = column * bit_depth;
            let shift = 8 - bit_depth - bit % 8;
            indices.push((usize::from(row[bit / 8]) >> shift) & mask);
        }
    }

    Ok((indices, rows * (line_bytes + 1)))
}

/// Decode an indexed file. An index past a short palette reads as entry 0;
/// an index with a clear tRNS entry reads as -1.
pub fn decode_indexed(bytes: &[u8], strict_palette: bool) -> Result<Decoded, String> {
    let checked = rewrite(bytes, strict_palette)?;
    let layout = layout(bytes);
    let data = miniz_oxide::inflate::decompress_to_vec_zlib(&layout.data).map_err(|_| DECODE_ERROR.to_string())?;
    let (width, height) = (checked.width as usize, checked.height as usize);
    let mut indices = vec![0_usize; width * height];

    if layout.interlaced {
        let mut offset = 0;

        for (x0, y0, dx, dy) in ADAM7 {
            let pass_width = width.saturating_sub(x0).div_ceil(dx);
            let pass_height = height.saturating_sub(y0).div_ceil(dy);
            let (pass, used) = read_indices(&data[offset.min(data.len())..], pass_width, pass_height, layout.bit_depth)?;

            for (position, index) in pass.into_iter().enumerate() {
                let (x, y) = (x0 + position % pass_width * dx, y0 + position / pass_width * dy);
                indices[y * width + x] = index;
            }

            offset += used;
        }
    } else {
        indices = read_indices(&data, width, height, layout.bit_depth)?.0;
    }

    let pixels = indices
        .into_iter()
        .map(|index| {
            let entry = if index < layout.palette_count { index } else { 0 };

            if layout.alpha[entry] == 255 { entry as i32 } else { -1 }
        })
        .collect();

    Ok(Decoded {
        width: checked.width,
        height: checked.height,
        pixels,
        palette: checked.palette,
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

    #[test]
    fn encoded_files_decode_to_their_indices() {
        let mut palette = vec![0; 768];
        palette[3] = 9;
        let pixels = [0, 1, -1, 1, 0, 0];
        let file = encode_indexed(3, 2, &pixels, &palette).unwrap();
        let decoded = decode_indexed(&file, true).unwrap();
        assert_eq!((decoded.width, decoded.height), (3, 2));
        assert_eq!(decoded.pixels, pixels);
        assert_eq!(decoded.palette[3], 9);
    }
}
