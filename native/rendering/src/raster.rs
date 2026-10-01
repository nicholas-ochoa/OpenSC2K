//! CPU pixels of the painter draws. A sprite pixel with any alpha replaces the
//! pixel below it, as Godot's `Image.blend_rect` does with the opaque indexed
//! artwork. Previews, exports and the CPU city view use this. Ships and sailboats
//! follow the floating rule of `floating.rs`.
use super::{
    Builder, Draw, Rect,
    floating::{self, Ground},
    sprites::{PLACEHOLDER, Sprite, Sprites},
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
