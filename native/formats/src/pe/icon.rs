//! Icon and cursor resources.

use super::{u16_at, u32_at};

/// One entry of an icon or cursor group.
pub struct GroupEntry {
    pub id: u32,
    pub width: u32,
    pub height: u32,
    pub planes: u32,
    pub bits: u32,
    pub length: u32,
}

pub fn decode_group(bytes: &[u8], cursor: bool) -> Result<Vec<GroupEntry>, String> {
    if bytes.len() < 6 || u16_at(bytes, 0) != 0 || u16_at(bytes, 2) != if cursor { 2 } else { 1 } {
        return Err("Invalid icon/cursor group header".into());
    }

    let count = u16_at(bytes, 4) as usize;

    if count == 0 || bytes.len() != 6 + count * 14 {
        return Err("Invalid icon/cursor group length".into());
    }

    let mut entries: Vec<GroupEntry> = Vec::new();

    for i in 0..count {
        let at = (6 + i * 14) as i64;
        let size = |offset: i64| {
            if cursor {
                u16_at(bytes, at + offset)
            } else {
                match bytes[(at + offset / 2) as usize] {
                    0 => 256,
                    value => u32::from(value),
                }
            }
        };

        let (width, height) = (size(0), size(2));
        let id = u16_at(bytes, at + 12);
        let length = u32_at(bytes, at + 8);

        if width == 0 || width > 256 || height == 0 || height > 512 || id == 0 || entries.iter().any(|e| e.id == id) || length == 0 {
            return Err("Invalid icon/cursor group entry".into());
        }

        entries.push(GroupEntry {
            id,
            width,
            height,
            planes: u16_at(bytes, at + 4),
            bits: u16_at(bytes, at + 6),
            length,
        });
    }

    Ok(entries)
}

/// An icon or cursor image: XOR indices, the AND mask, and its palette.
pub struct IconImage {
    pub width: usize,
    pub height: usize,
    pub bits: u32,
    pub hotspot: (u32, u32),
    /// RGB colors.
    pub palette: Vec<u8>,
    pub pixels: Vec<i32>,
    pub and_mask: Vec<u8>,
    pub inverting_pixels: usize,
    pub trailing_bytes: usize,
}

pub fn decode_icon(bytes: &[u8], cursor: bool) -> Result<IconImage, String> {
    let start = if cursor { 4 } else { 0 };

    if bytes.len() < start + 40 {
        return Err("Icon/cursor DIB header is truncated".into());
    }

    let hotspot = if cursor { (u16_at(bytes, 0), u16_at(bytes, 2)) } else { (0, 0) };
    let s = start as i64;
    let header = u32_at(bytes, s) as usize;
    let width = u32_at(bytes, s + 4) as i32;
    let stored_height = u32_at(bytes, s + 8) as i32;
    let bits = u16_at(bytes, s + 14);

    if header != 40 || !(1..=256).contains(&width) || !(2..=512).contains(&stored_height) || stored_height % 2 != 0 {
        return Err("Unsupported icon/cursor DIB dimensions or header".into());
    }

    // the DIB height counts the pixels and the mask
    let (width, height) = (width as usize, (stored_height / 2) as usize);

    if hotspot.0 as usize >= width || hotspot.1 as usize >= height {
        return Err("Cursor hotspot is outside its image".into());
    }

    if u16_at(bytes, s + 12) != 1 || ![1, 4, 8].contains(&bits) || u32_at(bytes, s + 16) != 0 {
        return Err("Icon/cursor DIB must be uncompressed indexed data".into());
    }

    let mut count = u32_at(bytes, s + 32) as usize;

    if count == 0 {
        count = 1 << bits;
    }

    if count > 1 << bits {
        return Err("Invalid icon/cursor palette length".into());
    }

    let pixels_start = start + header + count * 4;
    let xor_stride = (width * bits as usize).div_ceil(32) * 4;
    let and_stride = width.div_ceil(32) * 4;
    let mask_start = pixels_start + xor_stride * height;
    let end = mask_start + and_stride * height;

    if bytes.len() < end {
        return Err("Icon/cursor palette or mask data is truncated".into());
    }

    let palette: Vec<u8> = (0..count)
        .flat_map(|i| {
            let at = start + header + i * 4;
            [bytes[at + 2], bytes[at + 1], bytes[at]]
        })
        .collect();
    let bits_usize = bits as usize;
    let mut pixels = Vec::with_capacity(width * height);
    let mut and_mask = Vec::with_capacity(width * height);
    let mut inverting = 0;

    for y in 0..height {
        let row = height - 1 - y;

        for x in 0..width {
            let bit = x * bits_usize;
            let byte = bytes[pixels_start + row * xor_stride + bit / 8];
            let index = usize::from((byte >> (8 - bits_usize - bit % 8)) & ((1_u16 << bits) - 1) as u8);

            if index >= count {
                return Err("Icon/cursor index is outside its palette".into());
            }

            let mask = (bytes[mask_start + row * and_stride + x / 8] >> (7 - x % 8)) & 1;
            pixels.push(index as i32);
            and_mask.push(mask);

            if mask == 1 && palette[index * 3..index * 3 + 3] != [0, 0, 0] {
                inverting += 1;
            }
        }
    }

    Ok(IconImage {
        width,
        height,
        bits,
        hotspot,
        palette,
        pixels,
        and_mask,
        inverting_pixels: inverting,
        trailing_bytes: bytes.len() - end,
    })
}

/// RGBA8 pixels: the AND mask makes a pixel transparent.
pub fn icon_transparent(pixels: &[i32], and_mask: &[u8], palette: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(pixels.len() * 4);

    for (pixel, mask) in pixels.iter().zip(and_mask) {
        if *mask != 0 {
            out.extend_from_slice(&[0, 0, 0, 0]);
        } else {
            let at = *pixel as usize * 3;
            out.extend_from_slice(&[palette[at], palette[at + 1], palette[at + 2], 255]);
        }
    }

    out
}

/// RGBA8 pixels of the icon drawn over `background`: the AND mask keeps the
/// background, and the XOR colors invert it.
pub fn icon_composite(pixels: &[i32], and_mask: &[u8], palette: &[u8], background: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(pixels.len() * 4);

    for (i, (pixel, mask)) in pixels.iter().zip(and_mask).enumerate() {
        let at = *pixel as usize * 3;
        let backdrop = if *mask != 0 {
            &background[i * 4..i * 4 + 3]
        } else {
            &[0, 0, 0][..]
        };

        out.extend_from_slice(&[
            backdrop[0] ^ palette[at],
            backdrop[1] ^ palette[at + 1],
            backdrop[2] ^ palette[at + 2],
            255,
        ]);
    }

    out
}
