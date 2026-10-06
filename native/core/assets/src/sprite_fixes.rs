//! The sprite corrections of sc2kfix, as Sc2kfixSpriteFixes. A correction
//! applies only to a sprite whose size and pixels match the original Windows
//! sprite, so another graphics source keeps its own art.

use sc2k_formats::crc32;

const TRANSPARENT: i32 = -1;

/// One correction: the size and CRC-32 of the original pixels, a shift to the
/// right, and pixel edits as x, y, and index triples.
pub struct Fix<'a> {
    pub width: usize,
    pub height: usize,
    pub crc32: u32,
    pub shift_x: i64,
    pub edits: &'a [i64],
}

/// The CRC-32 of palette indices as little-endian 32-bit values.
fn pixels_crc(pixels: &[i32]) -> u32 {
    let bytes: Vec<u8> = pixels.iter().flat_map(|pixel| pixel.to_le_bytes()).collect();

    crc32::calculate(&bytes)
}

/// The corrected pixels, or `None` when `pixels` are not the original sprite.
pub fn corrected(pixels: &[i32], width: usize, height: usize, fix: &Fix) -> Option<Vec<i32>> {
    if width != fix.width || height != fix.height || pixels.len() != width * height || pixels_crc(pixels) != fix.crc32 {
        return None;
    }

    let mut result = vec![TRANSPARENT; pixels.len()];

    for y in 0..height {
        for x in 0..width {
            let source = x as i64 - fix.shift_x;

            if (0..width as i64).contains(&source) {
                result[y * width + x] = pixels[y * width + source as usize];
            }
        }
    }

    for edit in fix.edits.chunks_exact(3) {
        let index = edit[1] * width as i64 + edit[0];

        if let Some(slot) = usize::try_from(index).ok().and_then(|index| result.get_mut(index)) {
            *slot = edit[2] as i32;
        }
    }

    Some(result)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_the_original_sprite_changes() {
        let pixels = [1, 2, 3, 4];
        let fix = Fix {
            width: 2,
            height: 2,
            crc32: pixels_crc(&pixels),
            shift_x: 1,
            edits: &[0, 0, 9],
        };
        assert_eq!(corrected(&pixels, 2, 2, &fix), Some(vec![9, 1, -1, 3]));
        assert_eq!(corrected(&[1, 2, 3, 5], 2, 2, &fix), None);
    }
}
