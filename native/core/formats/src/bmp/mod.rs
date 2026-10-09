//! 8-bit indexed Windows bitmaps with 256-color palettes, and their DIB form.

mod encode;
mod palette;

#[cfg(test)]
mod tests;

pub use encode::*;
pub use palette::*;

/// The file header starts with "BM".
const SIGNATURE: [u8; 2] = *b"BM";
const FILE_HEADER_SIZE: usize = 14;
const INFO_HEADER_SIZE: usize = 40;
const COLORS: usize = 256;
const PALETTE_SIZE: usize = COLORS * 4;
const PIXEL_OFFSET: usize = FILE_HEADER_SIZE + INFO_HEADER_SIZE + PALETTE_SIZE;
const MAX_DIMENSION: i64 = 0x7fff;

/// The BI_RLE8 compression of a DIB.
const RLE8: u32 = 1;

fn u16_at(b: &[u8], at: usize) -> u32 {
    u32::from(u16::from_le_bytes([b[at], b[at + 1]]))
}

fn u32_at(b: &[u8], at: usize) -> u32 {
    u32::from_le_bytes([b[at], b[at + 1], b[at + 2], b[at + 3]])
}

fn i32_at(b: &[u8], at: usize) -> i32 {
    i32::from_le_bytes([b[at], b[at + 1], b[at + 2], b[at + 3]])
}

fn row_stride(width: usize) -> usize {
    (width + 3) & !3
}

pub struct Decoded {
    pub width: usize,
    pub height: usize,
    pub pixels: Vec<i32>,
    /// 256 RGB colors.
    pub palette: Vec<u8>,
    pub top_down: bool,
}

pub fn decode(bytes: &[u8]) -> Result<Decoded, String> {
    if bytes.len() < PIXEL_OFFSET {
        return Err("BMP file is shorter than an 8-bit indexed header.".into());
    }

    if bytes[..2] != SIGNATURE {
        return Err("File does not have a Windows BMP signature.".into());
    }

    let declared_size = u32_at(bytes, 2) as usize;

    if declared_size != 0 && declared_size > bytes.len() {
        return Err("BMP file is shorter than its declared size.".into());
    }

    let pixel_offset = u32_at(bytes, 10) as usize;
    let header_size = u32_at(bytes, FILE_HEADER_SIZE) as usize;

    if header_size < INFO_HEADER_SIZE {
        return Err("BMP does not use a supported information header.".into());
    }

    if FILE_HEADER_SIZE + header_size > bytes.len() {
        return Err("BMP information header extends past the file.".into());
    }

    let width = i64::from(i32_at(bytes, 18));
    let signed_height = i64::from(i32_at(bytes, 22));

    if width <= 0 || width > MAX_DIMENSION || signed_height == 0 || signed_height.abs() > MAX_DIMENSION {
        return Err("BMP dimensions are invalid or too large.".into());
    }

    if u16_at(bytes, 26) != 1 {
        return Err("BMP plane count is not one.".into());
    }

    if u16_at(bytes, 28) != 8 {
        return Err("SCURK import requires an 8-bit indexed BMP.".into());
    }

    if u32_at(bytes, 30) != 0 {
        return Err("SCURK import requires an uncompressed BMP.".into());
    }

    let color_count = match u32_at(bytes, 46) {
        0 => COLORS,
        count => count as usize,
    };

    if color_count != COLORS {
        return Err("SCURK import requires exactly 256 palette colors.".into());
    }

    let palette_offset = FILE_HEADER_SIZE + header_size;

    if palette_offset + PALETTE_SIZE > bytes.len() {
        return Err("BMP palette extends past the file.".into());
    }

    if pixel_offset < palette_offset + PALETTE_SIZE || pixel_offset > bytes.len() {
        return Err("BMP pixel offset is invalid.".into());
    }

    let (width, height) = (width as usize, signed_height.unsigned_abs() as usize);
    let stride = row_stride(width);

    if pixel_offset + stride * height > bytes.len() {
        return Err("BMP pixel data extends past the file.".into());
    }

    let palette = bytes[palette_offset..palette_offset + PALETTE_SIZE]
        .chunks_exact(4)
        .flat_map(|c| [c[2], c[1], c[0]])
        .collect();
    let top_down = signed_height < 0;
    let mut pixels = Vec::with_capacity(width * height);

    for y in 0..height {
        let source_y = if top_down { y } else { height - 1 - y };
        let row = pixel_offset + source_y * stride;
        pixels.extend(bytes[row..row + width].iter().map(|p| i32::from(*p)));
    }

    Ok(Decoded {
        width,
        height,
        pixels,
        palette,
        top_down,
    })
}

