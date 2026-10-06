//! Draw the visible regions into a frame through the cycling palette.

use super::Frame;
use super::camera::Camera;
use super::pixel;
use super::regions::{CLEAR, REGION, Regions};

/// The 256 frame colors of `palette` (RGB bytes) after the cycle `map`, which
/// gives the source entry of each index.
pub fn cycled_colors(palette: &[u8], map: &[i32]) -> [u32; 256] {
    let mut colors = [0; 256];

    for (index, color) in colors.iter_mut().enumerate() {
        let source = map
            .get(index)
            .copied()
            .unwrap_or(index as i32)
            .clamp(0, 255) as usize;
        let rgb = palette
            .get(source * 3..source * 3 + 3)
            .unwrap_or(&[0, 0, 0]);
        *color = pixel([rgb[0], rgb[1], rgb[2]]);
    }

    colors
}

/// Draw the map of `camera` into the viewport of `frame`. Pixels without paint
/// take `background`.
pub fn draw_map(
    frame: &mut Frame,
    camera: &Camera,
    regions: &mut Regions,
    colors: &[u32; 256],
    background: u32,
) {
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

            if (0..map_width).contains(&view) {
                view
            } else {
                -1
            }
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
            let line = &region.indices
                [local_y * region.width as usize..(local_y + 1) * region.width as usize];

            // the run of columns in this region
            while column < columns.len()
                && columns[column] >= 0
                && columns[column] / REGION == region_x
            {
                let index = line[(columns[column] - region.x) as usize];
                row[column] = if index == CLEAR {
                    background
                } else {
                    colors[index as usize]
                };
                column += 1;
            }
        }
    }
}
