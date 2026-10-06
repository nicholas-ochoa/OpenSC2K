//! Draw the visible regions into a frame through the cycling palette.

use super::Frame;
use super::camera::Camera;
use super::pixel;
use super::regions::{ARTWORK_FACTOR, CLEAR, CLEAR_COLOR, REGION, Regions};

/// The 256 frame colors of `palette` (RGB bytes) after the cycle `map`, which
/// gives the source entry of each index.
pub fn cycled_colors(palette: &[u8], map: &[i32]) -> [u32; 256] {
    let mut colors = [0; 256];

    for (index, color) in colors.iter_mut().enumerate() {
        let source = map.get(index).copied().unwrap_or(index as i32).clamp(0, 255) as usize;
        let rgb = palette.get(source * 3..source * 3 + 3).unwrap_or(&[0, 0, 0]);
        *color = pixel([rgb[0], rgb[1], rgb[2]]);
    }

    colors
}

/// Draw the map of `camera` into the viewport of `frame`. Pixels without paint
/// take `background`.
pub fn draw_map(frame: &mut Frame, camera: &Camera, regions: &mut Regions, colors: &[u32; 256], background: u32) {
    if regions.hd {
        return draw_map_hd(frame, camera, regions, background);
    }

    let viewport = camera.viewport;
    let (x0, y0) = (viewport.x.max(0.0) as usize, viewport.y.max(0.0) as usize);
    let x1 = ((viewport.x + viewport.width) as usize).min(frame.width);
    let y1 = ((viewport.y + viewport.height) as usize).min(frame.height);

    if x0 >= x1 || y0 >= y1 {
        return;
    }

    let (offset_x, offset_y) = camera.draw_offset();
    let scale = camera.scale();
    let view_scale = scale * f64::from(regions.divisor());
    let (map_width, map_height) = regions.size();

    // the view pixel of each screen column, or -1 off the map
    let columns: Vec<i32> = (x0..x1)
        .map(|x| {
            let view = ((x as f64 + 0.5 - offset_x) / view_scale).floor() as i32;

            if (0..map_width).contains(&view) { view } else { -1 }
        })
        .collect();

    for y in y0..y1 {
        let view_y = ((y as f64 + 0.5 - offset_y) / view_scale).floor() as i32;
        let row = &mut frame.pixels[y * frame.width + x0..y * frame.width + x1];

        if !(0..map_height).contains(&view_y) {
            row.fill(background);
            continue;
        }

        let region_y = view_y / REGION;
        let mut column = 0;

        while column < columns.len() {
            let view_x = columns[column];

            if view_x < 0 {
                row[column] = background;
                column += 1;
                continue;
            }

            let region_x = view_x / REGION;

            let Some(region) = regions.region(region_x, region_y) else {
                row[column] = background;
                column += 1;
                continue;
            };

            let local_y = (view_y - region.y) as usize;
            let line = &region.indices[local_y * region.width as usize..(local_y + 1) * region.width as usize];

            // the run of columns in this region
            while column < columns.len() && columns[column] >= 0 && columns[column] / REGION == region_x {
                let index = line[(columns[column] - region.x) as usize];
                row[column] = if index == CLEAR { background } else { colors[index as usize] };
                column += 1;
            }
        }
    }
}

/// Outline the surface of tile (x, y) of the painter city in `color`.
pub fn outline_tile(frame: &mut Frame, camera: &Camera, city: &sc2k_render::City, tile: (i32, i32), color: u32) {
    let corners = super::picking::surface_polygon(city, tile.0, tile.1).map(|point| camera.source_to_screen(point));

    for index in 0..4 {
        line(frame, corners[index], corners[(index + 1) % 4], color);
    }
}

/// A one-pixel line between two screen points.
pub fn line(frame: &mut Frame, from: (f64, f64), to: (f64, f64), color: u32) {
    let steps = (to.0 - from.0).abs().max((to.1 - from.1).abs()).ceil().max(1.0) as usize;

    for step in 0..=steps {
        let t = step as f64 / steps as f64;
        let (x, y) = ((from.0 + (to.0 - from.0) * t).round(), (from.1 + (to.1 - from.1) * t).round());

        if x >= 0.0 && y >= 0.0 && (x as usize) < frame.width && (y as usize) < frame.height {
            frame.pixels[y as usize * frame.width + x as usize] = color;
        }
    }
}

/// The RGBA pixels of the whole map of `regions`, with moving draws already
/// set, through `colors` over `background`.
pub fn whole_city(regions: &mut Regions, colors: &[u32; 256], background: u32) -> (usize, usize, Vec<u8>) {
    let (width, height) = regions.size();
    let (width, height) = (width.max(0) as usize, height.max(0) as usize);
    let mut rgba = vec![0_u8; width * height * 4];

    for region_y in 0..(height as i32 + REGION - 1) / REGION {
        for region_x in 0..(width as i32 + REGION - 1) / REGION {
            let Some(region) = regions.region(region_x, region_y) else {
                continue;
            };

            for row in 0..region.height as usize {
                for column in 0..region.width as usize {
                    let index = region.indices[row * region.width as usize + column];
                    let color = if index == CLEAR { background } else { colors[index as usize] };
                    let at = ((region.y as usize + row) * width + region.x as usize + column) * 4;
                    rgba[at..at + 4].copy_from_slice(&[(color >> 16) as u8, (color >> 8) as u8, color as u8, 255]);
                }
            }
        }
    }

    (width, height, rgba)
}

