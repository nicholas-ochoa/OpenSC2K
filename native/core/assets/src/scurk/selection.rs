//! Selection masks of the SCURK editor: one byte for each pixel, nonzero when selected.

pub const REPLACE: i64 = 0;
pub const ADD: i64 = 1;
pub const SUBTRACT: i64 = 2;

/// The mask of the rectangle from `start` to `finish`, clamped to the image.
pub fn rectangle(width: i64, height: i64, start: (i64, i64), finish: (i64, i64)) -> Vec<u8> {
    let mut mask = vec![0; (width.max(0) * height.max(0)) as usize];
    let (x0, y0) = (start.0.min(finish.0).max(0), start.1.min(finish.1).max(0));
    let (x1, y1) = (start.0.max(finish.0).min(width - 1), start.1.max(finish.1).min(height - 1));

    for y in y0..=y1 {
        for x in x0..=x1 {
            mask[(y * width + x) as usize] = 1;
        }
    }

    mask
}

/// The 4-connected pixels of the color at `start`.
pub fn wand(pixels: &[i32], width: i64, height: i64, start: (i64, i64)) -> Vec<u8> {
    let mut mask = vec![0; (width.max(0) * height.max(0)) as usize];
    let inside = |point: (i64, i64)| (0..width).contains(&point.0) && (0..height).contains(&point.1);

    if pixels.len() != mask.len() || !inside(start) {
        return mask;
    }

    let color = pixels[(start.1 * width + start.0) as usize];
    mask[(start.1 * width + start.0) as usize] = 1;
    let mut pending = vec![start];

    while let Some(point) = pending.pop() {
        for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
            let neighbor = (point.0 + dx, point.1 + dy);

            if !inside(neighbor) {
                continue;
            }

            let offset = (neighbor.1 * width + neighbor.0) as usize;

            if mask[offset] == 0 && pixels[offset] == color {
                mask[offset] = 1;
                pending.push(neighbor);
            }
        }
    }

    mask
}

/// The mask moved by `delta`; pixels that leave the image drop.
pub fn translated(mask: &[u8], width: i64, height: i64, delta: (i64, i64)) -> Vec<u8> {
    let mut result = vec![0; (width.max(0) * height.max(0)) as usize];

    for (offset, _) in mask.iter().enumerate().filter(|(_, selected)| **selected != 0) {
        let (x, y) = (offset as i64 % width + delta.0, offset as i64 / width + delta.1);

        if (0..width).contains(&x) && (0..height).contains(&y) {
            result[(y * width + x) as usize] = 1;
        }
    }

    result
}

/// `mask` combined with `value` by `mode`. An empty result is an empty mask.
pub fn combine(mask: &[u8], value: &[u8], mode: i64) -> Vec<u8> {
    let mut result = if mode == REPLACE || mask.len() != value.len() {
        vec![0; value.len()]
    } else {
        mask.to_vec()
    };

    for (slot, &selected) in result.iter_mut().zip(value) {
        *slot = if mode == SUBTRACT {
            if selected != 0 { 0 } else { *slot }
        } else {
            u8::from(selected != 0 || *slot != 0)
        };
    }

    if !result.contains(&1) {
        result.clear();
    }

    result
}

/// The bounds of the selected pixels: x, y, width, and height, or zeros.
pub fn bounds(mask: &[u8], width: i64, height: i64) -> [i64; 4] {
    let (mut min_x, mut min_y, mut max_x, mut max_y) = (width, height, -1, -1);

    for (offset, _) in mask.iter().enumerate().filter(|(_, selected)| **selected != 0) {
        let (x, y) = (offset as i64 % width, offset as i64 / width);
        (min_x, min_y, max_x, max_y) = (min_x.min(x), min_y.min(y), max_x.max(x), max_y.max(y));
    }

    if max_x >= 0 {
        [min_x, min_y, max_x - min_x + 1, max_y - min_y + 1]
    } else {
        [0; 4]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn masks_combine_and_move() {
        let rect = rectangle(3, 2, (2, 1), (1, 0));
        assert_eq!(rect, vec![0, 1, 1, 0, 1, 1]);
        assert_eq!(bounds(&rect, 3, 2), [1, 0, 2, 2]);
        assert_eq!(translated(&rect, 3, 2, (1, 0)), vec![0, 0, 1, 0, 0, 1]);
        assert!(combine(&rect, &rect, SUBTRACT).is_empty());
        assert_eq!(wand(&[1, 1, 2, 1], 2, 2, (0, 0)), vec![1, 1, 0, 1]);
    }
}