/// Any 1-, 4- or 8-bit indexed DIB, uncompressed or RLE8, with or without its
/// file header. Its color table may hold fewer than 256 colors.
pub fn decode_indexed(data: &[u8], file_header: bool) -> Result<Decoded, String> {
    let start = if file_header { FILE_HEADER_SIZE } else { 0 };

    if start + INFO_HEADER_SIZE > data.len() {
        return Err("Truncated bitmap header.".into());
    }

    if file_header && data[..2] != SIGNATURE {
        return Err("Missing BMP signature.".into());
    }

    let header_size = u32_at(data, start) as usize;
    let width = u32_at(data, start + 4) as usize;
    let signed_height = i64::from(i32_at(data, start + 8));
    let height = signed_height.unsigned_abs() as usize;
    let bits = u16_at(data, start + 14) as usize;
    let compression = u32_at(data, start + 16);
    let mut count = u32_at(data, start + 32) as usize;

    if header_size < INFO_HEADER_SIZE
        || start + header_size > data.len()
        || !(1..=4096).contains(&width)
        || !(1..=4096).contains(&height)
        || u16_at(data, start + 12) != 1
    {
        return Err("Invalid bitmap dimensions or header.".into());
    }

    if ![1, 4, 8].contains(&bits) || compression > RLE8 || (compression == RLE8 && (bits != 8 || signed_height < 0)) {
        return Err("Unsupported indexed bitmap encoding.".into());
    }

    if count == 0 {
        count = 1 << bits;
    }

    let palette_start = start + header_size;

    if count > 1 << bits || palette_start + count * 4 > data.len() {
        return Err("Invalid bitmap color table.".into());
    }

    let pixels_start = if file_header {
        u32_at(data, 10) as usize
    } else {
        palette_start + count * 4
    };

    if pixels_start < palette_start + count * 4 || pixels_start > data.len() {
        return Err("Invalid bitmap pixel offset.".into());
    }

    let pixels = if compression == RLE8 {
        let size = u32_at(data, start + 20) as usize;

        if size == 0 || pixels_start + size > data.len() {
            return Err("Truncated RLE8 bitmap data.".into());
        }

        crate::pe::decode_rle8(&data[pixels_start..pixels_start + size], width, height)?.0
    } else {
        let stride = (width * bits).div_ceil(32) * 4;

        if pixels_start + stride * height > data.len() {
            return Err("Truncated bitmap rows.".into());
        }

        let mut pixels = Vec::with_capacity(width * height);

        for y in 0..height {
            let row = pixels_start + (if signed_height < 0 { y } else { height - 1 - y }) * stride;
            pixels.extend((0..width).map(|x| {
                let bit = x * bits;
                i32::from((data[row + bit / 8] >> (8 - bits - bit % 8)) & ((1_u16 << bits) - 1) as u8)
            }));
        }

        pixels
    };

    if pixels.iter().any(|p| *p < 0 || *p as usize >= count) {
        return Err("Bitmap pixel exceeds the color table.".into());
    }

    let mut palette = vec![0; COLORS * 3];

    for index in 0..count {
        let at = palette_start + index * 4;
        palette[index * 3..index * 3 + 3].copy_from_slice(&[data[at + 2], data[at + 1], data[at]]);
    }

    Ok(Decoded {
        width,
        height,
        pixels,
        palette,
        top_down: signed_height < 0,
    })
}

/// A file without its file header. `bytes` must be a valid file.
pub fn to_dib(bytes: &[u8]) -> Result<Vec<u8>, String> {
    decode(bytes)?;
    Ok(bytes[FILE_HEADER_SIZE..].to_vec())
}

/// A file around an 8-bit uncompressed DIB with 256 colors.
pub fn from_dib(bytes: &[u8]) -> Result<Vec<u8>, String> {
    if bytes.len() < INFO_HEADER_SIZE {
        return Err("DIB data is shorter than its information header.".into());
    }

    let header_size = u32_at(bytes, 0) as usize;

    if header_size < INFO_HEADER_SIZE || header_size > bytes.len() {
        return Err("DIB information header is invalid.".into());
    }

    if u16_at(bytes, 12) != 1 {
        return Err("DIB plane count is not one.".into());
    }

    if u16_at(bytes, 14) != 8 {
        return Err("SCURK clipboard input requires an 8-bit indexed DIB.".into());
    }

    if u32_at(bytes, 16) != 0 {
        return Err("SCURK clipboard input requires an uncompressed DIB.".into());
    }

    let color_count = match u32_at(bytes, 32) {
        0 => COLORS,
        count => count as usize,
    };

    if color_count != COLORS {
        return Err("SCURK clipboard input requires exactly 256 palette colors.".into());
    }

    let pixel_offset = header_size + color_count * 4;

    if pixel_offset > bytes.len() {
        return Err("DIB palette extends past the clipboard data.".into());
    }

    let mut wrapped = vec![0; FILE_HEADER_SIZE];
    wrapped[..2].copy_from_slice(&SIGNATURE);
    wrapped[2..6].copy_from_slice(&((FILE_HEADER_SIZE + bytes.len()) as u32).to_le_bytes());
    wrapped[10..14].copy_from_slice(&((FILE_HEADER_SIZE + pixel_offset) as u32).to_le_bytes());
    wrapped.extend_from_slice(bytes);
    decode(&wrapped)?;
    Ok(wrapped)
}
