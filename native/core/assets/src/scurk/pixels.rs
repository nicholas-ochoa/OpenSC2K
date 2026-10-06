//! Pixel edits of the SCURK editor on palette indices; -1 is transparent.

/// The eight-row fill textures of the paint menu, one bit for each pixel.
pub const TEXTURE_ROWS: [[u8; 8]; 9] = [
    [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff],
    [0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55],
    [0xee, 0xbb, 0xee, 0xbb, 0xee, 0xbb, 0xee, 0xbb],
    [0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01],
    [0x81, 0x42, 0x24, 0x18, 0x18, 0x24, 0x42, 0x81],
    [0x88, 0x00, 0x22, 0x00, 0x88, 0x00, 0x22, 0x00],
    [0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc],
    [0xff, 0xff, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00],
    [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
];

/// A texture pixel that takes the selected color.
const TEXTURE_SELECTED: i32 = 0xff;
/// Texture pixels that leave the pixel transparent.
const TEXTURE_CLEAR: [i32; 2] = [0xf5, 0];
const PATTERN_EDGE: usize = 8;

/// A block of pixels.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Region {
    pub width: usize,
    pub height: usize,
    pub pixels: Vec<i32>,
}

fn fits(pixels: &[i32], width: i64, height: i64) -> bool {
    width > 0 && height > 0 && pixels.len() as i64 == width * height
}

/// The pixels of the rectangle from `start` to `finish`, clamped to the image.
pub fn copy_region(
    pixels: &[i32],
    width: i64,
    height: i64,
    start: (i64, i64),
    finish: (i64, i64),
) -> Region {
    if !fits(pixels, width, height) {
        return Region::default();
    }

    let low = |a: i64, b: i64, limit: i64| a.min(b).clamp(0, limit - 1);
    let high = |a: i64, b: i64, limit: i64| a.max(b).clamp(0, limit - 1);
    let (x0, y0) = (
        low(start.0, finish.0, width),
        low(start.1, finish.1, height),
    );
    let (x1, y1) = (
        high(start.0, finish.0, width),
        high(start.1, finish.1, height),
    );
    let (copied_width, copied_height) = ((x1 - x0 + 1) as usize, (y1 - y0 + 1) as usize);
    let mut copied = Vec::with_capacity(copied_width * copied_height);

    for y in 0..copied_height {
        let row = (y0 as usize + y) * width as usize + x0 as usize;
        copied.extend_from_slice(&pixels[row..row + copied_width]);
    }

    Region {
        width: copied_width,
        height: copied_height,
        pixels: copied,
    }
}

/// `target` with `source` pasted at `at`; pixels outside the target are dropped.
pub fn paste_region(
    target: &[i32],
    target_width: i64,
    target_height: i64,
    at: (i64, i64),
    source: &[i32],
    source_width: i64,
    source_height: i64,
) -> Vec<i32> {
    let mut result = target.to_vec();

    if !fits(&result, target_width, target_height) || !fits(source, source_width, source_height) {
        return result;
    }

    for source_y in 0..source_height {
        let y = at.1 + source_y;

        if !(0..target_height).contains(&y) {
            continue;
        }

        for source_x in 0..source_width {
            let x = at.0 + source_x;

            if (0..target_width).contains(&x) {
                result[(y * target_width + x) as usize] =
                    source[(source_y * source_width + source_x) as usize];
            }
        }
    }

    result
}

/// The image turned a quarter turn counterclockwise: `height` wide and `width` tall.
pub fn rotate_counterclockwise(pixels: &[i32], width: i64, height: i64) -> Vec<i32> {
    if !fits(pixels, width, height) {
        return Vec::new();
    }

    let mut result = vec![0; pixels.len()];

    for y in 0..height {
        for x in 0..width {
            result[((width - 1 - x) * height + y) as usize] = pixels[(y * width + x) as usize];
        }
    }

    result
}

pub fn flip_horizontal(pixels: &[i32], width: i64, height: i64) -> Vec<i32> {
    if !fits(pixels, width, height) {
        return Vec::new();
    }

    pixels
        .chunks(width as usize)
        .flat_map(|row| row.iter().rev().copied())
        .collect()
}

pub fn flip_vertical(pixels: &[i32], width: i64, height: i64) -> Vec<i32> {
    if !fits(pixels, width, height) {
        return Vec::new();
    }

    pixels
        .chunks(width as usize)
        .rev()
        .flatten()
        .copied()
        .collect()
}

/// The color that a texture pixel gives: the selected color, transparency, or itself.
pub fn resolve_texture_value(source: i32, selected_color: i32) -> i32 {
    if source == TEXTURE_SELECTED {
        selected_color
    } else if TEXTURE_CLEAR.contains(&source) {
        -1
    } else {
        source.clamp(0, 255)
    }
}

/// The color of `point` under a repeating texture.
pub fn texture_color(
    point: (i64, i64),
    selected_color: i32,
    pattern: &[i32],
    pattern_width: i64,
    pattern_height: i64,
) -> i32 {
    if !fits(pattern, pattern_width, pattern_height) {
        return selected_color;
    }

    let source = pattern[(point.1.rem_euclid(pattern_height) * pattern_width
        + point.0.rem_euclid(pattern_width)) as usize];

    resolve_texture_value(source, selected_color)
}

