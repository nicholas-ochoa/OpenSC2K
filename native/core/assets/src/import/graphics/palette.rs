//! The palettes of the source platforms. DOS and Macintosh tiles use the
//! Windows palette without its 16 reserved system colors. Their games load the
//! cycling colors at run time, so the stored palette has filler there.

use crate::bytes::read_u16_be;
use crate::palette::{COLOR_COUNT, FAST_CYCLE_COUNT, FAST_CYCLE_START, SLOW_CYCLE_COUNT, SLOW_CYCLE_START};

pub type Rgb = [u8; 3];

const SHIFTED_INDEX_OFFSET: i32 = 16;
const SHIFTED_FAST_CYCLE_END: i32 = 203;
const MAC_PALETTE_HEADER: usize = 16;
const MAC_PALETTE_ENTRY: usize = 16;
const MAC_TABLE_HEADER: usize = 8;
const MAC_TABLE_ENTRY: usize = 8;
const CARRIAGE_RETURN: u8 = 0x0d;
const LINE_FEED: u8 = 0x0a;

/// The colors of 16-bit red, green, and blue channels: the high byte of each.
fn mac_color(bytes: &[u8], offset: usize) -> Rgb {
    [bytes[offset], bytes[offset + 2], bytes[offset + 4]]
}

/// A Macintosh `pltt` resource of 256 colors.
pub fn mac_palette(bytes: &[u8]) -> Option<Vec<Rgb>> {
    if bytes.len() < MAC_PALETTE_HEADER
        || usize::from(read_u16_be(bytes, 0)) != COLOR_COUNT
        || bytes.len() < MAC_PALETTE_HEADER + COLOR_COUNT * MAC_PALETTE_ENTRY
    {
        return None;
    }

    Some(
        (0..COLOR_COUNT)
            .map(|index| mac_color(bytes, MAC_PALETTE_HEADER + index * MAC_PALETTE_ENTRY))
            .collect(),
    )
}

/// The Network Edition ships SC2K.PAL with CR LF line ends and reads it in text mode.
pub fn text_mode_bytes(bytes: &[u8]) -> Vec<u8> {
    (0..bytes.len())
        .filter(|&index| bytes[index] != CARRIAGE_RETURN || bytes.get(index + 1) != Some(&LINE_FEED))
        .map(|index| bytes[index])
        .collect()
}

/// A Macintosh color table: an 8-byte header, then a value and 16-bit RGB channels per color.
pub fn mac_color_table(bytes: &[u8]) -> Vec<Rgb> {
    if bytes.len() < MAC_TABLE_HEADER {
        return Vec::new();
    }

    let count = usize::from(read_u16_be(bytes, 6)) + 1;

    if bytes.len() < MAC_TABLE_HEADER + count * MAC_TABLE_ENTRY {
        return Vec::new();
    }

    (0..count)
        .map(|index| mac_color(bytes, MAC_TABLE_HEADER + index * MAC_TABLE_ENTRY + 2))
        .collect()
}

pub fn rgb_colors(bytes: &[u8]) -> Vec<Rgb> {
    bytes.chunks_exact(3).map(|rgb| [rgb[0], rgb[1], rgb[2]]).collect()
}

/// The slow cycle keeps its index. The Windows tiles draw other filler indices black.
pub fn windows_layout_index(index: i32) -> i32 {
    let slow = SLOW_CYCLE_START as i32..(SLOW_CYCLE_START + SLOW_CYCLE_COUNT) as i32;

    if index < 0 {
        index
    } else if index <= SHIFTED_FAST_CYCLE_END {
        index + SHIFTED_INDEX_OFFSET
    } else if slow.contains(&index) {
        index
    } else {
        0
    }
}

/// Move a DOS or Macintosh palette to the Windows indices that the renderer
/// cycles. Each missing cycle keeps the filler colors of the source palette.
pub fn windows_layout_palette(source: &[Rgb], fast: &[Rgb], slow: &[Rgb]) -> Vec<Rgb> {
    let mut palette = vec![[0; 3]; COLOR_COUNT];

    for (index, color) in source.iter().enumerate().take(COLOR_COUNT) {
        let target = windows_layout_index(index as i32);

        if target > 0 {
            palette[target as usize] = *color;
        }
    }

    if fast.len() == FAST_CYCLE_COUNT {
        palette[FAST_CYCLE_START..FAST_CYCLE_START + FAST_CYCLE_COUNT].copy_from_slice(fast);
    }

    if slow.len() == SLOW_CYCLE_COUNT {
        palette[SLOW_CYCLE_START..SLOW_CYCLE_START + SLOW_CYCLE_COUNT].copy_from_slice(slow);
    }

    palette
}

/// The 768 bytes of a palette.
pub fn rgb_bytes(colors: &[Rgb]) -> Vec<u8> {
    colors.iter().flatten().copied().collect()
}
