//! CPU pixels of the painter draws. A sprite pixel with any alpha replaces the
//! pixel below it, as Godot's `Image.blend_rect` does with the opaque indexed
//! artwork. Previews, exports and the CPU city view use this. Ships and sailboats
//! follow the floating rule of `floating.rs`.
use super::{
    Builder, Draw, Rect,
    floating::{self, Ground},
    sprites::{PLACEHOLDER, Sprite, Sprites},
    surface_grid,
};

use std::collections::{BTreeSet, HashMap};

/// The tiles that need missing artwork. `cells` and `sprites` pair up.
#[derive(Default)]
pub struct MissingTiles {
    pub cells: Vec<i32>,
    pub sprites: Vec<i32>,
    pub all: Vec<i32>,
}

/// The pixel owner of a draw that floating draws do not meet: the background,
/// the water surface, or another moving draw.
const OPEN: i64 = -1;

/// RGBA8 pixels of `bounds` with the draws composited in order over `background`.
/// A shadow draw changes the pixels below its opaque pixels through `shadows`.
/// Floating draws follow the rule of `floating.rs` on the `ground` map.
pub fn composite(
    draws: &[Draw],
    sprites: &Sprites,
    shadows: &HashMap<[u8; 4], [u8; 4]>,
    bounds: Rect,
    background: [u8; 4],
    ground: Ground,
) -> Vec<u8> {
    let (w, h) = (bounds.w.max(0) as usize, bounds.h.max(0) as usize);
    let mut pixels = background.repeat(w * h);

    // The last painter of each pixel: a static tile depth, OPEN, or a floating
    // draw `f` stored as `-2 - f`.
    let mut owners = vec![OPEN; w * h];
    let mut floating: Vec<(&Draw, Vec<i32>)> = Vec::new();
    let mut tile_depth = OPEN;

    for draw in draws {
        // Traffic draws have no depth. They belong to the tile before them.
        if !draw.moving && draw.depth >= 0 {
            tile_depth = draw.depth;
        }

        let clipped = draw.rect.clip(bounds);

        if !clipped.area() {
            continue;
        }

        let sprite = &sprites.images[&draw.image];
        let water = !draw.moving && ground.water_surface(draw.sprite);
        let owner = if draw.moving && draw.floating >= 0 {
            floating.push((draw, floating::waterline(sprite)));
            -1 - floating.len() as i64
        } else if draw.moving || water {
            OPEN
        } else {
            tile_depth
        };

        for y in clipped.y..clipped.y + clipped.h {
            let source_row = ((y - draw.rect.y) * sprite.w) as usize;
            let target_row = ((y - bounds.y) as usize) * w;

            for x in clipped.x..clipped.x + clipped.w {
                let source = (source_row + (x - draw.rect.x) as usize) * 4;

                if sprite.rgba[source + 3] == 0 {
                    continue;
                }

                let at = target_row + (x - bounds.x) as usize;

                if !paints_over(owners[at], owner, water, x, &floating, ground) {
                    continue;
                }

                let target = at * 4;
                owners[at] = owner;

                if draw.shadow {
                    let below: [u8; 4] = pixels[target..target + 4].try_into().unwrap();

                    if let Some(darker) = shadows.get(&below) {
                        pixels[target..target + 4].copy_from_slice(darker);
                    }
                } else {
                    pixels[target..target + 4].copy_from_slice(&sprite.rgba[source..source + 4]);
                }
            }
        }
    }

    pixels
}

/// The largest CPU raster band of full-color art, in output pixels (64 MiB).
const MAX_ARTWORK_PIXELS: usize = 16 * 1024 * 1024;

/// A shadow over full-color art darkens the art by this factor. Over indexed
/// pixels it uses the palette shadow colors.
const ARTWORK_SHADOW: f32 = 0.62;

