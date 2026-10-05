//! Mapping imported colors to a target palette.

use super::COLORS;

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
