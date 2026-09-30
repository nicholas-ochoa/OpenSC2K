//! Sign foregrounds: indexed RGBA8 pixels in front of a sign. Without the GPU
//! palette shader, the CPU view colors them through the palette cycle.

/// The palette indices of the opaque pixels, in order of first use.
pub fn used_indices(indexed: &[u8]) -> Vec<u8> {
    let mut seen = [false; 256];
    let mut used = Vec::new();

    for pixel in indexed.chunks_exact(4) {
        if pixel[3] == 0 || seen[usize::from(pixel[0])] {
            continue;
        }

        seen[usize::from(pixel[0])] = true;
        used.push(pixel[0]);
    }

    used
}

/// The pixels colored through the cycle `mapping` and the 256 RGBA `palette`
/// colors. Transparent pixels and each alpha stay unchanged.
pub fn colorize(indexed: &[u8], mapping: &[i32], palette: &[u8]) -> Vec<u8> {
    let mut out = indexed.to_vec();

    for pixel in out.chunks_exact_mut(4) {
        if pixel[3] == 0 {
            continue;
        }

        let index = mapping.get(usize::from(pixel[0])).copied().unwrap_or(0).clamp(0, 255) as usize;
        pixel[..3].copy_from_slice(&palette[index * 4..index * 4 + 3]);
    }

    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn used_indices_skip_transparent_pixels() {
        let pixels = [7, 7, 7, 255, 3, 3, 3, 0, 9, 9, 9, 255, 7, 7, 7, 255];

        assert_eq!(used_indices(&pixels), vec![7, 9]);
    }

    #[test]
    fn colors_follow_the_cycle() {
        let pixels = [1, 1, 1, 255, 2, 2, 2, 0];
        let mapping: Vec<i32> = (0..256).map(|i| if i == 1 { 5 } else { i }).collect();
        let palette: Vec<u8> = (0..=255).flat_map(|i| [i, i, 0, 255]).collect();

        assert_eq!(colorize(&pixels, &mapping, &palette), vec![5, 5, 0, 255, 2, 2, 2, 0]);
    }
}