/// RGBA8 pixels of `bounds` at `factor` output pixels for each view pixel, with
/// the full-color art of the draws that have it. Art is filtered bilinearly in
/// premultiplied color and blends over the pixels below. Indexed sprites repeat
/// their pixels. `frame` selects the frame of animation strips.
#[allow(clippy::too_many_arguments)]
pub fn composite_artwork(
    draws: &[Draw],
    sprites: &Sprites,
    shadows: &HashMap<[u8; 4], [u8; 4]>,
    bounds: Rect,
    background: [u8; 4],
    ground: Ground,
    factor: i32,
    frame: i64,
    grid: bool,
) -> Result<Vec<u8>, String> {
    if ![1, 2, 4].contains(&factor) {
        return Err("invalid artwork raster scale".into());
    }

    let w = (bounds.w.max(0) * factor) as usize;
    let h = (bounds.h.max(0) * factor) as usize;

    if w * h > MAX_ARTWORK_PIXELS {
        return Err("artwork raster band exceeds 64 MiB".into());
    }

    let mut pixels = background.repeat(w * h);
    let mut owners = vec![OPEN; w * h];
    let mut floating: Vec<(&Draw, Vec<i32>)> = Vec::new();
    let mut tile_depth = OPEN;

    for draw in draws {
        if !draw.moving && draw.depth >= 0 {
            tile_depth = draw.depth;
        }

        let artwork = if draw.shadow { None } else { sprites.artwork_source(draw.image) };
        let rect = if artwork.is_some() { sprites.artwork_rect(draw) } else { draw.rect };
        let clipped = rect.clip(bounds);

        if !clipped.area() {
            continue;
        }

        let sprite = &sprites.images[&draw.image];
        let water = !draw.moving && ground.water_surface(draw.sprite);
        let owner = if draw.moving && draw.floating >= 0 {
            floating.push((draw, floating::waterline(sprite)));
            -1 - floating.len() as i64
        } else if draw.moving || water {
            OPEN
        } else {
            tile_depth
        };

        let mask = sprites.traffic_masks.get(&draw.image);

        for py in (clipped.y - bounds.y) * factor..(clipped.y + clipped.h - bounds.y) * factor {
            let y = bounds.y + py / factor;
            // the sample position inside the rectangle, from 0 to 1
            let v = ((py as f32 + 0.5) / factor as f32 + (bounds.y - rect.y) as f32) / rect.h as f32;

            for px in (clipped.x - bounds.x) * factor..(clipped.x + clipped.w - bounds.x) * factor {
                let x = bounds.x + px / factor;
                let u = ((px as f32 + 0.5) / factor as f32 + (bounds.x - rect.x) as f32) / rect.w as f32;

                let color = match artwork {
                    Some((source, mirrored)) => {
                        let art = &sprites.artwork[&source];
                        let mut color = sample_artwork(art, if mirrored { 1.0 - u } else { u }, v, frame);

                        if let Some(mask) = mask {
                            let mx = ((u * mask.w as f32) as i32).clamp(0, mask.w - 1);
                            let my = ((v * mask.h as f32) as i32).clamp(0, mask.h - 1);
                            color[3] = (u16::from(color[3]) * u16::from(mask.rgba[((my * mask.w + mx) * 4 + 3) as usize]) / 255) as u8;
                        }

                        color
                    }
                    None => {
                        let source = (((y - draw.rect.y) * sprite.w + x - draw.rect.x) * 4) as usize;
                        sprite.rgba[source..source + 4].try_into().unwrap()
                    }
                };

                if color[3] == 0 {
                    continue;
                }

                let at = py as usize * w + px as usize;

                // Floating draws use the view pixel of the original sprite.
                if !paints_over(owners[at], owner, water, x, &floating, ground) {
                    continue;
                }

                let target = &mut pixels[at * 4..at * 4 + 4];
                owners[at] = owner;

                if draw.shadow {
                    let below: [u8; 4] = (&*target).try_into().unwrap();

                    match shadows.get(&below) {
                        Some(darker) => target.copy_from_slice(darker),
                        None => {
                            for channel in target.iter_mut().take(3) {
                                *channel = (f32::from(*channel) * ARTWORK_SHADOW).round() as u8;
                            }
                        }
                    }
                } else if artwork.is_some() {
                    blend_over(target, color);
                } else {
                    target.copy_from_slice(&color);
                }
            }
        }

        if grid && artwork.is_some() && draw.surface_grid != 0 {
            surface_grid::raster(draw, bounds, factor, &mut pixels, &owners, owner, sprite);
        }
    }

    Ok(pixels)
}