/// Draw HD regions: each view pixel holds `ARTWORK_FACTOR` by `ARTWORK_FACTOR`
/// colors, so a close zoom shows the finer art.
fn draw_map_hd(frame: &mut Frame, camera: &Camera, regions: &mut Regions, background: u32) {
    let viewport = camera.viewport;
    let (x0, y0) = (viewport.x.max(0.0) as usize, viewport.y.max(0.0) as usize);
    let x1 = ((viewport.x + viewport.width) as usize).min(frame.width);
    let y1 = ((viewport.y + viewport.height) as usize).min(frame.height);

    if x0 >= x1 || y0 >= y1 {
        return;
    }

    let (offset_x, offset_y) = camera.draw_offset();
    let art_scale = camera.scale() * f64::from(regions.divisor()) / f64::from(ARTWORK_FACTOR);
    let (map_width, map_height) = regions.size();
    let (art_width, art_height) = (map_width * ARTWORK_FACTOR, map_height * ARTWORK_FACTOR);
    let art_region = REGION * ARTWORK_FACTOR;
    let columns: Vec<i32> = (x0..x1)
        .map(|x| {
            let art = ((x as f64 + 0.5 - offset_x) / art_scale).floor() as i32;

            if (0..art_width).contains(&art) { art } else { -1 }
        })
        .collect();

    for y in y0..y1 {
        let art_y = ((y as f64 + 0.5 - offset_y) / art_scale).floor() as i32;
        let row = &mut frame.pixels[y * frame.width + x0..y * frame.width + x1];

        if !(0..art_height).contains(&art_y) {
            row.fill(background);
            continue;
        }

        let region_y = art_y / art_region;
        let mut column = 0;

        while column < columns.len() {
            let art_x = columns[column];

            if art_x < 0 {
                row[column] = background;
                column += 1;
                continue;
            }

            let region_x = art_x / art_region;

            let Some(region) = regions.region(region_x, region_y) else {
                row[column] = background;
                column += 1;
                continue;
            };

            let width = (region.width * ARTWORK_FACTOR) as usize;
            let local_y = (art_y - region.y * ARTWORK_FACTOR) as usize;
            let line = &region.colors[local_y * width..(local_y + 1) * width];

            while column < columns.len() && columns[column] >= 0 && columns[column] / art_region == region_x {
                let color = line[(columns[column] - region.x * ARTWORK_FACTOR) as usize];
                row[column] = if color == CLEAR_COLOR { background } else { color };
                column += 1;
            }
        }
    }
}

/// The dark underground colors of cycled frame colors, as
/// Sc2Palette.underground_animation_image: the dry pipe ramp turns brown, the
/// wet pipes stay blue, white turns dark, and the rest darkens by its hue.
pub fn dark_underground(colors: &[u32; 256]) -> [u32; 256] {
    let mut result = [0; 256];

    for (index, color) in colors.iter().enumerate() {
        let channel = |shift: u32| f32::from(((color >> shift) & 0xff) as u8) / 255.0;
        let (r, g, b) = (channel(16), channel(8), channel(0));
        let (high, low) = (r.max(g).max(b), r.min(g).min(b));
        let lerp = |a: [f32; 3], z: [f32; 3], t: f32| [a[0] + (z[0] - a[0]) * t, a[1] + (z[1] - a[1]) * t, a[2] + (z[2] - a[2]) * t];
        let remapped = if (200..=207).contains(&index) {
            lerp([0.22, 0.66, 0.82], [0.66, 0.94, 1.0], g)
        } else if (140..=147).contains(&index) {
            // the fixed blue pipe ramp means no water
            lerp([0.36, 0.20, 0.12], [0.72, 0.46, 0.28], high)
        } else if low > 0.97 {
            [0.125, 0.157, 0.188]
        } else if high - low < 0.08 {
            lerp([0.28, 0.33, 0.38], [0.60, 0.66, 0.70], high)
        } else if b > r * 1.3 && b > g * 1.15 {
            lerp([0.18, 0.43, 0.65], [0.40, 0.78, 0.96], high)
        } else if g > r * 1.2 && g > b * 1.2 {
            lerp([0.18, 0.43, 0.28], [0.45, 0.82, 0.56], high)
        } else {
            [r * 0.6, g * 0.6, b * 0.6]
        };
        let byte = |value: f32| (value.clamp(0.0, 1.0) * 255.0).round() as u32;
        result[index] = (byte(remapped[0]) << 16) | (byte(remapped[1]) << 8) | byte(remapped[2]);
    }

    result
}
