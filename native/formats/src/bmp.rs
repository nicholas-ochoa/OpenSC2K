//! 8-bit indexed Windows bitmaps with 256-color palettes, and their DIB form.

const FILE_HEADER_SIZE: usize = 14;
const INFO_HEADER_SIZE: usize = 40;
const COLORS: usize = 256;
const PALETTE_SIZE: usize = COLORS * 4;
const PIXEL_OFFSET: usize = FILE_HEADER_SIZE + INFO_HEADER_SIZE + PALETTE_SIZE;
const MAX_DIMENSION: i64 = 0x7fff;

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
    if bytes[0] != 0x42 || bytes[1] != 0x4d {
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
    if file_header && &data[..2] != b"BM" {
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
    if ![1, 4, 8].contains(&bits) || compression > 1 || (compression == 1 && (bits != 8 || signed_height < 0)) {
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
    let pixels = if compression == 1 {
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

/// A bottom-up file. `palette` holds 256 RGB colors. A -1 pixel takes `transparent_index`.
pub fn encode(width: i64, height: i64, pixels: &[i32], palette: &[u8], transparent_index: i64) -> Result<Vec<u8>, String> {
    if width <= 0 || width > MAX_DIMENSION || height <= 0 || height > MAX_DIMENSION {
        return Err("BMP dimensions are invalid or too large.".into());
    }
    if pixels.len() as i64 != width * height {
        return Err("BMP pixel count does not match its dimensions.".into());
    }
    if palette.len() != COLORS * 3 {
        return Err("The SimCity 2000 palette is not available.".into());
    }
    if !(0..COLORS as i64).contains(&transparent_index) {
        return Err("BMP transparent palette index is invalid.".into());
    }
    if pixels.iter().any(|p| !(-1..COLORS as i32).contains(p)) {
        return Err("BMP has a palette index outside the 8-bit range.".into());
    }
    let (w, h) = (width as usize, height as usize);
    let stride = row_stride(w);
    let data_size = stride * h;
    let mut bytes = vec![0; PIXEL_OFFSET + data_size];
    bytes[0] = 0x42;
    bytes[1] = 0x4d;
    let put = |bytes: &mut Vec<u8>, at: usize, value: u32| bytes[at..at + 4].copy_from_slice(&value.to_le_bytes());
    put(&mut bytes, 2, (PIXEL_OFFSET + data_size) as u32);
    put(&mut bytes, 10, PIXEL_OFFSET as u32);
    put(&mut bytes, 14, INFO_HEADER_SIZE as u32);
    put(&mut bytes, 18, w as u32);
    put(&mut bytes, 22, h as u32);
    bytes[26] = 1;
    bytes[28] = 8;
    put(&mut bytes, 34, data_size as u32);
    put(&mut bytes, 46, COLORS as u32);
    put(&mut bytes, 50, COLORS as u32);
    for (index, color) in palette.chunks_exact(3).enumerate() {
        let at = FILE_HEADER_SIZE + INFO_HEADER_SIZE + index * 4;
        bytes[at..at + 3].copy_from_slice(&[color[2], color[1], color[0]]);
    }
    for (y, row) in pixels.chunks_exact(w).enumerate() {
        let at = PIXEL_OFFSET + (h - 1 - y) * stride;
        for (target, pixel) in bytes[at..at + w].iter_mut().zip(row) {
            *target = if *pixel < 0 { transparent_index as u8 } else { *pixel as u8 };
        }
    }
    Ok(bytes)
}

/// Pixels in `target` palette indices. Colors equal to the target color of the
/// same index keep it; others take the nearest target color from index 1.
/// `transparent_index` becomes -1. Returns the pixels and the remapped color count.
pub fn map_to_palette(pixels: &[i32], source: &[u8], target: &[u8], transparent_index: usize) -> (Vec<i32>, usize) {
    let mut index_map = [0_i32; COLORS];
    let mut remapped = 0;
    for (index, slot) in index_map.iter_mut().enumerate() {
        if index == transparent_index {
            *slot = -1;
            continue;
        }
        let color = &source[index * 3..index * 3 + 3];
        if color == &target[index * 3..index * 3 + 3] {
            *slot = index as i32;
            continue;
        }
        *slot = nearest(color, target);
        remapped += 1;
    }
    let mapped = pixels.iter().map(|p| index_map[*p as usize & 0xff]).collect();
    (mapped, remapped)
}
/// Pixels in `target` palette indices, like `map_to_palette`, but -1 pixels stay
/// and the count covers only the colors that pixels use.
pub fn map_used_colors(pixels: &[i32], source: &[u8], target: &[u8]) -> (Vec<i32>, usize) {
    let mut index_map: [Option<i32>; COLORS] = [None; COLORS];
    let mut remapped = 0;
    let mapped = pixels
        .iter()
        .map(|&pixel| {
            let Ok(index) = usize::try_from(pixel) else {
                return pixel;
            };
            *index_map[index & 0xff].get_or_insert_with(|| {
                let index = index & 0xff;
                let color = &source[index * 3..index * 3 + 3];
                let value = if color == &target[index * 3..index * 3 + 3] {
                    index as i32
                } else {
                    nearest(color, target)
                };
                remapped += usize::from(value != index as i32);
                value
            })
        })
        .collect();
    (mapped, remapped)
}
fn nearest(color: &[u8], target: &[u8]) -> i32 {
    let (mut best, mut best_distance) = (1, i32::MAX);
    for index in 1..COLORS {
        let distance: i32 = (0..3)
            .map(|c| {
                let delta = i32::from(color[c]) - i32::from(target[index * 3 + c]);
                delta * delta
            })
            .sum();
        if distance < best_distance {
            best = index as i32;
            best_distance = distance;
            if distance == 0 {
                break;
            }
        }
    }
    best
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
    wrapped[0] = 0x42;
    wrapped[1] = 0x4d;
    wrapped[2..6].copy_from_slice(&((FILE_HEADER_SIZE + bytes.len()) as u32).to_le_bytes());
    wrapped[10..14].copy_from_slice(&((FILE_HEADER_SIZE + pixel_offset) as u32).to_le_bytes());
    wrapped.extend_from_slice(bytes);
    decode(&wrapped)?;
    Ok(wrapped)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn palette() -> Vec<u8> {
        (0..256).flat_map(|i| [i as u8, 3, 9]).collect()
    }

    #[test]
    fn round_trip_and_dib() {
        let pixels = vec![1, -1, 7, 255, 0, 3];
        let bytes = encode(3, 2, &pixels, &palette(), 5).unwrap();
        let decoded = decode(&bytes).unwrap();
        assert_eq!(decoded.pixels, vec![1, 5, 7, 255, 0, 3]);
        assert_eq!(&decoded.palette[6..9], &[2, 3, 9]);
        assert!(!decoded.top_down);
        let dib = to_dib(&bytes).unwrap();
        assert_eq!(from_dib(&dib).unwrap(), bytes);
    }

    #[test]
    fn palette_mapping() {
        let mut source = palette();
        source[6..9].copy_from_slice(&[3, 3, 9]);
        let (mapped, remapped) = map_to_palette(&[0, 1, 2], &source, &palette(), 0);
        assert_eq!(mapped, vec![-1, 1, 3]);
        assert_eq!(remapped, 1);
    }

    #[test]
    fn used_color_mapping() {
        let mut source = palette();
        source[6..9].copy_from_slice(&[3, 3, 9]);
        let (mapped, remapped) = map_used_colors(&[-1, 2, 2, 1], &source, &palette());
        assert_eq!(mapped, vec![-1, 3, 3, 1]);
        assert_eq!(remapped, 1);
    }

    #[test]
    fn indexed_depths() {
        // a 4-bit, 3 by 1 DIB with two colors
        let mut dib = vec![0; 40];
        dib[0] = 40;
        dib[4] = 3;
        dib[8] = 1;
        dib[12] = 1;
        dib[14] = 4;
        dib[32] = 2;
        dib.extend_from_slice(&[1, 2, 3, 0, 4, 5, 6, 0]);
        dib.extend_from_slice(&[0x10, 0x10, 0, 0]);
        let decoded = decode_indexed(&dib, false).unwrap();
        assert_eq!(decoded.pixels, vec![1, 0, 1]);
        assert_eq!(&decoded.palette[..6], &[3, 2, 1, 6, 5, 4]);
        dib[40 + 8] = 0x20;
        assert_eq!(decode_indexed(&dib, false).err().unwrap(), "Bitmap pixel exceeds the color table.");
    }

    #[test]
    fn errors() {
        assert_eq!(decode(&[0; 4]).err().unwrap(), "BMP file is shorter than an 8-bit indexed header.");
        assert_eq!(
            encode(0, 1, &[], &palette(), 0).err().unwrap(),
            "BMP dimensions are invalid or too large."
        );
        assert_eq!(from_dib(&[0; 4]).err().unwrap(), "DIB data is shorter than its information header.");
    }
}