/// The art at `u`, `v` (0 to 1 over its rectangle), in the frame of `frame`.
/// Bilinear filtering of premultiplied colors; samples stay inside the frame.
fn sample_artwork(art: &super::sprites::Artwork, u: f32, v: f32, frame: i64) -> [u8; 4] {
    let image = &art.image;
    let frames = i32::from(art.frames.max(1));
    let frame_height = image.h / frames;
    let top = frame.rem_euclid(i64::from(frames)) as i32 * frame_height;
    let sx = u * image.w as f32 - 0.5;
    let sy = v * frame_height as f32 - 0.5;
    let (x0, y0) = (sx.floor(), sy.floor());
    let (fx, fy) = (sx - x0, sy - y0);
    let mut sum = [0.0_f32; 4];

    for (dx, dy, weight) in [
        (0, 0, (1.0 - fx) * (1.0 - fy)),
        (1, 0, fx * (1.0 - fy)),
        (0, 1, (1.0 - fx) * fy),
        (1, 1, fx * fy),
    ] {
        let x = (x0 as i32 + dx).clamp(0, image.w - 1);
        let y = (y0 as i32 + dy).clamp(0, frame_height - 1) + top;
        let at = ((y * image.w + x) * 4) as usize;
        let alpha = f32::from(image.rgba[at + 3]) / 255.0 * weight;

        for (channel, value) in sum.iter_mut().take(3).enumerate() {
            *value += f32::from(image.rgba[at + channel]) * alpha;
        }

        sum[3] += alpha;
    }

    if sum[3] <= 0.0 {
        return [0; 4];
    }

    [
        (sum[0] / sum[3]).round().clamp(0.0, 255.0) as u8,
        (sum[1] / sum[3]).round().clamp(0.0, 255.0) as u8,
        (sum[2] / sum[3]).round().clamp(0.0, 255.0) as u8,
        (sum[3] * 255.0).round().clamp(0.0, 255.0) as u8,
    ]
}

/// Blends `color` over `target`, both with straight alpha.
fn blend_over(target: &mut [u8], color: [u8; 4]) {
    let alpha = f32::from(color[3]) / 255.0;
    let below = f32::from(target[3]) / 255.0;
    let out = alpha + below * (1.0 - alpha);

    if out <= 0.0 {
        return;
    }

    for channel in 0..3 {
        let value = (f32::from(color[channel]) * alpha + f32::from(target[channel]) * below * (1.0 - alpha)) / out;
        target[channel] = value.round().clamp(0.0, 255.0) as u8;
    }

    target[3] = (out * 255.0).round() as u8;
}

/// Whether a pixel of `owner` paints over the pixel of `below` at screen `x`.
/// `water` marks a water surface draw, which owns its pixels as OPEN.
fn paints_over(below: i64, owner: i64, water: bool, x: i32, floating: &[(&Draw, Vec<i32>)], ground: Ground) -> bool {
    // A static draw hides a floating column only when the column stands under or
    // behind the draw's tile.
    if below < OPEN && (water || owner >= 0) {
        let (draw, line) = &floating[(-2 - below) as usize];
        let row = line[(x - draw.rect.x) as usize];

        return !water && ground.hides(owner, x, draw.rect.y + row, draw.floating);
    }

    // A floating draw paints over the static draws that do not hide its column.
    if owner < OPEN && below >= 0 {
        let (draw, line) = &floating[(-2 - owner) as usize];
        let row = line[(x - draw.rect.x) as usize];

        return !ground.hides(below, x, draw.rect.y + row, draw.floating);
    }

    true
}