/// The 8 by 8 texture of eight row masks.
pub fn pattern_pixels(rows: &[u8; 8]) -> Vec<i32> {
    (0..PATTERN_EDGE * PATTERN_EDGE)
        .map(|index| {
            if rows[index / PATTERN_EDGE] & (0x80 >> (index % PATTERN_EDGE)) != 0 {
                0xff
            } else {
                0
            }
        })
        .collect()
}

/// Fill the 4-connected area of the color at `start` with a texture.
#[allow(clippy::too_many_arguments)]
pub fn flood_fill_texture(
    pixels: &[i32],
    width: i64,
    height: i64,
    start: (i64, i64),
    selected_color: i32,
    pattern: &[i32],
    pattern_width: i64,
    pattern_height: i64,
) -> Vec<i32> {
    let mut result = pixels.to_vec();
    let inside =
        |point: (i64, i64)| (0..width).contains(&point.0) && (0..height).contains(&point.1);

    if !fits(&result, width, height)
        || !inside(start)
        || !(-1..=255).contains(&selected_color)
        || !fits(pattern, pattern_width, pattern_height)
    {
        return result;
    }

    let target = result[(start.1 * width + start.0) as usize];
    let mut visited = vec![false; result.len()];
    let mut pending = vec![start];

    while let Some(point) = pending.pop() {
        let index = (point.1 * width + point.0) as usize;

        if visited[index] || result[index] != target {
            continue;
        }

        visited[index] = true;
        result[index] = texture_color(
            point,
            selected_color,
            pattern,
            pattern_width,
            pattern_height,
        );

        for neighbor in [
            (point.0 - 1, point.1),
            (point.0 + 1, point.1),
            (point.0, point.1 - 1),
            (point.0, point.1 + 1),
        ] {
            if inside(neighbor) {
                pending.push(neighbor);
            }
        }
    }

    result
}

/// The pixels of a Bresenham line from `start` to `finish`.
pub fn line_points(start: (i64, i64), finish: (i64, i64)) -> Vec<(i64, i64)> {
    let (mut x, mut y) = start;
    let dx = (finish.0 - x).abs();
    let sx = if x < finish.0 { 1 } else { -1 };
    let dy = -(finish.1 - y).abs();
    let sy = if y < finish.1 { 1 } else { -1 };
    let mut error = dx + dy;
    let mut points = Vec::new();

    loop {
        points.push((x, y));

        if (x, y) == finish {
            return points;
        }

        let doubled = error * 2;

        if doubled >= dy {
            error += dy;
            x += sx;
        }

        if doubled <= dx {
            error += dx;
            y += sy;
        }
    }
}

/// The path without the corner pixel of each L-shaped step.
pub fn pixel_perfect_path(points: &[(i64, i64)]) -> Vec<(i64, i64)> {
    let mut result: Vec<(i64, i64)> = Vec::new();

    for &point in points {
        if result.last() == Some(&point) {
            continue;
        }

        if let [.., before, last] = result[..] {
            let first = (last.0 - before.0, last.1 - before.1);
            let second = (point.0 - last.0, point.1 - last.1);
            let unit = |step: (i64, i64)| step.0.abs() + step.1.abs() == 1;

            if unit(first) && unit(second) && first.0 * second.0 + first.1 * second.1 == 0 {
                result.pop();
            }
        }

        result.push(point);
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn regions_turn_and_flip() {
        let pixels = [1, 2, 3, 4, 5, 6];
        assert_eq!(
            rotate_counterclockwise(&pixels, 3, 2),
            vec![3, 6, 2, 5, 1, 4]
        );
        assert_eq!(flip_horizontal(&pixels, 3, 2), vec![3, 2, 1, 6, 5, 4]);
        assert_eq!(flip_vertical(&pixels, 3, 2), vec![4, 5, 6, 1, 2, 3]);
        assert_eq!(
            copy_region(&pixels, 3, 2, (5, 0), (1, 9)).pixels,
            vec![2, 3, 5, 6]
        );
        assert_eq!(
            paste_region(&pixels, 3, 2, (2, 1), &[9, 9], 2, 1),
            vec![1, 2, 3, 4, 5, 9]
        );
    }

    #[test]
    fn fills_follow_the_texture() {
        let pattern = pattern_pixels(&TEXTURE_ROWS[1]);
        let filled = flood_fill_texture(&[-1; 4], 2, 2, (0, 0), 7, &pattern, 8, 8);
        assert_eq!(filled, vec![7, -1, -1, 7]);
        assert_eq!(
            line_points((0, 0), (3, 1)),
            vec![(0, 0), (1, 0), (2, 1), (3, 1)]
        );
        assert_eq!(
            pixel_perfect_path(&[(0, 0), (1, 0), (1, 1), (2, 1)]),
            vec![(0, 0), (1, 1), (2, 1)]
        );
    }
}
