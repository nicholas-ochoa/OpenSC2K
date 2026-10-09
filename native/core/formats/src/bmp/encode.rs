//! 8-bit indexed BMP export.

use super::*;

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
    bytes[..2].copy_from_slice(&SIGNATURE);
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