impl Builder {
    /// RGBA8 pixels of `bounds` and the uncut draws that meet it.
    pub fn raster(&mut self, bounds: Rect, background: [u8; 4]) -> Result<(Vec<u8>, Vec<Draw>), String> {
        let draws = self.collect(bounds)?;
        let ground = Ground {
            edge: self.city.edge,
            config: self.config,
        };

        Ok((composite(&draws, &self.sprites, &self.shadows, bounds, background, ground), draws))
    }

    /// RGBA8 pixels of `bounds` with the full-color art, at `factor` pixels for
    /// each view pixel, and the uncut draws that meet it.
    pub fn raster_artwork(&mut self, bounds: Rect, background: [u8; 4], factor: i32, frame: i64) -> Result<(Vec<u8>, Vec<Draw>), String> {
        let draws = self.collect(bounds)?;
        let ground = Ground {
            edge: self.city.edge,
            config: self.config,
        };
        let grid = self.config.effects & super::effects::GRID != 0;
        let pixels = composite_artwork(
            &draws,
            &self.sprites,
            &self.shadows,
            bounds,
            background,
            ground,
            factor,
            frame,
            grid,
        )?;

        Ok((pixels, draws))
    }

    /// Every sprite ID that the city needs and the artwork lacks, in order. The
    /// pass paints each tile with placeholders, then forgets the painted tiles.
    pub fn missing_sprites(&mut self) -> Vec<i32> {
        self.sprites.images.insert(
            PLACEHOLDER,
            Sprite {
                w: 1,
                h: 1,
                rgba: vec![0; 4],
                la: vec![0; 2],
            },
        );
        self.sprites.placeholders = true;
        self.sprites.missing.clear();

        for x in 0..self.city.edge {
            for y in 0..self.city.edge {
                // Missing sprites become placeholders, so painting cannot fail here.
                let _ = self.paint(x, y);
            }
        }

        self.sprites.placeholders = false;
        self.sprites.images.remove(&PLACEHOLDER);
        std::mem::take(&mut self.sprites.missing).into_iter().collect()
    }

    /// The tiles of `window` that need artwork the sprites lack: the cell index
    /// and the lowest missing sprite ID of each tile, and every missing ID.
    pub fn missing_tiles(&mut self, window: Rect) -> MissingTiles {
        self.sprites.images.insert(
            PLACEHOLDER,
            Sprite {
                w: 1,
                h: 1,
                rgba: vec![0; 4],
                la: vec![0; 2],
            },
        );
        self.sprites.placeholders = true;
        let mut result = MissingTiles::default();
        let mut all = BTreeSet::new();
        let (x0, y0) = (window.x.max(0), window.y.max(0));
        let (x1, y1) = ((window.x + window.w).min(self.city.edge), (window.y + window.h).min(self.city.edge));

        for x in x0..x1 {
            for y in y0..y1 {
                self.sprites.missing.clear();

                // Missing sprites become placeholders, so painting cannot fail here.
                let _ = self.paint(x, y);

                if let Some(&first) = self.sprites.missing.first() {
                    result.cells.push(self.city.index(x, y) as i32);
                    result.sprites.push(first);
                    all.extend(self.sprites.missing.iter().copied());
                }
            }
        }

        self.sprites.missing.clear();
        self.sprites.placeholders = false;
        self.sprites.images.remove(&PLACEHOLDER);
        result.all = all.into_iter().collect();
        result
    }

    /// The uncut draws of one tile, in painter order. The tile cache is not used.
    pub fn tile_draws(&mut self, x: i32, y: i32) -> Result<Vec<Draw>, String> {
        if x < 0 || y < 0 || x >= self.city.edge || y >= self.city.edge {
            return Ok(Vec::new());
        }

        self.paint(x, y)
    }
}
