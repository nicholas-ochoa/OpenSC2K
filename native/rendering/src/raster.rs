//! CPU pixels of the painter draws. A sprite pixel with any alpha replaces the
//! pixel below it, as Godot's `Image.blend_rect` does with the opaque indexed
//! artwork. Previews, exports and the CPU city view use this.
use super::{
    Builder, Draw, Rect,
    sprites::{PLACEHOLDER, Sprite, Sprites},
};
use std::collections::HashMap;

/// RGBA8 pixels of `bounds` with the draws composited in order over `background`.
/// A shadow draw changes the pixels below its opaque pixels through `shadows`.
pub fn composite(draws: &[Draw], sprites: &Sprites, shadows: &HashMap<[u8; 4], [u8; 4]>, bounds: Rect, background: [u8; 4]) -> Vec<u8> {
    let (w, h) = (bounds.w.max(0) as usize, bounds.h.max(0) as usize);
    let mut pixels = background.repeat(w * h);
    for draw in draws {
        let clipped = draw.rect.clip(bounds);
        if !clipped.area() {
            continue;
        }
        let sprite = &sprites.images[&draw.image];
        for y in clipped.y..clipped.y + clipped.h {
            let source_row = ((y - draw.rect.y) * sprite.w) as usize;
            let target_row = ((y - bounds.y) as usize) * w;
            for x in clipped.x..clipped.x + clipped.w {
                let source = (source_row + (x - draw.rect.x) as usize) * 4;
                if sprite.rgba[source + 3] == 0 {
                    continue;
                }
                let target = (target_row + (x - bounds.x) as usize) * 4;
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

impl Builder {
    /// RGBA8 pixels of `bounds` and the uncut draws that meet it.
    pub fn raster(&mut self, bounds: Rect, background: [u8; 4]) -> Result<(Vec<u8>, Vec<Draw>), String> {
        let draws = self.collect(bounds)?;
        Ok((composite(&draws, &self.sprites, &self.shadows, bounds, background), draws))
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
    /// The uncut draws of one tile, in painter order. The tile cache is not used.
    pub fn tile_draws(&mut self, x: i32, y: i32) -> Result<Vec<Draw>, String> {
        if x < 0 || y < 0 || x >= self.city.edge || y >= self.city.edge {
            return Ok(Vec::new());
        }
        self.paint(x, y)
    }
}
